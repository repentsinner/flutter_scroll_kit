import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_scroll_kit/fixed_line_view.dart';

/// Advances an active line on a timer and keeps it centered.
class FixedLineViewDemo extends StatefulWidget {
  const FixedLineViewDemo({super.key});

  @override
  State<FixedLineViewDemo> createState() => _FixedLineViewDemoState();
}

class _FixedLineViewDemoState extends State<FixedLineViewDemo> {
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
