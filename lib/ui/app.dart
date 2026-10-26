/// App shell: layout, controls, keyboard handling.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import 'package:flutter/semantics.dart';

import '../engine/puzzle.dart';
import '../engine/variant.dart';
import '../state/game_controller.dart';
import '../state/settings_controller.dart';
import 'board/board_view.dart';
import 'hint_panel.dart';
import 'number_pad.dart';
import 'radial_menu.dart';
import 'skins.dart';
import 'theme.dart';

/// Root widget.
class FSudokuApp extends StatefulWidget {
  /// Creates the app.
  ///
  /// Pass [controller] to drive a specific game, which lets tests work
  /// against a seeded puzzle instead of a random one, and [settings] to start
  /// on a particular skin.
  const FSudokuApp({super.key, this.controller, this.settings});

  /// An externally supplied game, or null to start a fresh one.
  final GameController? controller;

  /// Externally supplied presentation settings, or null for the defaults.
  final SettingsController? settings;

  @override
  State<FSudokuApp> createState() => _FSudokuAppState();
}

class _FSudokuAppState extends State<FSudokuApp> {
  late final SettingsController _settings =
      widget.settings ?? SettingsController();

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) => MaterialApp(
        title: 'Sudoku Trainer',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(_settings.skin, Brightness.light),
        darkTheme: buildAppTheme(_settings.skin, Brightness.dark),
        themeMode: _settings.themeMode,
        // Long enough to see the skin change, short enough not to feel slow.
        themeAnimationDuration: const Duration(milliseconds: 420),
        themeAnimationCurve: Curves.easeOutCubic,
        home: GamePage(controller: widget.controller, settings: _settings),
      ),
    );
  }
}

/// The single screen: board, controls and hint explanation.
class GamePage extends StatefulWidget {
  /// Creates the game page.
  const GamePage({super.key, this.controller, this.settings});

  /// An externally supplied game, or null to start a fresh one.
  final GameController? controller;

  /// Presentation settings, or null to use defaults owned by this page.
  final SettingsController? settings;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController _game = (widget.controller ?? GameController())
    ..onSolved = _announceWin;
  late final SettingsController _settings =
      widget.settings ?? SettingsController();
  final FocusNode _keyboard = FocusNode(debugLabel: 'board-keyboard');

