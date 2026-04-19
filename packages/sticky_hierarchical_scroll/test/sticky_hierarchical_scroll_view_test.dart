import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticky_hierarchical_scroll/sticky_hierarchical_scroll.dart';

/// Simple test item.
class _TestItem {
  final String name;
  final int level;
  final bool isSection;
  final double height;

  const _TestItem(
    this.name,
    this.level, {
    this.isSection = false,
    this.height = 20.0,
  });
}

/// Builds a test harness for StickyHierarchicalScrollView.
Widget _buildTestWidget({
  required List<_TestItem> items,
  double itemExtent = 20.0,
  ScrollController? controller,
  int maxStickyHeaders = 5,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 200,
        width: 300,
        child: StickyHierarchicalScrollView<_TestItem>(
          items: items,
          getLevel: (item) => item.level,
          isSection: (item) => item.isSection,
          itemExtent: itemExtent,
          controller: controller,
          itemBuilder: (context, item, index) {
            return Text(item.name, key: ValueKey('item_$index'));
          },
          config: StickyScrollConfig<_TestItem>(
            maxStickyHeaders: maxStickyHeaders,
            stickyHeaderBuilder: (context, candidate) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  candidate.data.name,
                  key: ValueKey('sticky_${candidate.originalIndex}'),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Builds a test harness using variable-height items via [itemHeight].
Widget _buildVariableHeightTestWidget({
  required List<_TestItem> items,
  ScrollController? controller,
  int maxStickyHeaders = 5,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 200,
        width: 300,
        child: StickyHierarchicalScrollView<_TestItem>.variableHeight(
          items: items,
          getLevel: (item) => item.level,
          isSection: (item) => item.isSection,
          itemHeight: (item) => item.height,
          controller: controller,
          itemBuilder: (context, item, index) {
            return Text(item.name, key: ValueKey('item_$index'));
          },
          config: StickyScrollConfig<_TestItem>(
            maxStickyHeaders: maxStickyHeaders,
            stickyHeaderBuilder: (context, candidate) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  candidate.data.name,
                  key: ValueKey('sticky_${candidate.originalIndex}'),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

void main() {
  final testItems = [
    const _TestItem('Section A', 0, isSection: true),
    const _TestItem('item a1', 1),
    const _TestItem('item a2', 1),
    const _TestItem('Sub B', 1, isSection: true),
    const _TestItem('item b1', 2),
    const _TestItem('item b2', 2),
    const _TestItem('Section C', 0, isSection: true),
    const _TestItem('item c1', 1),
    const _TestItem('item c2', 1),
    const _TestItem('item c3', 1),
    // Add enough items to make scrolling possible.
    const _TestItem('item c4', 1),
    const _TestItem('item c5', 1),
    const _TestItem('item c6', 1),
    const _TestItem('item c7', 1),
    const _TestItem('item c8', 1),
    const _TestItem('item c9', 1),
  ];

  group('StickyHierarchicalScrollView', () {
    testWidgets('renders items', (tester) async {
      await tester.pumpWidget(_buildTestWidget(items: testItems));

      // The viewport is 200px tall, itemExtent 20 -> 10 visible items.
      // Verify first visible items are rendered.
      expect(find.byKey(const ValueKey('item_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('item_1')), findsOneWidget);
    });

    testWidgets('sticky headers appear after scrolling past a section', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: testItems, controller: controller),
      );
      // Extra pump to process the post-frame callback that initializes
      // sticky headers.
      await tester.pump();

      // At scroll position 0, no headers are sticky — the list hasn't
      // scrolled past any section.
      expect(find.byKey(const ValueKey('sticky_0')), findsNothing);

      // Scroll past Sub B (index 3, position 60). After scrolling 80px,
      // Sub B's start (60) < 80, so both A and B should be sticky.
      controller.jumpTo(80.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('sticky_3')), findsOneWidget);
    });

    testWidgets('external ScrollController works', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: testItems, controller: controller),
      );

      // Jump using the external controller.
      controller.jumpTo(40.0);
      await tester.pump();

      // The widget should still function — Section A sticky header present.
      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);

      // Verify the controller offset is what we set.
      expect(controller.offset, 40.0);
    });

    testWidgets('renders with empty items', (tester) async {
      await tester.pumpWidget(_buildTestWidget(items: []));
      // Should not crash.
      expect(
        find.byType(StickyHierarchicalScrollView<_TestItem>),
        findsOneWidget,
      );
    });

    testWidgets('L1 sibling replaces outgoing header naturally', (
      tester,
    ) async {
      // Two L1 sibling sections under one L0 parent.
      // Sub X scope ends at Sub Y start, so they're consecutive siblings.
      final siblingItems = [
        const _TestItem('Section A', 0, isSection: true), // idx 0
        const _TestItem('Sub X', 1, isSection: true), // idx 1, startPos=20
        const _TestItem('item x1', 2), // idx 2
        const _TestItem('item x2', 2), // idx 3
        const _TestItem('Sub Y', 1, isSection: true), // idx 4, startPos=80
        const _TestItem('item y1', 2), // idx 5
        const _TestItem('item y2', 2), // idx 6
        const _TestItem('item y3', 2), // idx 7
        const _TestItem('item y4', 2), // idx 8
        const _TestItem('item y5', 2), // idx 9
        const _TestItem('item y6', 2), // idx 10
        const _TestItem('item y7', 2), // idx 11
        const _TestItem('item y8', 2), // idx 12
        const _TestItem('item y9', 2), // idx 13
      ];

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: siblingItems, controller: controller),
      );
      await tester.pump();

      // At scrollTop=50: Sub X is being pushed out (scope ends at 80).
      // Canonical: Sub X is still active, Sub Y not scrolled past yet.
      controller.jumpTo(50.0);
      await tester.pump();

      // Section A sticky at slot 0.
      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);
      // Sub X still sticky (being pushed out).
      expect(find.byKey(const ValueKey('sticky_1')), findsOneWidget);
      // Sub Y NOT rendered — not scrolled past (startPos=80 > 50).
      // Canonical: no synthetic replacement rendering.
      expect(find.byKey(const ValueKey('sticky_4')), findsNothing);

      // After scrolling past Sub Y, it appears naturally.
      controller.jumpTo(81.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('sticky_4')), findsOneWidget);
    });

    testWidgets('variable height items render correctly', (tester) async {
      // Headers are 30px tall, leaves are 20px (default).
      final varItems = [
        const _TestItem('Section A', 0, isSection: true, height: 30.0),
        const _TestItem('item a1', 1),
        const _TestItem('item a2', 1),
        const _TestItem('Section B', 0, isSection: true, height: 30.0),
        const _TestItem('item b1', 1),
        const _TestItem('item b2', 1),
        const _TestItem('item b3', 1),
        const _TestItem('item b4', 1),
        const _TestItem('item b5', 1),
        const _TestItem('item b6', 1),
      ];

      await tester.pumpWidget(_buildVariableHeightTestWidget(items: varItems));

      // Verify items render.
      expect(find.byKey(const ValueKey('item_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('item_1')), findsOneWidget);
    });

    testWidgets('variable height sticky headers appear after scrolling', (
      tester,
    ) async {
      // Headers 30px, leaves 20px (default).
      // Section A at offset 0 (height 30)
      // item a1 at offset 30 (height 20)
      // item a2 at offset 50 (height 20)
      // Section B at offset 70 (height 30)
      // item b1..b6 at offset 100, 120, 140, ...
      final varItems = [
        const _TestItem('Section A', 0, isSection: true, height: 30.0),
        const _TestItem('item a1', 1),
        const _TestItem('item a2', 1),
        const _TestItem('Section B', 0, isSection: true, height: 30.0),
        const _TestItem('item b1', 1),
        const _TestItem('item b2', 1),
        const _TestItem('item b3', 1),
        const _TestItem('item b4', 1),
        const _TestItem('item b5', 1),
        const _TestItem('item b6', 1),
      ];

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildVariableHeightTestWidget(items: varItems, controller: controller),
      );
      await tester.pump();

      // At scroll 0, no sticky headers.
      expect(find.byKey(const ValueKey('sticky_0')), findsNothing);

      // Scroll past Section A (30px header). At 31px, A is scrolled past.
      controller.jumpTo(31.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);
    });

    testWidgets('L0 section replaces outgoing header naturally', (
      tester,
    ) async {
      // Two consecutive L0 sections.
      final l0Items = [
        const _TestItem('Section A', 0, isSection: true), // idx 0
        const _TestItem('item a1', 1), // idx 1
        const _TestItem('item a2', 1), // idx 2
        const _TestItem('Section B', 0, isSection: true), // idx 3, startPos=60
        const _TestItem('item b1', 1), // idx 4
        const _TestItem('item b2', 1), // idx 5
        const _TestItem('item b3', 1), // idx 6
        const _TestItem('item b4', 1), // idx 7
        const _TestItem('item b5', 1), // idx 8
        const _TestItem('item b6', 1), // idx 9
        const _TestItem('item b7', 1), // idx 10
        const _TestItem('item b8', 1), // idx 11
        const _TestItem('item b9', 1), // idx 12
      ];

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: l0Items, controller: controller),
      );
      await tester.pump();

      // Section A scope ends at Section B (idx 3). scopeEndPosition = 60.
      // At scrollTop=45: A being pushed out. B not scrolled past (60 > 45).
      controller.jumpTo(45.0);
      await tester.pump();

      // Section A still sticky (outgoing, being pushed out).
      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);
      // Section B NOT rendered — canonical: no synthetic replacement.
      expect(find.byKey(const ValueKey('sticky_3')), findsNothing);

      // After scrolling past Section B, it appears naturally.
      controller.jumpTo(61.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('sticky_3')), findsOneWidget);
    });
  });
}
