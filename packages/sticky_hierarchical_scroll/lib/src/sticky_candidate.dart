/// A candidate for sticky scroll display.
///
/// Represents a section header that may become sticky as the user scrolls.
/// Modeled after VSCode's `StickyLineCandidate`.
///
/// Supports two position modes:
/// - **Uniform**: all rows share one [itemExtent]. Positions computed as
///   `index * itemExtent`.
/// - **Variable**: cumulative offsets ([startOffset], [scopeEndOffset])
///   precomputed from per-item heights. [itemExtent] is this candidate's
///   own height (used for sticky slot sizing).
final class StickyCandidate<T> {
  /// The hierarchical level (0-based) determining depth.
  final int level;

  /// The original data item this candidate represents.
  final T data;

  /// The index in the original list where this candidate appears.
  final int originalIndex;

  /// The index of the last item within this candidate's scope.
  final int endIndex;

  /// Height of this candidate's row. In uniform mode, shared by all rows.
  /// In variable mode, this candidate's own height.
  final double itemExtent;

  /// Precomputed pixel offset of this candidate's top edge.
  /// When null, falls back to `originalIndex * itemExtent` (uniform mode).
  final double? startOffset;

  /// Precomputed pixel offset of the bottom edge of the last item in scope.
  /// When null, falls back to `(endIndex + 1) * itemExtent` (uniform mode).
  final double? scopeEndOffset;

  StickyCandidate({
    required this.level,
    required this.data,
    required this.originalIndex,
    required this.endIndex,
    required this.itemExtent,
    this.startOffset,
    this.scopeEndOffset,
  });

  /// Pixel position of the top edge of this candidate's row.
  double get startPosition => startOffset ?? originalIndex * itemExtent;

  /// Pixel position of the bottom edge of this candidate's row.
  double get endPosition => startPosition + itemExtent;

  /// Pixel position of the bottom edge of the last item in this
  /// candidate's scope. The scope includes the item at [endIndex],
  /// so its bottom edge is at `(endIndex + 1) * itemExtent` in uniform
  /// mode, or [scopeEndOffset] in variable mode.
  double get scopeEndPosition => scopeEndOffset ?? (endIndex + 1) * itemExtent;
}
