import 'dart:async';

import 'package:fixed_line_view/fixed_line_view.dart';
import 'package:flutter/material.dart';

void main() => runApp(const FixedLineViewDemo());

class FixedLineViewDemo extends StatelessWidget {
  const FixedLineViewDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixed Line View Demo',
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
  static const int _lineCount = 100;
  static const double _itemExtent = 24.0;

  int _activeLine = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 400), (_) {
      setState(() {
        _activeLine = (_activeLine + 1) % _lineCount;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Active line: $_activeLine')),
      body: FixedLineView(
        lineCount: _lineCount,
        itemExtent: _itemExtent,
        activeLineIndex: _activeLine,
        autoScroll: AutoScrollBehavior.center,
        lineBuilder: (context, index) {
          final isActive = index == _activeLine;
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: isActive ? Colors.blue.withValues(alpha: 0.25) : null,
            child: Text(
              'line ${index.toString().padLeft(3, '0')}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }
}
