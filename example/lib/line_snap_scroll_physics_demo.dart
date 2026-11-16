import 'package:flutter/material.dart';
import 'package:flutter_scroll_kit/line_snap_scroll_physics.dart';

/// Scrolls a list whose offsets snap to line boundaries.
class LineSnapScrollPhysicsDemo extends StatefulWidget {
  const LineSnapScrollPhysicsDemo({super.key});

  @override
  State<LineSnapScrollPhysicsDemo> createState() =>
      _LineSnapScrollPhysicsDemoState();
}

class _LineSnapScrollPhysicsDemoState extends State<LineSnapScrollPhysicsDemo> {
  static const double _itemExtent = 48.0;
  static const int _lineCount = 50;

  late final LineSnapScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LineSnapScrollController(itemExtent: _itemExtent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        controller: _controller,
        physics: const LineSnapScrollPhysics(itemExtent: _itemExtent),
        itemExtent: _itemExtent,
        itemCount: _lineCount,
        itemBuilder: (context, index) => Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Text('Line ${index.toString().padLeft(3, '0')}'),
        ),
      ),
    );
  }
}
