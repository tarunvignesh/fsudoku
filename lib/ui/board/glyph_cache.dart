/// Cached laid-out digit glyphs for the board painter.
library;

import 'package:flutter/rendering.dart';

import '../theme.dart';

/// What a digit on the board represents, which decides how it is drawn.
enum GlyphRole {
  /// A clue that came with the puzzle.
  given,

  /// An answer the player typed.
  entry,

  /// An answer that duplicates a peer.
  conflict,

  /// A pencil mark the player wrote.
  note,

  /// A candidate the app computed.
  candidate,
}

/// Lays out digit glyphs once and reuses them across repaints.
///
/// Laying out text is the expensive part of drawing a Sudoku board: a 9x9 grid
/// showing candidates can need several hundred glyphs, and re-laying them out
/// every frame is what makes a canvas-drawn board stutter. Digits are a tiny
/// fixed alphabet, so they are laid out on first use and cached until the cell
/// size or colours change.
class GlyphCache {
  /// Creates an empty cache.
  GlyphCache();

  final Map<(GlyphRole, int), TextPainter> _painters = {};
  double _cellSize = -1;
  Map<GlyphRole, Color> _colors = const {};
  BoardStyle? _style;

  /// Discards cached glyphs if [cellSize], [colors] or [style] changed.
  ///
  /// Call once per paint before requesting any glyph. Switching skins changes
  /// the typeface and the proportions, so the cache has to key on the style
  /// as well as the size.
  void configure({
    required double cellSize,
    required Map<GlyphRole, Color> colors,
    required BoardStyle style,
  }) {
    if (_cellSize == cellSize && _style == style && _sameColors(colors)) {
      return;
    }
    _cellSize = cellSize;
    _colors = Map.unmodifiable(colors);
    _style = style;
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }

  bool _sameColors(Map<GlyphRole, Color> other) {
    if (_colors.length != other.length) return false;
    for (final entry in other.entries) {
      if (_colors[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// A laid-out painter for [digit] in [role], ready to paint.
  TextPainter glyph(GlyphRole role, int digit) {
    return _painters.putIfAbsent((role, digit), () {
      final painter = TextPainter(
        text: TextSpan(
          text: '$digit',
          style: TextStyle(
            fontFamily: _style?.fontFamily ?? 'Inter',
            fontSize: _fontSize(role),
            fontWeight: _weight(role),
            color: _colors[role],
            height: 1,
            // Tabular figures keep columns of digits optically aligned.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      return painter;
    });
  }

  double _fontSize(GlyphRole role) => switch (role) {
    GlyphRole.given ||
    GlyphRole.entry ||
    GlyphRole.conflict => _cellSize * 0.56,
    GlyphRole.note || GlyphRole.candidate => _cellSize * 0.24,
  };

  FontWeight _weight(GlyphRole role) => switch (role) {
    GlyphRole.given => FontWeight.w600,
    GlyphRole.entry || GlyphRole.conflict => FontWeight.w500,
    GlyphRole.note => FontWeight.w500,
    GlyphRole.candidate => FontWeight.w400,
  };

  /// Releases every cached glyph.
  void dispose() {
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }
}
