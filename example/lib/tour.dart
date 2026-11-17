import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Pause on each view so a viewer can read it.
const Duration _dwell = Duration(milliseconds: 1500);

/// Time the log stays scrolled back, to show it holding still.
const Duration _logPause = Duration(seconds: 3);

/// Delay between typed characters, near a quick typist's pace.
const Duration _keystroke = Duration(milliseconds: 90);

/// Pause between the last keystroke and Enter.
const Duration _typingPause = Duration(milliseconds: 600);

/// The command the tour types at the REPL prompt.
const String _tourCommand = 'ls -l logs';

/// Length of one slow drag.
const Duration _dragDuration = Duration(milliseconds: 1200);

/// Interval between synthesized pointer moves, about one 60 Hz frame.
const Duration _moveInterval = Duration(milliseconds: 16);

/// Pointer id for synthesized events, clear of ids real devices use.
const int _tourPointer = 9000;

/// Loops through every tab, scrolling each demo with synthesized touch
/// drags and typing a command at the REPL prompt.
///
/// The drags go through the gesture system, so each one reaches the demo's
/// scroll physics the way a finger would. That is what makes the line-snap
/// list settle on a line boundary in the tour.
class Tour extends StatefulWidget {
  const Tour({super.key, required this.child});

  final Widget child;

  @override
  State<Tour> createState() => _TourState();
}

class _TourState extends State<Tour> {
  Timer? _timer;

  /// Timestamp of the last synthesized event. Velocity tracking reads
  /// timestamps, and a drag whose events share one scrolls only part of its
  /// length, so each move advances this by one [_moveInterval] whether or
  /// not the clock has.
  Duration _eventTime = Duration.zero;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loop() async {
    final tabs = DefaultTabController.of(context);
    while (!_disposed) {
      debugPrint('tour cycle start ${DateTime.now().millisecondsSinceEpoch}');

      // Code view: a drag released mid-line settles on a line boundary.
      await _select(tabs, 0);
      await _drag(const Offset(0, -230));
      await _sleep(_dwell);
      await _drag(const Offset(0, 230));
      await _sleep(_dwell);

      // Sticky headers: section headers stack as their scope scrolls past.
      await _select(tabs, 1);
      await _drag(const Offset(0, -700));
      await _sleep(_dwell);
      await _drag(const Offset(0, -700));
      await _sleep(_dwell);

      // Log stream: the log follows its tail, holds still while scrolled
      // back, and follows again once dragged back to the bottom. The drag
      // back overshoots, because the bottom moves on while the log holds.
      await _select(tabs, 2);
      await _sleep(_dwell);
      await _drag(const Offset(0, 300));
      await _sleep(_logPause);
      await _drag(const Offset(0, -1200));
      await _sleep(_logPause);

      // REPL: type a command at the prompt, then scroll its output while the
      // command stays pinned above it.
      await _select(tabs, 3);
      await _type(_tourCommand);
      await _sleep(_typingPause);
      _submit();
      await _sleep(_dwell);
      await _drag(const Offset(0, 500));
      await _sleep(_dwell);
      await _drag(const Offset(0, -600));
      await _sleep(_dwell);
    }
  }

  /// Returns the text field in the visible tab, or null when it has none.
  EditableTextState? _textField() {
    EditableTextState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  /// Types [text] into the visible text field one character at a time, as
  /// keyboard edits.
  Future<void> _type(String text) async {
    for (var length = 1; length <= text.length; length++) {
      if (_disposed) return;
      final typed = text.substring(0, length);
      _textField()?.userUpdateTextEditingValue(
        TextEditingValue(
          text: typed,
          selection: TextSelection.collapsed(offset: typed.length),
        ),
        SelectionChangedCause.keyboard,
      );
      await _sleep(_keystroke);
    }
  }

  /// Presses Enter in the visible text field.
  void _submit() {
    if (_disposed) return;
    _textField()?.performAction(TextInputAction.done);
  }

  Future<void> _select(TabController tabs, int index) async {
    if (_disposed) return;
    tabs.animateTo(index);
    await _sleep(_dwell);
  }

  /// Drags from the middle of [Tour.child] by [offset] over
  /// [_dragDuration], then lifts.
  Future<void> _drag(Offset offset) async {
    if (_disposed) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    var position = box.localToGlobal(box.size.center(Offset.zero));
    final steps = _dragDuration.inMicroseconds ~/ _moveInterval.inMicroseconds;
    final step = offset / steps.toDouble();

    final gestures = GestureBinding.instance;
    gestures.handlePointerEvent(
      PointerDownEvent(
        pointer: _tourPointer,
        timeStamp: _eventTime += _dragDuration,
        position: position,
      ),
    );
    for (var i = 0; i < steps; i++) {
      await _sleep(_moveInterval);
      if (_disposed) return;
      position += step;
      gestures.handlePointerEvent(
        PointerMoveEvent(
          pointer: _tourPointer,
          timeStamp: _eventTime += _moveInterval,
          position: position,
          delta: step,
        ),
      );
    }
    gestures.handlePointerEvent(
      PointerUpEvent(
        pointer: _tourPointer,
        timeStamp: _eventTime,
        position: position,
      ),
    );
  }

  /// Waits [duration] on a timer that dispose cancels, which abandons the
  /// loop instead of leaving it running against a dead widget.
  Future<void> _sleep(Duration duration) {
    final done = Completer<void>();
    _timer = Timer(duration, done.complete);
    return done.future;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
