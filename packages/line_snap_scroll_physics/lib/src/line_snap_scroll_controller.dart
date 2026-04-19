import 'package:flutter/widgets.dart';

/// A [ScrollController] whose positions round every pixel update to the
/// nearest `itemExtent` boundary.
///
/// Use this controller to guarantee that the scroll offset is always a
/// multiple of [itemExtent] — during drag, fling, and programmatic
/// scroll. Lines never render at fractional positions.
///
/// Pair with [ListView.itemExtent] set to the same value.
final class LineSnapScrollController extends ScrollController {
  /// Height of each line/item in logical pixels.
  final double itemExtent;

  /// Creates a controller that quantizes scroll offsets to [itemExtent]
  /// boundaries.
  LineSnapScrollController({
    required this.itemExtent,
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  }) : assert(itemExtent > 0, 'itemExtent must be positive');

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _LineSnappedScrollPosition(
      itemExtent: itemExtent,
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
    );
  }
}

class _LineSnappedScrollPosition extends ScrollPositionWithSingleContext {
  final double itemExtent;

  _LineSnappedScrollPosition({
    required this.itemExtent,
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  double setPixels(double newPixels) {
    // Snap relative to the viewport bottom edge so lines align to the
    // bottom of the container. Any fractional line appears at the top,
    // matching terminal/console convention (VS Code, xterm.js).
    //
    // viewportDimension is 0.0 before the first layout; fall back to
    // top-aligned snap in that case.
    final v = hasViewportDimension ? viewportDimension : 0.0;
    final snapped = ((newPixels + v) / itemExtent).round() * itemExtent - v;
    return super.setPixels(snapped);
  }
}
