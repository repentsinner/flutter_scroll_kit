import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repl_view/repl_view.dart';
import 'package:sticky_hierarchical_scroll/sticky_hierarchical_scroll.dart';

/// The default Material scrollbar thickness used as the auto fallback.
const double _materialThickness = 8.0;
const double _viewportWidth = 300.0;
const double _viewportHeight = 200.0;
const double _itemExtent = 20.0;

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
    this.coalescingKey = '',
  }) : count = 1;

  factory _Entry.input(String v, {required int id}) =>
      _Entry(v, isInput: true, coalescingKey: 'user:$v', identity: id);

  factory _Entry.response(String v, {required int id}) =>
      _Entry(v, isInput: false, coalescingKey: v, identity: id);
}

/// Builds a [ReplView] whose rows carry a trailing [IconButton] aligned to
/// the right edge, so we can probe whether the gutter keeps trailing
/// content and tap targets — on both scrollback rows and the pinned sticky
/// input header — clear of the scroll lane.
Widget _gutterHarness({
  required double? scrollbarGutter,
  required List<_Entry> entries,
  required ScrollController controller,
  VoidCallback? onRowTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: _viewportHeight,
        width: _viewportWidth,
        child: ReplView<_Entry>(
          entries: entries,
          itemExtent: _itemExtent,
          controller: controller,
          scrollbarGutter: scrollbarGutter,
          entryBuilder: (context, entry) => Row(
            children: [
              Expanded(
                child: Text(
                  entry.value,
                  key: ValueKey('row_${entry.value}'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: ValueKey('btn_${entry.value}'),
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

/// One input followed by enough responses to overflow the viewport, so
/// dragging up pins the input as a sticky header.
List<_Entry> _entries() {
  final entries = <_Entry>[_Entry.input('cmd', id: 0)];
  for (var i = 0; i < 30; i++) {
    entries.add(_Entry.response('resp-$i', id: i + 1));
  }
  return entries;
}

void main() {
  group('ReplView scrollbar gutter', () {
    testWidgets('default gutter insets scrollback rows by theme thickness', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _gutterHarness(
          scrollbarGutter: null,
          entries: _entries(),
          controller: controller,
        ),
      );
      await tester.pump();

      final btn = tester.getRect(find.byKey(const ValueKey('btn_resp-29')));
      expect(
        btn.right,
        moreOrLessEquals(_viewportWidth - _materialThickness, epsilon: 0.5),
      );
    });

    testWidgets('trailing affordance on a scrollback row fires', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var fired = false;

      await tester.pumpWidget(
        _gutterHarness(
          scrollbarGutter: null,
          entries: _entries(),
          controller: controller,
          onRowTap: () => fired = true,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('btn_resp-29')));
      expect(fired, isTrue);
    });

    testWidgets('trailing affordance on a pinned sticky input header fires', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      var fired = false;

      await tester.pumpWidget(
        _gutterHarness(
          scrollbarGutter: null,
          entries: _entries(),
          controller: controller,
          onRowTap: () => fired = true,
        ),
      );
      await tester.pump();

      // Scroll the input row above the viewport top so it pins as a sticky
      // header. The header overlay re-renders the entryBuilder, so a second
      // 'cmd' button appears at the viewport top.
      controller.jumpTo(_itemExtent * 5);
      await tester.pump();
      await tester.pump();

      // The pinned header sits at the viewport top.
      final headerBtn = find.byKey(const ValueKey('btn_cmd'));
      expect(headerBtn, findsWidgets);
      final headerRect = tester.getRect(headerBtn.first);
      expect(
        headerRect.right,
        moreOrLessEquals(_viewportWidth - _materialThickness, epsilon: 0.5),
      );

      await tester.tap(headerBtn.first);
      expect(fired, isTrue);
    });

    testWidgets('explicit positive gutter reserves exactly that width', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const explicit = 24.0;

      await tester.pumpWidget(
        _gutterHarness(
          scrollbarGutter: explicit,
          entries: _entries(),
          controller: controller,
        ),
      );
      await tester.pump();

      final btn = tester.getRect(find.byKey(const ValueKey('btn_resp-29')));
      expect(
        btn.right,
        moreOrLessEquals(_viewportWidth - explicit, epsilon: 0.5),
      );
    });

    testWidgets('scrollbarGutter: 0 restores full-bleed', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _gutterHarness(
          scrollbarGutter: 0,
          entries: _entries(),
          controller: controller,
        ),
      );
      await tester.pump();

      final btn = tester.getRect(find.byKey(const ValueKey('btn_resp-29')));
      expect(btn.right, moreOrLessEquals(_viewportWidth, epsilon: 0.5));
    });

    testWidgets('null scrollbarGutter forwards as null to the sticky view', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _gutterHarness(
          scrollbarGutter: null,
          entries: _entries(),
          controller: controller,
        ),
      );
      await tester.pump();

      final scrollView = tester.widget<StickyHierarchicalScrollView<_Entry>>(
        find.byType(StickyHierarchicalScrollView<_Entry>),
      );
      expect(scrollView.scrollbarGutter, isNull);
    });

    testWidgets('explicit gutter forwards verbatim to the sticky view', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const explicit = 24.0;

      await tester.pumpWidget(
        _gutterHarness(
          scrollbarGutter: explicit,
          entries: _entries(),
          controller: controller,
        ),
      );
      await tester.pump();

      final scrollView = tester.widget<StickyHierarchicalScrollView<_Entry>>(
        find.byType(StickyHierarchicalScrollView<_Entry>),
      );
      expect(scrollView.scrollbarGutter, explicit);
    });
  });
}
