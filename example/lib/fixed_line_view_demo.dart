import 'dart:async';

import 'package:flutter_scroll_kit/fixed_line_view.dart';
import 'package:material_ui/material_ui.dart';

import 'demo_caption.dart';

enum _Severity { debug, info, warn, error }

class _LogEvent {
  const _LogEvent(this.time, this.severity, this.source, this.message);

  final DateTime time;
  final _Severity severity;
  final String source;
  final String message;
}

/// Shows a log that streams in and follows its tail, pausing while the
/// viewer scrolls back through history.
class FixedLineViewDemo extends StatefulWidget {
  const FixedLineViewDemo({super.key});

  @override
  State<FixedLineViewDemo> createState() => _FixedLineViewDemoState();
}

class _FixedLineViewDemoState extends State<FixedLineViewDemo> {
  static const double _itemExtent = 22.0;
  static const int _history = 60;
  static const int _maxLines = 2000;
  static const Duration _interval = Duration(milliseconds: 250);

  /// A fixed start time keeps every run, and every recording, identical.
  static final DateTime _start = DateTime(2026, 1, 1, 9, 41);

  static const List<String> _sources = ['http', 'db', 'cache', 'worker'];
  static const List<String> _messages = [
    'lorem ipsum dolor sit amet',
    'consectetur adipiscing elit in 12 ms',
    'sed do eiusmod tempor incididunt',
    'ut labore et dolore magna aliqua',
    'ut enim ad minim veniam, quis nostrud',
    'exercitation ullamco laboris retried (2/3)',
    'nisi ut aliquip ex ea commodo consequat',
    'duis aute irure dolor in reprehenderit',
  ];

  final StreamController<_LogEvent> _events = StreamController<_LogEvent>();
  late final List<_LogEvent> _initial = [
    for (var i = 0; i < _history; i++) _event(i),
  ];
  int _next = _history;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(_interval, (_) => _events.add(_event(_next++)));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _events.close();
    super.dispose();
  }

  /// Builds the [n]th event. Severity and wording follow from [n], so the
  /// log reads as varied but repeats exactly between runs.
  _LogEvent _event(int n) {
    final severity = switch (n % 17) {
      0 => _Severity.error,
      3 || 11 => _Severity.warn,
      5 || 8 || 14 => _Severity.debug,
      _ => _Severity.info,
    };
    return _LogEvent(
      _start.add(_interval * n),
      severity,
      _sources[(n * 7) % _sources.length],
      _messages[(n * 5) % _messages.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoCaption(
      library: 'fixed_line_view',
      summary: 'a live log that follows its tail and pauses while you scroll',
      child: StreamLineView<_LogEvent>(
        itemStream: _events.stream,
        initialItems: _initial,
        maxLines: _maxLines,
        itemExtent: _itemExtent,
        itemBuilder: (context, event, index) => _buildRow(event),
      ),
    );
  }

  Widget _buildRow(_LogEvent event) {
    const base = TextStyle(fontFamily: 'monospace', fontSize: 13);
    final (label, color) = switch (event.severity) {
      _Severity.debug => ('DEBUG', Colors.blueGrey),
      _Severity.info => ('INFO ', Colors.lightBlueAccent),
      _Severity.warn => ('WARN ', Colors.amber),
      _Severity.error => ('ERROR', Colors.redAccent),
    };
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(
              text: '${_timestamp(event.time)} ',
              style: const TextStyle(color: Colors.white54),
            ),
            TextSpan(
              text: label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: ' [${event.source.padRight(6)}] ',
              style: const TextStyle(color: Colors.white70),
            ),
            TextSpan(text: event.message),
          ],
        ),
        maxLines: 1,
      ),
    );
  }

  static String _timestamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.$ms';
  }
}
