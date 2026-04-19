import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sticky_hierarchical_scroll/sticky_hierarchical_scroll.dart';

import 'console_entry.dart';

/// A REPL-style scroll view with sticky input headers.
///
/// Renders a flat list of [entries] using
/// [StickyHierarchicalScrollView]. Input entries ([ConsoleEntry.isInput]
/// true) become level-0 sticky section headers; response entries render
/// as level-1 leaves within the surrounding input's scope.
///
/// Behavior:
/// - Fixed-height rows (all entries share [itemExtent]).
/// - Two viewport states:
///   - **Stuck to bottom** (default): the viewport tracks the tail of
///     the list. Coalescing updates, parent rebuilds, and detach/
///     reattach all settle back to `maxScrollExtent`.
///   - **Floating**: when the user drags away from the bottom, the
///     viewport is anchored to a persistent entry
///     ([ConsoleEntry.identity]) plus a pixel offset within that
///     entry. Coalescing and tail-appends leave the anchor content
///     under the viewport unchanged. If the anchor entry is trimmed
///     from the scrollback, the view snaps back to the bottom and
///     returns to stuck state.
///   - Returning to the bottom (dragging back to max extent) exits
///     floating and re-enters stuck.
/// - Optional [trailingItemBuilder] / [trailingItemCount] provides
///   consumer-owned footer rows (prompt line, separators, status
///   messages) that scroll with the content rather than pinning.
///
/// The widget is rendering-only — coalescing happens upstream in the
/// consumer's data source. [ConsoleEntry.count] > 1 on a supplied
/// entry causes [entryBuilder] to receive a multi-count entry; it is
/// the builder's responsibility to render a count badge if desired.
class ReplView<T extends ConsoleEntry> extends StatefulWidget {
  /// Entries to display, in display order (oldest first).
  final List<T> entries;

  /// Builds a single row for a given entry. Used both for the scroll
  /// list items and for the sticky header representation of input
  /// entries — the package does not distinguish between the two
  /// representations; consumers that want differentiated styling can
  /// branch inside the builder on [ConsoleEntry.isInput].
  final Widget Function(BuildContext context, T entry) entryBuilder;

  /// Fixed pixel height of every row (entries and trailing items).
  final double itemExtent;

  /// Maximum number of sticky headers to stack. Defaults to 1
  /// (REPL usage: one input at a time pins at the top of its scope).
  final int maxStickyHeaders;

  /// Decoration applied behind each sticky header. Defaults match
  /// [StickyScrollConfig]'s default.
  final Decoration? stickyDecoration;

  /// Optional external scroll controller. When null, the widget
  /// creates and manages its own.
  final ScrollController? controller;

  /// Scroll physics for the underlying list. Defaults to null
  /// (platform default).
  final ScrollPhysics? physics;

  /// Number of trailing items appended after [entries]. These rows
  /// scroll with the content and are not considered sticky candidates.
  final int trailingItemCount;

  /// Builder for trailing items. [index] is 0-based within the
  /// trailing range.
  final Widget Function(BuildContext context, int index)? trailingItemBuilder;

  const ReplView({
    super.key,
    required this.entries,
    required this.entryBuilder,
    required this.itemExtent,
    this.maxStickyHeaders = 1,
    this.stickyDecoration,
    this.controller,
    this.physics,
    this.trailingItemCount = 0,
    this.trailingItemBuilder,
  }) : assert(
         trailingItemCount == 0 || trailingItemBuilder != null,
         'trailingItemBuilder must be provided when trailingItemCount > 0',
       );

  @override
  State<ReplView<T>> createState() => _ReplViewState<T>();
}

/// A frozen viewport position expressed as an entry identity plus a
/// pixel offset within that entry. Survives coalescing updates and
/// tail-appends; invalidated only when the anchor entry is removed.
class _FloatingAnchor {
  final Object identity;
  final double offsetWithinEntry;

  const _FloatingAnchor({
    required this.identity,
    required this.offsetWithinEntry,
  });
}

class _ReplViewState<T extends ConsoleEntry> extends State<ReplView<T>> {
  ScrollController? _ownController;

  /// Null means stuck to bottom; non-null means floating at the
  /// anchored position.
  _FloatingAnchor? _anchor;

  /// Guard against re-entrant notification handling while we apply a
  /// programmatic [ScrollController.jumpTo]. `jumpTo` fires
  /// synchronous scroll notifications that would otherwise get
  /// interpreted as user scroll events.
  bool _suppressNotifications = false;

  /// True between [ScrollStartNotification] and [ScrollEndNotification]
  /// — covers both drags and ballistic flings. While true, the
  /// settlement logic stays out of the way so programmatic jumps
  /// don't fight a user-driven scroll.
  bool _scrollInProgress = false;

