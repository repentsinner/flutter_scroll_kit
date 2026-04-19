import 'package:fixed_line_view/fixed_line_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FixedLineViewController', () {
    test('creates internal ScrollController when none provided', () {
      final viewController = FixedLineViewController();
      addTearDown(viewController.dispose);

      expect(viewController.scrollController, isA<ScrollController>());
    });

    test('uses external ScrollController when provided', () {
      final external = ScrollController();
      addTearDown(external.dispose);

      final viewController = FixedLineViewController(
        scrollController: external,
      );
      addTearDown(viewController.dispose);

      expect(viewController.scrollController, same(external));
    });

    test('disposes only owned controller', () {
      // Controller that owns its ScrollController.
      final owned = FixedLineViewController();
      // Should not throw — disposes the internal controller.
      owned.dispose();

      // Controller with external ScrollController.
      final external = ScrollController();
      final notOwned = FixedLineViewController(scrollController: external);
      notOwned.dispose();

      // External controller should still be usable after dispose of
      // the FixedLineViewController.
      // This verifies that dispose did not dispose the external controller.
      // If it had, creating a new animation would throw.
      expect(() => external.dispose(), returnsNormally);
    });
  });
}
