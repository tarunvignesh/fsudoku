/// Mutable game state: the player's board, selection, notes, hints and clock.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/generator.dart';
import '../engine/hint.dart';
import '../engine/puzzle.dart';
import '../engine/solver.dart';
import '../engine/variant.dart';

/// One reversible change to a single cell.
///
/// Storing both sides of the edit makes undo and redo symmetric, which is why
/// the original stack-of-moves approach could not restore a cleared cell.
@immutable
class _Move {
  const _Move({
    required this.cell,
    required this.beforeValue,
    required this.afterValue,
    required this.beforeNotes,
    required this.afterNotes,
    required this.peerNotesBefore,
  });

  final int cell;
  final int beforeValue;
  final int afterValue;
  final int beforeNotes;
  final int afterNotes;

  /// Notes this move cleaned out of peer cells, so undo can put them back.
  final Map<int, int> peerNotesBefore;
}

/// Drives one game of Sudoku.
///
/// Holds the board the player is editing plus everything derived from it. The
/// board is rendered by a single painter, so a change here means one repaint of
/// one layer rather than a rebuild of every cell.
class GameController extends ChangeNotifier {
  /// Starts a game on [variant] at [difficulty].
  GameController({
    Variant variant = Variant.nine,
    Difficulty difficulty = Difficulty.gentle,
  }) {
    _variant = variant;
    _difficulty = difficulty;
    _start();
  }

  late Variant _variant;
  late Difficulty _difficulty;

  late Puzzle _puzzle;
  late List<int> _values;
  late List<int> _notes;
  late BoardAnalysis _analysis;

  final List<_Move> _undo = [];
  final List<_Move> _redo = [];

  int? _selected;
  bool _notesMode = false;
  bool _showCandidates = false;
  Hint? _hint;
  int _hintsUsed = 0;
  bool _solved = false;

  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;

  /// Elapsed play time, updated once a second.
  ///
  /// Separate from [ChangeNotifier] so the clock does not repaint the board.
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  /// Fires when the board is completed correctly.
  VoidCallback? onSolved;

  // ---------------------------------------------------------------- accessors

  Variant get variant => _variant;
  Difficulty get difficulty => _difficulty;
  Puzzle get puzzle => _puzzle;

  /// Current board contents, one digit per cell with 0 for empty.
  List<int> get values => _values;

  /// Pencil marks per cell, as a digit bitmask.
  List<int> get notes => _notes;

  /// Derived candidates, conflicts and hints for the current position.
  BoardAnalysis get analysis => _analysis;

  /// Selected cell index, or null.
  int? get selected => _selected;

  /// Whether digit entry writes pencil marks instead of answers.
  bool get notesMode => _notesMode;

  /// Whether computed candidates are shown in empty cells.
  bool get showCandidates => _showCandidates;

  /// The hint currently being explained, if any.
  Hint? get hint => _hint;

  /// How many hints the player has asked for this puzzle.
  int get hintsUsed => _hintsUsed;

  /// Whether the puzzle is finished and correct.
  bool get isSolved => _solved;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Increments on every change.
  ///
  /// The board arrays are mutated in place for speed, so identity comparison
  /// cannot detect edits. The painter compares this instead of walking cells.
  int get revision => _revision;
  int _revision = 0;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

  /// Whether the clock is running.
  bool get isRunning => _clock.isRunning;

  /// Cells still empty.
  int get remaining => _values.where((v) => v == 0).length;

  /// True when [cell] came with the puzzle and cannot be edited.
  bool isGiven(int cell) => _puzzle.isGiven(cell);

  // ------------------------------------------------------------- lifecycle

