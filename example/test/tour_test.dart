import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter_scroll_kit/line_snap_scroll_physics.dart';
import 'package:flutter_scroll_kit_example/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const Duration _tick = Duration(milliseconds: 50);
const Duration _patience = Duration(minutes: 2);

/// Line height in the code view demo.
const double _lineSnapExtent = 24;

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var waited = Duration.zero; !done(); waited += _tick) {
    if (waited > _patience) fail('condition not met within $_patience');
    await tester.pump(_tick);
  }
}

TabController _tabs(WidgetTester tester) =>
    DefaultTabController.of(tester.element(find.byType(TabBar)));

void main() {
  testWidgets('the tour visits every tab and returns to the first', (
    tester,
  ) async {
    await tester.pumpWidget(const ScrollKitDemo(tour: true));

    final visited = <int>{};
    await _pumpUntil(tester, () {
      visited.add(_tabs(tester).index);
      return visited.length == 4;
    });
    await _pumpUntil(tester, () => _tabs(tester).index == 0);
  });

  testWidgets('the tour scrolls the line snap list onto a line boundary', (
    tester,
  ) async {
    await tester.pumpWidget(const ScrollKitDemo(tour: true));

    ScrollPosition position() => tester
        .state<ScrollableState>(
          find.byWidgetPredicate(
            (w) => w is Scrollable && w.physics is LineSnapScrollPhysics,
          ),
        )
        .position;

    await _pumpUntil(tester, () => position().pixels > 0);
    await _pumpUntil(
      tester,
      () => !position().isScrollingNotifier.value && position().pixels > 0,
    );
    // Line snap aligns lines to the viewport's bottom edge.
    final bottom = position().pixels + position().viewportDimension;
    expect(bottom % _lineSnapExtent, closeTo(0, precisionErrorTolerance));
  });

  testWidgets('the tour types a command at the REPL prompt', (tester) async {
    await tester.pumpWidget(const ScrollKitDemo(tour: true));

    await _pumpUntil(
      tester,
      () => find.text('> ls -l logs').evaluate().isNotEmpty,
    );
    expect(find.textContaining('app-'), findsWidgets);
  });

  testWidgets('without --tour the app stays on the first tab', (tester) async {
    await tester.pumpWidget(const ScrollKitDemo());
    await tester.pump(const Duration(seconds: 30));
    expect(_tabs(tester).index, 0);
  });
}
