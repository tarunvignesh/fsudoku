/// The interactive board: hit testing, hover and highlight animation.
library;

import 'package:flutter/material.dart';

import '../../engine/hint.dart';
import '../../state/game_controller.dart';
import '../theme.dart';
import 'board_painter.dart';
import 'glyph_cache.dart';

/// Renders the board and turns pointer input into cell selection.
///
/// The board is one [CustomPaint], so selecting a cell repaints a single layer
/// rather than rebuilding a widget per cell.
class BoardView extends StatefulWidget {
  /// Creates a board view driven by [controller].
  const BoardView({required this.controller, super.key});

  /// The game being played.
  final GameController controller;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> with TickerProviderStateMixin {
  final GlyphCache _cache = GlyphCache();

  late final AnimationController _selection = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
  );
  late final AnimationController _hintFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  int? _lastSelected;
  Hint? _lastHint;
  int? _hovered;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _selection.value = 1;
    _hintFade.value = 1;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _selection.dispose();
    _hintFade.dispose();
    _cache.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final selected = widget.controller.selected;
    if (selected != _lastSelected) {
      _lastSelected = selected;
      if (selected != null) _selection.forward(from: 0);
    }
    final hint = widget.controller.hint;
    if (hint != _lastHint) {
      _lastHint = hint;
      if (hint != null) _hintFade.forward(from: 0);
    }
  }

  /// The cell under [local], or null when the point is off the board.
  int? _cellAt(Offset local, double board) {
    final n = widget.controller.variant.size;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= board ||
        local.dy >= board) {
      return null;
    }
    final col = (local.dx / board * n).floor().clamp(0, n - 1);
    final row = (local.dy / board * n).floor().clamp(0, n - 1);
    return row * n + col;
  }

  void _selectAt(Offset local, double board) {
    final cell = _cellAt(local, board);
    if (cell != null) widget.controller.select(cell);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<BoardPalette>()!;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final board = constraints.biggest.shortestSide;
        return MouseRegion(
          cursor: SystemMouseCursors.basic,
          onHover: (event) {
            final cell = _cellAt(event.localPosition, board);
            if (cell != _hovered) setState(() => _hovered = cell);
          },
          onExit: (_) {
            if (_hovered != null) setState(() => _hovered = null);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _selectAt(d.localPosition, board),
            onPanUpdate: (d) => _selectAt(d.localPosition, board),
            child: AnimatedBuilder(
              animation: Listenable.merge([
                widget.controller,
                _selection,
                _hintFade,
              ]),
              builder: (context, _) {
                final c = widget.controller;
                final analysis = c.analysis;
                final conflicts = <int>{
                  for (final conflict in analysis.conflicts()) conflict.cell,
                };

                return CustomPaint(
                  size: Size.square(board),
                  isComplex: true,
                  willChange: _selection.isAnimating || _hintFade.isAnimating,
                  painter: BoardPainter(
                    cache: _cache,
                    render: BoardRender(
                      variant: c.variant,
                      geometry: analysis.geometry,
                      revision: c.revision,
                      values: c.values,
                      notes: c.notes,
                      givens: c.puzzle.givens,
                      candidates: analysis.candidates,
                      conflictCells: conflicts,
                      showCandidates: c.showCandidates,
                      palette: palette,
                      devicePixelRatio: dpr,
                      selected: c.selected,
                      hovered: _hovered,
                      hint: c.hint,
                      selectionProgress: Curves.easeOutCubic.transform(
                        _selection.value,
                      ),
                      hintProgress: Curves.easeOutCubic.transform(
                        _hintFade.value,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
