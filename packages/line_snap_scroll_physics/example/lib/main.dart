import 'package:flutter/material.dart';
import 'package:line_snap_scroll_physics/line_snap_scroll_physics.dart';

void main() => runApp(const LineSnapDemo());

class LineSnapDemo extends StatelessWidget {
  const LineSnapDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Line Snap Scroll Physics Demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
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
      appBar: AppBar(title: const Text('Line Snap Demo')),
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
