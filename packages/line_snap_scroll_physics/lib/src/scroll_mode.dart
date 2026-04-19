/// Controls whether scrolling snaps to line boundaries or scrolls smoothly.
enum ScrollMode {
  /// Snap to `itemExtent` boundaries after every scroll gesture.
  line,

  /// Platform-default smooth scrolling (no snapping).
  pixel,
}