  /// De-dupe post-frame settlement callbacks across multiple builds
  /// that land in the same frame.
  bool _settlementPending = false;

  ScrollController get _scrollController =>
      widget.controller ?? (_ownController ??= ScrollController());

  @override
  void didUpdateWidget(ReplView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _ownController?.dispose();
      _ownController = null;
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  /// Whether the scroll position is at (or within one item of) the
  /// bottom. Treated as `true` when the scroll view is not yet
  /// attached — the initial state is "stuck to bottom."
  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels >= position.maxScrollExtent - widget.itemExtent;
  }

  /// Capture the current scroll position as a floating anchor. Returns
  /// null when no anchor can be formed (empty list or no attached
  /// scroll view).
  _FloatingAnchor? _captureAnchor() {
    if (!_scrollController.hasClients) return null;
    if (widget.entries.isEmpty) return null;
    final pixels = _scrollController.position.pixels;
    final extent = widget.itemExtent;
    final rawIndex = (pixels / extent).floor();
    final index = rawIndex.clamp(0, widget.entries.length - 1);
    final offsetWithinEntry = pixels - (index * extent);
    return _FloatingAnchor(
      identity: widget.entries[index].identity,
      offsetWithinEntry: offsetWithinEntry,
    );
  }

  /// Compute the scroll target pixels for the current state. Returns
  /// null when the target can't be computed yet (no clients).
  ///
  /// As a side effect, clears a stale anchor when its identity is no
  /// longer present in the entry list — treating this as "anchor
  /// trimmed out of the scrollback" and falling back to stuck state.
  double? _computeTargetPixels() {
    if (!_scrollController.hasClients) return null;
    final pos = _scrollController.position;

    if (_anchor == null) {
      return pos.maxScrollExtent;
    }

    for (var i = 0; i < widget.entries.length; i++) {
      if (widget.entries[i].identity == _anchor!.identity) {
        final target = i * widget.itemExtent + _anchor!.offsetWithinEntry;
        return target.clamp(0.0, pos.maxScrollExtent);
      }
    }

    // Anchor content is gone — snap to bottom and clear.
    _anchor = null;
    return pos.maxScrollExtent;
  }

  /// Settle the scroll view to the current target if it differs from
  /// the actual position. Idempotent; safe to call repeatedly.
  void _settleScrollPosition() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    // Don't fight a drag or fling in progress — let the user's gesture
    // land, and re-settle on the next build after the notification
    // flow has updated the anchor.
    if (_scrollInProgress) return;
    final target = _computeTargetPixels();
    if (target == null) return;
    final current = _scrollController.position.pixels;
    if ((current - target).abs() < 0.5) return;
    _suppressNotifications = true;
    try {
      _scrollController.jumpTo(target);
    } finally {
      _suppressNotifications = false;
    }
  }

  /// Update the floating/stuck state from a user-driven scroll
  /// notification. Programmatic jumps are gated by
  /// [_suppressNotifications].
  bool _handleScrollNotification(ScrollNotification notification) {
    if (_suppressNotifications) return false;
    switch (notification) {
      case ScrollStartNotification():
        _scrollInProgress = true;
      case ScrollUpdateNotification(dragDetails: final DragUpdateDetails _)
          when !_isAtBottom():
        // User is in the middle of dragging upward. Enter floating
        // state immediately so new entries arriving mid-drag don't
        // yank the viewport to the bottom. The precise anchor is
        // captured on ScrollEndNotification below.
        _anchor ??= _captureAnchor();
      case ScrollEndNotification():
        _scrollInProgress = false;
        if (_isAtBottom()) {
          _anchor = null;
        } else {
          _anchor = _captureAnchor();
        }
      default:
        break;
    }
    return false;
  }

  void _scheduleSettle() {
    if (_settlementPending) return;
    _settlementPending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _settlementPending = false;
      _settleScrollPosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSettle();

    final decoration =
        widget.stickyDecoration ??
        const BoxDecoration(color: Color(0xFF1E1E1E));

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: StickyHierarchicalScrollView<T>(
        items: widget.entries,
        getLevel: (entry) => entry.isInput ? 0 : 1,
        isSection: (entry) => entry.isInput,
        itemExtent: widget.itemExtent,
        controller: _scrollController,
        physics: widget.physics,
        trailingItemCount: widget.trailingItemCount,
        trailingItemBuilder: widget.trailingItemBuilder,
        itemBuilder: (context, entry, _) => widget.entryBuilder(context, entry),
        config: StickyScrollConfig<T>(
          maxStickyHeaders: widget.maxStickyHeaders,
          stickyDecoration: decoration,
          stickyHeaderBuilder: (context, candidate) =>
              widget.entryBuilder(context, candidate.data),
        ),
      ),
    );
  }
}
