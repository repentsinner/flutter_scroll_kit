/// Controls automatic scrolling when content or active line changes.
enum AutoScrollBehavior {
  /// No automatic scrolling.
  none,

  /// Keep the active line centered in the viewport.
  center,

  /// Keep the newest content visible at the bottom.
  bottom,
}
