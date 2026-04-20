import 'package:flutter/material.dart';
import 'package:repl_view/repl_view.dart';

void main() => runApp(const ReplViewDemo());

class ReplViewDemo extends StatelessWidget {
  const ReplViewDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REPL View Demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoEntry implements ConsoleEntry {
  const DemoEntry({
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

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  static const double _itemExtent = 24.0;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();

    return Scaffold(
      appBar: AppBar(title: const Text('REPL View Demo')),
      body: ReplView<DemoEntry>(
        entries: entries,
        itemExtent: _itemExtent,
        entryBuilder: (context, entry) => _buildRow(entry),
      ),
    );
  }

  Widget _buildRow(DemoEntry entry) {
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

  List<DemoEntry> _buildEntries() {
    var id = 0;
    DemoEntry input(String v) =>
        DemoEntry(value: v, isInput: true, identity: id++);
    DemoEntry response(String v, {int count = 1}) =>
        DemoEntry(value: v, isInput: false, identity: id++, count: count);

    return <DemoEntry>[
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
