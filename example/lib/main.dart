import 'package:flutter/material.dart';

import 'fixed_line_view_demo.dart';
import 'line_snap_scroll_physics_demo.dart';
import 'repl_view_demo.dart';
import 'sticky_hierarchical_scroll_demo.dart';
import 'tour.dart';

/// Starts the demo. `--tour` loops through every tab on its own.
void main(List<String> args) =>
    runApp(ScrollKitDemo(tour: args.contains('--tour')));

/// Shows one tab per flutter_scroll_kit primitive.
class ScrollKitDemo extends StatelessWidget {
  const ScrollKitDemo({super.key, this.tour = false});

  /// Whether the app tours its tabs on a loop.
  final bool tour;

  static const List<({String label, Widget demo})> _demos = [
    (label: 'Code view', demo: LineSnapScrollPhysicsDemo()),
    (label: 'Sticky headers', demo: StickyHierarchicalScrollDemo()),
    (label: 'Log stream', demo: FixedLineViewDemo()),
    (label: 'REPL', demo: ReplViewDemo()),
  ];

  @override
  Widget build(BuildContext context) {
    final Widget body = TabBarView(
      // Swiping between tabs would steal the vertical drags each demo
      // exists to show, so tabs change only by tapping.
      physics: const NeverScrollableScrollPhysics(),
      children: [for (final d in _demos) d.demo],
    );

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
          body: tour ? Tour(child: body) : body,
        ),
      ),
    );
  }
}
