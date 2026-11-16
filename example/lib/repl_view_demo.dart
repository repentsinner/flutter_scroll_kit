import 'package:flutter/material.dart';
import 'package:flutter_scroll_kit/repl_view.dart';

class _DemoEntry implements ConsoleEntry {
  const _DemoEntry({
    required this.value,
    required this.isInput,
    required this.identity,
    this.count = 1,
  });

  @override
  final String value;

  @override
  final bool isInput;

  @override
  final Object identity;

  @override
  final int count;

  @override
  String get coalescingKey => '$isInput:$value';
}

/// Shows REPL scrollback with sticky input lines and a coalesced response.
class ReplViewDemo extends StatelessWidget {
  const ReplViewDemo({super.key});

  static const double _itemExtent = 24.0;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();

    return Scaffold(
      body: ReplView<_DemoEntry>(
        entries: entries,
        itemExtent: _itemExtent,
        entryBuilder: (context, entry) => _buildRow(entry),
      ),
    );
  }

  Widget _buildRow(_DemoEntry entry) {
    final prefix = entry.isInput ? '> ' : '  ';
    final style = TextStyle(
      fontFamily: 'monospace',
      fontWeight: entry.isInput ? FontWeight.bold : FontWeight.normal,
      color: entry.isInput ? Colors.amber : Colors.white70,
    );
    final countBadge = entry.count > 1 ? '  x${entry.count}' : '';

    return Container(
      height: _itemExtent,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text('$prefix${entry.value}$countBadge', style: style),
    );
  }

  List<_DemoEntry> _buildEntries() {
    var id = 0;
    _DemoEntry input(String v) =>
        _DemoEntry(value: v, isInput: true, identity: id++);
    _DemoEntry response(String v, {int count = 1}) =>
        _DemoEntry(value: v, isInput: false, identity: id++, count: count);

    return <_DemoEntry>[
      input('help'),
      response('Available commands: help, status, load, run'),
      input('status'),
      response('ready'),
      response('uptime: 00:05:12'),
      input('load demo.gcode'),
      response('loaded 1,248 lines'),
      response('estimated duration: 12m 04s'),
      input('run'),
      response('starting...'),
      response('line 1 / 1248'),
      response('line 2 / 1248'),
      response('line 3 / 1248'),
      response('warning: feedrate override active', count: 3),
      response('line 4 / 1248'),
      response('line 5 / 1248'),
    ];
  }
}
