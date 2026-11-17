import 'package:flutter/material.dart';
import 'package:flutter_scroll_kit/line_snap_scroll_physics.dart';

import 'demo_caption.dart';

/// Shows a source file whose scroll offset always lands on a whole line,
/// as in a code editor.
class LineSnapScrollPhysicsDemo extends StatefulWidget {
  const LineSnapScrollPhysicsDemo({super.key});

  @override
  State<LineSnapScrollPhysicsDemo> createState() =>
      _LineSnapScrollPhysicsDemoState();
}

class _LineSnapScrollPhysicsDemoState extends State<LineSnapScrollPhysicsDemo> {
  static const double _itemExtent = 24.0;
  static const double _gutterWidth = 56.0;
  static const TextStyle _code = TextStyle(fontFamily: 'monospace');

  static final List<String> _lines = _buildSource();

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
    final gutter = Colors.teal.shade300;
    return DemoCaption(
      library: 'line_snap_scroll_physics',
      summary: 'scrolling stops on whole lines, like a code editor',
      child: ListView.builder(
        controller: _controller,
        physics: const LineSnapScrollPhysics(itemExtent: _itemExtent),
        itemExtent: _itemExtent,
        itemCount: _lines.length,
        itemBuilder: (context, index) => Row(
          children: [
            SizedBox(
              width: _gutterWidth,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.right,
                style: _code.copyWith(color: gutter),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(_lines[index], style: _code, maxLines: 1)),
          ],
        ),
      ),
    );
  }

  /// Returns a few screens of plausible source text.
  static List<String> _buildSource() {
    const words = ['lorem', 'ipsum', 'dolor', 'sit', 'amet', 'consectetur'];
    final lines = <String>["import 'package:lorem/ipsum.dart';", ''];
    for (var i = 0; i < words.length; i++) {
      final name = words[i];
      final type = '${name[0].toUpperCase()}${name.substring(1)}';
      lines.addAll([
        '/// Adipiscing elit, sed do eiusmod tempor incididunt.',
        'class $type extends Dolor {',
        '  $type(this.magna, {this.aliqua = $i});',
        '',
        '  final String magna;',
        '  final int aliqua;',
        '',
        '  int ut(int enim) {',
        '    if (enim > aliqua) return enim - aliqua;',
        "    return magna.length + '$name'.length;",
        '  }',
        '}',
        '',
      ]);
    }
    return lines;
  }
}
