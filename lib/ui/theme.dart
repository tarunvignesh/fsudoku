/// Colour scheme and board-specific design tokens.
library;

import 'package:flutter/material.dart';

/// Colours the board needs that a [ColorScheme] has no slot for.
///
/// Exposed as a [ThemeExtension] so the painter reads them from the active
/// theme instead of branching on brightness at every draw.
@immutable
class BoardPalette extends ThemeExtension<BoardPalette> {
  /// Creates a board palette.
  const BoardPalette({
    required this.surface,
    required this.boxTint,
    required this.gridLine,
    required this.boxLine,
    required this.givenText,
    required this.entryText,
    required this.conflictText,
    required this.conflictFill,
    required this.selectionFill,
    required this.peerFill,
    required this.hintFill,
    required this.hintEvidenceFill,
    required this.noteText,
    required this.candidateText,
    required this.completedUnitFill,
  });

  /// Board background.
  final Color surface;

  /// Alternating wash over every other box, to read box boundaries at a glance.
  final Color boxTint;

  /// Hairline between cells.
  final Color gridLine;

  /// Heavier line between boxes.
  final Color boxLine;

  /// Digits that came with the puzzle.
  final Color givenText;

  /// Digits the player entered.
  final Color entryText;

  /// Digits that duplicate a peer.
  final Color conflictText;

  /// Wash behind a conflicting digit and its collisions.
  final Color conflictFill;

  /// Wash behind the selected cell.
  final Color selectionFill;

  /// Wash behind cells sharing a unit with the selection.
  final Color peerFill;

  /// Wash behind the cell a hint points at.
  final Color hintFill;

  /// Wash behind the cells a hint cites as evidence.
  final Color hintEvidenceFill;

  /// Player-written pencil marks.
  final Color noteText;

  /// Automatically computed candidate marks, dimmer than [noteText].
  final Color candidateText;

  /// Brief wash over a row, column or box the player just completed.
  final Color completedUnitFill;

  @override
  BoardPalette copyWith({
    Color? surface,
    Color? boxTint,
    Color? gridLine,
    Color? boxLine,
    Color? givenText,
    Color? entryText,
    Color? conflictText,
    Color? conflictFill,
    Color? selectionFill,
    Color? peerFill,
    Color? hintFill,
    Color? hintEvidenceFill,
    Color? noteText,
    Color? candidateText,
    Color? completedUnitFill,
  }) {
    return BoardPalette(
      surface: surface ?? this.surface,
      boxTint: boxTint ?? this.boxTint,
      gridLine: gridLine ?? this.gridLine,
      boxLine: boxLine ?? this.boxLine,
      givenText: givenText ?? this.givenText,
      entryText: entryText ?? this.entryText,
      conflictText: conflictText ?? this.conflictText,
      conflictFill: conflictFill ?? this.conflictFill,
      selectionFill: selectionFill ?? this.selectionFill,
      peerFill: peerFill ?? this.peerFill,
      hintFill: hintFill ?? this.hintFill,
      hintEvidenceFill: hintEvidenceFill ?? this.hintEvidenceFill,
      noteText: noteText ?? this.noteText,
      candidateText: candidateText ?? this.candidateText,
      completedUnitFill: completedUnitFill ?? this.completedUnitFill,
    );
  }

  @override
  BoardPalette lerp(BoardPalette? other, double t) {
    if (other == null) return this;
    return BoardPalette(
      surface: Color.lerp(surface, other.surface, t)!,
      boxTint: Color.lerp(boxTint, other.boxTint, t)!,
      gridLine: Color.lerp(gridLine, other.gridLine, t)!,
      boxLine: Color.lerp(boxLine, other.boxLine, t)!,
      givenText: Color.lerp(givenText, other.givenText, t)!,
      entryText: Color.lerp(entryText, other.entryText, t)!,
      conflictText: Color.lerp(conflictText, other.conflictText, t)!,
      conflictFill: Color.lerp(conflictFill, other.conflictFill, t)!,
      selectionFill: Color.lerp(selectionFill, other.selectionFill, t)!,
      peerFill: Color.lerp(peerFill, other.peerFill, t)!,
      hintFill: Color.lerp(hintFill, other.hintFill, t)!,
      hintEvidenceFill: Color.lerp(
        hintEvidenceFill,
        other.hintEvidenceFill,
        t,
      )!,
      noteText: Color.lerp(noteText, other.noteText, t)!,
      candidateText: Color.lerp(candidateText, other.candidateText, t)!,
      completedUnitFill: Color.lerp(
        completedUnitFill,
        other.completedUnitFill,
        t,
      )!,
    );
  }

  /// Light-mode board colours.
  static const light = BoardPalette(
    surface: Color(0xFFFDFCFA),
    boxTint: Color(0x06000000),
    gridLine: Color(0x1A1C2033),
    boxLine: Color(0x661C2033),
    givenText: Color(0xFF14181F),
    entryText: Color(0xFF2563C9),
    conflictText: Color(0xFFC0303A),
    conflictFill: Color(0x1FC0303A),
    selectionFill: Color(0x2E2563C9),
    peerFill: Color(0x1F2563C9),
    hintFill: Color(0x3817A398),
    hintEvidenceFill: Color(0x1217A398),
    noteText: Color(0xFF5B6475),
    candidateText: Color(0xFF9AA2B1),
    completedUnitFill: Color(0x2617A398),
  );

  /// Dark-mode board colours.
  static const dark = BoardPalette(
    surface: Color(0xFF14171D),
    boxTint: Color(0x0DFFFFFF),
    gridLine: Color(0x1FFFFFFF),
    boxLine: Color(0x5CFFFFFF),
    givenText: Color(0xFFF2F4F8),
    entryText: Color(0xFF79B2FF),
    conflictText: Color(0xFFFF8A8A),
    conflictFill: Color(0x30FF6B6B),
    selectionFill: Color(0x3D79B2FF),
    peerFill: Color(0x2679B2FF),
    hintFill: Color(0x4D33D6C8),
    hintEvidenceFill: Color(0x1A33D6C8),
    noteText: Color(0xFFA6AEBF),
    candidateText: Color(0xFF6D7687),
    completedUnitFill: Color(0x3333D6C8),
  );
}

/// Builds the app theme for [brightness].
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  // primary (blue)  -> the player's own entries and the selection
  // tertiary (teal)  -> the teaching layer: hints and their evidence
  // secondary        -> pencil-mark mode
  // Tertiary is pinned rather than derived, so the hint panel matches the
  // teal the board paints its hint cells with.
  // Overriding `tertiary` alone is not enough: fromSeed derives the container
  // roles from the seed, not from the override, so the hint panel would keep
  // the seed's mauve while the hint icon turned teal.
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2563C9),
    brightness: brightness,
    tertiary: isDark ? const Color(0xFF33D6C8) : const Color(0xFF17A398),
    onTertiary: isDark ? const Color(0xFF00352F) : const Color(0xFFFFFFFF),
    tertiaryContainer: isDark
        ? const Color(0xFF07514B)
        : const Color(0xFFB9EFE8),
    onTertiaryContainer: isDark
        ? const Color(0xFFB9EFE8)
        : const Color(0xFF00322C),
  );

  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF0E1116)
        : const Color(0xFFF4F6FA),
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    extensions: [isDark ? BoardPalette.dark : BoardPalette.light],
    textTheme: isDark
        ? Typography.material2021().white
        : Typography.material2021().black,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
  );
}
