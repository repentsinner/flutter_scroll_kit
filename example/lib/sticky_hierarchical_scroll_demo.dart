import 'package:flutter/material.dart';
import 'package:flutter_scroll_kit/sticky_hierarchical_scroll.dart';

class _DemoItem {
  final String label;
  final int level;
  final bool isSection;

  const _DemoItem(this.label, {required this.level, this.isSection = false});
}

/// Shows a file tree whose section headers stick as their scope scrolls.
class StickyHierarchicalScrollDemo extends StatelessWidget {
  const StickyHierarchicalScrollDemo({super.key});

  static const double _itemExtent = 32.0;

  @override
  Widget build(BuildContext context) {
    final items = _buildDemoItems();

    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: StickyHierarchicalScrollView<_DemoItem>(
        items: items,
        // Levels are 0-based: top-level projects are level 0, their
        // children level 1, and so on down the tree.
        getLevel: (item) => item.level,
        isSection: (item) => item.isSection,
        itemExtent: _itemExtent,
        config: StickyScrollConfig<_DemoItem>(
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

  Widget _buildRow(_DemoItem item) {
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
  List<_DemoItem> _buildDemoItems() {
    final items = <_DemoItem>[];

    for (int project = 0; project < 5; project++) {
      items.add(_DemoItem('project_$project/', level: 0, isSection: true));

      for (int dir = 0; dir < 4; dir++) {
        items.add(_DemoItem('src_$dir/', level: 1, isSection: true));

        for (int subdir = 0; subdir < 3; subdir++) {
          items.add(_DemoItem('module_$subdir/', level: 2, isSection: true));

          for (int file = 0; file < 6; file++) {
            items.add(_DemoItem('file_$file.dart', level: 3));
          }
        }
      }
    }

    return items;
  }
}
