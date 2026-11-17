import 'package:flutter/material.dart';
import 'package:flutter_scroll_kit_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a command typed at the prompt runs on Enter', (tester) async {
    await tester.pumpWidget(const ScrollKitDemo());
    await tester.tap(find.text('REPL'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ls -l logs');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('> ls -l logs'), findsOneWidget);
    expect(find.textContaining('app-060.log'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('an unknown command reports itself', (tester) async {
    await tester.pumpWidget(const ScrollKitDemo());
    await tester.tap(find.text('REPL'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'lorem');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('unknown command: lorem'), findsOneWidget);
  });
}
