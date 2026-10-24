/// Digit entry pad.
library;

import 'package:flutter/material.dart';

import '../state/game_controller.dart';

/// The digit buttons, sized to the active variant.
///
/// Each button dims once every copy of that digit is placed, which gives the
/// player a running read on what is left without them counting the board.
class NumberPad extends StatelessWidget {
  /// Creates a number pad driven by [controller].
  const NumberPad({required this.controller, super.key});

  /// The game being played.
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final size = controller.variant.size;
        final placed = List<int>.filled(size + 1, 0);
        for (final v in controller.values) {
          if (v != 0) placed[v]++;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // 4x4 and 6x6 fit one row; 9x9 gets two so buttons stay tappable.
            final perRow = size <= 6 ? size : 5;
            const gap = 8.0;
            final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var d = 1; d <= size; d++)
                  SizedBox(
                    width: width,
                    child: _DigitButton(
                      digit: d,
                      exhausted: placed[d] >= size,
                      notesMode: controller.notesMode,
                      onPressed: () => controller.enter(d),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({
    required this.digit,
    required this.exhausted,
    required this.notesMode,
    required this.onPressed,
  });

  final int digit;
  final bool exhausted;
  final bool notesMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = notesMode ? scheme.secondary : scheme.primary;

    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedOpacity(
        opacity: exhausted ? 0.32 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: notesMode
              ? scheme.secondaryContainer.withValues(alpha: 0.55)
              : scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: accent.withValues(alpha: 0.28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Text(
                '$digit',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: notesMode ? FontWeight.w500 : FontWeight.w600,
                  color: notesMode
                      ? scheme.onSecondaryContainer
                      : scheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
