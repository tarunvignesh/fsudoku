/// The digit menu that opens on the cell you tapped.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/solver.dart';
import '../../engine/variant.dart';
import '../theme.dart';

/// What a cell menu writes when you pick a digit.
enum CellMenuMode {
  /// Commit the digit as an answer.
  answer,

  /// Toggle the digit as a pencil mark.
  pencil,
}

/// A compact digit picker anchored on a cell.
///
/// Entry happens at the cell rather than at a pad across the screen, so the
/// pointer never leaves the board. Digits are laid out on the variant's own
/// box grid, which means the menu, the board and the pencil marks inside a
/// cell all share one arrangement -- on 6x6 that is three wide and two tall.
class CellMenu extends StatelessWidget {
  /// Creates a cell menu.
  const CellMenu({
    required this.variant,
    required this.mode,
    required this.notes,
    required this.value,
    required this.onPick,
    required this.onClear,
    required this.onDismiss,
    this.candidates = 0,
    this.showCandidates = false,
    super.key,
  });

  /// Board size, which decides how many digits are offered.
  final Variant variant;

  /// Whether picking writes an answer or a pencil mark.
  final CellMenuMode mode;

  /// The cell's current pencil marks, as a digit bitmask.
  final int notes;

  /// The cell's current answer, or 0.
  final int value;

  /// Digits that are still legal here, as a bitmask.
  ///
  /// Only consulted when [showCandidates] is on. Impossible digits are dimmed
  /// rather than hidden, so the layout stays put and the dimming itself
  /// teaches.
  final int candidates;

  /// Whether the player has asked to be shown candidates.
  ///
  /// Gating on this matters: dimming the menu's impossible digits is the same
  /// assistance the candidate overlay gives, so offering it unconditionally
  /// would hand over information the player chose to switch off.
  final bool showCandidates;

  /// Called with the chosen digit.
  final ValueChanged<int> onPick;

  /// Called to empty the cell.
  final VoidCallback onClear;

  /// Called when the menu should close without a choice.
  final VoidCallback onDismiss;

  bool get _pencilling => mode == CellMenuMode.pencil;

  static const double _button = 42;
  static const double _gap = 6;
  static const double _pad = 8;

  /// Height reserved for the header row of label and buttons.
  static const double _headerHeight = 30;

  /// Narrowest the menu may be, so the header's label and buttons always fit.
  static const double _minWidth = 172;

  /// The menu's width for [variant].
  ///
  /// Exposed so whatever positions the menu clamps against the same number the
  /// menu actually paints, rather than a second copy of this arithmetic.
  static double widthFor(Variant variant) => math.max(
    variant.boxCols * _button + (variant.boxCols - 1) * _gap + _pad * 2,
    _minWidth,
  );

  /// An estimate of the menu's height for [variant].
  ///
  /// Used only to decide whether the menu fits below its cell. The menu itself
  /// sizes to its content rather than to this number, so text scaling or a
  /// taller font changes the real height without clipping anything; being a
  /// few pixels out here only nudges where it is placed.
  static double heightFor(Variant variant) =>
      _pad * 2 +
      _headerHeight +
      _gap +
      variant.boxRows * _button +
      (variant.boxRows - 1) * _gap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _pencilling ? scheme.secondary : scheme.primary;

    return Material(
      color: Colors.transparent,
      child: Container(
        // Width is fixed because a Positioned child gets unbounded
        // constraints and the column below needs something to stretch to.
        // Height is deliberately left to the content.
        width: widthFor(variant),
        padding: const EdgeInsets.all(_pad),
        decoration: BoxDecoration(
          color: ElevationOverlay.applySurfaceTint(
            scheme.surfaceContainerHigh,
            scheme.surfaceTint,
            3,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, accent),
            const SizedBox(height: _gap),
            for (var r = 0; r < variant.boxRows; r++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: r == variant.boxRows - 1 ? 0 : _gap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var c = 0; c < variant.boxCols; c++)
                      Padding(
                        padding: EdgeInsets.only(
                          right: c == variant.boxCols - 1 ? 0 : _gap,
                        ),
                        child: _digit(context, r * variant.boxCols + c + 1),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          _pencilling ? Icons.edit_outlined : Icons.keyboard_outlined,
          size: 15,
          color: accent,
        ),
        const SizedBox(width: 6),
        Text(
          _pencilling ? 'Pencil' : 'Answer',
          style: theme.textTheme.labelSmall?.copyWith(color: accent),
        ),
        const SizedBox(width: 14),
        _MiniButton(
          icon: Icons.backspace_outlined,
          tooltip: 'Erase',
          onPressed: value == 0 && notes == 0 ? null : onClear,
        ),
        _MiniButton(icon: Icons.close, tooltip: 'Close', onPressed: onDismiss),
      ],
    );
  }

  Widget _digit(BuildContext context, int digit) {
    final scheme = Theme.of(context).colorScheme;
    final palette = Theme.of(context).extension<BoardPalette>()!;

    final pencilled = notes & digitBit(digit) != 0;
    final isCurrent = value == digit;
    final possible = !showCandidates || candidates & digitBit(digit) != 0;

    final highlight = _pencilling ? pencilled : isCurrent;
    final accent = _pencilling ? scheme.secondary : scheme.primary;

    return Tooltip(
      message: _pencilling
          ? (pencilled ? 'Erase pencil mark $digit' : 'Pencil $digit')
          : 'Enter $digit',
      waitDuration: const Duration(milliseconds: 600),
      child: SizedBox(
        width: _button,
        height: _button,
        child: Material(
          color: highlight
              ? accent.withValues(alpha: 0.22)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: highlight ? accent : scheme.outlineVariant,
              width: highlight ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onPick(digit),
            child: Opacity(
              opacity: possible ? 1 : 0.42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$digit',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: highlight ? accent : scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  // The original pencil menu swapped each digit's icon between
                  // a pencil and an eraser to show what tapping would do. Kept,
                  // as a corner glyph so the digit stays the main thing.
                  if (_pencilling)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Icon(
                        pencilled ? Icons.backspace_outlined : Icons.edit,
                        size: 10,
                        color: pencilled
                            ? accent
                            : palette.noteText.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 16,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 15,
            color: onPressed == null
                ? Theme.of(context).disabledColor
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
