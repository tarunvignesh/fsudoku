/// App shell: layout, controls, keyboard handling.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/puzzle.dart';
import '../engine/variant.dart';
import '../state/game_controller.dart';
import 'board/board_view.dart';
import 'hint_panel.dart';
import 'number_pad.dart';
import 'theme.dart';

/// Root widget.
class FSudokuApp extends StatelessWidget {
  /// Creates the app.
  const FSudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku Trainer',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: const GamePage(),
    );
  }
}

/// The single screen: board, controls and hint explanation.
class GamePage extends StatefulWidget {
  /// Creates the game page.
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _game = GameController()..onSolved = _announceWin;
  final FocusNode _keyboard = FocusNode(debugLabel: 'board-keyboard');

  @override
  void dispose() {
    _game.dispose();
    _keyboard.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ input

  /// Routes physical keys to game actions.
  ///
  /// Handled here rather than per-widget so the whole board is playable from
  /// the keyboard alone, which is how most people will use it on the web.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final pressed = HardwareKeyboard.instance;
    final ctrl = pressed.isControlPressed || pressed.isMetaPressed;

    // Digits, from both the number row and the numpad.
    for (var d = 1; d <= _game.variant.size; d++) {
      if (key == _digitKeys[d - 1] || key == _numpadKeys[d - 1]) {
        _game.enter(d);
        return KeyEventResult.handled;
      }
    }

    if (ctrl && key == LogicalKeyboardKey.keyZ) {
      pressed.isShiftPressed ? _game.redo() : _game.undo();
      return KeyEventResult.handled;
    }
    if (ctrl && key == LogicalKeyboardKey.keyY) {
      _game.redo();
      return KeyEventResult.handled;
    }

    switch (key) {
      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.digit0:
        _game.clearSelected();
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyA:
        _game.moveSelection(-1, 0);
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyD:
        _game.moveSelection(1, 0);
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.keyW:
        _game.moveSelection(0, -1);
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.keyS:
        _game.moveSelection(0, 1);
      case LogicalKeyboardKey.keyN:
        _game.toggleNotesMode();
      case LogicalKeyboardKey.keyC:
        _game.toggleCandidates();
      case LogicalKeyboardKey.keyH:
        _requestHint();
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space:
        _game.hint != null ? _game.applyHint() : _requestHint();
      case LogicalKeyboardKey.escape:
        _game.hint != null ? _game.dismissHint() : _game.select(null);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  static const _numpadKeys = [
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
    LogicalKeyboardKey.numpad5,
    LogicalKeyboardKey.numpad6,
    LogicalKeyboardKey.numpad7,
    LogicalKeyboardKey.numpad8,
    LogicalKeyboardKey.numpad9,
  ];

  // ---------------------------------------------------------------- actions

  void _requestHint() {
    final hint = _game.requestHint();
    if (hint != null) return;

    // Nothing follows by deduction. Say which of the two reasons it is.
    final analysis = _game.analysis;
    final conflicts = analysis.conflicts();
    final starved = analysis.starvedCells();
    final message = conflicts.isNotEmpty
        ? 'There is a repeated digit on the board. Clear the cells marked in '
              'red and the trail will pick up again.'
        : starved.isNotEmpty
        ? 'One of the empty cells has no digit left that fits, so '
              'something earlier is wrong. Try undoing a few moves.'
        : 'No single move follows from logic alone here. This board needs '
              'a guess: pick a cell with two candidates and try one.';
    _showSnack(message);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          width: 460,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<void> _announceWin() async {
    final time = _game.elapsed.value;
    final hints = _game.hintsUsed;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solved'),
        content: Text(
          '${_game.variant.label} · ${_game.difficulty.label}\n'
          'Time ${_format(time)}\n'
          '${hints == 0 ? "No hints used" : "$hints hint${hints == 1 ? "" : "s"} used"}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay here'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _game.newGame();
            },
            child: const Text('New puzzle'),
          ),
        ],
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ----------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboard,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 880;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: wide ? _wideLayout() : _narrowLayout(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(game: _game, onNewGame: _game.newGame),
              const SizedBox(height: 16),
              Flexible(child: _board()),
            ],
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Toolbar(game: _game, onHint: _requestHint),
                const SizedBox(height: 16),
                NumberPad(controller: _game),
                const SizedBox(height: 16),
                HintPanel(controller: _game),
                const SizedBox(height: 16),
                const _KeyboardLegend(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(game: _game, onNewGame: _game.newGame),
          const SizedBox(height: 14),
          _board(),
          const SizedBox(height: 14),
          _Toolbar(game: _game, onHint: _requestHint),
          const SizedBox(height: 14),
          NumberPad(controller: _game),
          const SizedBox(height: 14),
          HintPanel(controller: _game),
        ],
      ),
    );
  }

  Widget _board() {
    return AspectRatio(aspectRatio: 1, child: BoardView(controller: _game));
  }
}

