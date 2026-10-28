/// Draws the whole board onto one canvas layer.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../engine/hint.dart';
import '../../engine/solver.dart';
import '../../engine/variant.dart';
import '../theme.dart';
import 'glyph_cache.dart';

/// An immutable snapshot of everything the board needs to draw itself.
///
/// Built fresh each frame from the controller. [revision] stands in for deep
/// equality of the mutable board arrays, so [BoardPainter.shouldRepaint] stays
/// O(1) instead of walking every cell.
@immutable
class BoardRender {
  /// Creates a render snapshot.
  const BoardRender({
    required this.variant,
    required this.geometry,
    required this.revision,
    required this.values,
    required this.notes,
    required this.givens,
    required this.candidates,
    required this.conflictCells,
    required this.wrongCells,
    required this.revealsCorrectness,
    required this.celebrated,
    required this.celebrationOrigin,
    required this.paused,
    required this.showCandidates,
    required this.palette,
    required this.style,
    required this.devicePixelRatio,
    this.selected,
    this.hovered,
    this.hint,
    this.selectionProgress = 1,
    this.hintProgress = 1,
    this.celebrationProgress = 1,
  });

  final Variant variant;
  final Geometry geometry;

  /// Bumped by the controller on every change; drives repaint decisions.
  final int revision;

  final List<int> values;
  final List<int> notes;
  final List<int> givens;

  /// Candidate bitmask per cell, from [BoardAnalysis].
  final List<int> candidates;

  /// Cells involved in a duplicate-digit clash.
  final Set<int> conflictCells;

  /// Filled cells whose digit is not the one the solution requires.
  ///
  /// Empty when the mode does not reveal correctness; see [revealsCorrectness],
  /// which distinguishes "nothing is wrong" from "we are not saying".
  final Set<int> wrongCells;

  /// Whether the active mode marks right and wrong answers at all.
  final bool revealsCorrectness;

  /// Cells of a row, column or box the player just completed correctly.
  final Set<int> celebrated;

  /// The cell the completing answer went into; the flourish starts here.
  final int celebrationOrigin;

  /// Whether play is paused, in which case the board's contents are hidden.
  final bool paused;

  /// Whether to draw computed candidates in empty cells.
  final bool showCandidates;

  final BoardPalette palette;

  /// Line weights, proportions and typeface from the active skin.
  final BoardStyle style;

  /// Used to snap grid lines onto physical pixels.
  final double devicePixelRatio;

  final int? selected;

  /// Cell under the pointer, on platforms that have one.
  final int? hovered;

  final Hint? hint;

  /// Eases the selection wash in, 0 to 1.
  final double selectionProgress;

  /// Eases the hint wash in, 0 to 1.
  final double hintProgress;

  /// Runs 0 to 1 as the completion flourish plays out.
  final double celebrationProgress;
}

/// Paints the board: box shading, highlights, grid lines and digits.
class BoardPainter extends CustomPainter {
  /// Creates a painter for [render], reusing [cache] for glyph layout.
  ///
  /// [onSelectCell] receives taps that arrive through assistive technology.
  BoardPainter({required this.render, required this.cache, this.onSelectCell});

  final BoardRender render;
  final GlyphCache cache;

  /// Called when a screen reader activates a cell.
  final void Function(int cell)? onSelectCell;

  @override
  void paint(Canvas canvas, Size size) {
    final r = render;
    final n = r.variant.size;
    final board = size.shortestSide;
    final edges = _snappedEdges(board, n, r.devicePixelRatio);
    final cell = board / n;
    final radius = cell * r.style.cornerRadiusScale;

    cache.configure(
      cellSize: cell,
      style: r.style,
      colors: {
        GlyphRole.given: r.palette.givenText,
        GlyphRole.entry: r.palette.entryText,
        GlyphRole.conflict: r.palette.conflictText,
        GlyphRole.note: r.palette.noteText,
        GlyphRole.candidate: r.palette.candidateText,
      },
    );

    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, board, board),
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(outer);
    canvas.drawRRect(outer, Paint()..color = r.palette.surface);

    _paintBoxTints(canvas, edges, n);
    if (!r.paused) {
      _paintHighlights(canvas, edges, n);
      _paintCelebration(canvas, edges);
    }
    _paintGrid(canvas, edges, n, board);
    // Pausing hides the digits, not just the clock, so a paused board cannot
    // be studied for free.
    if (!r.paused) _paintDigits(canvas, edges, n, cell);

    canvas.restore();

