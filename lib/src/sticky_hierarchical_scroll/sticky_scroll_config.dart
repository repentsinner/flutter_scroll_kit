import 'package:flutter/widgets.dart';

import 'sticky_candidate.dart';

/// Configuration for sticky scroll behavior.
final class StickyScrollConfig<T> {
  /// Maximum number of sticky headers to show.
  final int maxStickyHeaders;

  /// Whether to enable click-to-navigate functionality.
  final bool enableNavigation;

  /// Decoration for each sticky header. Supports backgrounds, borders,
  /// gradients, shadows, and border radii. Defaults to a solid dark
  /// background matching VS Code's style.
  final Decoration stickyDecoration;

  /// Builder for sticky header widgets. The consumer provides the full
  /// widget, including any styling or indentation.
  final Widget Function(BuildContext context, StickyCandidate<T> candidate)
  stickyHeaderBuilder;

  const StickyScrollConfig({
    required this.stickyHeaderBuilder,
    this.maxStickyHeaders = 5,
    this.enableNavigation = true,
    this.stickyDecoration = const BoxDecoration(color: Color(0xFF1E1E1E)),
  });
}
