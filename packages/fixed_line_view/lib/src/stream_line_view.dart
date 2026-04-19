import 'dart:async';

import 'package:flutter/widgets.dart';

import 'auto_scroll_behavior.dart';
import 'fixed_line_view.dart';

/// A stream-driven wrapper around [FixedLineView].
///
/// Subscribes to [itemStream] and appends items to an internal list,
/// optionally trimming to [maxLines] (ring buffer behavior).
class StreamLineView<T> extends StatefulWidget {
  /// Creates a [StreamLineView].
  const StreamLineView({
    super.key,
    required this.itemStream,
    this.initialItems = const [],
    this.maxLines,
    required this.itemExtent,
    required this.itemBuilder,
    this.autoScroll = AutoScrollBehavior.bottom,
    this.emptyBuilder,
    this.controller,
    this.physics,
    this.selectable = false,
    this.selectionColor,
    this.lineSnap = false,
  });

  /// Stream of individual items to append.
  final Stream<T> itemStream;

  /// Initial items (e.g., history loaded before stream).
  final List<T> initialItems;

  /// Maximum number of items to retain (ring buffer). Null = unlimited.
  final int? maxLines;

  /// Height of each line.
  final double itemExtent;

  /// Builder for each item.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Auto-scroll behavior (typically bottom for log-like views).
  final AutoScrollBehavior autoScroll;

  /// Widget to show when empty.
  final Widget? emptyBuilder;

  /// Optional external scroll controller.
  final ScrollController? controller;

  /// Optional scroll physics.
  final ScrollPhysics? physics;

  /// Whether to enable multi-line text selection.
  final bool selectable;

  /// Selection highlight color. See [FixedLineView.selectionColor].
  final Color? selectionColor;

  /// Whether to quantize scroll offsets to line boundaries.
  final bool lineSnap;

  @override
  State<StreamLineView<T>> createState() => _StreamLineViewState<T>();
}

class _StreamLineViewState<T> extends State<StreamLineView<T>> {
  late final List<T> _items;
  StreamSubscription<T>? _subscription;

  @override
  void initState() {
    super.initState();
    _items = List<T>.of(widget.initialItems);
    _subscribe();
  }

  @override
  void didUpdateWidget(StreamLineView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemStream != oldWidget.itemStream) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.itemStream.listen((item) {
      setState(() {
        _items.add(item);
        final maxLines = widget.maxLines;
        if (maxLines != null && _items.length > maxLines) {
          _items.removeRange(0, _items.length - maxLines);
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FixedLineView(
      lineCount: _items.length,
      itemExtent: widget.itemExtent,
      autoScroll: widget.autoScroll,
      controller: widget.controller,
      physics: widget.physics,
      emptyBuilder: widget.emptyBuilder,
      selectable: widget.selectable,
      selectionColor: widget.selectionColor,
      lineSnap: widget.lineSnap,
      lineBuilder: (context, index) =>
          widget.itemBuilder(context, _items[index], index),
    );
  }
}