  @override
  void dispose() {
    // The page takes ownership of its controller, injected or not, and so
    // disposes it here. That keeps the controller's clock from outliving the
    // widget tree, which a caller is easy to forget to do.
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

    // While paused the board is hidden, so it accepts nothing but un-pausing.
    if (_game.paused) {
      if (key == LogicalKeyboardKey.keyP || key == LogicalKeyboardKey.escape) {
        _game.togglePause();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Digits, from both the number row and the numpad. Shift pencils the
    // digit without switching modes, mirroring the original's long-press.
    for (var d = 1; d <= _game.variant.size; d++) {
      if (key == _digitKeys[d - 1] || key == _numpadKeys[d - 1]) {
        pressed.isShiftPressed ? _game.enterNote(d) : _game.enter(d);
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
      case LogicalKeyboardKey.keyP:
        _game.togglePause();
      case LogicalKeyboardKey.keyF:
        _settings.toggleGridOnly();
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
    if (hint != null) {
      // A sighted player sees the explanation appear and the cells light up.
      // Spoken, it has to be announced or it simply does not arrive.
      _announce('${hint.technique.label}. ${hint.explanation}');
      return;
    }

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

  /// Speaks [message] to assistive technology.
  void _announce(
    String message, {
    Assertiveness assertiveness = Assertiveness.polite,
  }) {
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        TextDirection.ltr,
        assertiveness: assertiveness,
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          // A fixed width wider than the screen is wrong on a phone; null
          // lets it span the width with the usual margin instead.
          width: MediaQuery.sizeOf(context).width < 520 ? null : 460.0,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  Future<void> _announceWin() async {
    final time = _game.elapsed.value;
    final hints = _game.hintsUsed;
    if (!mounted) return;

    _announce(
      'Solved in ${_format(time)}.',
      assertiveness: Assertiveness.assertive,
    );
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
              // The side panel needs room in both directions. A phone in
              // landscape is wide but short, so width alone is not the test.
              final fits =
                  constraints.maxWidth >= 900 && constraints.maxHeight >= 620;

              if (!fits || _settings.gridOnly) {
                // Offer a way back only when the panel is actually available;
                // on a phone there is nothing to go back to.
                return _immersiveLayout(canShowPanel: fits);
              }

              return Center(
                // Generous, not capped at a width that leaves a 1920 screen
                // mostly empty. The board is bounded by height anyway.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1800),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _fullLayout(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fullLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                game: _game,
                onNewGame: _game.newGame,
                onOpenSkins: _showSkinSheet,
                onGridOnly: _settings.toggleGridOnly,
              ),
              const SizedBox(height: 16),
              Flexible(child: _board()),
            ],
          ),
        ),
        const SizedBox(width: 28),
        // Fixed, so extra width goes to the board rather than stretching
        // controls that gain nothing from it.
        SizedBox(
          width: 360,
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

  /// The phone layout: the board and nothing else.
  ///
  /// Everything that would otherwise sit around the board lives in the radial
  /// menu, so the puzzle gets the whole screen in either orientation. Digits
  /// are entered through the cell menu, which needs no chrome of its own.
  Widget _immersiveLayout({required bool canShowPanel}) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Center(child: _board()),
        ),

        // Only when the panel exists to go back to. Deliberately small and
        // out of the way: the point of this view is the absence of chrome.
        if (canShowPanel)
          Positioned(
            top: 6,
            right: 6,
            child: Tooltip(
              message: 'Show panel (F)',
              child: IconButton(
                onPressed: _settings.toggleGridOnly,
                icon: const Icon(Icons.fullscreen_exit, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
        // Fills the screen so its fanned-out actions are inside its own hit
        // test bounds; taps elsewhere fall through to the board beneath.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _game,
            builder: (context, _) => RadialMenu(
              status: _ImmersiveStatus(game: _game),
              actions: [
                RadialAction(
                  icon: Icons.lightbulb_outline,
                  label: 'Hint',
                  onPressed: _requestHint,
                ),
                RadialAction(
                  icon: Icons.edit_outlined,
                  label: 'Notes',
                  keepsMenuOpen: true,
                  selected: _game.notesMode,
                  onPressed: _game.toggleNotesMode,
                ),
                RadialAction(
                  icon: Icons.grid_on,
                  label: 'Candidates',
                  keepsMenuOpen: true,
                  selected: _game.showCandidates,
                  onPressed: _game.toggleCandidates,
                ),
                RadialAction(
                  icon: Icons.undo,
                  label: 'Undo',
                  onPressed: _game.canUndo ? _game.undo : null,
                ),
                RadialAction(
                  icon: Icons.more_horiz,
                  label: 'More',
                  onPressed: _showGameSheet,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Skin and brightness picker.
  Future<void> _showSkinSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AnimatedBuilder(
        animation: _settings,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Skin',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode, size: 18),
                        ),
                      ],
                      selected: {_settings.themeMode},
                      onSelectionChanged: (s) => _settings.themeMode = s.first,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final skin in Skin.all)
                  _SkinTile(
                    skin: skin,
                    selected: skin.id == _settings.skin.id,
                    onTap: () => _settings.skin = skin,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Board size, difficulty and a new puzzle, for the immersive layout.
  Future<void> _showGameSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => AnimatedBuilder(
        animation: _game,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<Variant>(
                  showSelectedIcon: false,
                  segments: [
                    for (final v in Variant.values)
                      ButtonSegment(value: v, label: Text(v.label)),
                  ],
                  selected: {_game.variant},
                  onSelectionChanged: (s) => _game.newGame(variant: s.first),
                ),
                const SizedBox(height: 10),
                SegmentedButton<Difficulty>(
                  showSelectedIcon: false,
                  segments: [
                    for (final d in Difficulty.values)
                      ButtonSegment(value: d, label: Text(d.label)),
                  ],
                  selected: {_game.difficulty},
                  onSelectionChanged: (s) => _game.newGame(difficulty: s.first),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _game.newGame();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('New puzzle'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _game.togglePause();
                        },
                        icon: Icon(
                          _game.paused ? Icons.play_arrow : Icons.pause,
                        ),
                        label: Text(_game.paused ? 'Resume' : 'Pause'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showSkinSheet();
                        },
                        icon: const Icon(Icons.palette_outlined),
                        label: const Text('Skin'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _board() {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedBuilder(
        animation: _game,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            child!,
            if (_game.paused) _PausedCover(onResume: _game.togglePause),
          ],
        ),
        child: BoardView(controller: _game),
      ),
    );
  }
}

/// Variant and difficulty pickers, the clock, and a new-game button.
class _Header extends StatelessWidget {
  const _Header({
    required this.game,
    required this.onNewGame,
    required this.onOpenSkins,
    required this.onGridOnly,
  });

  final GameController game;
  final VoidCallback onNewGame;
  final VoidCallback onOpenSkins;
  final VoidCallback onGridOnly;

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
                _ScoreChip(
                  count: game.correctMoves,
                  icon: Icons.check,
                  tone: _Tone.good,
                ),
                const SizedBox(width: 6),
                _ScoreChip(
                  count: game.wrongMoves,
                  icon: Icons.close,
                  tone: _Tone.bad,
                ),
                const SizedBox(width: 12),
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
                const SizedBox(width: 4),
                // Compact: three buttons at the default 48px footprint push
                // the row past its width once the clock and counters are in.
                _HeaderButton(
                  tooltip: 'Grid only (F)',
                  icon: Icons.fullscreen,
                  onPressed: onGridOnly,
                ),
                _HeaderButton(
                  tooltip: 'Skins and theme',
                  icon: Icons.palette_outlined,
                  onPressed: onOpenSkins,
                ),
                _HeaderButton(
                  tooltip: 'New puzzle',
                  icon: Icons.refresh,
                  onPressed: onNewGame,
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

/// One row in the skin picker, with a miniature of the board it produces.
class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  final Skin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final palette = dark ? skin.dark : skin.light;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _SkinSwatch(palette: palette, style: skin.style),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        skin.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: skin.uiFontFamily,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        skin.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A four-cell miniature showing a skin's surface, grid and digit colours.
class _SkinSwatch extends StatelessWidget {
  const _SkinSwatch({required this.palette, required this.style});

  final BoardPalette palette;
  final BoardStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(style.cornerRadiusScale * 24),
        border: Border.all(color: palette.boxLine, width: 1.2),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MiniCell('5', palette.givenText, style.fontFamily),
                ),
                Expanded(
                  child: _MiniCell('3', palette.entryText, style.fontFamily),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: ColoredBox(
                    color: palette.selectionFill,
                    child: _MiniCell('7', palette.entryText, style.fontFamily),
                  ),
                ),
                Expanded(
                  child: _MiniCell('2', palette.conflictText, style.fontFamily),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCell extends StatelessWidget {
  const _MiniCell(this.digit, this.color, this.family);

  final String digit;
  final Color color;
  final String? family;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 13,
          height: 1,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: family,
        ),
      ),
    );
  }
}

/// Clock and score, shown only while the radial menu is open.
///
/// The immersive layout deliberately has nowhere to put these at rest; they
/// appear with the controls and leave with them.
class _ImmersiveStatus extends StatelessWidget {
  const _ImmersiveStatus({required this.game});

  final GameController game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: game.elapsed,
              builder: (context, value, _) => Text(
                _GamePageState._format(value),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ScoreChip(
              count: game.correctMoves,
              icon: Icons.check,
              tone: _Tone.good,
            ),
            const SizedBox(width: 5),
            _ScoreChip(
              count: game.wrongMoves,
              icon: Icons.close,
              tone: _Tone.bad,
            ),
            const SizedBox(width: 8),
            Text(
              '${game.remaining} left',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Covers a paused board with an invitation to resume.
///
/// The board itself already stops drawing its digits while paused; this just
/// says why, and gives the pointer somewhere obvious to go.
class _PausedCover extends StatelessWidget {
  const _PausedCover({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: GestureDetector(
        onTap: onResume,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: theme.colorScheme.surface.withValues(alpha: 0.55),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  size: 44,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text('Paused', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Click the board or press P to resume',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small icon button for the header's right-hand cluster.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    );
  }
}

/// Which way a score chip reads.
enum _Tone { good, bad }

/// A compact count of correct or mistaken answers.
///
/// The original tracked these with animated badges; the information was worth
/// keeping, the animation on every increment was not.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.count,
    required this.icon,
    required this.tone,
  });

  final int count;
  final IconData icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<BoardPalette>()!;
    final color = tone == _Tone.good
        ? theme.colorScheme.tertiary
        : palette.conflictText;

    return Tooltip(
      message: tone == _Tone.good ? 'Correct answers' : 'Mistakes',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
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
            _ToolButton(
              icon: game.paused ? Icons.play_arrow : Icons.pause,
              label: game.paused ? 'Resume' : 'Pause',
              selected: game.paused,
              onPressed: game.togglePause,
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
    ('shift+1-9', 'pencil a digit'),
    ('N', 'notes mode'),
    ('C', 'show candidates'),
    ('H', 'hint'),
    ('space', 'place the hint'),
    ('P', 'pause'),
    ('F', 'grid only'),
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
