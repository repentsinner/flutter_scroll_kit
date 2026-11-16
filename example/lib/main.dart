import 'package:flutter/material.dart';

import 'fixed_line_view_demo.dart';
import 'line_snap_scroll_physics_demo.dart';
import 'repl_view_demo.dart';
import 'sticky_hierarchical_scroll_demo.dart';

void main() => runApp(const ScrollKitDemo());

/// Shows one tab per flutter_scroll_kit primitive.
class ScrollKitDemo extends StatelessWidget {
  const ScrollKitDemo({super.key});

  static const List<({String label, Widget demo})> _demos = [
    (label: 'Line snap', demo: LineSnapScrollPhysicsDemo()),
    (label: 'Sticky headers', demo: StickyHierarchicalScrollDemo()),
    (label: 'Fixed lines', demo: FixedLineViewDemo()),
    (label: 'REPL', demo: ReplViewDemo()),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_scroll_kit demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: DefaultTabController(
        length: _demos.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('flutter_scroll_kit'),
            bottom: TabBar(
              isScrollable: true,
              tabs: [for (final d in _demos) Tab(text: d.label)],
            ),
          ),
          body: TabBarView(
            // Swiping between tabs would steal the vertical drags each demo
            // exists to show, so tabs change only by tapping.
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final d in _demos) d.demo],
          ),
        ),
      ),
    );
  }
}
