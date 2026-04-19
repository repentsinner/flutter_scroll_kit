/// Consumer-facing entry in a REPL-style scroll view.
///
/// Implementations describe a single line in the scrollback: either an
/// input (user-submitted) line that pins as a sticky section header, or
/// a response (non-input) line that scrolls as a leaf within the
/// section.
///
/// Coalescing — collapsing repeated identical responses into one line
/// with a count — happens upstream in the consumer's data source. This
/// package consumes the result: [count] > 1 renders a count badge on
/// the row, but the widget does not itself dedupe entries.
abstract class ConsoleEntry {
  /// Display text for this entry.
  String get value;

  /// True when the entry represents user input (pins as a sticky
  /// section header); false for response lines (leaf rows under the
  /// current input section).
  bool get isInput;

  /// Consumer-owned key used to group coalesced entries. The widget
  /// itself does not inspect this — it is exposed on the interface so
  /// consumers can reason about coalescing using a consistent shape.
  String get coalescingKey;

  /// Number of coalesced occurrences represented by this entry. A
  /// value of 1 means a single occurrence (no badge); values greater
  /// than 1 indicate the entry stands in for `count` repeats.
  int get count;

  /// Opaque identity that survives coalescing updates and list
  /// rebuilds. Two entries with `identity == other.identity` refer to
  /// the same logical line in the scrollback even if their `value` or
  /// `count` has changed between frames.
  ///
  /// [ReplView] uses this to anchor viewport position while the user
  /// has scrolled away from the bottom: if the anchored entry still
  /// appears in the next entry list, the viewport is restored to it;
  /// if the anchor has been trimmed out of the scrollback, the view
  /// snaps back to the bottom.
  ///
  /// Equality is compared with `==`. Consumers typically use a
  /// monotonic integer assigned when the underlying message is created
  /// and preserved across coalescing.
  Object get identity;
}
