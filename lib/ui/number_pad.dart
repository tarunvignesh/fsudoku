/// Digit entry pad.
library;

import 'package:flutter/material.dart';

import '../engine/solver.dart';
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

        final selected = controller.selected;
        final notes = selected == null ? 0 : controller.notes[selected];
        final current = selected == null ? 0 : controller.values[selected];

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
                      pencilled: notes & digitBit(d) != 0,
                      isCurrent: current == d,
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
    required this.pencilled,
    required this.isCurrent,
    required this.onPressed,
  });

  final int digit;
  final bool exhausted;
  final bool notesMode;

  /// Whether this digit is already pencilled in the selected cell.
  final bool pencilled;

  /// Whether this digit is the selected cell's current answer.
  final bool isCurrent;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = notesMode ? scheme.secondary : scheme.primary;
    // Reflect what this digit already is in the selected cell, the way the
    // original's pencil menu showed a pencil or an eraser per digit.
    final active = notesMode ? pencilled : isCurrent;

    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedOpacity(
        opacity: exhausted ? 0.32 : 1,
        duration: const Duration(milliseconds: 180),
        child: Material(
          color: active
              ? accent.withValues(alpha: 0.22)
              : notesMode
              ? scheme.secondaryContainer.withValues(alpha: 0.55)
              : scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: accent.withValues(alpha: active ? 0.9 : 0.28),
              width: active ? 1.6 : 1,
            ),
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
                  color: active
                      ? accent
                      : notesMode
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