/// Variant and difficulty pickers, the clock, and a new-game button.
class _Header extends StatelessWidget {
  const _Header({required this.game, required this.onNewGame});

  final GameController game;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Flexible rather than fixed: at large text-scale settings on
                // a narrow phone a fixed title overflows the row.
                Flexible(
                  child: Text(
                    'Sudoku Trainer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Spacer(),
                ValueListenableBuilder<Duration>(
                  valueListenable: game.elapsed,
                  builder: (context, value, _) => Text(
                    _GamePageState._format(value),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'New puzzle',
                  onPressed: onNewGame,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SegmentedButton<Variant>(
                  showSelectedIcon: false,
                  segments: [
                    for (final v in Variant.values)
                      ButtonSegment(value: v, label: Text(v.label)),
                  ],
                  selected: {game.variant},
                  onSelectionChanged: (s) => game.newGame(variant: s.first),
                ),
                SegmentedButton<Difficulty>(
                  showSelectedIcon: false,
                  segments: [
                    for (final d in Difficulty.values)
                      ButtonSegment(value: d, label: Text(d.label)),
                  ],
                  selected: {game.difficulty},
                  onSelectionChanged: (s) => game.newGame(difficulty: s.first),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Undo, redo, erase, notes, candidates and hint.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.game, required this.onHint});

  final GameController game;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ToolButton(
              icon: Icons.undo,
              label: 'Undo',
              onPressed: game.canUndo ? game.undo : null,
            ),
            _ToolButton(
              icon: Icons.redo,
              label: 'Redo',
              onPressed: game.canRedo ? game.redo : null,
            ),
            _ToolButton(
              icon: Icons.backspace_outlined,
              label: 'Erase',
              onPressed: game.selected == null ? null : game.clearSelected,
            ),
            _ToolButton(
              icon: Icons.edit_outlined,
              label: 'Notes',
              selected: game.notesMode,
              accent: _Accent.notes,
              onPressed: game.toggleNotesMode,
            ),
            _ToolButton(
              icon: Icons.grid_on,
              label: 'Candidates',
              selected: game.showCandidates,
              onPressed: game.toggleCandidates,
            ),
            _ToolButton(
              icon: Icons.lightbulb_outline,
              label: 'Hint',
              onPressed: onHint,
            ),
          ],
        );
      },
    );
  }
}

/// Which accent a toggled tool carries.
enum _Accent {
  /// Pencil-mark mode, kept visually distinct from the teaching layer.
  notes,

  /// Part of the teaching layer, so it matches the hint colour.
  teaching,
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.accent = _Accent.teaching,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final _Accent accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = accent == _Accent.notes
        ? scheme.secondaryContainer
        : scheme.tertiaryContainer;
    final foreground = accent == _Accent.notes
        ? scheme.onSecondaryContainer
        : scheme.onTertiaryContainer;
    return Tooltip(
      message: label,
      child: selected
          ? FilledButton.tonalIcon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: background,
                foregroundColor: foreground,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }
}

/// Discoverability for the keyboard controls, shown only on wide layouts.
class _KeyboardLegend extends StatelessWidget {
  const _KeyboardLegend();

  static const _rows = [
    ('1-9', 'enter a digit'),
    ('arrows / WASD', 'move selection'),
    ('backspace', 'erase'),
    ('N', 'notes mode'),
    ('C', 'show candidates'),
    ('H', 'hint'),
    ('space', 'place the hint'),
    ('ctrl+Z', 'undo'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Keyboard',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final (keys, action) in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  child: Text(
                    keys,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  action,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
