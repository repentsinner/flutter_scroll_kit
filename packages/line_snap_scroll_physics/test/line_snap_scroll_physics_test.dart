import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:line_snap_scroll_physics/line_snap_scroll_physics.dart';

void main() {
  group('ScrollMode', () {
    test('has line and pixel values', () {
      expect(ScrollMode.values, hasLength(2));
      expect(ScrollMode.line, isNotNull);
      expect(ScrollMode.pixel, isNotNull);
    });
  });

  group('LineSnapScrollPhysics', () {
    const itemExtent = 20.0;

    testWidgets('fling settles on item boundary in line mode', (
      WidgetTester tester,
    ) async {
      final controller = LineSnapScrollController(itemExtent: itemExtent);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(
            controller: controller,
            physics: const LineSnapScrollPhysics(itemExtent: itemExtent),
            itemExtent: itemExtent,
            itemCount: 200,
            itemBuilder: (context, index) =>
                SizedBox(height: itemExtent, child: Text('Line $index')),
          ),
        ),
      );

      // Perform a fling gesture
      await tester.fling(find.byType(ListView), const Offset(0, -300), 1500);

      // Let the simulation settle
      await tester.pumpAndSettle();

      // Final offset should be on an item boundary
      final offset = controller.offset;
      final remainder = offset % itemExtent;
      expect(
        remainder,
        moreOrLessEquals(0.0, epsilon: 0.01),
        reason: 'Offset $offset should be a multiple of $itemExtent',
      );
    });

    testWidgets('pixel mode scrolls without snapping', (
      WidgetTester tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(
            controller: controller,
            physics: const LineSnapScrollPhysics(
              itemExtent: itemExtent,
              mode: ScrollMode.pixel,
            ),
            itemExtent: itemExtent,
            itemCount: 200,
            itemBuilder: (context, index) =>
                SizedBox(height: itemExtent, child: Text('Line $index')),
          ),
        ),
      );

      // Jump to a non-boundary position
      controller.jumpTo(35.0);
      await tester.pump();

      // In pixel mode, position is not forced to a boundary
      expect(controller.offset, 35.0);
    });

    testWidgets('snaps to nearest boundary when settling', (
      WidgetTester tester,
    ) async {
      final controller = LineSnapScrollController(itemExtent: itemExtent);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(
            controller: controller,
            physics: const LineSnapScrollPhysics(itemExtent: itemExtent),
            itemExtent: itemExtent,
            itemCount: 200,
            itemBuilder: (context, index) =>
                SizedBox(height: itemExtent, child: Text('Line $index')),
          ),
        ),
      );

      // Drag to a non-boundary position and release
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(0, -15)); // 15px, not on boundary
      await gesture.up();
      await tester.pumpAndSettle();

      // Should snap to nearest boundary (20.0)
      final offset = controller.offset;
      final remainder = offset % itemExtent;
      expect(
        remainder,
        moreOrLessEquals(0.0, epsilon: 0.01),
        reason: 'Offset $offset should snap to item boundary',
      );
    });

    test('applyTo preserves itemExtent and mode', () {
      const physics = LineSnapScrollPhysics(itemExtent: 24.0);

      final applied = physics.applyTo(const BouncingScrollPhysics());

      expect(applied.itemExtent, 24.0);
      expect(applied.mode, ScrollMode.line);
      expect(applied.parent, isA<BouncingScrollPhysics>());
    });
  });

  group('LineSnapScrollController', () {
    const itemExtent = 20.0;

    testWidgets('offset is always line-aligned during fling animation', (
      WidgetTester tester,
    ) async {
      final controller = LineSnapScrollController(itemExtent: itemExtent);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(
            controller: controller,
            physics: const LineSnapScrollPhysics(itemExtent: itemExtent),
            itemExtent: itemExtent,
            itemCount: 200,
            itemBuilder: (context, index) =>
                SizedBox(height: itemExtent, child: Text('Line $index')),
          ),
        ),
      );

      // Fling and check every frame
      await tester.fling(find.byType(ListView), const Offset(0, -200), 1000);

      // Pump individual frames and verify alignment at each
      var aligned = true;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final offset = controller.offset;
        final remainder = offset % itemExtent;
        if (remainder > 0.01 && (itemExtent - remainder) > 0.01) {
          aligned = false;
          break;
        }
      }

      expect(aligned, isTrue, reason: 'Offset was not line-aligned mid-fling');
    });

    testWidgets('jumpTo rounds to nearest line boundary', (
      WidgetTester tester,
    ) async {
      final controller = LineSnapScrollController(itemExtent: itemExtent);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(
            controller: controller,
            physics: const LineSnapScrollPhysics(itemExtent: itemExtent),
            itemExtent: itemExtent,
            itemCount: 200,
            itemBuilder: (context, index) =>
                SizedBox(height: itemExtent, child: Text('Line $index')),
          ),
        ),
      );

      controller.jumpTo(33.0);
      await tester.pump();
      expect(controller.offset, moreOrLessEquals(40.0, epsilon: 0.01));

      controller.jumpTo(29.0);
      await tester.pump();
      expect(controller.offset, moreOrLessEquals(20.0, epsilon: 0.01));

      controller.jumpTo(50.0);
      await tester.pump();
      expect(controller.offset, moreOrLessEquals(60.0, epsilon: 0.01));
    });

    testWidgets('drag quantizes to line boundaries', (
      WidgetTester tester,
    ) async {
      final controller = LineSnapScrollController(itemExtent: itemExtent);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView.builder(
            controller: controller,
            physics: const LineSnapScrollPhysics(itemExtent: itemExtent),
            itemExtent: itemExtent,
            itemCount: 200,
            itemBuilder: (context, index) =>
                SizedBox(height: itemExtent, child: Text('Line $index')),
          ),
        ),
      );

      // Drag by various amounts — offset should always be line-aligned
      final gesture = await tester.startGesture(const Offset(200, 300));

      // Small drag: less than half a line — stays at 0
      await gesture.moveBy(const Offset(0, -5));
      await tester.pump();
      expect(
        controller.offset % itemExtent,
        moreOrLessEquals(0.0, epsilon: 0.01),
      );

      // Drag past half a line threshold — snaps to next line
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      expect(
        controller.offset % itemExtent,
        moreOrLessEquals(0.0, epsilon: 0.01),
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
