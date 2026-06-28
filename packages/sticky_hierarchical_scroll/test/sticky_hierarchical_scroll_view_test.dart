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

  group('Trailing-item key stability', () {
    testWidgets(
      'prepending a data item preserves trailing widget state (focus)',
      (tester) async {
        // Mutable item list so we can prepend and re-pump.
        var items = <_TestItem>[
          const _TestItem('Section A', 0, isSection: true),
          for (int i = 1; i <= 10; i++) _TestItem('item $i', 1),
        ];

        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        late StateSetter setOuter;
        Widget build() {
          return MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  setOuter = setState;
                  return SizedBox(
                    height: 400,
                    width: 300,
                    child: StickyHierarchicalScrollView<_TestItem>(
                      items: items,
                      getLevel: (item) => item.level,
                      isSection: (item) => item.isSection,
                      itemExtent: 20.0,
                      trailingItemCount: 1,
                      trailingItemBuilder: (context, index) => TextField(
                        key: const ValueKey('trailing_field'),
                        focusNode: focusNode,
                      ),
                      itemBuilder: (context, item, index) =>
                          Text(item.name, key: ValueKey('item_$index')),
                      config: StickyScrollConfig<_TestItem>(
                        stickyHeaderBuilder: (context, candidate) =>
                            Text(candidate.data.name),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }

        await tester.pumpWidget(build());
        await tester.pump();

        // Focus the trailing TextField.
        await tester.tap(find.byKey(const ValueKey('trailing_field')));
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);

        // Prepend a data item — shifts every data index by one and so
        // shifts the trailing element's positional index. Without the
        // negative-key findChildIndexCallback the trailing element would
        // be recreated and focus lost.
        setOuter(() {
          items = [const _TestItem('Section Z', 0, isSection: true), ...items];
        });
        await tester.pump();

        expect(
          focusNode.hasFocus,
          isTrue,
          reason:
              'trailing TextField must retain focus across the index shift; '
              'findChildIndexCallback keys it by ValueKey<int>(-(i+1))',
        );
      },
    );
  });

  group('Internal/external controller disposal', () {
    testWidgets('internal controller created and disposed without error', (
      tester,
    ) async {
      // No controller passed -> the widget owns one.
      await tester.pumpWidget(_buildTestWidget(items: testItems));
      await tester.pump();

      // Remove the widget to trigger dispose(). A leaked or
      // double-disposed internal controller surfaces as a test error.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('external controller is NOT disposed by the widget', (
      tester,
    ) async {
      final external = ScrollController();

      await tester.pumpWidget(
        _buildTestWidget(items: testItems, controller: external),
      );
      await tester.pump();

      // Remove the widget. It must not dispose a controller it does
      // not own.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      // If the widget had disposed it, this second dispose would throw
      // "A ScrollController was used after being disposed".
      expect(external.dispose, returnsNormally);
    });
  });

  group('onStickyHeaderTap navigation callback', () {
    Widget buildNavHarness({
      required ScrollController controller,
      required bool enableNavigation,
      void Function(int)? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: 300,
            child: StickyHierarchicalScrollView<_TestItem>(
              items: testItems,
              getLevel: (item) => item.level,
              isSection: (item) => item.isSection,
              itemExtent: 20.0,
              controller: controller,
              onStickyHeaderTap: onTap,
              itemBuilder: (context, item, index) =>
                  Text(item.name, key: ValueKey('item_$index')),
              config: StickyScrollConfig<_TestItem>(
                enableNavigation: enableNavigation,
                stickyHeaderBuilder: (context, candidate) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    candidate.data.name,
                    key: ValueKey('sticky_${candidate.originalIndex}'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('tapping a pinned header fires callback with originalIndex; '
        'scroll position unchanged', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      int? tapped;

      await tester.pumpWidget(
        buildNavHarness(
          controller: controller,
          enableNavigation: true,
          onTap: (index) => tapped = index,
        ),
      );
      await tester.pump();

      // Scroll so Section A (index 0) pins.
      controller.jumpTo(80.0);
      await tester.pump();
      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);

      final before = controller.offset;
      await tester.tap(find.byKey(const ValueKey('sticky_0')));
      await tester.pump();

      expect(tapped, 0);
      // Package does not scroll itself when a callback is supplied.
      expect(controller.offset, before);
    });

    testWidgets('enableNavigation false makes the header tap a no-op', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var fired = false;

      await tester.pumpWidget(
        buildNavHarness(
          controller: controller,
          enableNavigation: false,
          onTap: (_) => fired = true,
        ),
      );
      await tester.pump();

      controller.jumpTo(80.0);
      await tester.pump();
      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);

      final before = controller.offset;
      await tester.tap(find.byKey(const ValueKey('sticky_0')));
      await tester.pump();

      // GestureDetector.onTap is null -> callback never fires, no scroll.
      expect(fired, isFalse);
      expect(controller.offset, before);
    });
  });

  group('stickyDecoration application', () {
    testWidgets('pinned header is wrapped in a DecoratedBox carrying the '
        'configured decoration', (tester) async {
      const distinctive = BoxDecoration(color: Color(0xFF123456));
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              width: 300,
              child: StickyHierarchicalScrollView<_TestItem>(
                items: testItems,
                getLevel: (item) => item.level,
                isSection: (item) => item.isSection,
                itemExtent: 20.0,
                controller: controller,
                itemBuilder: (context, item, index) =>
                    Text(item.name, key: ValueKey('item_$index')),
                config: StickyScrollConfig<_TestItem>(
                  stickyDecoration: distinctive,
                  stickyHeaderBuilder: (context, candidate) => Text(
                    candidate.data.name,
                    key: ValueKey('sticky_${candidate.originalIndex}'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Scroll past Section A only (Sub B at 60 not yet passed), so a
      // single header pins and exactly one DecoratedBox carries the
      // configured decoration.
      controller.jumpTo(40.0);
      await tester.pump();
      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);
      expect(find.byKey(const ValueKey('sticky_3')), findsNothing);

      final decorated = find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.decoration == distinctive,
      );
      expect(decorated, findsOneWidget);
    });
  });

  group('StickyHierarchicalScrollView scrollbar gutter', () {
    // Items: one section header (sticky candidate) plus enough leaves to
    // scroll, so a header can pin and we can probe both a scrolling row
    // and a pinned header.
    final gutterItems = <_TestItem>[
      const _TestItem('Section A', 0, isSection: true), // idx 0
      for (int i = 1; i <= 20; i++) _TestItem('item $i', 1), // idx 1..20
    ];

    // The default Material scrollbar thickness used as the auto fallback.
    const double materialThickness = 8.0;
    const double viewportWidth = 300.0;

    /// Builds a harness whose rows and sticky header each carry a trailing
    /// IconButton aligned to the right edge, so we can test whether the
    /// gutter keeps it clear of the scroll lane.
    Widget buildGutterHarness({
      required double? scrollbarGutter,
      required ScrollController controller,
      VoidCallback? onRowTap,
      VoidCallback? onHeaderTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            width: viewportWidth,
            child: StickyHierarchicalScrollView<_TestItem>(
              items: gutterItems,
              getLevel: (item) => item.level,
              isSection: (item) => item.isSection,
              itemExtent: 20.0,
              controller: controller,
              scrollbarGutter: scrollbarGutter,
              itemBuilder: (context, item, index) {
                return Row(
                  children: [
                    Expanded(
                      child: Text(item.name, key: ValueKey('item_$index')),
                    ),
                    IconButton(
                      key: ValueKey('row_btn_$index'),
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      onPressed: onRowTap,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                );
              },
              config: StickyScrollConfig<_TestItem>(
                stickyHeaderBuilder: (context, candidate) {
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          candidate.data.name,
                          key: ValueKey('sticky_${candidate.originalIndex}'),
                        ),
                      ),
                      IconButton(
                        key: ValueKey('header_btn_${candidate.originalIndex}'),
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        onPressed: onHeaderTap,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('default gutter insets the inner ListView by theme thickness', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildGutterHarness(scrollbarGutter: null, controller: controller),
      );
      await tester.pump();

      // The trailing edge of a row's content must clear the scroll lane:
      // the row's right edge sits at viewportWidth - gutter.
      final btn = tester.getRect(find.byKey(const ValueKey('row_btn_0')));
      expect(
        btn.right,
        moreOrLessEquals(viewportWidth - materialThickness, epsilon: 0.5),
      );
    });

    testWidgets('default gutter insets the sticky-header overlay', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildGutterHarness(scrollbarGutter: null, controller: controller),
      );
      await tester.pump();

      // Scroll so Section A pins as a sticky overlay.
      controller.jumpTo(80.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);
      final headerBtn = tester.getRect(
        find.byKey(const ValueKey('header_btn_0')),
      );
      expect(
        headerBtn.right,
        moreOrLessEquals(viewportWidth - materialThickness, epsilon: 0.5),
      );
    });

    testWidgets('trailing IconButton in a row fires when gutter shown', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var fired = false;

      await tester.pumpWidget(
        buildGutterHarness(
          scrollbarGutter: null,
          controller: controller,
          onRowTap: () => fired = true,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('row_btn_0')));
      expect(fired, isTrue);
    });

    testWidgets('trailing affordance in a pinned header fires', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var fired = false;

      await tester.pumpWidget(
        buildGutterHarness(
          scrollbarGutter: null,
          controller: controller,
          onHeaderTap: () => fired = true,
        ),
      );
      await tester.pump();

      controller.jumpTo(80.0);
      await tester.pump();
      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('header_btn_0')));
      expect(fired, isTrue);
    });

    testWidgets('explicit positive gutter reserves exactly that width', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const explicit = 24.0;

      await tester.pumpWidget(
        buildGutterHarness(scrollbarGutter: explicit, controller: controller),
      );
      await tester.pump();

      final btn = tester.getRect(find.byKey(const ValueKey('row_btn_0')));
      expect(
        btn.right,
        moreOrLessEquals(viewportWidth - explicit, epsilon: 0.5),
      );
    });

    testWidgets('scrollbarGutter: 0 restores full-bleed', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        buildGutterHarness(scrollbarGutter: 0, controller: controller),
      );
      await tester.pump();

      final btn = tester.getRect(find.byKey(const ValueKey('row_btn_0')));
      expect(btn.right, moreOrLessEquals(viewportWidth, epsilon: 0.5));

      controller.jumpTo(80.0);
      await tester.pump();
      expect(find.byKey(const ValueKey('sticky_0')), findsOneWidget);
      final headerBtn = tester.getRect(
        find.byKey(const ValueKey('header_btn_0')),
      );
      expect(headerBtn.right, moreOrLessEquals(viewportWidth, epsilon: 0.5));
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
              width: viewportWidth,
              child: StickyHierarchicalScrollView<_TestItem>(
                items: gutterItems,
                getLevel: (item) => item.level,
                isSection: (item) => item.isSection,
                itemExtent: 20.0,
                controller: controller,
                itemBuilder: (context, item, index) => Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    key: ValueKey('probe_$index'),
                    width: 4,
                    height: 4,
                  ),
                ),
                config: StickyScrollConfig<_TestItem>(
                  stickyHeaderBuilder: (context, candidate) =>
                      Text(candidate.data.name),
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
        moreOrLessEquals(viewportWidth - customThickness, epsilon: 0.5),
      );
    });
  });
}
