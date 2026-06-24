import 'package:fixed_line_view/fixed_line_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Item extent for the bottom auto-scroll suppression tests. 50px in the
/// 600px test viewport: a fling/drag of < 50px contact travel stays within
/// one item of the bottom, exercising the post-settle suppression path.
const _itemExtent = 50.0;

/// A bottom-following [FixedLineView] over [lineCount] lines on [controller].
Widget _bottomView(ScrollController controller, int lineCount) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: FixedLineView(
        lineCount: lineCount,
        itemExtent: _itemExtent,
        autoScroll: AutoScrollBehavior.bottom,
        controller: controller,
        lineBuilder: (context, index) => Text('Line $index'),
      ),
    );

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

    testWidgets('suspends auto-scroll after a fling away from the bottom', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      // A fling with < itemExtent of contact travel never crosses the
      // at-bottom threshold during the drag, so suppression must come from
      // the post-fling settle.
      await tester.pumpWidget(_bottomView(controller, 100));
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);

      // Fast flick: little contact travel (40px < itemExtent), high
      // velocity (~2000px/s). Momentum carries the viewport up under a
      // ballistic simulation whose updates carry no drag details.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FixedLineView)),
      );
      for (var ms = 5; ms <= 40; ms += 5) {
        await gesture.moveBy(
          const Offset(0, 5),
          timeStamp: Duration(milliseconds: ms),
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Momentum left us well above the bottom.
      expect(
        controller.offset,
        lessThan(controller.position.maxScrollExtent - _itemExtent),
      );
      final flungTo = controller.offset;

      // Appending a line must NOT yank the viewport back to the bottom.
      await tester.pumpWidget(_bottomView(controller, 101));
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(flungTo, 0.5));
    });

    testWidgets('suspends auto-scroll after a mouse-wheel scroll up', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_bottomView(controller, 100));
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);

      // Mouse-wheel scroll up emits a UserScrollNotification but carries no
      // drag details — the desktop case the old detection missed.
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      final location = tester.getCenter(find.byType(FixedLineView));
      await tester.sendEventToBinding(pointer.hover(location));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -300)));
      await tester.pumpAndSettle();

      expect(
        controller.offset,
        lessThan(controller.position.maxScrollExtent - _itemExtent),
      );
      final scrolledTo = controller.offset;

      // Appending a line must NOT yank the viewport back to the bottom.
      await tester.pumpWidget(_bottomView(controller, 101));
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(scrolledTo, 0.5));
    });

    testWidgets('suspends auto-scroll when a drag rests within one item', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_bottomView(controller, 100));
      await tester.pumpAndSettle();

      // Slow drag up 30px (> tolerance, < itemExtent) at near-zero velocity
      // so it rests in-band. The trailing line is now hidden, so this is
      // "scrolled away" even though it is within one item of the bottom —
      // the case the old full-itemExtent slack wrongly treated as at-bottom.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FixedLineView)),
      );
      for (var ms = 100; ms <= 600; ms += 100) {
        await gesture.moveBy(
          const Offset(0, 5),
          timeStamp: Duration(milliseconds: ms),
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final restedAt = controller.offset;
      final max = controller.position.maxScrollExtent;
      expect(restedAt, lessThan(max));
      expect(restedAt, greaterThan(max - _itemExtent));

      // Appending a line must NOT yank the hidden line into view.
      await tester.pumpWidget(_bottomView(controller, 101));
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(restedAt, 0.5));
    });

    testWidgets('resumes auto-scroll when returned to the bottom', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_bottomView(controller, 100));
      await tester.pumpAndSettle();

      // User drags away from the bottom — auto-scroll suspended.
      await tester.drag(find.byType(FixedLineView), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(
        controller.offset,
        lessThan(controller.position.maxScrollExtent - _itemExtent),
      );

      // External code jumps back to the bottom (e.g. a "jump to bottom"
      // button). Resting at the bottom must resume follow regardless of who
      // scrolled there — the old code only resumed on a user drag.
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // A newly appended line auto-scrolls to the new bottom again.
      await tester.pumpWidget(_bottomView(controller, 101));
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
