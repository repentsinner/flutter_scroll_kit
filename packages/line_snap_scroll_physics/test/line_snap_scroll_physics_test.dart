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

  group('bottom-alignment invariant', () {
    testWidgets('holds after drag+settle on non-divisible viewport', (
      WidgetTester tester,
    ) async {
      // 150 / 20 = 7.5 -> viewport is not an integer multiple of itemExtent.
      final controller = await _pumpSizedList(
        tester,
        itemExtent: 20.0,
        viewportHeight: 150.0,
      );
      expect(controller.position.viewportDimension, 150.0);

      final gesture = await tester.startGesture(const Offset(200, 75));
      await gesture.moveBy(const Offset(0, -57)); // arbitrary, off-boundary
      await gesture.up();
      await tester.pumpAndSettle();

      _expectBottomAligned(controller);
    });

    testWidgets('holds after fling+settle on non-divisible viewport', (
      WidgetTester tester,
    ) async {
      final controller = await _pumpSizedList(
        tester,
        itemExtent: 20.0,
        viewportHeight: 150.0,
      );

      await tester.fling(find.byType(ListView), const Offset(0, -300), 1500);
      await tester.pumpAndSettle();

      _expectBottomAligned(controller);
    });

    // Snap math across extent/viewport combinations, including
    // non-divisible viewports. One widget per combo so each gets a fresh
    // layout (viewportDimension established before the first jump). Jump
    // targets are away from the min/max clamp boundaries, where the snap
    // formula governs the result directly.
    const extents = [16.0, 20.0, 24.0];
    const viewports = [100.0, 150.0, 137.0];
    for (final extent in extents) {
      for (final viewport in viewports) {
        testWidgets('invariant holds after jumps '
            '(extent $extent, viewport $viewport)', (
          WidgetTester tester,
        ) async {
          final controller = await _pumpSizedList(
            tester,
            itemExtent: extent,
            viewportHeight: viewport,
          );

          for (final target in [extent / 2 + 1, extent * 3 + 5, extent + 7]) {
            controller.jumpTo(target);
            await tester.pump();
            _expectBottomAligned(controller);
          }
        });
      }
    }

    testWidgets('clamps to minScrollExtent on negative-direction input', (
      WidgetTester tester,
    ) async {
      // Snap math at the zero/negative boundary. The formula's nearest
      // aligned target may be negative; the ListView clamps it to
      // minScrollExtent (0). Offset never goes below 0 and stays >= 0
      // under a negative-direction drag.
      final controller = await _pumpSizedList(
        tester,
        itemExtent: 20.0,
        viewportHeight: 150.0,
      );

      controller.jumpTo(0.0);
      await tester.pump();
      final atTop = controller.offset;
      expect(atTop, greaterThanOrEqualTo(0.0));
      expect(atTop, lessThan(20.0));

      // Drag downward (toward negative offset): offset stays clamped.
      final gesture = await tester.startGesture(const Offset(200, 75));
      await gesture.moveBy(const Offset(0, 13));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThanOrEqualTo(0.0));
      expect(controller.offset, lessThan(20.0));
    });
  });

  group('itemExtent guard', () {
    test('LineSnapScrollController rejects zero extent', () {
      expect(
        () => LineSnapScrollController(itemExtent: 0),
        throwsAssertionError,
      );
    });

    test('LineSnapScrollController rejects negative extent', () {
      expect(
        () => LineSnapScrollController(itemExtent: -10),
        throwsAssertionError,
      );
    });

    test('LineSnapScrollPhysics rejects zero extent', () {
      expect(() => LineSnapScrollPhysics(itemExtent: 0), throwsAssertionError);
    });

    test('LineSnapScrollPhysics rejects negative extent', () {
      expect(
        () => LineSnapScrollPhysics(itemExtent: -10),
        throwsAssertionError,
      );
    });
  });
}

/// Pumps a fixed-height [ListView] so [ScrollMetrics.viewportDimension] is
/// known and may be non-divisible by [itemExtent].
Future<LineSnapScrollController> _pumpSizedList(
  WidgetTester tester, {
  required double itemExtent,
  required double viewportHeight,
}) async {
  final controller = LineSnapScrollController(itemExtent: itemExtent);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          height: viewportHeight,
          child: ListView.builder(
            controller: controller,
            physics: LineSnapScrollPhysics(itemExtent: itemExtent),
            itemExtent: itemExtent,
            itemCount: 500,
            itemBuilder: (context, index) =>
                SizedBox(height: itemExtent, child: Text('Line $index')),
          ),
        ),
      ),
    ),
  );
  return controller;
}

/// Asserts the bottom-alignment invariant (SPEC §5):
/// `(offset + viewportDimension) mod itemExtent == 0`.
void _expectBottomAligned(LineSnapScrollController controller) {
  final extent = controller.itemExtent;
  final viewport = controller.position.viewportDimension;
  final remainder = (controller.offset + viewport) % extent;
  expect(
    remainder < 0.01 || (extent - remainder) < 0.01,
    isTrue,
    reason:
        'offset ${controller.offset} + viewport $viewport should align to '
        'itemExtent $extent (remainder $remainder)',
  );
}