    // Draw the outline last so highlights never bleed over the rounded edge.
    canvas.drawRRect(
      outer.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = r.palette.boxLine,
    );
  }

  /// Cell boundary positions snapped to whole physical pixels.
  ///
  /// Without this, a 9-cell division of an arbitrary width lands lines on
  /// fractional pixels and the grid renders visibly soft, which is the most
  /// common reason a canvas-drawn board looks worse than a widget one.
  List<double> _snappedEdges(double board, int n, double dpr) {
    return List<double>.generate(n + 1, (i) {
      final exact = board * i / n;
      return (exact * dpr).roundToDouble() / dpr;
    }, growable: false);
  }

  Rect _cellRect(List<double> edges, int row, int col) =>
      Rect.fromLTRB(edges[col], edges[row], edges[col + 1], edges[row + 1]);

  void _paintBoxTints(Canvas canvas, List<double> edges, int n) {
    final r = render;
    if (r.style.boxTint == BoxTint.none) return;

    final paint = Paint()..color = r.palette.boxTint;
    for (var bandRow = 0; bandRow < r.variant.bandRows; bandRow++) {
      for (var bandCol = 0; bandCol < r.variant.bandCols; bandCol++) {
        final shade = r.style.boxTint == BoxTint.bands
            ? bandRow.isOdd
            : (bandRow + bandCol).isOdd;
        if (!shade) continue;
        final top = bandRow * r.variant.boxRows;
        final left = bandCol * r.variant.boxCols;
        canvas.drawRect(
          Rect.fromLTRB(
            edges[left],
            edges[top],
            edges[left + r.variant.boxCols],
            edges[top + r.variant.boxRows],
          ),
          paint,
        );
      }
    }
  }

  void _paintHighlights(Canvas canvas, List<double> edges, int n) {
    final r = render;
    final geometry = r.geometry;
    final selected = r.selected;
    final hint = r.hint;

    void wash(int index, Color color) {
      if (color.a == 0) return;
      canvas.drawRect(
        _cellRect(edges, geometry.rowOf[index], geometry.colOf[index]),
        Paint()..color = color,
      );
    }

    final hovered = r.hovered;
    if (hovered != null && hovered != selected) {
      final fill = r.palette.peerFill;
      wash(hovered, fill.withValues(alpha: fill.a * 1.4));
    }

    // Peers of the selection, then cells repeating the selected digit.
    if (selected != null) {
      final t = r.selectionProgress;
      for (final peer in geometry.peers[selected]) {
        wash(
          peer,
          r.palette.peerFill.withValues(alpha: r.palette.peerFill.a * t),
        );
      }
      final digit = r.values[selected];
      if (digit != 0) {
        final tint = r.palette.selectionFill.withValues(
          alpha: r.palette.selectionFill.a * 0.45 * t,
        );
        for (var i = 0; i < r.values.length; i++) {
          if (i != selected && r.values[i] == digit) wash(i, tint);
        }
      }
    }

    // Hint evidence sits under the hint target.
    if (hint != null) {
      final t = r.hintProgress;
      final evidence = r.palette.hintEvidenceFill;
      for (final c in hint.because) {
        wash(c, evidence.withValues(alpha: evidence.a * t));
      }
    }

    for (final c in r.conflictCells) {
      wash(c, r.palette.conflictFill);
    }

    if (selected != null) {
      final fill = r.palette.selectionFill;
      wash(selected, fill.withValues(alpha: fill.a * r.selectionProgress));
    }

    if (hint != null) {
      final fill = r.palette.hintFill;
      wash(hint.cell, fill.withValues(alpha: fill.a * r.hintProgress));
    }
  }

  /// How far into the flourish [cell] is, 0 to 1, or null if it has not begun.
  ///
  /// Cells start in order of their distance from [BoardRender.celebrationOrigin]
  /// so the flourish travels outward from the move that caused it rather than
  /// flashing the whole unit at once.
  double? _celebrationPhase(int cell) {
    final r = render;
    final g = r.geometry;
    final origin = r.celebrationOrigin;

    // Chebyshev distance: a row, a column and a box all advance evenly.
    final steps = math.max(
      (g.rowOf[cell] - g.rowOf[origin]).abs(),
      (g.colOf[cell] - g.colOf[origin]).abs(),
    );
    final spread = r.variant.size - 1;
    final delay = spread == 0 ? 0.0 : (steps / spread) * _celebrationSpread;

    final local = (r.celebrationProgress - delay) / (1 - _celebrationSpread);
    if (local <= 0 || local >= 1) return null;
    return local;
  }

  /// Share of the animation spent launching cells, leaving the rest to play.
  static const double _celebrationSpread = 0.45;

  /// Sends a wave of light along a just-completed row, column or box.
  void _paintCelebration(Canvas canvas, List<double> edges) {
    final r = render;
    if (r.celebrated.isEmpty || r.celebrationProgress >= 1) return;

    final base = r.palette.completedUnitFill;
    for (final c in r.celebrated) {
      final phase = _celebrationPhase(c);
      if (phase == null) continue;

      // Rise and fall within each cell's own slice of the animation.
      final strength = math.sin(phase * math.pi);
      final rect = _cellRect(edges, r.geometry.rowOf[c], r.geometry.colOf[c]);

      canvas.drawRect(
        rect,
        Paint()..color = base.withValues(alpha: base.a * strength),
      );

      // A bright edge rides the crest, which is what makes it read as a wave
      // rather than a row of cells blinking.
      if (strength > 0.55) {
        canvas.drawRect(
          rect.deflate(rect.width * 0.06),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = base.withValues(
              alpha: ((strength - 0.55) / 0.45).clamp(0.0, 1.0) * 0.9,
            ),
        );
      }
    }
  }

  void _paintGrid(Canvas canvas, List<double> edges, int n, double board) {
    final r = render;
    final thin = Paint()
      ..color = r.palette.gridLine
      ..strokeWidth = r.style.gridLineScale / r.devicePixelRatio
      ..isAntiAlias = false;
    final thick = Paint()
      ..color = r.palette.boxLine
      ..strokeWidth = _thickStroke(r.devicePixelRatio) * r.style.boxLineScale
      ..isAntiAlias = false;

    for (var i = 1; i < n; i++) {
      final onBoxEdge = i % r.variant.boxCols == 0;
      final x = edges[i];
      canvas.drawLine(Offset(x, 0), Offset(x, board), onBoxEdge ? thick : thin);
    }
    for (var i = 1; i < n; i++) {
      final onBoxEdge = i % r.variant.boxRows == 0;
      final y = edges[i];
      canvas.drawLine(Offset(0, y), Offset(board, y), onBoxEdge ? thick : thin);
    }
  }

  /// Box separators are two physical pixels, so they read as heavier than the
  /// hairlines at any density without becoming chunky on low-DPR displays.
  double _thickStroke(double dpr) => 2 / dpr * (dpr >= 2 ? 1.5 : 2);

  void _paintDigits(Canvas canvas, List<double> edges, int n, double cell) {
    final r = render;
    for (var i = 0; i < r.values.length; i++) {
      final rect = _cellRect(edges, r.geometry.rowOf[i], r.geometry.colOf[i]);
      final value = r.values[i];

      // Digits ride the completion wave, scaling up slightly as it passes.
      final lift = r.celebrated.contains(i) && r.celebrationProgress < 1
          ? _celebrationPhase(i)
          : null;
      if (lift != null) {
        canvas
          ..save()
          ..translate(rect.center.dx, rect.center.dy)
          ..scale(1 + 0.16 * math.sin(lift * math.pi))
          ..translate(-rect.center.dx, -rect.center.dy);
      }

      if (value != 0) {
        // Givens, the player's correct answers, and the player's mistakes
        // each read differently, so progress is legible at a glance.
        final role = r.givens[i] != 0
            ? GlyphRole.given
            : r.wrongCells.contains(i)
            ? GlyphRole.conflict
            : GlyphRole.entry;
        final glyph = cache.glyph(role, value);
        glyph.paint(
          canvas,
          rect.center - Offset(glyph.width / 2, glyph.height / 2),
        );
        if (lift != null) canvas.restore();
        continue;
      }
      if (lift != null) canvas.restore();

      // Player notes take precedence; computed candidates fill in when asked.
      final noteMask = r.notes[i];
      final mask = noteMask != 0
          ? noteMask
          : (r.showCandidates ? r.candidates[i] : 0);
      if (mask == 0) continue;

      _paintMarks(
        canvas,
        rect,
        mask,
        noteMask != 0 ? GlyphRole.note : GlyphRole.candidate,
      );
    }
  }

  /// Lays marks out on the box's own grid, so a 6x6 board's notes sit in the
  /// same 3-wide, 2-tall arrangement as its boxes.
  ///
  /// The player's own pencil marks are drawn rotated a quarter turn. That is
  /// carried over from the original app, where it separated "I think" from
  /// "I know" at a glance, and it does the same job here between hand-written
  /// marks and the candidates the app computed. Only the mark layer turns --
  /// rotating the whole cell, as the original did, would carry its block
  /// separator borders around onto the wrong edges.
  void _paintMarks(Canvas canvas, Rect rect, int mask, GlyphRole role) {
    final r = render;
    final rotate = role == GlyphRole.note;

    if (rotate) {
      canvas.save();
      // A quarter turn about the centre of a square maps the cell onto
      // itself, so the marks stay within their own cell.
      canvas
        ..translate(rect.center.dx, rect.center.dy)
        ..rotate(math.pi / 2)
        ..translate(-rect.center.dx, -rect.center.dy);
    }

    final cols = r.variant.boxCols;
    final rows = r.variant.boxRows;
    final inset = rect.deflate(rect.width * 0.08);
    final cw = inset.width / cols;
    final ch = inset.height / rows;

    for (final digit in digitsOf(mask)) {
      final slot = digit - 1;
      final cx = inset.left + (slot % cols) * cw + cw / 2;
      final cy = inset.top + (slot ~/ cols) * ch + ch / 2;
      final glyph = cache.glyph(role, digit);
      glyph.paint(canvas, Offset(cx - glyph.width / 2, cy - glyph.height / 2));
    }

    if (rotate) canvas.restore();
  }

  // ------------------------------------------------------------- semantics

  /// Describes every cell to assistive technology.
  ///
  /// A `CustomPaint` is one opaque rectangle to a screen reader, so a board
  /// drawn this way is invisible to one unless its contents are published
  /// separately. These nodes are built from the same snapshot the painting
  /// uses, so the two cannot drift apart.
  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final r = render;
    final board = size.shortestSide;
    final edges = _snappedEdges(board, r.variant.size, r.devicePixelRatio);

    return [
      for (var i = 0; i < r.values.length; i++)
        CustomPainterSemantics(
          key: ValueKey(i),
          rect: _cellRect(edges, r.geometry.rowOf[i], r.geometry.colOf[i]),
          properties: SemanticsProperties(
            label: _describeCell(i),
            textDirection: TextDirection.ltr,
            enabled: !r.paused && !_isLocked(i),
            selected: i == r.selected,
            button: !r.paused && !_isLocked(i),
            onTap: r.paused || onSelectCell == null
                ? null
                : () => onSelectCell!(i),
          ),
        ),
    ];
  };

  bool _isLocked(int cell) {
    final r = render;
    // A given always. A correct answer only where the mode has already said
    // so -- otherwise "cannot be edited" would leak the same information.
    return r.givens[cell] != 0 ||
        (r.revealsCorrectness &&
            r.values[cell] != 0 &&
            !r.wrongCells.contains(cell));
  }

  /// One cell, in the words a listener needs rather than the ones on screen.
  String _describeCell(int cell) {
    final r = render;
    final where =
        'row ${r.geometry.rowOf[cell] + 1}, '
        'column ${r.geometry.colOf[cell] + 1}';

    // Pausing hides the board; it must hide it from everyone equally.
    if (r.paused) return '$where, hidden while paused';

    final value = r.values[cell];
    if (value != 0) {
      if (r.givens[cell] != 0) return '$where, $value, clue';
      // Saying nothing is right here. Calling an unflagged digit "correct"
      // would be a lie in play mode, where nothing has been checked aloud.
      if (!r.revealsCorrectness) return '$where, $value';
      if (r.wrongCells.contains(cell)) return '$where, $value, incorrect';
      return '$where, $value, correct';
    }

    final notes = digitsOf(r.notes[cell]);
    if (notes.isNotEmpty) {
      return '$where, empty, pencilled ${_list(notes)}';
    }
    if (r.showCandidates) {
      final candidates = digitsOf(r.candidates[cell]);
      if (candidates.isNotEmpty) {
        return '$where, empty, candidates ${_list(candidates)}';
      }
      return '$where, empty, no candidates left';
    }
    return '$where, empty';
  }

  /// Joins digits the way they would be said aloud.
  static String _list(List<int> digits) {
    if (digits.length == 1) return '${digits.first}';
    final head = digits.sublist(0, digits.length - 1).join(', ');
    return '$head and ${digits.last}';
  }

  @override
  bool shouldRebuildSemantics(BoardPainter oldDelegate) {
    final a = oldDelegate.render;
    final b = render;
    return a.revision != b.revision ||
        a.selected != b.selected ||
        a.paused != b.paused ||
        a.showCandidates != b.showCandidates ||
        a.revealsCorrectness != b.revealsCorrectness ||
        a.variant != b.variant ||
        !setEquals(a.wrongCells, b.wrongCells);
  }

  @override
  bool shouldRepaint(BoardPainter old) {
    final a = old.render;
    final b = render;
    return a.revision != b.revision ||
        a.selected != b.selected ||
        a.hovered != b.hovered ||
        a.hint != b.hint ||
        a.showCandidates != b.showCandidates ||
        a.paused != b.paused ||
        a.revealsCorrectness != b.revealsCorrectness ||
        a.celebrationProgress != b.celebrationProgress ||
        a.celebrationOrigin != b.celebrationOrigin ||
        !setEquals(a.wrongCells, b.wrongCells) ||
        !setEquals(a.celebrated, b.celebrated) ||
        a.selectionProgress != b.selectionProgress ||
        a.hintProgress != b.hintProgress ||
        a.palette != b.palette ||
        a.style != b.style ||
        a.variant != b.variant ||
        a.devicePixelRatio != b.devicePixelRatio;
  }
}
