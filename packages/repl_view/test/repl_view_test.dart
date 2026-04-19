import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repl_view/repl_view.dart';
import 'package:sticky_hierarchical_scroll/sticky_hierarchical_scroll.dart';

/// Minimal test-only [ConsoleEntry] implementation.
class _Entry implements ConsoleEntry {
  @override
  final String value;
  @override
  final bool isInput;
  @override
  final String coalescingKey;
  @override
  final int count;
  @override
  final Object identity;

  const _Entry(
    this.value, {
    required this.isInput,
    required this.identity,
    this.count = 1,
    this.coalescingKey = '',
  });

  factory _Entry.input(String v, {required int id}) =>
      _Entry(v, isInput: true, coalescingKey: 'user:$v', identity: id);

  factory _Entry.response(String v, {required int id, int count = 1}) =>
      _Entry(v, isInput: false, count: count, coalescingKey: v, identity: id);

  _Entry copyWith({String? value, int? count}) => _Entry(
    value ?? this.value,
    isInput: isInput,
    identity: identity,
    count: count ?? this.count,
    coalescingKey: coalescingKey,
  );
}

Widget _harness({
  required List<_Entry> entries,
  ScrollController? controller,
  int trailingItemCount = 0,
  Widget Function(BuildContext, int)? trailingItemBuilder,
  double itemExtent = 16.0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 400,
        child: ReplView<_Entry>(
          entries: entries,
          itemExtent: itemExtent,
          controller: controller,
          trailingItemCount: trailingItemCount,
          trailingItemBuilder: trailingItemBuilder,
          entryBuilder: (context, entry) {
            return Row(
              children: [
                if (entry.count > 1)
                  Text(
                    'x${entry.count}',
                    key: ValueKey('count:${entry.value}'),
                  ),
                Expanded(
                  child: Text(
                    entry.value,
                    key: ValueKey('row:${entry.value}'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

List<_Entry> _buildEntries({required int responseCount, int startId = 0}) {
  final entries = <_Entry>[_Entry.input('cmd', id: startId)];
  for (var i = 0; i < responseCount; i++) {
    entries.add(_Entry.response('ok-$i', id: startId + 1 + i));
  }
  return entries;
}

void main() {
  group('ReplView', () {
    testWidgets('wraps StickyHierarchicalScrollView with entries', (
      tester,
    ) async {
      final entries = [
        _Entry.input(r'$$', id: 0),
        _Entry.response('[VER:1.1]', id: 1),
        _Entry.response('ok', id: 2),
      ];

      await tester.pumpWidget(_harness(entries: entries));
      await tester.pump();

      expect(find.byType(StickyHierarchicalScrollView<_Entry>), findsOneWidget);
      final scrollView = tester.widget<StickyHierarchicalScrollView<_Entry>>(
        find.byType(StickyHierarchicalScrollView<_Entry>),
      );
      expect(scrollView.items.length, entries.length);
    });

    testWidgets('input entries register as sticky sections', (tester) async {
      final entries = [
        _Entry.input('G0 X10', id: 0),
        _Entry.response('ok', id: 1),
        _Entry.input('G0 X20', id: 2),
        _Entry.response('ok', id: 3),
      ];

      await tester.pumpWidget(_harness(entries: entries));
      await tester.pump();

      final scrollView = tester.widget<StickyHierarchicalScrollView<_Entry>>(
        find.byType(StickyHierarchicalScrollView<_Entry>),
      );

      // getLevel: input -> 0, response -> 1
      expect(scrollView.getLevel(entries[0]), 0);
      expect(scrollView.getLevel(entries[1]), 1);

      // isSection: only inputs
      expect(scrollView.isSection(entries[0]), true);
      expect(scrollView.isSection(entries[1]), false);
      expect(scrollView.isSection(entries[2]), true);
    });

    testWidgets('renders count badge when entry.count > 1', (tester) async {
      final entries = [
        _Entry.input(r'$$', id: 0),
        _Entry.response('ok', id: 1, count: 47),
      ];

      await tester.pumpWidget(_harness(entries: entries));
      await tester.pump();

      expect(find.byKey(const ValueKey('count:ok')), findsOneWidget);
      expect(find.text('x47'), findsOneWidget);
    });

    testWidgets('omits count badge when entry.count == 1', (tester) async {
      final entries = [
        _Entry.input(r'$$', id: 0),
        _Entry.response('ok', id: 1),
      ];

      await tester.pumpWidget(_harness(entries: entries));
      await tester.pump();

      expect(find.byKey(const ValueKey('count:ok')), findsNothing);
    });

    testWidgets('renders trailing items after entries', (tester) async {
      final entries = [_Entry.input('A', id: 0), _Entry.response('B', id: 1)];

      await tester.pumpWidget(
        _harness(
          entries: entries,
          trailingItemCount: 2,
          trailingItemBuilder: (context, index) => SizedBox(
            height: 16,
            child: Text('trailing-$index', key: ValueKey('trailing-$index')),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('trailing-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('trailing-1')), findsOneWidget);
    });

    testWidgets('auto-scrolls to bottom when entries grow', (tester) async {
      final controller = ScrollController();
      final entries = _buildEntries(responseCount: 50);

      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();
      entries.add(_Entry.response('ok-new', id: 9999));
      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      // We should be at the bottom — within half a pixel of maxScrollExtent.
      final pos = controller.position;
      expect(pos.pixels, closeTo(pos.maxScrollExtent, 0.5));
    });

    testWidgets('suspends auto-scroll after user drags away from the bottom', (
      tester,
    ) async {
      final controller = ScrollController();
      final entries = _buildEntries(responseCount: 50);

      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      // Drag content down (finger moves down) to scroll the list
      // up — leaves the bottom.
      await tester.drag(find.byType(ReplView<_Entry>), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(
        controller.position.pixels,
        lessThan(controller.position.maxScrollExtent - 16.0),
      );
      final scrolledAway = controller.position.pixels;

      // Add a new entry — auto-scroll must NOT fire.
      entries.add(_Entry.response('ok-new', id: 9999));
      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();
      // Position must not have jumped to the new max.
      expect(controller.position.pixels, closeTo(scrolledAway, 0.5));
    });
  });

  group('ReplView viewport anchoring', () {
    testWidgets('coalescing update while floating preserves viewport', (
      tester,
    ) async {
      final controller = ScrollController();
      final entries = _buildEntries(responseCount: 60);

      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ReplView<_Entry>), const Offset(0, 300));
      await tester.pumpAndSettle();
      final floatingPixels = controller.position.pixels;
      expect(
        floatingPixels,
        lessThan(controller.position.maxScrollExtent - 16.0),
      );

      // Mutate last response in place (same identity, bumped count).
      final lastIdx = entries.length - 1;
      entries[lastIdx] = entries[lastIdx].copyWith(count: 5);

      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      expect(controller.position.pixels, closeTo(floatingPixels, 0.5));
    });

    testWidgets('tail append while floating preserves viewport', (
      tester,
    ) async {
      final controller = ScrollController();
      final entries = _buildEntries(responseCount: 60);

      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ReplView<_Entry>), const Offset(0, 300));
      await tester.pumpAndSettle();
      final floatingPixels = controller.position.pixels;

      // Append 20 new entries at the tail.
      for (var i = 0; i < 20; i++) {
        entries.add(_Entry.response('new-$i', id: 1000 + i));
      }
      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      expect(controller.position.pixels, closeTo(floatingPixels, 0.5));
    });

    testWidgets('anchor trim snaps viewport to bottom', (tester) async {
      final controller = ScrollController();
      final entries = _buildEntries(responseCount: 80);

      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      // Drag to float somewhere near the top.
      await tester.drag(find.byType(ReplView<_Entry>), const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(
        controller.position.pixels,
        lessThan(controller.position.maxScrollExtent - 16.0),
      );

      // Trim the head: remove more entries than the viewport could
      // possibly anchor to, guaranteeing the anchor entry is gone.
      entries.removeRange(0, 60);
      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      // Anchor entry is gone — should snap to bottom of new list.
      expect(
        controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, 0.5),
      );
    });

    testWidgets('returning to bottom re-enters stuck state', (tester) async {
      final controller = ScrollController();
      final entries = _buildEntries(responseCount: 60);

      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      // Float first.
      await tester.drag(find.byType(ReplView<_Entry>), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(
        controller.position.pixels,
        lessThan(controller.position.maxScrollExtent - 16.0),
      );

      // Drag back to the bottom.
      await tester.drag(find.byType(ReplView<_Entry>), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(
        controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, 0.5),
      );

      // New entry should auto-scroll since we're back to stuck.
      entries.add(_Entry.response('ok-new', id: 9999));
      await tester.pumpWidget(
        _harness(entries: List.of(entries), controller: controller),
      );
      await tester.pumpAndSettle();

      expect(
        controller.position.pixels,
        closeTo(controller.position.maxScrollExtent, 0.5),
      );
    });
  });

  group('ConsoleEntry contract', () {
    test(
      'implementations expose value, isInput, coalescingKey, count, identity',
      () {
        const e = _Entry(
          'hello',
          isInput: true,
          coalescingKey: 'user:hello',
          count: 3,
          identity: 42,
        );
        expect(e.value, 'hello');
        expect(e.isInput, true);
        expect(e.coalescingKey, 'user:hello');
        expect(e.count, 3);
        expect(e.identity, 42);
      },
    );
  });
}
