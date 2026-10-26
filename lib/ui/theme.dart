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
    noteText: Color(0xFF4D5564),
    candidateText: Color(0xFF636975),
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
    noteText: Color(0xFF86B1EC),
    candidateText: Color(0xFF8E96A3),
    completedUnitFill: Color(0x3333D6C8),
  );
}

/// How a skin shades the boxes behind the grid.
enum BoxTint {
  /// Alternating boxes, like a chequerboard.
  checker,

  /// Alternating bands of box-rows.
  bands,

  /// No shading; box boundaries read from the heavy lines alone.
  none,
}

/// The non-colour half of a skin: line weights, proportions and type.
///
/// Held separately from [BoardPalette] because these survive a light/dark
/// switch -- a skin keeps its character in both.
@immutable
class BoardStyle extends ThemeExtension<BoardStyle> {
  /// Creates a board style.
  const BoardStyle({
    required this.fontFamily,
    required this.gridLineScale,
    required this.boxLineScale,
    required this.cornerRadiusScale,
    required this.boxTint,
    required this.digitScale,
    required this.noteScale,
    required this.givenWeight,
    required this.entryWeight,
  });

  /// Font for the board's digits, or null for the platform default.
  final String? fontFamily;

  /// Multiplies the hairline between cells.
  final double gridLineScale;

  /// Multiplies the heavier line between boxes.
  final double boxLineScale;

  /// Board corner rounding, as a fraction of one cell.
  final double cornerRadiusScale;

  /// How the boxes are shaded.
  final BoxTint boxTint;

  /// Digit size, as a fraction of one cell.
  final double digitScale;

  /// Pencil-mark size, as a fraction of one cell.
  final double noteScale;

  /// Weight for the puzzle's own clues.
  final FontWeight givenWeight;

  /// Weight for the player's answers.
  final FontWeight entryWeight;

  @override
  BoardStyle copyWith({
    String? fontFamily,
    double? gridLineScale,
    double? boxLineScale,
    double? cornerRadiusScale,
    BoxTint? boxTint,
    double? digitScale,
    double? noteScale,
    FontWeight? givenWeight,
    FontWeight? entryWeight,
  }) {
    return BoardStyle(
      fontFamily: fontFamily ?? this.fontFamily,
      gridLineScale: gridLineScale ?? this.gridLineScale,
      boxLineScale: boxLineScale ?? this.boxLineScale,
      cornerRadiusScale: cornerRadiusScale ?? this.cornerRadiusScale,
      boxTint: boxTint ?? this.boxTint,
      digitScale: digitScale ?? this.digitScale,
      noteScale: noteScale ?? this.noteScale,
      givenWeight: givenWeight ?? this.givenWeight,
      entryWeight: entryWeight ?? this.entryWeight,
    );
  }

  @override
  BoardStyle lerp(BoardStyle? other, double t) {
    if (other == null) return this;
    // Discrete properties snap at the midpoint; sizes interpolate.
    return BoardStyle(
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
      gridLineScale: _lerp(gridLineScale, other.gridLineScale, t),
      boxLineScale: _lerp(boxLineScale, other.boxLineScale, t),
      cornerRadiusScale: _lerp(cornerRadiusScale, other.cornerRadiusScale, t),
      boxTint: t < 0.5 ? boxTint : other.boxTint,
      digitScale: _lerp(digitScale, other.digitScale, t),
      noteScale: _lerp(noteScale, other.noteScale, t),
      givenWeight: t < 0.5 ? givenWeight : other.givenWeight,
      entryWeight: t < 0.5 ? entryWeight : other.entryWeight,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool operator ==(Object other) =>
      other is BoardStyle &&
      other.fontFamily == fontFamily &&
      other.gridLineScale == gridLineScale &&
      other.boxLineScale == boxLineScale &&
      other.cornerRadiusScale == cornerRadiusScale &&
      other.boxTint == boxTint &&
      other.digitScale == digitScale &&
      other.noteScale == noteScale &&
      other.givenWeight == givenWeight &&
      other.entryWeight == entryWeight;

  @override
  int get hashCode => Object.hash(
    fontFamily,
    gridLineScale,
    boxLineScale,
    cornerRadiusScale,
    boxTint,
    digitScale,
    noteScale,
    givenWeight,
    entryWeight,
  );
}
