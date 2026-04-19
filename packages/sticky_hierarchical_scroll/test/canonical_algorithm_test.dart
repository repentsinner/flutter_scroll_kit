import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sticky_hierarchical_scroll/sticky_hierarchical_scroll.dart';

// ---------------------------------------------------------------------------
// Test infrastructure
// ---------------------------------------------------------------------------

/// Simple test item with name, level, and section flag.
class _TestItem {
  final String name;
  final int level;
  final bool isSection;

  const _TestItem(this.name, this.level, {this.isSection = false});

  @override
  String toString() => '$name (L$level${isSection ? " §" : ""})';
}

/// Builds a test harness for StickyHierarchicalScrollView.
///
/// The viewport is 200px tall with 20px items (10 visible rows).
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
            return SizedBox(
              height: itemExtent,
              child: Text(item.name, key: ValueKey('item_$index')),
            );
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

/// Finds the Rect of a sticky header widget by its original index.
Rect? _stickyRect(WidgetTester tester, int originalIndex) {
  final finder = find.byKey(ValueKey('sticky_$originalIndex'));
  if (finder.evaluate().isEmpty) return null;
  return tester.getRect(finder);
}

/// Returns top-left Y of a sticky header, or null if not found.
double? _stickyTop(WidgetTester tester, int originalIndex) {
  return _stickyRect(tester, originalIndex)?.top;
}

/// Returns whether a sticky header is present in the widget tree.
bool _stickyExists(WidgetTester tester, int originalIndex) {
  return find.byKey(ValueKey('sticky_$originalIndex')).evaluate().isNotEmpty;
}

// ---------------------------------------------------------------------------
// Standard test hierarchy (8 items, itemExtent=20)
//
//  idx  item                level  section  startPos  endIdx  scopeEnd
//  ---  ------------------  -----  -------  --------  ------  --------
//   0   Section A           0      yes      0         5       120
//   1     item a1           1      no
//   2     item a2           1      no
//   3     Sub-section B     1      yes      60        5       120
//   4       item b1         2      no
//   5       item b2         2      no
//   6   Section C           0      yes      120       7       160
//   7     item c1           1      no
// ---------------------------------------------------------------------------

final _standardItems = [
  const _TestItem('Section A', 0, isSection: true), // idx 0
  const _TestItem('item a1', 1), // idx 1
  const _TestItem('item a2', 1), // idx 2
  const _TestItem('Sub B', 1, isSection: true), // idx 3
  const _TestItem('item b1', 2), // idx 4
  const _TestItem('item b2', 2), // idx 5
  const _TestItem('Section C', 0, isSection: true), // idx 6
  const _TestItem('item c1', 1), // idx 7
  // Padding to ensure scrollable area.
  const _TestItem('item c2', 1), // idx 8
  const _TestItem('item c3', 1), // idx 9
  const _TestItem('item c4', 1), // idx 10
  const _TestItem('item c5', 1), // idx 11
  const _TestItem('item c6', 1), // idx 12
  const _TestItem('item c7', 1), // idx 13
  const _TestItem('item c8', 1), // idx 14
  const _TestItem('item c9', 1), // idx 15
];

