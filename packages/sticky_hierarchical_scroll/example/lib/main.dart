import 'package:flutter/material.dart';
import 'package:sticky_hierarchical_scroll/sticky_hierarchical_scroll.dart';

void main() => runApp(const StickyScrollDemo());

class StickyScrollDemo extends StatelessWidget {
  const StickyScrollDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticky Hierarchical Scroll Demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

/// A row in the demo list — either a section header or a leaf item.
class DemoItem {
  final String label;
  final int level;
  final bool isSection;

  const DemoItem(this.label, {required this.level, this.isSection = false});
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  static const double _itemExtent = 32.0;

  @override
  Widget build(BuildContext context) {
    final items = _buildDemoItems();

    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: StickyHierarchicalScrollView<DemoItem>(
        items: items,
        getLevel: (item) => item.level,
        isSection: (item) => item.isSection,
        itemExtent: _itemExtent,
        config: StickyScrollConfig<DemoItem>(
          maxStickyHeaders: 3,
          stickyDecoration: BoxDecoration(color: bgColor),
          stickyHeaderBuilder: (context, candidate) {
            return _buildRow(candidate.data);
          },
        ),
        itemBuilder: (context, item, index) {
          return _buildRow(item);
        },
      ),
    );
  }

  Widget _buildRow(DemoItem item) {
    final indent = item.level * 16.0;
    final style = item.isSection
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)
        : const TextStyle(fontSize: 13);

    return Container(
      height: _itemExtent,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 8 + indent),
      child: Text(item.label, style: style),
    );
  }

  /// Generate a file-tree-like hierarchy for demo purposes.
  List<DemoItem> _buildDemoItems() {
    final items = <DemoItem>[];

    for (int project = 0; project < 5; project++) {
      items.add(DemoItem('project_$project/', level: 0, isSection: true));

      for (int dir = 0; dir < 4; dir++) {
        items.add(DemoItem('src_$dir/', level: 1, isSection: true));

        for (int subdir = 0; subdir < 3; subdir++) {
          items.add(DemoItem('module_$subdir/', level: 2, isSection: true));

          for (int file = 0; file < 6; file++) {
            items.add(DemoItem('file_$file.dart', level: 3));
          }
        }
      }
    }

    return items;
  }
}
