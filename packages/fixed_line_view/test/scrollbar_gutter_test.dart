import 'package:fixed_line_view/fixed_line_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The default Material scrollbar thickness used as the auto fallback.
const double _materialThickness = 8.0;
const double _viewportWidth = 300.0;
const double _itemExtent = 20.0;

/// Builds a [FixedLineView] whose rows carry a trailing [IconButton]
/// aligned to the right edge, so we can probe whether the gutter keeps
/// trailing content and tap targets clear of the scroll lane.
Widget _gutterHarness({
  required double? scrollbarGutter,
  required ScrollController controller,
  VoidCallback? onRowTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 200,
        width: _viewportWidth,
        child: FixedLineView(
          lineCount: 20,
          itemExtent: _itemExtent,
          controller: controller,
          scrollbarGutter: scrollbarGutter,
          lineBuilder: (context, index) => Row(
            children: [
              Expanded(
                child: Text('item $index', key: ValueKey('item_$index')),
              ),
              IconButton(
                key: ValueKey('row_btn_$index'),
                padding: EdgeInsets.zero,
                iconSize: 16,
                onPressed: onRowTap,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FixedLineView scrollbar gutter', () {
    testWidgets('default gutter insets the ListView by theme thickness', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _gutterHarness(scrollbarGutter: null, controller: controller),
      );
      await tester.pump();

      // The trailing edge of a row's content must clear the scroll lane:
      // the row's right edge sits at viewportWidth - gutter.
      final btn = tester.getRect(find.byKey(const ValueKey('row_btn_0')));
      expect(
        btn.right,
        moreOrLessEquals(_viewportWidth - _materialThickness, epsilon: 0.5),
      );
    });

    testWidgets('trailing IconButton in a row fires when gutter shown', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var fired = false;

      await tester.pumpWidget(
        _gutterHarness(
          scrollbarGutter: null,
          controller: controller,
          onRowTap: () => fired = true,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('row_btn_0')));
      expect(fired, isTrue);
    });

    testWidgets('explicit positive gutter reserves exactly that width', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const explicit = 24.0;

      await tester.pumpWidget(
        _gutterHarness(scrollbarGutter: explicit, controller: controller),
      );
      await tester.pump();

      final btn = tester.getRect(find.byKey(const ValueKey('row_btn_0')));
      expect(
        btn.right,
        moreOrLessEquals(_viewportWidth - explicit, epsilon: 0.5),
      );
    });

    testWidgets('scrollbarGutter: 0 restores full-bleed', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _gutterHarness(scrollbarGutter: 0, controller: controller),
      );
      await tester.pump();

      final btn = tester.getRect(find.byKey(const ValueKey('row_btn_0')));
      expect(btn.right, moreOrLessEquals(_viewportWidth, epsilon: 0.5));
    });

    testWidgets('gutter tracks a custom ScrollbarThemeData thickness', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const customThickness = 14.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            scrollbarTheme: const ScrollbarThemeData(
              thickness: WidgetStatePropertyAll<double>(customThickness),
            ),
          ),
          home: Scaffold(
            body: SizedBox(
              height: 200,
              width: _viewportWidth,
              child: FixedLineView(
                lineCount: 20,
                itemExtent: _itemExtent,
                controller: controller,
                lineBuilder: (context, index) => Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    key: ValueKey('probe_$index'),
                    width: 4,
                    height: 4,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final probe = tester.getRect(find.byKey(const ValueKey('probe_0')));
      expect(
        probe.right,
        moreOrLessEquals(_viewportWidth - customThickness, epsilon: 0.5),
      );
    });

    testWidgets('StreamLineView forwards scrollbarGutter to FixedLineView', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const explicit = 24.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              width: _viewportWidth,
              child: StreamLineView<int>(
                itemStream: const Stream<int>.empty(),
                initialItems: const [0, 1, 2, 3, 4],
                itemExtent: _itemExtent,
                controller: controller,
                scrollbarGutter: explicit,
                itemBuilder: (context, item, index) => Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    key: ValueKey('probe_$index'),
                    width: 4,
                    height: 4,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final probe = tester.getRect(find.byKey(const ValueKey('probe_0')));
      expect(
        probe.right,
        moreOrLessEquals(_viewportWidth - explicit, epsilon: 0.5),
      );
    });

    test('FixedLineView rejects a negative scrollbarGutter', () {
      expect(
        () => FixedLineView(
          lineCount: 1,
          itemExtent: _itemExtent,
          scrollbarGutter: -1,
          lineBuilder: (context, index) => const SizedBox(),
        ),
        throwsAssertionError,
      );
    });
  });
}
