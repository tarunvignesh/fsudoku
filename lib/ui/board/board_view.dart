/// The interactive board: hit testing, hover and highlight animation.
library;

import 'package:flutter/material.dart';

import '../../engine/hint.dart';
import '../../state/game_controller.dart';
import '../theme.dart';
import 'board_painter.dart';
import 'cell_menu.dart';
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

  /// Plays once each time a row, column or box is completed.
  late final AnimationController _celebrate = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  int? _lastSelected;
  Hint? _lastHint;
  int? _hovered;
  int _lastCelebration = 0;

  /// The cell whose menu is open, and what it writes.
  int? _menuCell;
  CellMenuMode _menuMode = CellMenuMode.answer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _selection.value = 1;
    _hintFade.value = 1;
    _celebrate.value = 1;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _selection.dispose();
    _hintFade.dispose();
    _celebrate.dispose();
    _cache.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final selected = widget.controller.selected;
    if (selected != _lastSelected) {
      _lastSelected = selected;
      if (selected != null) _selection.forward(from: 0);
      // Moving on with the keyboard dismisses a menu left open by a tap.
      if (_menuCell != null && selected != _menuCell) _closeMenu();
    }
    if (widget.controller.paused && _menuCell != null) _closeMenu();
    final hint = widget.controller.hint;
    if (hint != _lastHint) {
      _lastHint = hint;
      if (hint != null) _hintFade.forward(from: 0);
    }
    final tick = widget.controller.celebrationTick;
    if (tick != _lastCelebration) {
      _lastCelebration = tick;
      _celebrate.forward(from: 0);
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

  void _closeMenu() {
    if (_menuCell == null) return;
    setState(() => _menuCell = null);
  }

  /// Opens the digit menu on the cell under [local], if it is still editable.
  void _openMenu(Offset local, double board, CellMenuMode mode) {
    final controller = widget.controller;
    if (controller.paused) return;
    final cell = _cellAt(local, board);
    if (cell == null) return;

    controller.select(cell);

    // Settled cells take no input, so they get no menu either -- the absence
    // of the menu is how the board says "this one is done".
    if (controller.isLocked(cell)) {
      _closeMenu();
      return;
    }
    setState(() {
      _menuCell = cell;
      _menuMode = mode;
    });
  }

  /// Opens the menu on an already-selected [cell].
  void _openMenuOn(int cell, CellMenuMode mode) {
    final controller = widget.controller;
    if (controller.paused || controller.isLocked(cell)) {
      _closeMenu();
      return;
    }
    setState(() {
      _menuCell = cell;
      _menuMode = mode;
    });
  }

  /// Places the menu beside its cell, kept within the board's bounds.
  Widget _positionedMenu(
    BuildContext context,
    GameController controller,
    double board,
  ) {
    final cell = _menuCell!;
    final variant = controller.variant;
    final geometry = controller.analysis.geometry;
    final cellSize = board / variant.size;

    final menuW = CellMenu.widthFor(variant);
    final menuH = CellMenu.heightFor(variant);

    final cellLeft = geometry.colOf[cell] * cellSize;
    final cellTop = geometry.rowOf[cell] * cellSize;

    // Below the cell by default, above it when that would fall off the board.
    var top = cellTop + cellSize + 8;
    if (top + menuH > board) top = cellTop - menuH - 8;
    top = top.clamp(0.0, (board - menuH).clamp(0.0, board));

    final left = (cellLeft + cellSize / 2 - menuW / 2).clamp(
      0.0,
      (board - menuW).clamp(0.0, board),
    );

    return Positioned(
      left: left,
      top: top,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('$cell-$_menuMode'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.88 + 0.12 * t, child: child),
        ),
        child: CellMenu(
          variant: variant,
          mode: _menuMode,
          notes: controller.notes[cell],
          value: controller.values[cell],
          candidates: controller.analysis.candidates[cell],
          showCandidates: controller.showCandidates,
          onPick: (digit) {
            if (_menuMode == CellMenuMode.pencil) {
              controller.enterNote(digit);
            } else {
              controller.enterAnswer(digit);
              _closeMenu();
            }
          },
          onClear: controller.clearSelected,
          onDismiss: _closeMenu,
        ),
      ),
    );
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
            onTap: () {
              final selected = widget.controller.selected;
              if (selected != null) {
                _openMenuOn(selected, CellMenuMode.answer);
              }
            },
            // Long press on touch, right click with a mouse: the same gesture
            // the original used to pencil without committing a move.
            onLongPressStart: (d) =>
                _openMenu(d.localPosition, board, CellMenuMode.pencil),
            onSecondaryTapDown: (d) =>
                _openMenu(d.localPosition, board, CellMenuMode.pencil),
            child: AnimatedBuilder(
              animation: Listenable.merge([
                widget.controller,
                _selection,
                _hintFade,
                _celebrate,
              ]),
              builder: (context, _) {
                final c = widget.controller;
                final analysis = c.analysis;
                final conflicts = <int>{
                  for (final conflict in analysis.conflicts()) conflict.cell,
                };
                final wrong = <int>{
                  for (var i = 0; i < c.values.length; i++)
                    if (c.isWrong(i)) i,
                };

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size.square(board),
                      isComplex: true,
                      willChange:
                          _selection.isAnimating ||
                          _hintFade.isAnimating ||
                          _celebrate.isAnimating,
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
                          wrongCells: wrong,
                          celebrated: c.celebrated,
                          paused: c.paused,
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
                          celebrationProgress: _celebrate.value,
                        ),
                      ),
                    ),
                    if (_menuCell != null && !c.paused)
                      _positionedMenu(context, c, board),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
