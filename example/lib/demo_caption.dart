import 'package:material_ui/material_ui.dart';

/// Shows a demo above a one-line caption naming the library it uses and
/// what that library does.
class DemoCaption extends StatelessWidget {
  const DemoCaption({
    super.key,
    required this.library,
    required this.summary,
    required this.child,
  });

  /// The library the demo imports, without the `.dart` suffix.
  final String library;

  /// What the demo shows, in a few words.
  final String summary;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerHigh,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: library,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(text: '  $summary'),
              ],
            ),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
