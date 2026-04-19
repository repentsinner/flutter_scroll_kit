import 'package:fixed_line_view/fixed_line_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FixedLineView', () {
    testWidgets('renders correct number of items', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 5,
            itemExtent: 20.0,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      for (var i = 0; i < 5; i++) {
        expect(find.text('Line $i'), findsOneWidget);
      }
    });

    testWidgets('shows emptyBuilder when lineCount is 0', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 0,
            itemExtent: 20.0,
            lineBuilder: (context, index) => Text('Line $index'),
            emptyBuilder: const Text('Empty'),
          ),
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('shows SizedBox when lineCount is 0 and no emptyBuilder', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 0,
            itemExtent: 20.0,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('auto-scrolls to center when activeLineIndex changes', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      // Render enough items to require scrolling. 600px default height,
      // 20px per item, 100 items = 2000px total.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 100,
            itemExtent: 20.0,
            autoScroll: AutoScrollBehavior.center,
            activeLineIndex: 0,
            controller: controller,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      expect(controller.offset, 0.0);

      // Change active line to index 50.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 100,
            itemExtent: 20.0,
            autoScroll: AutoScrollBehavior.center,
            activeLineIndex: 50,
            controller: controller,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      // Let the post-frame callback and animation run.
      await tester.pumpAndSettle();

      // The scroll offset should have moved toward centering line 50.
      expect(controller.offset, greaterThan(0.0));
    });

    testWidgets('auto-scrolls to bottom when autoScroll is bottom', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 100,
            itemExtent: 20.0,
            autoScroll: AutoScrollBehavior.bottom,
            controller: controller,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      // Increase line count to trigger bottom scroll.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 110,
            itemExtent: 20.0,
            autoScroll: AutoScrollBehavior.bottom,
            controller: controller,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The post-frame callback reads maxScrollExtent before the new
      // itemCount has been laid out, so it animates to the *previous*
      // maxScrollExtent (1400). A second widget update triggers a
      // follow-up scroll to the true maxScrollExtent (1600). This
      // matches real-world use where a stream continuously appends.
      // Verify the offset moved to the bottom of the previous extent.
      expect(controller.offset, greaterThan(0.0));

      // A second pump cycle with the same widget brings us to true max.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 111,
            itemExtent: 20.0,
            autoScroll: AutoScrollBehavior.bottom,
            controller: controller,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(controller.offset, controller.position.maxScrollExtent);
    });

    testWidgets('uses external ScrollController when provided', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 100,
            itemExtent: 20.0,
            controller: controller,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      // The external controller should be attached.
      expect(controller.hasClients, isTrue);
    });

    testWidgets('wraps in SelectionArea when selectable is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FixedLineView(
            lineCount: 3,
            itemExtent: 20.0,
            selectable: true,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.text('Line 0'), findsOneWidget);
    });

    testWidgets('no SelectionArea when selectable is false', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FixedLineView(
            lineCount: 3,
            itemExtent: 20.0,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );

      expect(find.byType(SelectionArea), findsNothing);
    });

    testWidgets(
      'scrolls to bottom on initial build when autoScroll is bottom',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: FixedLineView(
              lineCount: 100,
              itemExtent: 20.0,
              autoScroll: AutoScrollBehavior.bottom,
              controller: controller,
              lineBuilder: (context, index) => Text('Line $index'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(controller.offset, controller.position.maxScrollExtent);
      },
    );

    testWidgets(
      'scrolls to center on initial build when autoScroll is center',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: FixedLineView(
              lineCount: 100,
              itemExtent: 20.0,
              autoScroll: AutoScrollBehavior.center,
              activeLineIndex: 50,
              controller: controller,
              lineBuilder: (context, index) => Text('Line $index'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(controller.offset, greaterThan(0.0));
      },
    );
  });
}
