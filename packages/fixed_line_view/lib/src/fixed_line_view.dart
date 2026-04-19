import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:line_snap_scroll_physics/line_snap_scroll_physics.dart';

import 'auto_scroll_behavior.dart';

/// A virtualized fixed-height line view widget.
///
/// Wraps [ListView.builder] with support for active line tracking and
/// configurable auto-scroll behaviors. When [selectable] is true, wraps
/// in a [SelectionArea] for cross-line text selection.
class FixedLineView extends StatefulWidget {
  /// Creates a [FixedLineView].
  const FixedLineView({
    super.key,
    required this.lineCount,
    required this.itemExtent,
    required this.lineBuilder,
    this.activeLineIndex,
    this.autoScroll = AutoScrollBehavior.none,
    this.controller,
    this.physics,
    this.emptyBuilder,
    this.selectable = false,
    this.selectionColor,
    this.lineSnap = false,
  });

  /// Total number of lines.
  final int lineCount;

  /// Height of each line in logical pixels.
  final double itemExtent;

  /// Builder for each line.
  final Widget Function(BuildContext context, int index) lineBuilder;

  /// Currently active line index (e.g., executing line), or null.
  final int? activeLineIndex;

  /// How to auto-scroll when [activeLineIndex] changes.
  final AutoScrollBehavior autoScroll;

  /// Optional external scroll controller.
  final ScrollController? controller;

  /// Optional scroll physics.
  final ScrollPhysics? physics;

  /// Widget to show when [lineCount] is 0.
  final Widget? emptyBuilder;

  /// Whether to enable multi-line text selection.
  ///
  /// When true, wraps the list in a [SelectionArea] so the user can
  /// click-drag across multiple lines to select text.
  final bool selectable;

  /// Selection highlight color used when [selectable] is true.
  ///
  /// Defaults to an opaque VS Code-style blue (`#264F78`) so that
  /// overlapping selection rectangles between adjacent lines render
  /// as a uniform solid color instead of showing darker bands.
  final Color? selectionColor;

  /// Whether to quantize scroll offsets to line boundaries.
  ///
  /// When true, uses [LineSnapScrollController] so every frame renders
  /// at an exact line boundary — no fractional line positions during
  /// drag, fling, or programmatic scroll. Overrides [controller] and
  /// [physics] with line-snapping variants.
  final bool lineSnap;

  @override
  State<FixedLineView> createState() => _FixedLineViewState();
}

class _FixedLineViewState extends State<FixedLineView> {
  ScrollController? _internalController;

  /// True when the user has manually scrolled away from the bottom.
  /// Suppresses auto-scroll until the user scrolls back to bottom.
  bool _userScrolledAway = false;

  ScrollController get _scrollController =>
      widget.controller ??
      (_internalController ??= widget.lineSnap
          ? LineSnapScrollController(itemExtent: widget.itemExtent)
          : ScrollController());

  ScrollPhysics? get _effectivePhysics => widget.lineSnap
      ? LineSnapScrollPhysics(itemExtent: widget.itemExtent)
      : widget.physics;

  @override
  void initState() {
    super.initState();
    // Scroll to position on initial build (e.g., when initialData is
    // non-empty). didUpdateWidget only fires on subsequent rebuilds.
    if (widget.autoScroll == AutoScrollBehavior.bottom &&
        widget.lineCount > 0) {
      _scrollToBottomAfterBuild();
    } else if (widget.autoScroll == AutoScrollBehavior.center &&
        widget.activeLineIndex != null) {
      _scrollToCenterAfterBuild(widget.activeLineIndex!);
    }
  }

  @override
  void didUpdateWidget(FixedLineView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.autoScroll == AutoScrollBehavior.none) return;

    if (widget.autoScroll == AutoScrollBehavior.center &&
        widget.activeLineIndex != null &&
        widget.activeLineIndex != oldWidget.activeLineIndex) {
      _scrollToCenterAfterBuild(widget.activeLineIndex!);
    } else if (widget.autoScroll == AutoScrollBehavior.bottom &&
        !_userScrolledAway &&
        (widget.lineCount != oldWidget.lineCount ||
            widget.activeLineIndex != oldWidget.activeLineIndex)) {
      _scrollToBottomAfterBuild();
    }
  }

  /// Whether the scroll position is at (or within one item of) the bottom.
  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels >= position.maxScrollExtent - widget.itemExtent;
  }

  /// Tracks user scroll intent for bottom auto-scroll suppression.
  bool _handleScrollNotification(ScrollNotification notification) {
    if (widget.autoScroll != AutoScrollBehavior.bottom) return false;

    switch (notification) {
      // User is actively dragging — mark as scrolled away if not at bottom.
      case ScrollUpdateNotification(dragDetails: final DragUpdateDetails _)
          when !_isAtBottom():
        _userScrolledAway = true;
      // Scroll settled — re-enable auto-scroll if back at bottom.
      case ScrollEndNotification() when _isAtBottom():
        _userScrolledAway = false;
      default:
        break;
    }
    return false;
  }

  void _scrollToCenterAfterBuild(int index) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;

      final targetOffset = index * widget.itemExtent;
      final viewportHeight = _scrollController.position.viewportDimension;
      final centeredOffset =
          targetOffset - (viewportHeight / 2) + widget.itemExtent;
      final clampedOffset = centeredOffset.clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToBottomAfterBuild() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lineCount == 0) {
      return widget.emptyBuilder ?? const SizedBox.shrink();
    }

    final listView = NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.lineCount,
        itemExtent: widget.itemExtent,
        physics: _effectivePhysics,
        itemBuilder: widget.lineBuilder,
      ),
    );

    if (widget.selectable) {
      return DefaultSelectionStyle(
        selectionColor: widget.selectionColor ?? const Color(0xFF264F78),
        child: SelectionArea(child: listView),
      );
    }

    return listView;
  }
}
