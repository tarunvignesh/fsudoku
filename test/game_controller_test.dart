import 'package:fsudoku/engine/puzzle.dart';
import 'package:fsudoku/engine/solver.dart';
import 'package:fsudoku/engine/variant.dart';
import 'package:fsudoku/state/game_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// The first cell the player is allowed to edit.
int firstBlank(GameController g) => g.values.indexOf(0);

void main() {
  late GameController game;

  setUp(() => game = GameController(variant: Variant.four));
  tearDown(() => game.dispose());

  group('setup', () {
    test('starts on the requested variant with the puzzle loaded', () {
      expect(game.variant, Variant.four);
      expect(game.values.length, 16);
      expect(game.values, game.puzzle.givens);
      expect(game.isSolved, isFalse);
      expect(game.canUndo, isFalse);
      expect(game.canRedo, isFalse);
    });

    test('switching variant rebuilds the board', () {
      game.newGame(variant: Variant.nine, difficulty: Difficulty.steady);
      expect(game.variant, Variant.nine);
      expect(game.values.length, 81);
      expect(game.difficulty, Difficulty.steady);
    });
  });

  group('entry', () {
    test('writes a digit into the selected cell', () {
      final cell = firstBlank(game);
      game.select(cell);
      game.enter(3);
      expect(game.values[cell], 3);
    });

    test('re-entering the same digit clears it', () {
      final cell = firstBlank(game);
      game.select(cell);
      game.enter(3);
      game.enter(3);
      expect(game.values[cell], 0);
    });

    test('refuses to edit a given', () {
      final given = game.values.indexWhere((v) => v != 0);
      final before = game.values[given];
      game.select(given);
      game.enter(before == 1 ? 2 : 1);
      expect(game.values[given], before);
      expect(game.canUndo, isFalse);
    });

    test('ignores entry with nothing selected', () {
      game.enter(2);
      expect(game.canUndo, isFalse);
    });

    test('ignores digits outside the variant range', () {
      game.select(firstBlank(game));
      game.enter(7); // 4x4 only goes to 4
      expect(game.canUndo, isFalse);
    });

    test('notes mode writes pencil marks, not answers', () {
      final cell = firstBlank(game);
      game.select(cell);
      game.toggleNotesMode();
      game.enter(2);
      expect(game.values[cell], 0);
      expect(game.notes[cell] & digitBit(2), isNot(0));
    });

    test('the same note toggles off', () {
      final cell = firstBlank(game);
      game.select(cell);
      game.toggleNotesMode();
      game.enter(2);
      game.enter(2);
      expect(game.notes[cell], 0);
    });

    test('placing a digit clears that note from peers', () {
      final cell = firstBlank(game);
      final peer = game.analysis.geometry.peers[cell].firstWhere(
        (p) => game.values[p] == 0,
      );

      game.select(peer);
      game.toggleNotesMode();
      game.enter(3);
      expect(game.notes[peer] & digitBit(3), isNot(0));

      game.toggleNotesMode();
      game.select(cell);
      game.enter(3);
      expect(game.notes[peer] & digitBit(3), 0);
    });
  });

  group('undo and redo', () {
    test('undo restores the previous digit', () {
      final cell = firstBlank(game);
      game.select(cell);
      game.enter(1);
      game.enter(2); // overwrite
      expect(game.values[cell], 2);
      game.undo();
      expect(game.values[cell], 1);
      game.undo();
      expect(game.values[cell], 0);
      expect(game.canUndo, isFalse);
    });

    // The old implementation could not undo an erase, which is why the action
    // was disabled outright in the last commit before this rewrite.
    test('undo restores an erased digit', () {
      final cell = firstBlank(game);
      game.select(cell);
      game.enter(4);
      game.clearSelected();
      expect(game.values[cell], 0);
      game.undo();
      expect(game.values[cell], 4);
    });

    test('undo restores pencil marks', () {
      final cell = firstBlank(game);
      game.select(cell);
      game.toggleNotesMode();
      game.enter(1);
      game.enter(2);
      final before = game.notes[cell];
      game.clearSelected();
      expect(game.notes[cell], 0);
      game.undo();
      expect(game.notes[cell], before);
    });

    test('undo restores notes cleared from peers', () {
      final cell = firstBlank(game);
      final peer = game.analysis.geometry.peers[cell].firstWhere(
        (p) => game.values[p] == 0,
      );

      game.select(peer);
      game.toggleNotesMode();
      game.enter(3);
      final peerNotes = game.notes[peer];

      game.toggleNotesMode();
      game.select(cell);
      game.enter(3);
      expect(game.notes[peer], isNot(peerNotes));

      game.undo();
      expect(game.notes[peer], peerNotes);
    });

    test('redo reapplies the undone edit', () {
      final cell = firstBlank(game);
      game.select(cell);
      game.enter(2);
      game.undo();
      expect(game.values[cell], 0);
      game.redo();
      expect(game.values[cell], 2);
      expect(game.canRedo, isFalse);
    });

    test('a new edit clears the redo stack', () {
      final cell = firstBlank(game);
      game.select(cell);
      game.enter(2);
      game.undo();
      expect(game.canRedo, isTrue);
      game.enter(3);
      expect(game.canRedo, isFalse);
    });

    test('undo and redo are no-ops when the stacks are empty', () {
      final before = List<int>.of(game.values);
      game.undo();
      game.redo();
      expect(game.values, before);
    });

    test('a long edit sequence undoes back to the starting board', () {
      final start = List<int>.of(game.puzzle.givens);
      final blanks = [
        for (var i = 0; i < 16; i++)
          if (game.values[i] == 0) i,
      ];
      for (final cell in blanks) {
        game.select(cell);
        game.enter((cell % 4) + 1);
      }
      while (game.canUndo) {
        game.undo();
      }
      expect(game.values, start);
    });
  });

  group('selection', () {
    test('arrow movement clamps at the edges', () {
      game.select(0);
      game.moveSelection(-1, 0);
      expect(game.selected, 0);
      game.moveSelection(0, -1);
      expect(game.selected, 0);
      game.moveSelection(1, 0);
      expect(game.selected, 1);
      game.moveSelection(0, 1);
      expect(game.selected, 5);
    });

    test('moving with nothing selected starts at the top left', () {
      expect(game.selected, isNull);
      game.moveSelection(1, 0);
      expect(game.selected, 0);
    });

    test('selecting a different cell clears the active hint', () {
      final hint = game.requestHint()!;
      expect(game.selected, hint.cell);
      final elsewhere = List<int>.generate(
        16,
        (i) => i,
      ).firstWhere((i) => i != hint.cell && game.values[i] == 0);
      game.select(elsewhere);
      expect(game.hint, isNull);
    });

    test('re-selecting the hinted cell keeps the explanation on screen', () {
      final hint = game.requestHint()!;
      game.select(hint.cell);
      expect(game.hint, isNotNull);
    });
  });

  group('hints', () {
    test('a hint points at a blank cell and counts as used', () {
      final hint = game.requestHint();
      expect(hint, isNotNull);
      expect(game.values[hint!.cell], 0);
      expect(game.hintsUsed, 1);
      expect(game.selected, hint.cell);
    });

    test('applying a hint fills the correct digit', () {
      final hint = game.requestHint()!;
      game.applyHint();
      expect(game.values[hint.cell], hint.digit);
      expect(game.values[hint.cell], game.puzzle.solution[hint.cell]);
    });

    test('applying with no hint active does nothing', () {
      final before = List<int>.of(game.values);
      game.applyHint();
      expect(game.values, before);
    });

    test('dismissing clears the explanation but keeps the count', () {
      game.requestHint();
      game.dismissHint();
      expect(game.hint, isNull);
      expect(game.hintsUsed, 1);
    });
  });

  group('completion', () {
    test('filling the solution marks the game solved and fires onSolved', () {
      var fired = 0;
      game.onSolved = () => fired++;
      for (var i = 0; i < 16; i++) {
        if (game.values[i] != 0) continue;
        game.select(i);
        game.enter(game.puzzle.solution[i]);
      }
      expect(game.isSolved, isTrue);
      expect(fired, 1);
      expect(game.remaining, 0);
      expect(game.isRunning, isFalse);
    });

    test('a full but wrong board is not solved', () {
      // Fill every blank with the same digit, which must duplicate somewhere.
      for (var i = 0; i < 16; i++) {
        if (game.values[i] != 0) continue;
        game.select(i);
        game.enter(1);
      }
      expect(game.remaining, 0);
      expect(game.isSolved, isFalse);
      expect(game.analysis.conflicts(), isNotEmpty);
    });
  });

  group('restart and revision', () {
    test('restart clears entries but keeps the puzzle', () {
      final puzzle = game.puzzle;
      game.select(firstBlank(game));
      game.enter(2);
      game.restart();
      expect(game.puzzle, same(puzzle));
      expect(game.values, puzzle.givens);
      expect(game.canUndo, isFalse);
    });

    test('revision advances on every change', () {
      final before = game.revision;
      game.select(firstBlank(game));
      expect(game.revision, greaterThan(before));
      final afterSelect = game.revision;
      game.enter(2);
      expect(game.revision, greaterThan(afterSelect));
    });

    test('pausing stops the clock', () {
      expect(game.isRunning, isTrue);
      game.setPaused(paused: true);
      expect(game.isRunning, isFalse);
      game.setPaused(paused: false);
      expect(game.isRunning, isTrue);
    });
  });
}
