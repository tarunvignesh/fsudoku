/// Explains the current hint, or reports on the puzzle when there isn't one.
library;

import 'package:flutter/material.dart';

import '../engine/hint.dart';
import '../state/game_controller.dart';

/// Shows the reasoning behind the active hint.
///
/// The explanation is the point of the feature: naming the technique and the
/// unit it applies to is what turns a hint from an answer into a lesson.
class HintPanel extends StatelessWidget {
  /// Creates a hint panel driven by [controller].
  const HintPanel({required this.controller, super.key});

  /// The game being played.
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hint = controller.hint;

        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hint == null
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  : scheme.tertiaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hint == null
                    ? scheme.outlineVariant
                    : scheme.tertiary.withValues(alpha: 0.4),
              ),
            ),
            child: hint == null
                ? _status(context)
                : _explanation(context, hint),
          ),
        );
      },
    );
  }

  Widget _status(BuildContext context) {
    final theme = Theme.of(context);
    final puzzle = controller.puzzle;
    final remaining = controller.remaining;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          remaining == 0 ? 'Board complete' : '$remaining cells to go',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          puzzle.solvableByLogicAlone
              ? 'This board can be finished by deduction alone. Press H any '
                    'time you want the next step explained.'
              : 'This board needs at least one guess. Narrow a cell to two '
                    'candidates, then commit to one.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _explanation(BuildContext context, Hint hint) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb, size: 18, color: scheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint.technique.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              onPressed: controller.dismissHint,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(hint.explanation, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        // Wraps rather than overflows: the panel is a fixed width and the
        // button's label grows with the digit and the active font.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            FilledButton.icon(
              onPressed: controller.applyHint,
              icon: const Icon(Icons.check, size: 18),
              label: Text('Place ${hint.digit}'),
            ),
            Text(
              'or press space',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
