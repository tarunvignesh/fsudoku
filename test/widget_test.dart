import 'dart:math';

import 'package:fsudoku/engine/variant.dart';
import 'package:fsudoku/state/game_controller.dart';
import 'package:fsudoku/ui/board/board_view.dart';
import 'package:fsudoku/ui/board/cell_menu.dart';
import 'package:fsudoku/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsudoku/engine/solver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends a key through the real shortcut handling, as a player would.
Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Reads the digits currently painted on the board.
///
/// The board is a single canvas, so there is nothing in the widget tree to
/// query; the status line is the observable surface instead.
String statusLine(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((s) => s.contains('cells to go'), orElse: () => '');
}

void main() {
  // The board renders to a canvas sized by the viewport, so give tests a
  // desktop-shaped window and reset it afterwards.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1600, 1100);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('boots to a playable 9x9 board', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    expect(find.text('Sudoku Trainer'), findsOneWidget);
    for (final v in Variant.values) {
      expect(find.text(v.label), findsOneWidget);
    }
    expect(find.text('Hint'), findsOneWidget);
    expect(statusLine(tester), contains('cells to go'));
  });

  testWidgets('the digit pad shows one button per digit', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    // 9x9 by default, so digits 1 through 9 each appear on the pad.
    for (var d = 1; d <= 9; d++) {
      expect(find.text('$d'), findsWidgets, reason: 'digit $d');
    }
  });

  testWidgets('switching to 4x4 reduces the digit pad', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    await tester.tap(find.text('4x4'));
    await tester.pumpAndSettle();

    // 4x4 has no 9, on the pad or anywhere else.
    expect(find.text('9'), findsNothing);
    expect(find.text('4'), findsWidgets);
  });

  testWidgets('keyboard entry changes the board', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    await tester.tap(find.text('4x4'));
    await tester.pumpAndSettle();

    final before = statusLine(tester);

    // Puzzles are generated at random, so which cells are editable varies.
    // Raster-scan the whole board rather than walking a diagonal: every
    // puzzle has blanks, so an exhaustive sweep always finds one, and the
    // test cannot depend on where they happened to land.
    await press(tester, LogicalKeyboardKey.arrowRight); // select (0, 0)
    var entered = false;
    for (var row = 0; row < 4 && !entered; row++) {
      for (var col = 0; col < 4; col++) {
        await press(tester, LogicalKeyboardKey.digit1);
        if (statusLine(tester) != before) {
          entered = true;
          break;
        }
        await press(tester, LogicalKeyboardKey.arrowRight);
      }
      if (entered) break;
      // Back to column 0 (arrow movement clamps) and down a row.
      for (var i = 0; i < 4; i++) {
        await press(tester, LogicalKeyboardKey.arrowLeft);
      }
      await press(tester, LogicalKeyboardKey.arrowDown);
    }

    expect(entered, isTrue, reason: 'no editable cell found on the board');
    expect(statusLine(tester), isNot(before));
  });

  testWidgets('H surfaces an explained hint, space places it', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    expect(find.textContaining('can only be'), findsNothing);

    await press(tester, LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();

    // The explanation names the technique and the reasoning.
    expect(find.text('Last remaining digit'), findsOneWidget);
    expect(find.textContaining('can only be'), findsOneWidget);
    expect(find.textContaining('Place '), findsOneWidget);

    final before = statusLine(tester);
    await press(tester, LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(statusLine(tester), isNot(before));
  });

  testWidgets('N toggles notes mode and C toggles candidates', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    // Both start off; toggling is reflected in the tool buttons' styling,
    // which switches between outlined and filled.
    final outlinedAtRest = tester
        .widgetList(find.byType(OutlinedButton))
        .length;

    await press(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(
      tester.widgetList(find.byType(OutlinedButton)).length,
      lessThan(outlinedAtRest),
    );

    await press(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(
      tester.widgetList(find.byType(OutlinedButton)).length,
      outlinedAtRest,
    );

    await press(tester, LogicalKeyboardKey.keyC);
    await tester.pumpAndSettle();
    expect(
      tester.widgetList(find.byType(OutlinedButton)).length,
      lessThan(outlinedAtRest),
    );
  });

  testWidgets('renders narrow layouts without overflowing', (tester) async {
    final view = tester.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;

    await tester.pumpWidget(const FSudokuApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sudoku Trainer'), findsOneWidget);
  });

  testWidgets('renders in light and dark without throwing', (tester) async {
    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpWidget(const FSudokuApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$brightness');
    }
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  group('cell menu', () {
    /// Taps the centre of [cell] on the painted board.
    Future<void> tapCell(
      WidgetTester tester,
      GameController game,
      int cell,
    ) async {
      final box = tester.renderObject<RenderBox>(find.byType(BoardView));
      final board = box.size.shortestSide;
      final n = game.variant.size;
      final size = board / n;
      final origin = tester.getTopLeft(find.byType(BoardView));
      await tester.tapAt(
        origin +
            Offset((cell % n) * size + size / 2, (cell ~/ n) * size + size / 2),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens on an editable cell and writes an answer', (
      tester,
    ) async {
      final game = GameController(variant: Variant.four, random: Random(5));
      await tester.pumpWidget(FSudokuApp(controller: game));
      await tester.pump();

      expect(find.byType(CellMenu), findsNothing);

      final blank = game.values.indexOf(0);
      await tapCell(tester, game, blank);
      expect(find.byType(CellMenu), findsOneWidget);

      // The menu offers exactly the variant's digits, laid out on its boxes.
      final wrong = game.puzzle.solution[blank] == 1 ? 2 : 1;
      await tester.tap(
        find.descendant(
          of: find.byType(CellMenu),
          matching: find.text('$wrong'),
        ),
      );
      await tester.pumpAndSettle();

      expect(game.values[blank], wrong);
      // Picking an answer closes the menu.
      expect(find.byType(CellMenu), findsNothing);
    });

    testWidgets('does not open on a locked cell', (tester) async {
      final game = GameController(variant: Variant.four, random: Random(5));
      await tester.pumpWidget(FSudokuApp(controller: game));
      await tester.pump();

      final given = game.values.indexWhere((v) => v != 0);
      await tapCell(tester, game, given);
      expect(find.byType(CellMenu), findsNothing);

      // A cell answered correctly locks, and stops offering a menu too.
      final blank = game.values.indexOf(0);
      game
        ..select(blank)
        ..enterAnswer(game.puzzle.solution[blank]);
      await tester.pumpAndSettle();

      await tapCell(tester, game, blank);
      expect(find.byType(CellMenu), findsNothing);
    });

    testWidgets('long press opens the menu in pencil mode', (tester) async {
      final game = GameController(variant: Variant.four, random: Random(5));
      await tester.pumpWidget(FSudokuApp(controller: game));
      await tester.pump();

      final blank = game.values.indexOf(0);
      final box = tester.renderObject<RenderBox>(find.byType(BoardView));
      final board = box.size.shortestSide;
      final n = game.variant.size;
      final size = board / n;
      final origin = tester.getTopLeft(find.byType(BoardView));
      await tester.longPressAt(
        origin +
            Offset(
              (blank % n) * size + size / 2,
              (blank ~/ n) * size + size / 2,
            ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CellMenu), findsOneWidget);
      expect(find.text('Pencil'), findsOneWidget);

      // Picking pencils rather than answering, and leaves the menu up so
      // several marks can be made in one visit.
      await tester.tap(
        find.descendant(of: find.byType(CellMenu), matching: find.text('2')),
      );
      await tester.pumpAndSettle();

      expect(game.values[blank], 0);
      expect(game.notes[blank] & digitBit(2), isNot(0));
      expect(find.byType(CellMenu), findsOneWidget);
    });

    testWidgets('pausing hides the board and blocks entry', (tester) async {
      final game = GameController(variant: Variant.four, random: Random(5));
      await tester.pumpWidget(FSudokuApp(controller: game));
      await tester.pump();

      final blank = game.values.indexOf(0);
      game.select(blank);

      await press(tester, LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      expect(game.paused, isTrue);
      expect(find.text('Paused'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.digit1);
      expect(game.values[blank], 0, reason: 'paused boards take no input');

      await press(tester, LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      expect(game.paused, isFalse);
      expect(find.text('Paused'), findsNothing);
    });
  });
}
