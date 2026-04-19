import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverLayoutDimensions;

import 'sticky_candidate.dart';
import 'sticky_scroll_config.dart';

/// A hierarchical scroll view with sticky section headers.
///
/// Displays a flat list of [items] with sticky section headers that
/// maintain a hierarchical breadcrumb as the user scrolls. Modeled
/// after VSCode's tree Sticky Scroll.
///
/// Sticky headers render as an **overlay** on top of the list (not in a
/// column above it). This matches VS Code's approach and prevents the
/// doubled-header artifact that occurs with column-based layouts.
///
/// Supports two height modes:
/// - **Uniform**: all rows share one [itemExtent].
/// - **Variable**: each item's height comes from [itemHeight]. A
///   cumulative offset table enables O(log n) position lookups.
///   Flutter's `itemExtentBuilder` drives layout performance.
class StickyHierarchicalScrollView<T> extends StatefulWidget {
  /// Items to display.
  final List<T> items;

  /// Extracts the hierarchical level from an item.
  final int Function(T item) getLevel;

  /// Returns true if the item is a section header (sticky candidate).
  final bool Function(T item) isSection;

  /// Builds a widget for each item in the scrollable list.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Fixed pixel height of every row. Required when [itemHeight] is null
  /// (uniform mode). Ignored when [itemHeight] is provided.
  final double? itemExtent;

  /// Per-item height callback for variable-height mode. When provided,
  /// a cumulative offset table is precomputed for O(log n) lookups
  /// and `ListView.builder` uses `itemExtentBuilder`.
  final double Function(T item)? itemHeight;

  /// Sticky scroll configuration.
  final StickyScrollConfig<T> config;

  /// Optional external scroll controller. When null, the widget creates
  /// and manages its own.
  final ScrollController? controller;

  /// Scroll physics for the underlying list. Defaults to null
  /// (platform default: bouncing on Apple, clamping elsewhere).
  final ScrollPhysics? physics;

  /// Callback when a sticky header is tapped.
  final void Function(int index)? onStickyHeaderTap;

  /// Number of trailing items appended after [items]. These items
  /// are not part of the sticky model — they just scroll with the
  /// list. Useful for inline input areas or footers that should
  /// scroll rather than be pinned.
  final int trailingItemCount;

  /// Builder for trailing items. [index] is 0-based within the
  /// trailing range (not the global list index).
  final Widget Function(BuildContext context, int index)? trailingItemBuilder;

  /// Uniform-height constructor. All rows share [itemExtent].
  const StickyHierarchicalScrollView({
    super.key,
    required this.items,
    required this.getLevel,
    required this.isSection,
    required this.itemBuilder,
    required double this.itemExtent,
    required this.config,
    this.controller,
    this.physics,
    this.onStickyHeaderTap,
    this.trailingItemCount = 0,
    this.trailingItemBuilder,
  }) : itemHeight = null;

  /// Variable-height constructor. Each item's height comes from
  /// [itemHeight]. A cumulative offset table is precomputed for
  /// O(log n) position lookups.
  const StickyHierarchicalScrollView.variableHeight({
    super.key,
    required this.items,
    required this.getLevel,
    required this.isSection,
    required this.itemBuilder,
    required double Function(T item) this.itemHeight,
    required this.config,
    this.controller,
    this.physics,
    this.onStickyHeaderTap,
    this.trailingItemCount = 0,
    this.trailingItemBuilder,
  }) : itemExtent = null;

  @override
  State<StickyHierarchicalScrollView<T>> createState() =>
      _StickyHierarchicalScrollViewState<T>();
}

/// Active header with its computed rendering position.
class _ActiveHeader<T> {
  final StickyCandidate<T> candidate;
  final double top;

  const _ActiveHeader(this.candidate, this.top);
}

