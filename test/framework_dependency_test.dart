// Checks §spec:framework-dependency: the package builds on the widgets
// layer only, so every primitive runs under a root that provides no
// design-system localizations or theme. A plain WidgetsApp is that root.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_scroll_kit/flutter_scroll_kit.dart';
import 'package:flutter_test/flutter_test.dart';

const double _itemExtent = 20.0;
const double _viewportWidth = 300.0;
const double _viewportHeight = 200.0;
const Color _appColor = Color(0xFF000000);

Widget _widgetsApp(Widget child) {
  return WidgetsApp(
    color: _appColor,
    pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
        PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
    home: Center(
      child: SizedBox(
        width: _viewportWidth,
        height: _viewportHeight,
        child: child,
      ),
    ),
  );
}

/// Wraps its child with a marker so a test can find the scrollbar the
/// ambient behavior built, and records the controller it was given.
class _MarkerScrollBehavior extends ScrollBehavior {
  static const Key marker = ValueKey('ambient_scrollbar');
  final controllers = <ScrollController?>[];

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    controllers.add(details.controller);
    return KeyedSubtree(key: marker, child: child);
  }
}

void main() {
  test('no library imports a design-system library', () {
    final offenders = <String>[];
    final pattern = RegExp(
      r'''import\s+['"]package:flutter/(material|cupertino)\.dart['"]''',
    );
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (pattern.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });

  group('under a WidgetsApp root', () {
    testWidgets('selectable FixedLineView builds and copies a selection', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        _widgetsApp(
          FixedLineView(
            lineCount: 3,
            itemExtent: _itemExtent,
            selectable: true,
            lineBuilder: (context, index) => Text('Line $index'),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final start = tester.getTopLeft(find.text('Line 0'));
      final end = tester.getBottomRight(find.text('Line 1'));
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveTo(end);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(copied, contains('Line 0'));
      expect(copied, contains('Line 1'));
    });

    testWidgets('FixedLineView defaults the gutter to its constant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _widgetsApp(
          FixedLineView(
            lineCount: 3,
            itemExtent: _itemExtent,
            lineBuilder: (context, index) =>
                const SizedBox.expand(key: ValueKey('row')),
          ),
        ),
      );

      final view = tester.getRect(find.byType(FixedLineView));
      final row = tester.getRect(find.byKey(const ValueKey('row')).first);
      expect(
        view.right - row.right,
        moreOrLessEquals(FixedLineView.defaultScrollbarGutter),
      );
    });

    testWidgets('StickyHierarchicalScrollView uses the ambient scrollbar', (
      tester,
    ) async {
      final behavior = _MarkerScrollBehavior();
      await tester.pumpWidget(
        _widgetsApp(
          ScrollConfiguration(
            behavior: behavior,
            child: StickyHierarchicalScrollView<int>(
              items: List.generate(20, (i) => i),
              itemExtent: _itemExtent,
              getLevel: (_) => 0,
              isSection: (_) => false,
              config: StickyScrollConfig<int>(
                stickyHeaderBuilder: (context, candidate) =>
                    const SizedBox.shrink(),
              ),
              itemBuilder: (context, item, index) =>
                  SizedBox.expand(key: ValueKey('row_$item')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final scrollbar = find.byKey(_MarkerScrollBehavior.marker);
      expect(scrollbar, findsOneWidget);
      expect(
        find.descendant(of: scrollbar, matching: find.byType(ListView)),
        findsOneWidget,
      );
      expect(behavior.controllers, isNotEmpty);
      expect(behavior.controllers, everyElement(isNotNull));
    });

    testWidgets('StickyHierarchicalScrollView defaults the gutter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _widgetsApp(
          StickyHierarchicalScrollView<int>(
            items: List.generate(20, (i) => i),
            itemExtent: _itemExtent,
            getLevel: (_) => 0,
            isSection: (_) => false,
            config: StickyScrollConfig<int>(
              stickyHeaderBuilder: (context, candidate) =>
                  const SizedBox.shrink(),
            ),
            itemBuilder: (context, item, index) =>
                SizedBox.expand(key: ValueKey('row_$item')),
          ),
        ),
      );

      final view = tester.getRect(
        find.byType(StickyHierarchicalScrollView<int>),
      );
      final row = tester.getRect(find.byKey(const ValueKey('row_0')));
      expect(
        view.right - row.right,
        moreOrLessEquals(StickyHierarchicalScrollView.defaultScrollbarGutter),
      );
    });
  });
}
