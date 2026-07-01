import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
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
    this.scrollbarGutter,
  }) : assert(
         scrollbarGutter == null || scrollbarGutter >= 0,
         'scrollbarGutter must be null or a non-negative width '
         '(>= 0 also rejects NaN)',
       );

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
  /// When true, [LineSnapScrollPhysics] replaces [physics] so the offset
  /// settles on an exact line boundary at the end of a fling. The
  /// controller is line-snapping only when [FixedLineView] owns it: with
  /// no [controller] passed, the widget creates a
  /// [LineSnapScrollController] that quantizes every pixel update. A
  /// supplied [controller] is used as-is — pass a
  /// [LineSnapScrollController] to keep per-frame quantization while
  /// composing.
  final bool lineSnap;

  /// Trailing gutter reserved for the scrollbar lane.
  ///
  /// Inset as a trailing [ListView] padding so line content and trailing
  /// tap targets stay clear of the ambient scrollbar thumb. The gutter is
  /// static — present in every layout state regardless of whether the thumb
  /// is painted. [FixedLineView] does not render its own [Scrollbar]; it
  /// leaves the bar to the ambient [ScrollBehavior], which paints into the
  /// reserved strip.
  ///
  /// - `null` (default): auto-derive from the effective
  ///   [ScrollbarThemeData.thickness], falling back to the Material
  ///   default (8.0) when the theme leaves it unset.
  /// - `0`: disable the gutter for full-bleed content.
  /// - positive: reserve exactly that width.
  final double? scrollbarGutter;

  @override
  State<FixedLineView> createState() => _FixedLineViewState();
}

class _FixedLineViewState extends State<FixedLineView> {
  ScrollController? _internalController;

  /// True when the user has manually scrolled away from the bottom.
  /// Suppresses auto-scroll until the user scrolls back to bottom.
  bool _userScrolledAway = false;

  /// True while the in-flight scroll sequence is user-driven.
  /// Flutter emits [UserScrollNotification] for drags, flings, mouse-wheel,
  /// and trackpad scrolls — but not for programmatic [ScrollController]
  /// moves. Latching it on that signal (rather than on the presence of
  /// drag details) means a fling's ballistic phase and pointer-scroll
  /// deltas both count as user-driven, while our own auto-scroll never
  /// counts as the user scrolling away.
  bool _userScrolling = false;

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

  /// Sub-pixel distance from the bottom still counted as "at bottom".
  /// The bottom is always exactly [ScrollPosition.maxScrollExtent] (lineSnap
  /// aligns the last line to it, pixel mode lands on it), so this only
  /// absorbs ballistic/spring settling error — never a full hidden line.
  static const double _atBottomTolerance = 1.0;

  /// Whether the scroll position is at the bottom.
  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels >= position.maxScrollExtent - _atBottomTolerance;
  }

  /// Tracks user scroll intent for bottom auto-scroll suppression.
  bool _handleScrollNotification(ScrollNotification notification) {
    if (widget.autoScroll != AutoScrollBehavior.bottom) return false;

    switch (notification) {
      // The user started driving the scroll (drag, fling, mouse-wheel, or
      // trackpad). Latch the sequence as user-driven; programmatic
      // auto-scrolls never emit this.
      case UserScrollNotification(:final direction)
          when direction != ScrollDirection.idle:
        _userScrolling = true;
        if (!_isAtBottom()) _userScrolledAway = true;
      // User-driven scroll in progress (including a fling's ballistic
      // coast): suppress as soon as the viewport leaves the bottom, so an
      // entry arriving mid-scroll doesn't yank it back down.
      case ScrollUpdateNotification() when _userScrolling:
        if (!_isAtBottom()) _userScrolledAway = true;
      // Sequence settled. Resting at the bottom always resumes auto-scroll,
      // however we got there (user fling back, or an external controller
      // jumping to bottom). Resting away from the bottom suppresses only
      // when the user drove the scroll — an auto-scroll that lands short of
      // a freshly-grown extent must not be mistaken for the user leaving.
      case ScrollEndNotification():
        if (_isAtBottom()) {
          _userScrolledAway = false;
        } else if (_userScrolling) {
          _userScrolledAway = true;
        }
        _userScrolling = false;
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

  /// Material default scrollbar thickness, used when the theme leaves
  /// [ScrollbarThemeData.thickness] unset. Mirrors the Material
  /// `Scrollbar` desktop/web default.
  static const double _kDefaultScrollbarThickness = 8.0;

  /// Trailing gutter width to reserve for the scrollbar lane.
  ///
  /// `null` auto-derives from the effective [ScrollbarThemeData.thickness]
  /// (the same source the ambient [Scrollbar] renders from), falling back
  /// to [_kDefaultScrollbarThickness].
  double _resolveScrollbarGutter() =>
      widget.scrollbarGutter ??
      ScrollbarTheme.of(context).thickness?.resolve(const <WidgetState>{}) ??
      _kDefaultScrollbarThickness;

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
        // Reserve the scrollbar lane on the trailing edge so rows and tap
        // targets stay clear of the ambient thumb. The bar itself stays
        // with the ambient ScrollBehavior, which paints into this strip.
        padding: EdgeInsetsDirectional.only(end: _resolveScrollbarGutter()),
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