  void _start() {
    _puzzle = Generator(_variant).generate(_difficulty);
    _values = List<int>.of(_puzzle.givens);
    _notes = List<int>.filled(_variant.cellCount, 0);
    _undo.clear();
    _redo.clear();
    _selected = null;
    _hint = null;
    _hintsUsed = 0;
    _solved = false;
    _notesMode = false;
    _reanalyse();

    _clock
      ..reset()
      ..start();
    elapsed.value = Duration.zero;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed.value = _clock.elapsed;
    });
  }

  /// Starts a fresh puzzle, optionally changing [variant] or [difficulty].
  void newGame({Variant? variant, Difficulty? difficulty}) {
    _variant = variant ?? _variant;
    _difficulty = difficulty ?? _difficulty;
    _start();
    notifyListeners();
  }

  /// Clears every player entry, keeping the same puzzle.
  void restart() {
    _values = List<int>.of(_puzzle.givens);
    _notes = List<int>.filled(_variant.cellCount, 0);
    _undo.clear();
    _redo.clear();
    _hint = null;
    _solved = false;
    _reanalyse();
    _clock
      ..reset()
      ..start();
    elapsed.value = Duration.zero;
    notifyListeners();
  }

  /// Pauses or resumes the clock.
  void setPaused({required bool paused}) {
    if (paused && _clock.isRunning) {
      _clock.stop();
    } else if (!paused && !_clock.isRunning && !_solved) {
      _clock.start();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    elapsed.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- selection

  /// Selects [cell], or clears the selection when [cell] is null.
  void select(int? cell) {
    if (_selected == cell) return;
    _selected = cell;
    _hint = null; // a new selection supersedes the explanation on screen
    notifyListeners();
  }

  /// Moves the selection by [dx] columns and [dy] rows, clamped to the board.
  ///
  /// With nothing selected, starts at the top-left so the keyboard alone is
  /// enough to begin playing.
  void moveSelection(int dx, int dy) {
    final n = _variant.size;
    final current = _selected;
    if (current == null) {
      select(0);
      return;
    }
    final geometry = _analysis.geometry;
    final row = (geometry.rowOf[current] + dy).clamp(0, n - 1);
    final col = (geometry.colOf[current] + dx).clamp(0, n - 1);
    select(geometry.indexOf(row, col));
  }

  /// Toggles whether digit entry writes pencil marks.
  void toggleNotesMode() {
    _notesMode = !_notesMode;
    notifyListeners();
  }

  /// Toggles the computed candidate overlay.
  void toggleCandidates() {
    _showCandidates = !_showCandidates;
    notifyListeners();
  }

  // ------------------------------------------------------------------ edits

  /// Enters [digit] into the selected cell, as an answer or a pencil mark.
  ///
  /// Entering the digit already in the cell clears it, so the same key both
  /// sets and unsets.
  void enter(int digit) {
    final cell = _selected;
    if (cell == null || digit < 1 || digit > _variant.size) return;
    if (isGiven(cell)) return;

    if (_notesMode) {
      _apply(cell, value: _values[cell], notes: _notes[cell] ^ digitBit(digit));
      return;
    }

    final next = _values[cell] == digit ? 0 : digit;
    _apply(cell, value: next, notes: 0, clearPeerNotes: next != 0);
  }

  /// Clears the selected cell's answer and pencil marks.
  void clearSelected() {
    final cell = _selected;
    if (cell == null || isGiven(cell)) return;
    if (_values[cell] == 0 && _notes[cell] == 0) return;
    _apply(cell, value: 0, notes: 0);
  }

  void _apply(
    int cell, {
    required int value,
    required int notes,
    bool clearPeerNotes = false,
  }) {
    final peerNotesBefore = <int, int>{};
    if (clearPeerNotes && value != 0) {
      // Placing a digit invalidates that pencil mark everywhere it can see.
      final bit = digitBit(value);
      for (final peer in _analysis.geometry.peers[cell]) {
        if (_notes[peer] & bit != 0) {
          peerNotesBefore[peer] = _notes[peer];
          _notes[peer] &= ~bit;
        }
      }
    }

    final move = _Move(
      cell: cell,
      beforeValue: _values[cell],
      afterValue: value,
      beforeNotes: _notes[cell],
      afterNotes: notes,
      peerNotesBefore: peerNotesBefore,
    );

    _values[cell] = value;
    _notes[cell] = notes;
    _undo.add(move);
    _redo.clear();
    _hint = null;
    _afterEdit();
  }

  /// Reverts the last edit.
  void undo() {
    if (_undo.isEmpty) return;
    final move = _undo.removeLast();
    _values[move.cell] = move.beforeValue;
    _notes[move.cell] = move.beforeNotes;
    move.peerNotesBefore.forEach((peer, before) => _notes[peer] = before);
    _redo.add(move);
    _selected = move.cell;
    _hint = null;
    _afterEdit();
  }

  /// Reapplies the last undone edit.
  void redo() {
    if (_redo.isEmpty) return;
    final move = _redo.removeLast();
    _values[move.cell] = move.afterValue;
    _notes[move.cell] = move.afterNotes;
    if (move.afterValue != 0) {
      final bit = digitBit(move.afterValue);
      for (final peer in move.peerNotesBefore.keys) {
        _notes[peer] &= ~bit;
      }
    }
    _undo.add(move);
    _selected = move.cell;
    _hint = null;
    _afterEdit();
  }

  // ------------------------------------------------------------------ hints

  /// Finds the next deducible move and starts explaining it.
  ///
  /// Returns null when nothing follows by deduction, which on a correct board
  /// means the player has to guess, and on a broken one means they went wrong
  /// earlier. [BoardAnalysis.conflicts] and [BoardAnalysis.starvedCells]
  /// distinguish the two.
  Hint? requestHint() {
    final found = _analysis.nextHint();
    if (found != null) _hintsUsed++;
    _hint = found;
    _selected = found?.cell ?? _selected;
    notifyListeners();
    return found;
  }

  /// Fills in the cell the current hint points at.
  void applyHint() {
    final current = _hint;
    if (current == null) return;
    _selected = current.cell;
    _apply(current.cell, value: current.digit, notes: 0, clearPeerNotes: true);
  }

  /// Dismisses the hint explanation.
  void dismissHint() {
    if (_hint == null) return;
    _hint = null;
    notifyListeners();
  }

  // --------------------------------------------------------------- internals

  void _reanalyse() => _analysis = BoardAnalysis(_variant, _values);

  void _afterEdit() {
    _reanalyse();
    if (!_solved && _analysis.isSolved) {
      _solved = true;
      _clock.stop();
      _ticker?.cancel();
      elapsed.value = _clock.elapsed;
      notifyListeners();
      onSolved?.call();
      return;
    }
    notifyListeners();
  }
}
