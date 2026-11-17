import 'package:flutter_scroll_kit/repl_view.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_caption.dart';

class _DemoEntry implements ConsoleEntry {
  const _DemoEntry({
    required this.value,
    required this.isInput,
    required this.identity,
  });

  @override
  final String value;

  @override
  final bool isInput;

  @override
  final Object identity;

  @override
  int get count => 1;

  @override
  String get coalescingKey => '$isInput:$value';
}

/// Shows a terminal-style REPL. The prompt is the last row of the
/// scrollback, and each command pins as a header while its output scrolls
/// beneath it.
class ReplViewDemo extends StatefulWidget {
  const ReplViewDemo({super.key});

  @override
  State<ReplViewDemo> createState() => _ReplViewDemoState();
}

class _ReplViewDemoState extends State<ReplViewDemo> {
  static const double _itemExtent = 24.0;
  static const int _logFiles = 60;
  static const TextStyle _mono = TextStyle(fontFamily: 'monospace');

  final List<_DemoEntry> _entries = [];
  final TextEditingController _prompt = TextEditingController();
  final FocusNode _promptFocus = FocusNode();

  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _run('help');
    _run('status');
  }

  @override
  void dispose() {
    _prompt.dispose();
    _promptFocus.dispose();
    super.dispose();
  }

  /// Appends [command] and its output to the scrollback.
  void _run(String command) {
    _entries.add(_entry(command, isInput: true));
    for (final line in _respond(command.trim())) {
      _entries.add(_entry(line, isInput: false));
    }
  }

  _DemoEntry _entry(String value, {required bool isInput}) =>
      _DemoEntry(value: value, isInput: isInput, identity: _nextId++);

  List<String> _respond(String command) {
    if (command == 'help') return ['commands: help, status, ls -l logs'];
    if (command == 'status') return ['ready', 'uptime: 00:05:12'];
    if (command.startsWith('ls')) {
      return [
        'total ${_logFiles * 12}K',
        for (var i = 1; i <= _logFiles; i++)
          '-rw-r--r--  1 demo  staff  ${(i * 37) % 90 + 10}K  '
              'Jan  1 09:${(i % 60).toString().padLeft(2, '0')}  '
              'app-${i.toString().padLeft(3, '0')}.log',
      ];
    }
    return ['unknown command: $command'];
  }

  void _submit(String command) {
    if (command.trim().isEmpty) return;
    // Clear the field while it is still laid out in its current row. The
    // command's output moves the prompt down the list, and a field that
    // scrolls its caret into view from a row the list has not laid out yet
    // throws. So the command runs on the next frame.
    _prompt.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _run(command));
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoCaption(
      library: 'repl_view',
      summary: 'each command pins while its output scrolls beneath it',
      child: ReplView<_DemoEntry>(
        entries: List.unmodifiable(_entries),
        itemExtent: _itemExtent,
        entryBuilder: (context, entry) => _buildRow(entry),
        // The prompt is the last row, so it scrolls with the output, as in
        // a terminal.
        trailingItemCount: 1,
        trailingItemBuilder: (context, _) => _buildPrompt(),
      ),
    );
  }

  Widget _buildRow(_DemoEntry entry) {
    return Container(
      height: _itemExtent,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        '${entry.isInput ? '> ' : '  '}${entry.value}',
        style: _mono.copyWith(
          fontWeight: entry.isInput ? FontWeight.bold : FontWeight.normal,
          color: entry.isInput ? Colors.amber : Colors.white70,
        ),
        maxLines: 1,
      ),
    );
  }

  Widget _buildPrompt() {
    return Container(
      height: _itemExtent,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            '> ',
            style: _mono.copyWith(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _prompt,
              focusNode: _promptFocus,
              autofocus: true,
              style: _mono.copyWith(color: Colors.amber),
              cursorColor: Colors.amber,
              decoration: const InputDecoration.collapsed(hintText: null),
              // Keeps focus on the prompt after Enter, which would otherwise
              // unfocus the field.
              onEditingComplete: () {},
              onSubmitted: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