class _StickyHierarchicalScrollViewState<T>
    extends State<StickyHierarchicalScrollView<T>> {
  ScrollController? _ownController;
  final List<StickyCandidate<T>> _stickyCandidates = [];
  List<_ActiveHeader<T>> _currentActiveHeaders = [];

  /// Cumulative offset table for variable-height mode.
  /// `_cumulativeOffsets[i]` is the pixel offset of the top edge of item `i`.
  /// Length is `items.length + 1` (last entry = total scroll extent).
  List<double> _cumulativeOffsets = const [];

  /// Dynamic overlay height (shrinks during push-out).
  double _overlayHeight = 0.0;

  /// Whether we're in variable-height mode.
  bool get _isVariableHeight => widget.itemHeight != null;

  /// Effective item extent for uniform mode. Asserts not called in
  /// variable mode.
  double get _uniformExtent {
    assert(!_isVariableHeight, 'Cannot use _uniformExtent in variable mode');
    return widget.itemExtent!;
  }

  ScrollController get _scrollController =>
      widget.controller ?? (_ownController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _rebuildOffsetTable();
    _updateStickyModel();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateStickyHeaders();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _ownController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StickyHierarchicalScrollView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      final oldController = oldWidget.controller ?? _ownController;
      oldController?.removeListener(_onScroll);

      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }

      _scrollController.addListener(_onScroll);
    }

    if (oldWidget.items != widget.items) {
      _rebuildOffsetTable();
      _updateStickyModel();
      // Recalculate sticky headers after layout completes with
      // the new items. Without this, headers lag by one frame when
      // an external controller auto-scrolls in a post-frame callback.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateStickyHeaders();
      });
    }
  }

  // -- Offset table --

  /// Rebuild the cumulative offset table from per-item heights.
  void _rebuildOffsetTable() {
    if (!_isVariableHeight) {
      _cumulativeOffsets = const [];
      return;
    }

    final items = widget.items;
    final heightOf = widget.itemHeight!;
    final offsets = List<double>.filled(items.length + 1, 0.0);
    for (int i = 0; i < items.length; i++) {
      offsets[i + 1] = offsets[i] + heightOf(items[i]);
    }
    _cumulativeOffsets = offsets;
  }

  /// Pixel offset of the top edge of item at [index].
  double _offsetOf(int index) {
    if (_isVariableHeight) return _cumulativeOffsets[index];
    return index * _uniformExtent;
  }

  /// Height of the item at [index].
  double _heightOf(int index) {
    if (_isVariableHeight) {
      return _cumulativeOffsets[index + 1] - _cumulativeOffsets[index];
    }
    return _uniformExtent;
  }

  // -- Sticky model --

  /// Rebuild sticky candidates when content changes.
  void _updateStickyModel() {
    _stickyCandidates.clear();
    final items = widget.items;
    final itemCount = items.length;

    for (int i = 0; i < itemCount; i++) {
      final item = items[i];
      if (!widget.isSection(item)) continue;

      final currentLevel = widget.getLevel(item);
      int endIndex = itemCount - 1;

      // Scope ends before the next section at the same or lesser level.
      for (int j = i + 1; j < itemCount; j++) {
        if (widget.isSection(items[j]) &&
            widget.getLevel(items[j]) <= currentLevel) {
          endIndex = j - 1;
          break;
        }
      }

      final candidateHeight = _heightOf(i);

      _stickyCandidates.add(
        StickyCandidate<T>(
          level: currentLevel,
          data: item,
          originalIndex: i,
          endIndex: endIndex,
          itemExtent: candidateHeight,
          startOffset: _isVariableHeight ? _offsetOf(i) : null,
          scopeEndOffset: _isVariableHeight
              ? _cumulativeOffsets[endIndex + 1]
              : null,
        ),
      );
    }
  }

  void _onScroll() {
    _updateStickyHeaders();
  }

  /// Compute the maximum sticky area height from active candidates.
  ///
  /// In variable mode, each slot may have a different height.
  /// In uniform mode, all slots share [_uniformExtent].
  double _stickyAreaHeight(int slotCount) {
    if (!_isVariableHeight) {
      return slotCount * _uniformExtent;
    }
    // Sum the heights of the first [slotCount] candidates in the context.
    // This is an upper bound — actual heights depend on which candidates
    // fill the slots. Use the max candidate height * slotCount as a
    // conservative threshold for the binary search.
    double maxHeight = 0.0;
    for (final c in _stickyCandidates) {
      if (c.itemExtent > maxHeight) maxHeight = c.itemExtent;
    }
    return slotCount * maxHeight;
  }

  /// Update sticky headers using VS Code's canonical slot-fit algorithm.
  void _updateStickyHeaders() {
    if (!mounted) return;

    final scrollTop = _scrollController.offset.clamp(0.0, double.infinity);
    final maxHeaders = widget.config.maxStickyHeaders;

    final stickyAreaHeight = _stickyAreaHeight(maxHeaders);
    final intersecting = _getCandidatesIntersecting(
      scrollTop + stickyAreaHeight,
    );

    // Build context stack: keep most recent candidate at each level.
    final contextStack = <int, StickyCandidate<T>>{};
    int maxContextLevel = -1;
    bool hasScrolledPast = false;
    for (final candidate in intersecting) {
      if (candidate.startPosition < scrollTop) {
        contextStack[candidate.level] = candidate;
        contextStack.removeWhere((level, _) => level > candidate.level);
        maxContextLevel = candidate.level;
        hasScrolledPast = true;
      } else {
        if (!hasScrolledPast || candidate.level <= maxContextLevel) break;
        contextStack[candidate.level] = candidate;
        maxContextLevel = candidate.level;
      }
    }

    final sortedLevels = contextStack.keys.toList()..sort();
    final candidates = sortedLevels
        .map((level) => contextStack[level]!)
        .toList();

    // Slot-fit filter with variable slot tops.
    final active = <_ActiveHeader<T>>[];
    double slotTop = 0.0;
    for (int slot = 0; slot < candidates.length && slot < maxHeaders; slot++) {
      final candidate = candidates[slot];

      final activeHeader =
          _tryFitCandidate(candidate, slotTop, scrollTop) ??
          _tryFitNextCandidateAtLevel(candidate, slotTop, scrollTop);

      if (activeHeader != null) {
        active.add(activeHeader);
        slotTop += activeHeader.candidate.itemExtent;
      } else {
        break;
      }
    }

    // Compute dynamic overlay height.
    double newOverlayHeight = 0.0;
    if (active.isNotEmpty) {
      final lastHeader = active.last;
      newOverlayHeight = lastHeader.top + lastHeader.candidate.itemExtent;
      // Clamp: overlay should not be negative or exceed max possible.
      double maxOverlay = 0.0;
      for (final h in active) {
        maxOverlay += h.candidate.itemExtent;
      }
      newOverlayHeight = newOverlayHeight.clamp(0.0, maxOverlay);
    }

    if (_activeHeadersChanged(active, _currentActiveHeaders) ||
        newOverlayHeight != _overlayHeight) {
      setState(() {
        _currentActiveHeaders = active;
        _overlayHeight = newOverlayHeight;
      });
    }
  }

  /// Binary search for candidates whose startPosition < [threshold].
  List<StickyCandidate<T>> _getCandidatesIntersecting(double threshold) {
    if (_stickyCandidates.isEmpty) return [];

    int left = 0;
    int right = _stickyCandidates.length - 1;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      if (_stickyCandidates[mid].startPosition < threshold) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    if (right < 0) return [];

    return _stickyCandidates.sublist(0, right + 1);
  }

  /// Test whether [candidate] fits [slotTop] given the current [scrollTop].
  _ActiveHeader<T>? _tryFitCandidate(
    StickyCandidate<T> candidate,
    double slotTop,
    double scrollTop,
  ) {
    final headerViewportTop = candidate.startPosition - scrollTop;
    final scopeEndViewport = candidate.scopeEndPosition - scrollTop;

    if (headerViewportTop < slotTop && slotTop <= scopeEndViewport) {
      final slotBottom = slotTop + candidate.itemExtent;
      double top = slotTop;
      if (slotBottom > scopeEndViewport) {
        top = scopeEndViewport - candidate.itemExtent;
      }
      return _ActiveHeader(candidate, top);
    }
    return null;
  }

  /// When a candidate's scope has ended for its slot, search forward for the
  /// next sticky candidate at the same level.
  _ActiveHeader<T>? _tryFitNextCandidateAtLevel(
    StickyCandidate<T> current,
    double slotTop,
    double scrollTop,
  ) {
    for (int i = 0; i < _stickyCandidates.length; i++) {
      final candidate = _stickyCandidates[i];
      if (candidate.originalIndex <= current.originalIndex) continue;
      if (candidate.level != current.level) continue;
      return _tryFitCandidate(candidate, slotTop, scrollTop);
    }
    return null;
  }

  /// Detect changes in the active header set, including position changes.
  bool _activeHeadersChanged(
    List<_ActiveHeader<T>> newHeaders,
    List<_ActiveHeader<T>> oldHeaders,
  ) {
    if (newHeaders.length != oldHeaders.length) return true;
    for (int i = 0; i < newHeaders.length; i++) {
      if (newHeaders[i].candidate.originalIndex !=
          oldHeaders[i].candidate.originalIndex) {
        return true;
      }
      if (newHeaders[i].top != oldHeaders[i].top) {
        return true;
      }
    }
    return false;
  }

  // -- Navigation --

  void _navigateToItem(int index) {
    if (widget.onStickyHeaderTap != null) {
      widget.onStickyHeaderTap!(index);
    } else {
      final targetPosition = _offsetOf(index);
      final targetScrollOffset = (targetPosition - _overlayHeight).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        targetScrollOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // -- Rendering --

  /// Build a single sticky header widget at [top] position.
  Widget _buildHeaderWidget(StickyCandidate<T> header, double top) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: header.itemExtent,
      child: GestureDetector(
        onTap: widget.config.enableNavigation
            ? () => _navigateToItem(header.originalIndex)
            : null,
        child: DecoratedBox(
          decoration: widget.config.stickyDecoration,
          child: widget.config.stickyHeaderBuilder(context, header),
        ),
      ),
    );
  }

  /// Build the sticky header overlay content.
  Widget _buildStickyContent(double scrollTop) {
    if (_currentActiveHeaders.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    for (int i = _currentActiveHeaders.length - 1; i >= 0; i--) {
      final activeHeader = _currentActiveHeaders[i];
      children.add(
        _buildHeaderWidget(activeHeader.candidate, activeHeader.top),
      );
    }

    return ClipRect(
      child: SizedBox(
        height: _overlayHeight,
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.items.length + widget.trailingItemCount,
              // Uniform mode with trailing items must use builder to
              // avoid applying itemExtent to trailing items that may
              // differ. When no trailing items exist, use the simpler
              // fixed itemExtent path.
              itemExtent: _isVariableHeight || widget.trailingItemCount > 0
                  ? null
                  : widget.itemExtent,
              itemExtentBuilder:
                  _isVariableHeight || widget.trailingItemCount > 0
                  ? (int index, SliverLayoutDimensions _) {
                      if (index < widget.items.length) {
                        return _heightOf(index);
                      }
                      // Trailing items use uniform extent (or first
                      // item height as fallback in variable mode).
                      return widget.itemExtent ??
                          (widget.items.isNotEmpty ? _heightOf(0) : 24.0);
                    }
                  : null,
              physics: widget.physics,
              padding: EdgeInsets.zero,
              // Match trailing items by key across index shifts.
              // Without this, adding a data item shifts all trailing
              // indices, causing ListView to dispose and recreate
              // trailing widgets (losing TextField focus, etc.).
              findChildIndexCallback: widget.trailingItemCount > 0
                  ? (Key key) {
                      if (key case ValueKey<int>(value: final v) when v < 0) {
                        // Negative keys encode trailing index:
                        // -1 → trailing 0, -2 → trailing 1, etc.
                        return widget.items.length + (-v - 1);
                      }
                      return null;
                    }
                  : null,
              itemBuilder: (context, index) {
                if (index < widget.items.length) {
                  return widget.itemBuilder(
                    context,
                    widget.items[index],
                    index,
                  );
                }
                // Trailing items keyed for stable identity.
                final trailingIndex = index - widget.items.length;
                return KeyedSubtree(
                  key: ValueKey<int>(-(trailingIndex + 1)),
                  child: widget.trailingItemBuilder!(context, trailingIndex),
                );
              },
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ListenableBuilder(
              listenable: _scrollController,
              builder: (context, _) {
                final scrollTop = _scrollController.hasClients
                    ? _scrollController.offset
                    : 0.0;

                return _buildStickyContent(scrollTop);
              },
            ),
          ),
        ],
      ),
    );
  }
}
