/// Saving, restoring, and the modes that change what the board reveals.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsudoku/engine/puzzle.dart';
import 'package:fsudoku/engine/solver.dart';
import 'package:fsudoku/engine/variant.dart';
import 'package:fsudoku/state/game_controller.dart';
import 'package:fsudoku/state/game_mode.dart';
import 'package:fsudoku/state/persistence.dart';
import 'package:fsudoku/state/settings_controller.dart';
import 'package:fsudoku/state/storage/key_value_store.dart';
import 'package:fsudoku/ui/app.dart';
import 'package:fsudoku/ui/skins.dart';

void main() {
  group('snapshots', () {
    test('a game survives a round trip', () {
      final game = GameController(variant: Variant.six, random: Random(3));
      addTearDown(game.dispose);

      final blank = game.values.indexOf(0);
      game
        ..select(blank)
        ..enterAnswer(game.puzzle.solution[blank]);
      final other = game.values.indexOf(0);
      game
        ..select(other)
        ..enterNote(2)
        ..enterNote(5);

      final restored = GameController.restored(
        GameSnapshot.fromJson(game.snapshot().toJson())!,
      );
      addTearDown(restored.dispose);

      expect(restored.variant, game.variant);
      expect(restored.difficulty, game.difficulty);
      expect(restored.mode, game.mode);
      expect(restored.values, game.values);
      expect(restored.notes, game.notes);
      expect(restored.puzzle.givens, game.puzzle.givens);
      expect(restored.puzzle.solution, game.puzzle.solution);
      expect(restored.correctMoves, game.correctMoves);
      expect(restored.showCandidates, game.showCandidates);
    });

    test('a restored game keeps playing from where it stopped', () {
      final game = GameController(variant: Variant.four, random: Random(4));
      addTearDown(game.dispose);
      final blank = game.values.indexOf(0);
      game
        ..select(blank)
        ..enterAnswer(game.puzzle.solution[blank]);

      final restored = GameController.restored(game.snapshot());
      addTearDown(restored.dispose);

      // The next blank still takes input, and still checks against the same
      // solution the saved game was using.
      final next = restored.values.indexOf(0);
      restored
        ..select(next)
        ..enterAnswer(restored.puzzle.solution[next]);
      expect(restored.isCorrect(next), isTrue);
      expect(restored.isLocked(next), isTrue);
    });

    test('elapsed time carries across a restore', () {
      final game = GameController(variant: Variant.four, random: Random(4));
      addTearDown(game.dispose);

      final snapshot = GameSnapshot(
        variant: game.variant,
        difficulty: game.difficulty,
        mode: game.mode,
        givens: game.puzzle.givens,
        solution: game.puzzle.solution,
        values: game.values,
        notes: game.notes,
        elapsed: const Duration(minutes: 3, seconds: 20),
        correctMoves: 2,
        wrongMoves: 1,
        hintsUsed: 1,
        showCandidates: true,
      );

      final restored = GameController.restored(snapshot);
      addTearDown(restored.dispose);
      expect(restored.elapsed.value.inSeconds, greaterThanOrEqualTo(200));
      expect(restored.totalElapsed.inSeconds, greaterThanOrEqualTo(200));
      expect(restored.wrongMoves, 1);
      expect(restored.hintsUsed, 1);
    });

    test('nonsense is ignored rather than fatal', () {
      expect(GameSnapshot.fromJson({'variant': 'nope'}), isNull);
      expect(GameSnapshot.fromJson(const {}), isNull);
      expect(SettingsSnapshot.fromJson(const {}), isNull);

      // A board of the wrong length, as an older build might have written.
      final game = GameController(variant: Variant.four, random: Random(1));
      addTearDown(game.dispose);
      final json = game.snapshot().toJson();
      json['values'] = [1, 2, 3];
      expect(GameSnapshot.fromJson(json), isNull);
    });
  });

  group('repository', () {
    test('saves and reloads through a store', () {
      final store = InMemoryStore();
      final repository = GameRepository(store);
      expect(repository.loadGame(), isNull);

      final game = GameController(variant: Variant.four, random: Random(2));
      addTearDown(game.dispose);
      final blank = game.values.indexOf(0);
      game
        ..select(blank)
        ..enterNote(3);

      repository.saveGame(game.snapshot());
      final loaded = repository.loadGame();
      expect(loaded, isNotNull);
      expect(loaded!.notes[blank] & digitBit(3), isNot(0));
    });

    test('an untouched board is not worth saving', () {
      final store = InMemoryStore();
      final repository = GameRepository(store);
      final game = GameController(variant: Variant.four, random: Random(2));
      addTearDown(game.dispose);

      repository.saveGame(game.snapshot());
      expect(
        repository.loadGame(),
        isNull,
        reason: 'nothing has been played yet',
      );
    });

    test('corrupt storage does not take the app down', () {
      final store = InMemoryStore()
        ..write('fsudoku.game.v1', 'not json at all')
        ..write('fsudoku.settings.v1', '{"skin":');
      final repository = GameRepository(store);
      expect(repository.loadGame(), isNull);
      expect(repository.loadSettings(), isNull);
    });

    test('settings round trip, and a removed skin falls back', () {
      final store = InMemoryStore();
      final repository = GameRepository(store);
      final settings = SettingsController()
        ..skin = Skin.terminal
        ..themeMode = ThemeMode.dark
        ..gridOnly = true;
      addTearDown(settings.dispose);

      repository.saveSettings(settings.snapshot());
      final loaded = repository.loadSettings()!;
      expect(loaded.skin.id, 'terminal');
      expect(loaded.themeModeName, 'dark');
      expect(loaded.gridOnly, isTrue);

      final gone = SettingsSnapshot.fromJson({
        'skin': 'a-skin-that-was-removed',
        'themeMode': 'dark',
        'gridOnly': false,
      })!;
      expect(gone.skin.id, Skin.slate.id);
    });
  });

  group('through the app', () {
    testWidgets('a game played, torn down and relaunched comes back', (
      tester,
    ) async {
      final view = tester.platformDispatcher.views.first;
      view.physicalSize = const Size(1600, 1000);
      view.devicePixelRatio = 1;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      final repository = GameRepository(InMemoryStore());
      final game = GameController(variant: Variant.four, random: Random(6));
      await tester.pumpWidget(
        FSudokuApp(controller: game, repository: repository),
      );
      await tester.pump();

      final blank = game.values.indexOf(0);
      final digit = game.puzzle.solution[blank];
      game
        ..select(blank)
        ..enterAnswer(digit);
      await tester.pump(const Duration(seconds: 1));

      // Tear the tree down, which flushes whatever the debounce still holds.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final saved = repository.loadGame();
      expect(saved, isNotNull, reason: 'the played game should be stored');
      expect(saved!.values[blank], digit);

      // Relaunch with no injected controller: it must pick the game up.
      await tester.pumpWidget(FSudokuApp(repository: repository));
      await tester.pumpAndSettle();
      expect(find.text('Sudoku Trainer'), findsOneWidget);
    });

    testWidgets('a solved puzzle is not restored into', (tester) async {
      final repository = GameRepository(InMemoryStore());
      final game = GameController(variant: Variant.four, random: Random(7));
      await tester.pumpWidget(
        FSudokuApp(controller: game, repository: repository),
      );
      await tester.pump();

      for (var i = 0; i < 16; i++) {
        if (game.values[i] != 0) continue;
        game
          ..select(i)
          ..enterAnswer(game.puzzle.solution[i]);
      }
      expect(game.isSolved, isTrue);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(repository.loadGame(), isNull);
    });
  });

  group('results and records', () {
    GameResult resultWith({
      required Duration elapsed,
      int correct = 30,
      int wrong = 2,
      int hints = 1,
      GameMode mode = GameMode.training,
    }) => GameResult(
      variant: Variant.nine,
      difficulty: Difficulty.gentle,
      mode: mode,
      elapsed: elapsed,
      correctMoves: correct,
      wrongMoves: wrong,
      hintsUsed: hints,
      blanks: 40,
    );

    test('the first finish is a personal best', () {
      final repository = GameRepository(InMemoryStore());
      final played = resultWith(elapsed: const Duration(minutes: 5));
      final previous = repository.recordIfBest(played);

      expect(previous, isNull);
      expect(played.against(previous).isPersonalBest, isTrue);
      expect(repository.loadRecords()[played.recordKey]?.inMinutes, 5);
    });

    test('a slower run does not displace the record', () {
      final repository = GameRepository(InMemoryStore());
      repository.recordIfBest(resultWith(elapsed: const Duration(minutes: 4)));

      final slower = resultWith(elapsed: const Duration(minutes: 9));
      final previous = repository.recordIfBest(slower);

      expect(previous, const Duration(minutes: 4));
      expect(slower.against(previous).isPersonalBest, isFalse);
      expect(
        repository.loadRecords()[slower.recordKey],
        const Duration(minutes: 4),
        reason: 'the better time must survive',
      );
    });

    test('a faster run takes the record', () {
      final repository = GameRepository(InMemoryStore());
      repository.recordIfBest(resultWith(elapsed: const Duration(minutes: 6)));

      final faster = resultWith(elapsed: const Duration(minutes: 3));
      final previous = repository.recordIfBest(faster);

      expect(faster.against(previous).isPersonalBest, isTrue);
      expect(
        repository.loadRecords()[faster.recordKey],
        const Duration(minutes: 3),
      );
    });

    test('records are kept per size, difficulty and mode', () {
      final repository = GameRepository(InMemoryStore());
      repository.recordIfBest(resultWith(elapsed: const Duration(minutes: 5)));
      repository.recordIfBest(
        resultWith(elapsed: const Duration(minutes: 8), mode: GameMode.play),
      );

      final records = repository.loadRecords();
      expect(records.length, 2, reason: 'modes do not share a leaderboard');
      expect(records['nine/gentle/training'], const Duration(minutes: 5));
      expect(records['nine/gentle/play'], const Duration(minutes: 8));
    });

    test('accuracy is reported in training and withheld in play', () {
      expect(
        resultWith(elapsed: Duration.zero).accuracy,
        closeTo(30 / 32, 1e-9),
      );
      expect(
        resultWith(elapsed: Duration.zero, mode: GameMode.play).accuracy,
        isNull,
        reason: 'play never counted the mistakes',
      );
      expect(
        resultWith(elapsed: Duration.zero, correct: 40, wrong: 0).accuracy,
        1.0,
      );
    });

    test('corrupt records are ignored rather than fatal', () {
      final store = InMemoryStore()
        ..write(
          'fsudoku.records.v1',
          '{"nine/gentle/training": "not a number"}',
        );
      expect(GameRepository(store).loadRecords(), isEmpty);
    });
  });

  group('game modes', () {
    test('play mode does not reveal correctness or lock cells', () {
      final game = GameController(
        variant: Variant.four,
        mode: GameMode.play,
        random: Random(5),
      );
      addTearDown(game.dispose);

      expect(game.showCandidates, isFalse, reason: 'play starts unaided');

      final blank = game.values.indexOf(0);
      final right = game.puzzle.solution[blank];
      game
        ..select(blank)
        ..enterAnswer(right);

      // The app still knows; it simply does not settle the cell.
      expect(game.isCorrect(blank), isTrue);
      expect(
        game.isLocked(blank),
        isFalse,
        reason: 'locking a correct cell would reveal it by the back door',
      );
      game.clearSelected();
      expect(game.values[blank], 0);
    });

    test('training locks correct answers and shows candidates', () {
      final game = GameController(variant: Variant.four, random: Random(5));
      addTearDown(game.dispose);

      expect(game.mode, GameMode.training);
      expect(game.showCandidates, isTrue);

      final blank = game.values.indexOf(0);
      game
        ..select(blank)
        ..enterAnswer(game.puzzle.solution[blank]);
      expect(game.isLocked(blank), isTrue);
    });

    test('switching mode keeps the board but changes what it says', () {
      final game = GameController(variant: Variant.four, random: Random(5));
      addTearDown(game.dispose);

      final blank = game.values.indexOf(0);
      final wrong = game.puzzle.solution[blank] == 1 ? 2 : 1;
      game
        ..select(blank)
        ..enterAnswer(wrong);
      expect(game.isWrong(blank), isTrue);

      game.mode = GameMode.play;
      expect(game.values[blank], wrong, reason: 'the entry stays put');
      expect(game.isWrong(blank), isTrue, reason: 'the fact is unchanged');
      expect(game.mode.revealsCorrectness, isFalse);
      expect(game.showCandidates, isFalse);
    });

    test('the mode is remembered with the game', () {
      final game = GameController(
        variant: Variant.four,
        mode: GameMode.play,
        random: Random(5),
      );
      addTearDown(game.dispose);
      final blank = game.values.indexOf(0);
      game
        ..select(blank)
        ..enterNote(1);

      final restored = GameController.restored(game.snapshot());
      addTearDown(restored.dispose);
      expect(restored.mode, GameMode.play);
      expect(restored.isLocked(blank), isFalse);
    });
  });
}
