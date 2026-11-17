import 'package:flutter/rendering.dart' show ScrollDirection;
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

  /// Creates a [ScrollPosition] that quantizes every pixel offset to an
  /// [itemExtent] boundary. Flutter's scroll system calls this; callers
  /// do not invoke it directly.
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

  /// The drag offset before rounding, carried from one move of a drag to
  /// the next. Null outside a drag.
  ///
  /// A slow drag moves less than half a line per event. Rounding each
  /// event's offset on its own lands it back on the boundary it started
  /// from, so the list would never move.
  double? _dragPixels;

  /// Rounds [pixels] to a line boundary measured from the viewport's
  /// bottom edge, so lines align to the bottom of the container and any
  /// fractional line appears at the top. This matches terminal and console
  /// convention (VS Code, xterm.js).
  ///
  /// viewportDimension is 0.0 before the first layout, which falls back to
  /// a top-aligned snap.
  double _snap(double pixels) {
    final v = hasViewportDimension ? viewportDimension : 0.0;
    return ((pixels + v) / itemExtent).round() * itemExtent - v;
  }

  @override
  double setPixels(double newPixels) => super.setPixels(_snap(newPixels));

  @override
  void beginActivity(ScrollActivity? newActivity) {
    // A new drag starts from the painted offset, and any other activity
    // ends the drag.
    _dragPixels = null;
    super.beginActivity(newActivity);
  }

  @override
  void applyUserOffset(double delta) {
    updateUserScrollDirection(
      delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    final target =
        (_dragPixels ?? pixels) - physics.applyPhysicsToUserOffset(this, delta);
    setPixels(target);
    // Past a scroll boundary the offset clamps. Carrying on from the
    // clamped offset makes a reversed drag scroll at once, instead of first
    // unwinding the distance dragged past the edge. The test is on the
    // unrounded target: near the top, the nearest boundary can round below
    // zero and clamp even though the drag itself is in range.
    final inRange = target >= minScrollExtent && target <= maxScrollExtent;
    _dragPixels = inRange ? target : pixels;
  }
}
