import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/widgets.dart';

import 'scroll_mode.dart';

/// Scroll physics that snaps to `itemExtent` boundaries.
///
/// Works with any [ScrollView] that uses a fixed item extent. Unlike
/// [FixedExtentScrollPhysics], this is not coupled to
/// [ListWheelScrollView] or [FixedExtentScrollController].
///
/// When [mode] is [ScrollMode.pixel], delegates entirely to the parent
/// physics (platform-default smooth scrolling).
class LineSnapScrollPhysics extends ScrollPhysics {
  /// Height of each line/item in logical pixels.
  final double itemExtent;

  /// Whether to snap ([ScrollMode.line]) or pass through
  /// ([ScrollMode.pixel]).
  final ScrollMode mode;

  const LineSnapScrollPhysics({
    super.parent,
    required this.itemExtent,
    this.mode = ScrollMode.line,
  }) : assert(itemExtent > 0, 'itemExtent must be positive');

  @override
  LineSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LineSnapScrollPhysics(
      parent: buildParent(ancestor),
      itemExtent: itemExtent,
      mode: mode,
    );
  }

  /// Rounds [offset] to the nearest item boundary, aligned relative to
  /// the bottom of the viewport so fractional lines appear at the top.
  double _snapToBottom(double offset, double viewportDimension) {
    return ((offset + viewportDimension) / itemExtent).round() * itemExtent -
        viewportDimension;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (mode == ScrollMode.pixel) {
      return super.createBallisticSimulation(position, velocity);
    }

    // Snap the current position to the nearest item boundary.
    final target = _snapToBottom(
      position.pixels,
      position.viewportDimension,
    ).clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((target - position.pixels).abs() < precisionErrorTolerance) {
      // If we're already at a boundary and velocity is low, let parent
      // handle (which may return null, meaning no simulation needed).
      if (velocity.abs() < toleranceFor(position).velocity) {
        return null;
      }
      // Significant velocity: let parent physics create a fling, then
      // we'll snap when the next ballistic call happens at rest.
      return super.createBallisticSimulation(position, velocity);
    }

    // Animate to the nearest item boundary.
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}
