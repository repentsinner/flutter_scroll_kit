import 'dart:async';

import 'package:fixed_line_view/fixed_line_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamLineView', () {
    testWidgets('renders initialItems on first build', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StreamLineView<String>(
            itemStream: controller.stream,
            initialItems: const ['A', 'B', 'C'],
            itemExtent: 20.0,
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('appends items from stream', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StreamLineView<String>(
            itemStream: controller.stream,
            initialItems: const ['A'],
            itemExtent: 20.0,
            autoScroll: AutoScrollBehavior.none,
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing);

      controller.add('B');
      await tester.pump();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('ring buffer trims oldest when maxLines exceeded', (
      tester,
    ) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StreamLineView<String>(
            itemStream: controller.stream,
            initialItems: const ['A', 'B'],
            maxLines: 3,
            itemExtent: 20.0,
            autoScroll: AutoScrollBehavior.none,
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );

      controller.add('C');
      await tester.pump();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      // Adding a 4th item should trim 'A'.
      controller.add('D');
      await tester.pumpAndSettle();

      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('cancels subscription on dispose', (tester) async {
      final controller = StreamController<String>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: StreamLineView<String>(
            itemStream: controller.stream,
            itemExtent: 20.0,
            autoScroll: AutoScrollBehavior.none,
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      );

      expect(controller.hasListener, isTrue);

      // Remove the widget from the tree to trigger dispose.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      expect(controller.hasListener, isFalse);
    });
  });
}