void main() {
  // =========================================================================
  // Group 1: Activation threshold — when headers become/stop being sticky
  // =========================================================================
  group('Activation threshold', () {
    testWidgets('no sticky headers at scrollTop 0', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // At idle (scrollTop 0), no sticky headers should appear.
      expect(_stickyExists(tester, 0), isFalse);
    });

    testWidgets(
      'Section A becomes sticky at scrollTop 1 (just past startPosition)',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildTestWidget(items: _standardItems, controller: controller),
        );
        await tester.pump();

        controller.jumpTo(1.0);
        await tester.pump();

        expect(_stickyExists(tester, 0), isTrue);
      },
    );

    testWidgets('Sub B becomes sticky when scrolled past its slot threshold', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // Sub B: idx 3, startPosition=60, slot 1, slotTop=20.
      // Activation: 60 - scrollTop < 20 → scrollTop > 40.
      controller.jumpTo(41.0);
      await tester.pump();

      // Both Section A (parent) and Sub B should be sticky.
      expect(_stickyExists(tester, 0), isTrue);
      expect(_stickyExists(tester, 3), isTrue);
    });

    testWidgets('Sub B drops when its scope no longer covers its slot', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // Sub B scope ends at index 5 -> scopeEndPosition = 120.
      // Sub B occupies slot 1 (top = 20, bottom = 40).
      // Canonical: Sub B drops when slotTop(20) > scopeEndViewport.
      // scopeEndViewport = 120 - scrollTop.
      // At scrollTop=101: scopeEndViewport=19, 20 <= 19 is false → drops.
      //
      // Section A still active: slotTop(0) <= scopeEndViewport(19) ✓.
      // A is being pushed out (slotBottom(20) > 19).
      //
      // Section C starts at 120 — not scrolled past at 101.
      controller.jumpTo(101.0);
      await tester.pump();

      // Section A remains active (being pushed out).
      expect(
        _stickyExists(tester, 0),
        isTrue,
        reason: 'Section A should still be active (scope covers slot 0)',
      );
      // Sub B should NOT be active.
      expect(
        _stickyExists(tester, 3),
        isFalse,
        reason:
            'Sub B should drop when scope no longer covers slot 1 '
            '(canonical slot-fit)',
      );
      // Section C not yet scrolled past.
      expect(
        _stickyExists(tester, 6),
        isFalse,
        reason: 'Section C starts at 120, not scrolled past at 101',
      );
    });

    testWidgets('Section C becomes active after scrolling past it', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // Section C starts at index 6 -> position 120.
      // At scrollTop=121: C's startPosition(120) < 121 → in intersecting.
      // Context stack: A replaced by C at level 0, B cleared.
      // Slot 0: C headerVP = 120-121 = -1 < 0 ✓, scopeEndVP = 320-121
      //         = 199. 0 <= 199 ✓ → active.
      controller.jumpTo(121.0);
      await tester.pump();

      expect(
        _stickyExists(tester, 6),
        isTrue,
        reason: 'Section C should be sticky',
      );
      // Section A and Sub B should not be active.
      expect(_stickyExists(tester, 0), isFalse);
      expect(_stickyExists(tester, 3), isFalse);
    });
  });

  // =========================================================================
  // Group 2: Pixel-position assertions for sticky header placement
  // =========================================================================
  group('Pixel positions', () {
    testWidgets('single sticky header sits at top of viewport', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      controller.jumpTo(20.0);
      await tester.pump();

      // Section A at slot 0 → top should be at scaffold body top.
      final rect = _stickyRect(tester, 0);
      expect(rect, isNotNull);
      // The Scaffold body starts below the app bar (if any). In our test
      // setup there's no AppBar, so the body top is the screen top.
      // We check relative to the Scaffold body.
      final bodyFinder = find.byType(StickyHierarchicalScrollView<_TestItem>);
      final bodyRect = tester.getRect(bodyFinder);
      expect(rect!.top, bodyRect.top);
    });

    testWidgets('nested header sits at slot 1 (one itemExtent down)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // Scroll past Sub B (position 60).
      controller.jumpTo(61.0);
      await tester.pump();

      final bodyRect = tester.getRect(
        find.byType(StickyHierarchicalScrollView<_TestItem>),
      );

      // Section A at slot 0.
      final aTop = _stickyTop(tester, 0);
      expect(aTop, bodyRect.top);

      // Sub B at slot 1 (20px down).
      final bTop = _stickyTop(tester, 3);
      expect(bTop, bodyRect.top + 20.0);
    });
  });

  // =========================================================================
  // Group 3: Push-out — last-line negative offset
  // =========================================================================
  group('Push-out (last-line offset)', () {
    testWidgets(
      'only the last active header gets negative offset during push-out',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildTestWidget(items: _standardItems, controller: controller),
        );
        await tester.pump();

        // Section A and Sub B both active. Sub B scope ends at 120.
        // Sub B occupies slot 1 (top=20, bottom=40).
        // At scrollTop=90: scopeEndViewport = 120 - 90 = 30.
        // slotBottom(40) > scopeEndViewport(30) → push-out.
        // Offset = scopeEndViewport - slotBottom = 30 - 40 = -10.
        // Sub B rendered at 20 + (-10) = 10.
        controller.jumpTo(90.0);
        await tester.pump();

        final bodyRect = tester.getRect(
          find.byType(StickyHierarchicalScrollView<_TestItem>),
        );

        // Section A (slot 0) stays at its fixed position.
        final aTop = _stickyTop(tester, 0);
        expect(aTop, bodyRect.top, reason: 'Parent should not move');

        // Sub B should be pushed up. Its exact position depends on
        // the push-out calculation.
        final bTop = _stickyTop(tester, 3);
        expect(bTop, isNotNull);
        // Canonical: Sub B at slot 1 (20) with push offset.
        // scopeEndViewport = 120 - 90 = 30. slotBottom = 40.
        // Pushed to: 30 - 20 = 10 (scopeEndViewport - itemExtent).
        expect(
          bTop! < bodyRect.top + 20.0,
          isTrue,
          reason: 'Sub B should be pushed up from its normal slot position',
        );
      },
    );

    testWidgets('overlay height shrinks during push-out (canonical)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // With 2 headers active (A at slot 0, Sub B at slot 1),
      // normal overlay height = 40px (2 * 20).
      // During push-out at scrollTop=90:
      // lastLineRelativePosition = scopeEndViewport - slotBottom
      //   = (120-90) - 40 = -10
      // Canonical overlay height = 40 + (-10) = 30.
      controller.jumpTo(90.0);
      await tester.pump();

      // The sticky overlay is built by _buildStickyContent which wraps
      // everything in ClipRect > SizedBox(height: stickyAreaHeight) > Stack.
      // Find the inner Stack that's a descendant of Positioned (the overlay).
      // The outer Stack belongs to StickyHierarchicalScrollView's build.
      final overlayStack = find.descendant(
        of: find.byType(Positioned),
        matching: find.byType(Stack),
      );

      SizedBox? overlaySizedBox;
      for (final element in overlayStack.evaluate()) {
        final parent = element.renderObject?.parent;
        if (parent != null) {
          // Walk up to find the SizedBox with explicit height.
          Element? current = element;
          while (current != null) {
            if (current.widget is SizedBox) {
              final sb = current.widget as SizedBox;
              if (sb.height != null) {
                overlaySizedBox = sb;
                break;
              }
            }
            // Go to parent element.
            Element? parentElement;
            current.visitAncestorElements((e) {
              parentElement = e;
              return false; // stop at first ancestor
            });
            current = parentElement;
          }
          if (overlaySizedBox != null) break;
        }
      }

      expect(
        overlaySizedBox,
        isNotNull,
        reason: 'Overlay SizedBox should exist',
      );
      // Canonical: overlay height should be 30 (shrunk from 40).
      // Current implementation keeps it at 40 (divergence).
      expect(
        overlaySizedBox!.height,
        lessThan(40.0),
        reason:
            'Overlay should shrink during push-out '
            '(canonical dynamic height)',
      );
    });
  });

  // =========================================================================
  // Group 4: Regression — behaviors that diverge from canonical
  // =========================================================================
  group('Regression: stale header after scope ends', () {
    testWidgets('child header drops when its scope no longer covers its slot', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // Sub B scope ends at index 5 -> scopeEndPosition = 120.
      // Sub B occupies slot 1 (top=20, bottom=40).
      // When scopeEndViewport < slotTop(20), Sub B should drop.
      // scopeEndViewport = 120 - scrollTop < 20 → scrollTop > 100.
      // At scrollTop=101: scopeEndViewport = 19 < 20.
      // Canonical: Sub B should not be active.
      controller.jumpTo(101.0);
      await tester.pump();

      // Canonical: Sub B (index 3) should NOT be sticky.
      // (Current implementation may still show it — this is a regression
      // test for the canonical algorithm.)
      expect(
        _stickyExists(tester, 3),
        isFalse,
        reason:
            'Sub B should drop when its scope no longer covers slot 1 '
            '(canonical slot-fit)',
      );
    });

    testWidgets('no synthetic replacement rendering needed (canonical)', (
      tester,
    ) async {
      // Two L1 siblings under L0 parent. In canonical algorithm,
      // when Sub X scope ends, Sub Y appears naturally from the
      // candidate set — no _findNextSibling needed.
      final siblingItems = [
        const _TestItem('Root', 0, isSection: true), // idx 0
        const _TestItem('Sub X', 1, isSection: true), // idx 1, pos=20
        const _TestItem('x1', 2), // idx 2
        const _TestItem('x2', 2), // idx 3
        const _TestItem('Sub Y', 1, isSection: true), // idx 4, pos=80
        const _TestItem('y1', 2), // idx 5
        const _TestItem('y2', 2), // idx 6
        const _TestItem('y3', 2), // idx 7
        const _TestItem('y4', 2), // idx 8
        const _TestItem('y5', 2), // idx 9
        const _TestItem('y6', 2), // idx 10
        const _TestItem('y7', 2), // idx 11
        const _TestItem('y8', 2), // idx 12
        const _TestItem('y9', 2), // idx 13
      ];

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: siblingItems, controller: controller),
      );
      await tester.pump();

      // Sub X scope ends at index 3 -> scopeEndPosition = 80.
      // At scrollTop=81: Sub X scope doesn't cover slot 1 anymore.
      // Sub Y (startPosition=80) should now be active at slot 1.
      controller.jumpTo(81.0);
      await tester.pump();

      // Root should still be at slot 0.
      expect(_stickyExists(tester, 0), isTrue);
      // Sub Y should be sticky at slot 1 (natural replacement).
      expect(
        _stickyExists(tester, 4),
        isTrue,
        reason: 'Sub Y should appear naturally when Sub X scope ends',
      );
      // Sub X should NOT be sticky anymore.
      expect(
        _stickyExists(tester, 1),
        isFalse,
        reason: 'Sub X should drop when its scope ends',
      );
    });

    testWidgets('two headers do not move simultaneously during transition', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // At a scroll position where push-out is happening for Sub B,
      // only Sub B should have a negative offset. Section A stays fixed.
      controller.jumpTo(85.0);
      await tester.pump();

      final bodyRect = tester.getRect(
        find.byType(StickyHierarchicalScrollView<_TestItem>),
      );

      final aTop = _stickyTop(tester, 0);
      // Section A must remain at its fixed slot position.
      expect(
        aTop,
        bodyRect.top,
        reason: 'Only the last active header should move during push-out',
      );
    });
  });

  // =========================================================================
  // Group 5: Exact boundary tests
  // =========================================================================
  group('Exact boundaries', () {
    testWidgets('L0 header activates at startPosition + 1', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // Section A at position 0, slot 0: threshold is startPosition.
      // For slot 0, slot-fit and prefilter threshold coincide.
      controller.jumpTo(0.0);
      await tester.pump();
      expect(_stickyExists(tester, 0), isFalse);

      controller.jumpTo(1.0);
      await tester.pump();
      expect(_stickyExists(tester, 0), isTrue);
    });

    testWidgets(
      'nested header activates at slot threshold, not startPosition',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildTestWidget(items: _standardItems, controller: controller),
        );
        await tester.pump();

        // Sub B: idx 3, startPosition=60, level 1, slot 1.
        // VS Code threshold: startPosition - scrollTop < slot * itemExtent
        //   60 - scrollTop < 20  →  scrollTop > 40.
        // At scrollTop=40: 60-40=20, 20 < 20 is false → not active.
        controller.jumpTo(40.0);
        await tester.pump();
        expect(
          _stickyExists(tester, 3),
          isFalse,
          reason: 'Sub B should not be active at exact slot boundary',
        );

        // At scrollTop=41: 60-41=19, 19 < 20 → active.
        controller.jumpTo(41.0);
        await tester.pump();
        expect(
          _stickyExists(tester, 0),
          isTrue,
          reason: 'Section A should be active',
        );
        expect(
          _stickyExists(tester, 3),
          isTrue,
          reason: 'Sub B should activate when it crosses its slot, not y=0',
        );
      },
    );

    testWidgets('push-out begins exactly when slotBottom > scopeEndViewport', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // Section A alone: slot 0, slotBottom = 20.
      // scopeEndPosition = 120. Push-out when 120 - scrollTop < 20,
      // i.e. scrollTop > 100.

      // At scrollTop = 100: scopeEndViewport = 20. slotBottom = 20.
      // No push-out (20 >= 20 → not pushed).
      controller.jumpTo(100.0);
      await tester.pump();

      final bodyRect = tester.getRect(
        find.byType(StickyHierarchicalScrollView<_TestItem>),
      );

      // With both A and Sub B: Sub B at slot 1, slotBottom=40.
      // Sub B scopeEnd=120. Push-out when 120 - scrollTop < 40,
      // i.e. scrollTop > 80.

      // At scrollTop=80: scopeEndViewport = 40. slotBottom = 40.
      // No push-out yet.
      controller.jumpTo(80.0);
      await tester.pump();

      if (_stickyExists(tester, 3)) {
        final bTop = _stickyTop(tester, 3)!;
        // At scrollTop=80, Sub B should be at its normal slot position.
        expect(
          bTop,
          bodyRect.top + 20.0,
          reason: 'No push-out when scopeEndViewport == slotBottom',
        );
      }

      // At scrollTop=81: scopeEndViewport = 39. slotBottom = 40.
      // Push-out = 39 - 40 = -1. Sub B at 20 + (-1) = 19.
      controller.jumpTo(81.0);
      await tester.pump();

      if (_stickyExists(tester, 3)) {
        final bTop = _stickyTop(tester, 3)!;
        expect(
          bTop,
          lessThan(bodyRect.top + 20.0),
          reason: 'Push-out should start at scrollTop > 80',
        );
      }
    });
  });

  // =========================================================================
  // Group 6: Adversarial hierarchies
  // =========================================================================
  group('Adversarial hierarchies', () {
    testWidgets('deep nesting with multiple active ancestors', (tester) async {
      // 4 levels deep.
      final deepItems = [
        const _TestItem('L0', 0, isSection: true), // idx 0
        const _TestItem('L1', 1, isSection: true), // idx 1
        const _TestItem('L2', 2, isSection: true), // idx 2
        const _TestItem('L3', 3, isSection: true), // idx 3
        const _TestItem('leaf', 4), // idx 4
        const _TestItem('leaf', 4), // idx 5
        const _TestItem('leaf', 4), // idx 6
        const _TestItem('leaf', 4), // idx 7
        const _TestItem('leaf', 4), // idx 8
        const _TestItem('leaf', 4), // idx 9
        const _TestItem('leaf', 4), // idx 10
        const _TestItem('leaf', 4), // idx 11
        const _TestItem('leaf', 4), // idx 12
        const _TestItem('leaf', 4), // idx 13
        const _TestItem('leaf', 4), // idx 14
        const _TestItem('leaf', 4), // idx 15
      ];

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: deepItems, controller: controller),
      );
      await tester.pump();

      // Scroll past all 4 headers.
      // L3 starts at position 60. Scroll to 61.
      controller.jumpTo(61.0);
      await tester.pump();

      // All 4 ancestors should be sticky.
      expect(_stickyExists(tester, 0), isTrue, reason: 'L0 sticky');
      expect(_stickyExists(tester, 1), isTrue, reason: 'L1 sticky');
      expect(_stickyExists(tester, 2), isTrue, reason: 'L2 sticky');
      expect(_stickyExists(tester, 3), isTrue, reason: 'L3 sticky');

      // Verify slot positions.
      final bodyRect = tester.getRect(
        find.byType(StickyHierarchicalScrollView<_TestItem>),
      );
      expect(_stickyTop(tester, 0), bodyRect.top); // slot 0
      expect(_stickyTop(tester, 1), bodyRect.top + 20.0); // slot 1
      expect(_stickyTop(tester, 2), bodyRect.top + 40.0); // slot 2
      expect(_stickyTop(tester, 3), bodyRect.top + 60.0); // slot 3
    });

    testWidgets('maxStickyHeaders truncates active set', (tester) async {
      final deepItems = [
        const _TestItem('L0', 0, isSection: true), // idx 0
        const _TestItem('L1', 1, isSection: true), // idx 1
        const _TestItem('L2', 2, isSection: true), // idx 2
        const _TestItem('L3', 3, isSection: true), // idx 3
        const _TestItem('leaf', 4), // idx 4
        const _TestItem('leaf', 4), // idx 5
        const _TestItem('leaf', 4), // idx 6
        const _TestItem('leaf', 4), // idx 7
        const _TestItem('leaf', 4), // idx 8
        const _TestItem('leaf', 4), // idx 9
        const _TestItem('leaf', 4), // idx 10
        const _TestItem('leaf', 4), // idx 11
        const _TestItem('leaf', 4), // idx 12
        const _TestItem('leaf', 4), // idx 13
        const _TestItem('leaf', 4), // idx 14
        const _TestItem('leaf', 4), // idx 15
      ];

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(
          items: deepItems,
          controller: controller,
          maxStickyHeaders: 2,
        ),
      );
      await tester.pump();

      controller.jumpTo(61.0);
      await tester.pump();

      // Only 2 headers max. Should show the 2 deepest active ancestors
      // that fit in the max count.
      int stickyCount = 0;
      for (int i = 0; i < 4; i++) {
        if (_stickyExists(tester, i)) stickyCount++;
      }
      expect(
        stickyCount,
        lessThanOrEqualTo(2),
        reason: 'maxStickyHeaders=2 should limit visible headers',
      );
    });

    testWidgets('consecutive same-level siblings after nested sections', (
      tester,
    ) async {
      // L0 parent with two L1 children, each having L2 sub-sections.
      final items = [
        const _TestItem('Root', 0, isSection: true), // idx 0
        const _TestItem('Child A', 1, isSection: true), // idx 1
        const _TestItem('Grandchild A1', 2, isSection: true), // idx 2
        const _TestItem('leaf', 3), // idx 3
        const _TestItem('Child B', 1, isSection: true), // idx 4
        const _TestItem('Grandchild B1', 2, isSection: true), // idx 5
        const _TestItem('leaf', 3), // idx 6
        const _TestItem('leaf', 3), // idx 7
        const _TestItem('leaf', 3), // idx 8
        const _TestItem('leaf', 3), // idx 9
        const _TestItem('leaf', 3), // idx 10
        const _TestItem('leaf', 3), // idx 11
        const _TestItem('leaf', 3), // idx 12
        const _TestItem('leaf', 3), // idx 13
        const _TestItem('leaf', 3), // idx 14
        const _TestItem('leaf', 3), // idx 15
      ];

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: items, controller: controller),
      );
      await tester.pump();

      // Scroll past Grandchild B1 (idx 5, position 100).
      controller.jumpTo(101.0);
      await tester.pump();

      // Canonical: Root (L0), Child B (L1), Grandchild B1 (L2) active.
      // Child A should NOT be active (its scope ended at Child B).
      expect(_stickyExists(tester, 0), isTrue, reason: 'Root should be sticky');
      expect(
        _stickyExists(tester, 4),
        isTrue,
        reason: 'Child B should be sticky',
      );
      expect(
        _stickyExists(tester, 5),
        isTrue,
        reason: 'Grandchild B1 should be sticky',
      );
      expect(
        _stickyExists(tester, 1),
        isFalse,
        reason: 'Child A should NOT be sticky (scope ended)',
      );
    });

    testWidgets('very short scope (section with no children)', (tester) async {
      // A section immediately followed by a same-level section.
      final items = [
        const _TestItem('A', 0, isSection: true), // idx 0, scope 0..0
        const _TestItem('B', 0, isSection: true), // idx 1, scope 1..15
        const _TestItem('leaf', 1), // idx 2
        const _TestItem('leaf', 1), // idx 3
        const _TestItem('leaf', 1), // idx 4
        const _TestItem('leaf', 1), // idx 5
        const _TestItem('leaf', 1), // idx 6
        const _TestItem('leaf', 1), // idx 7
        const _TestItem('leaf', 1), // idx 8
        const _TestItem('leaf', 1), // idx 9
        const _TestItem('leaf', 1), // idx 10
        const _TestItem('leaf', 1), // idx 11
        const _TestItem('leaf', 1), // idx 12
        const _TestItem('leaf', 1), // idx 13
        const _TestItem('leaf', 1), // idx 14
        const _TestItem('leaf', 1), // idx 15
      ];

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: items, controller: controller),
      );
      await tester.pump();

      // A has scope endIndex=0 (just itself), scopeEndPosition=20.
      // At scrollTop=1: A is active. Its scope covers slot 0 (20-1=19 >= 0).
      controller.jumpTo(1.0);
      await tester.pump();

      // A should be briefly sticky.
      expect(_stickyExists(tester, 0), isTrue);

      // At scrollTop=21: A scopeEndViewport = 20-21 = -1 < 0.
      // A drops. B (startPosition=20) is active since 20 < 21.
      controller.jumpTo(21.0);
      await tester.pump();

      // B should be sticky, A should not.
      expect(_stickyExists(tester, 1), isTrue, reason: 'B should be sticky');
      // Canonical: A's scope (endIndex=0, scopeEnd=20) doesn't cover
      // slot 0 at scrollTop=21. A should drop.
      expect(
        _stickyExists(tester, 0),
        isFalse,
        reason: 'A should drop (very short scope ended)',
      );
    });

    testWidgets('first section not at index 0', (tester) async {
      // Non-section items before first section.
      final items = [
        const _TestItem('preamble 1', 0), // idx 0
        const _TestItem('preamble 2', 0), // idx 1
        const _TestItem('Section A', 0, isSection: true), // idx 2, pos=40
        const _TestItem('leaf', 1), // idx 3
        const _TestItem('leaf', 1), // idx 4
        const _TestItem('leaf', 1), // idx 5
        const _TestItem('leaf', 1), // idx 6
        const _TestItem('leaf', 1), // idx 7
        const _TestItem('leaf', 1), // idx 8
        const _TestItem('leaf', 1), // idx 9
        const _TestItem('leaf', 1), // idx 10
        const _TestItem('leaf', 1), // idx 11
        const _TestItem('leaf', 1), // idx 12
        const _TestItem('leaf', 1), // idx 13
        const _TestItem('leaf', 1), // idx 14
        const _TestItem('leaf', 1), // idx 15
      ];

      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: items, controller: controller),
      );
      await tester.pump();

      // At scrollTop=20, Section A (position 40) is not past yet.
      controller.jumpTo(20.0);
      await tester.pump();
      expect(
        _stickyExists(tester, 2),
        isFalse,
        reason: 'Section A not yet scrolled past',
      );

      // At scrollTop=41, Section A is past.
      controller.jumpTo(41.0);
      await tester.pump();
      expect(
        _stickyExists(tester, 2),
        isTrue,
        reason: 'Section A should be sticky',
      );
    });
  });

  // =========================================================================
  // Group 7: _headerListChanged must detect offset changes
  // =========================================================================
  group('setState fires on sub-pixel changes', () {
    testWidgets('scrolling by 1px during push-out updates header position', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildTestWidget(items: _standardItems, controller: controller),
      );
      await tester.pump();

      // Enter push-out zone for Section A (single header).
      // scopeEndPosition = 120. Push-out when scrollTop > 100.
      controller.jumpTo(105.0);
      await tester.pump();

      final top1 = _stickyTop(tester, 0);

      controller.jumpTo(106.0);
      await tester.pump();

      final top2 = _stickyTop(tester, 0);

      // If both exist, the position should have changed.
      // The current _headerListChanged only checks originalIndex,
      // so it may not detect sub-pixel position changes.
      // Canonical: _headerListChanged should include offset comparison.
      if (top1 != null && top2 != null) {
        expect(
          top1 != top2,
          isTrue,
          reason:
              'Header position should update on every scroll pixel '
              'during push-out (requires offset-aware _headerListChanged)',
        );
      }
    });
  });

  // =========================================================================
  // Group 8: Navigation uses actual overlay height, not header count
  // =========================================================================
  group('Navigation offset during push-out', () {
    testWidgets(
      'tapping sticky header during push-out scrolls to correct offset',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _buildTestWidget(items: _standardItems, controller: controller),
        );
        await tester.pump();

        // At scrollTop=90: A (slot 0) + Sub B (slot 1, being pushed out).
        // Overlay height = 30 (Sub B top=10, + 20 itemExtent).
        // Tapping Sub B (index 3): target = 3 * 20 = 60.
        // Correct offset: 60 - 30 = 30 (using actual overlay height).
        // Buggy offset: 60 - 40 = 20 (using 2 * 20 header count).
        controller.jumpTo(90.0);
        await tester.pump();

        // Sub B should exist and be tappable.
        expect(_stickyExists(tester, 3), isTrue);

        // Tap Sub B sticky header.
        await tester.tap(find.byKey(const ValueKey('sticky_3')));
        // Pump through the 300ms animation.
        await tester.pumpAndSettle();

        // The scroll should land at 30 (using overlay height 30),
        // not 20 (using header count * itemExtent = 40).
        expect(
          controller.offset,
          moreOrLessEquals(30.0, epsilon: 1.0),
          reason:
              'Navigation should subtract actual overlay height (30), '
              'not header count * itemExtent (40)',
        );
      },
    );
  });

  // =========================================================================
  // Group 9: Pure-state tests (no widget, just algorithm)
  // =========================================================================
  group('Pure-state canonical algorithm', () {
    // These test the expected output of the canonical slot-fit algorithm
    // at specific scroll positions, independent of widget rendering.
    // They document what the algorithm SHOULD produce.

    test('slot-fit filter: candidate active when slot covered by scope', () {
      // Section A: level 0, startPosition=0, scopeEndPosition=120.
      // Slot 0: top=0, bottom=20.
      // Active when: headerViewportTop < slotTop AND
      //              slotTop <= scopeEndViewport.
      // headerViewportTop = startPosition - scrollTop.
      // scopeEndViewport = scopeEndPosition - scrollTop.

      // scrollTop=1: headerVP = -1 < 0 = slotTop ✓
      //              slotTop(0) <= scopeEndVP(119) ✓ → active
      final aCandidate = StickyCandidate<String>(
        level: 0,
        data: 'Section A',
        originalIndex: 0,
        endIndex: 5,
        itemExtent: 20.0,
      );

      bool isActiveCanonical(
        StickyCandidate<String> c,
        int slot,
        double scrollTop,
        double itemExtent,
      ) {
        final slotTop = slot * itemExtent;
        final headerViewportTop = c.startPosition - scrollTop;
        final scopeEndViewport = c.scopeEndPosition - scrollTop;
        return headerViewportTop < slotTop && slotTop <= scopeEndViewport;
      }

      // scrollTop=1: active
      expect(isActiveCanonical(aCandidate, 0, 1.0, 20.0), isTrue);

      // scrollTop=0: headerVP = 0, slotTop = 0. 0 < 0 is false → not active.
      expect(isActiveCanonical(aCandidate, 0, 0.0, 20.0), isFalse);

      // scrollTop=100: scopeEndVP = 20, slotTop = 0. 0 <= 20 ✓ → active.
      expect(isActiveCanonical(aCandidate, 0, 100.0, 20.0), isTrue);

      // scrollTop=101: scopeEndVP = 19, slotTop = 0. 0 <= 19 ✓ → active.
      // But slotBottom(20) > scopeEndVP(19) → push-out applies.
      expect(isActiveCanonical(aCandidate, 0, 101.0, 20.0), isTrue);

      // scrollTop=120: scopeEndVP = 0, slotTop = 0. 0 <= 0 ✓ → active.
      // Edge case: still active at the very last pixel.
      expect(isActiveCanonical(aCandidate, 0, 120.0, 20.0), isTrue);

      // scrollTop=121: scopeEndVP = -1, slotTop = 0. 0 <= -1 is false → drop.
      expect(isActiveCanonical(aCandidate, 0, 121.0, 20.0), isFalse);
    });

    test('nested candidate activates at slot threshold, not startPosition', () {
      // Sub B: level 1, startPosition=60, scopeEndPosition=120.
      // Slot 1: top=20.
      // Canonical activation: headerViewportTop < slotTop
      //   60 - scrollTop < 20  →  scrollTop > 40.
      //
      // The prefilter must include Sub B in the candidate set when
      // scrollTop > 40, not only when scrollTop > 60.
      final bCandidate = StickyCandidate<String>(
        level: 1,
        data: 'Sub B',
        originalIndex: 3,
        endIndex: 5,
        itemExtent: 20.0,
      );

      bool isActiveCanonical(
        StickyCandidate<String> c,
        int slot,
        double scrollTop,
        double itemExtent,
      ) {
        final slotTop = slot * itemExtent;
        final headerViewportTop = c.startPosition - scrollTop;
        final scopeEndViewport = c.scopeEndPosition - scrollTop;
        return headerViewportTop < slotTop && slotTop <= scopeEndViewport;
      }

      // scrollTop=41: 60-41=19 < 20 ✓, 20 <= 79 ✓ → active.
      expect(isActiveCanonical(bCandidate, 1, 41.0, 20.0), isTrue);

      // scrollTop=40: 60-40=20 < 20 is false → not active (exact boundary).
      expect(isActiveCanonical(bCandidate, 1, 40.0, 20.0), isFalse);

      // scrollTop=60: 60-60=0 < 20 ✓ → active (also at startPosition).
      expect(isActiveCanonical(bCandidate, 1, 60.0, 20.0), isTrue);
    });

    test('last-line offset computation', () {
      // Sub B: level 1, slot 1, startPosition=60, scopeEndPosition=120.
      // Slot 1: top=20, bottom=40.
      // Push-out when slotBottom > scopeEndViewport:
      //   40 > 120 - scrollTop → scrollTop > 80.
      // Offset = scopeEndViewport - slotBottom = (120 - scrollTop) - 40.

      double lastLineOffset(double scrollTop) {
        const slotBottom = 40.0;
        final scopeEndViewport = 120.0 - scrollTop;
        if (slotBottom > scopeEndViewport) {
          return scopeEndViewport - slotBottom;
        }
        return 0.0;
      }

      expect(lastLineOffset(80.0), 0.0); // boundary: no push-out
      expect(lastLineOffset(81.0), -1.0); // push-out starts
      expect(lastLineOffset(90.0), -10.0);
      expect(lastLineOffset(100.0), -20.0); // fully pushed out
    });

    test('dynamic overlay height computation', () {
      // 2 active headers (20px each). Normal height = 40.
      // Last-line offset reduces it.
      double overlayHeight(double lastLineOffset, int headerCount) {
        return headerCount * 20.0 + lastLineOffset;
      }

      expect(overlayHeight(0.0, 2), 40.0);
      expect(overlayHeight(-10.0, 2), 30.0);
      expect(overlayHeight(-20.0, 2), 20.0); // last header fully gone
    });
  });
}
