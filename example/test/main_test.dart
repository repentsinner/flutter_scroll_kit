import 'package:flutter/widgets.dart';
import 'package:flutter_scroll_kit/flutter_scroll_kit.dart';
import 'package:flutter_scroll_kit_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('each tab shows its primitive', (tester) async {
    await tester.pumpWidget(const ScrollKitDemo());

    final tabs = <String, bool Function(Widget)>{
      'Line snap': (w) => w is Scrollable && w.physics is LineSnapScrollPhysics,
      'Sticky headers': (w) => w is StickyHierarchicalScrollView<Object?>,
      'Fixed lines': (w) => w is FixedLineView,
      'REPL': (w) => w is ReplView<ConsoleEntry>,
    };
    for (final MapEntry(key: label, value: isPrimitive) in tabs.entries) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(isPrimitive),
        findsWidgets,
        reason: '$label tab',
      );
    }
  });
}
