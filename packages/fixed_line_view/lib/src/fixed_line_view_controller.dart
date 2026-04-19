import 'package:flutter/widgets.dart';

/// A composition controller for sharing a [ScrollController] between a
/// [FixedLineView] and a sticky scroll overlay.
final class FixedLineViewController {
  /// Creates a controller, optionally with an existing [ScrollController].
  FixedLineViewController({ScrollController? scrollController})
    : scrollController = scrollController ?? ScrollController(),
      _ownsController = scrollController == null;

  /// The shared scroll controller.
  final ScrollController scrollController;

  /// Whether this controller owns (created) the ScrollController.
  final bool _ownsController;

  /// Dispose the scroll controller if owned.
  void dispose() {
    if (_ownsController) scrollController.dispose();
  }
}
