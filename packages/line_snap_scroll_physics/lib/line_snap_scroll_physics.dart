/// Line-aligned scroll physics and controller for any ScrollView.
///
/// Provides [LineSnapScrollController] that quantizes every scroll offset
/// to `itemExtent` boundaries (no fractional line positions — ever), and
/// [LineSnapScrollPhysics] for ballistic snap behavior. [ScrollMode]
/// selects line-snap vs platform-default pixel scrolling.
library;

export 'src/line_snap_scroll_controller.dart';
export 'src/line_snap_scroll_physics.dart';
export 'src/scroll_mode.dart';
