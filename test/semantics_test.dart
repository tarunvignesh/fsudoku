/// What a screen reader is told about the board.
///
/// The board is one `CustomPaint`, which is a single opaque rectangle to
/// assistive technology unless its contents are published separately. These
/// tests assert the published description, because nothing on screen reveals
/// whether it is right.
library;

import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsudoku/engine/variant.dart';
import 'package:fsudoku/state/game_controller.dart';
import 'package:fsudoku/ui/app.dart';
import 'package:fsudoku/ui/board/board_view.dart';

/// The root of the live semantics tree.
///
/// Walks the pipeline owners rather than reaching for the deprecated
/// `binding.pipelineOwner`: since the multi-view refactor each view owns a
/// child owner, and the semantics live there.
SemanticsNode semanticsRoot(WidgetTester tester) {
  SemanticsNode? found;
  void visit(PipelineOwner owner) {
    found ??= owner.semanticsOwner?.rootSemanticsNode;
    owner.visitChildren(visit);
  }

  visit(tester.binding.rootPipelineOwner);
  return found!;
}

/// Walks every node in the semantics tree.
void forEachNode(WidgetTester tester, void Function(SemanticsNode) fn) {
  void walk(SemanticsNode node) {
    fn(node);
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(semanticsRoot(tester));
}

/// Every semantics label currently published anywhere in the tree.
List<String> labels(WidgetTester tester) {
  final out = <String>[];
  forEachNode(tester, (n) {
    if (n.label.isNotEmpty) out.add(n.label);
  });
  return out;
}

/// The published node describing [cell], or null.
SemanticsNode? nodeForCell(WidgetTester tester, GameController game, int cell) {
  final where =
      'row ${cell ~/ game.variant.size + 1}, '
      'column ${cell % game.variant.size + 1},';
  SemanticsNode? found;
  forEachNode(tester, (n) {
    if (n.label.startsWith(where)) found = n;
  });
  return found;
}

/// The one label describing [cell], or null.
String? labelFor(WidgetTester tester, GameController game, int cell) {
  final where =
      'row ${cell ~/ game.variant.size + 1}, '
      'column ${cell % game.variant.size + 1},';
  final hits = labels(tester).where((l) => l.startsWith(where)).toList();
  return hits.isEmpty ? null : hits.first;
}

Future<GameController> pumpBoard(
  WidgetTester tester, {
  Variant? variant,
}) async {
  final view = tester.platformDispatcher.views.first;
  view.physicalSize = const Size(1600, 1000);
  view.devicePixelRatio = 1;
  addTearDown(() {
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  final game = GameController(
    variant: variant ?? Variant.four,
    random: Random(5),
  );
  await tester.pumpWidget(FSudokuApp(controller: game));
  await tester.pumpAndSettle();
  return game;
}

void main() {
  late SemanticsHandle handle;
  setUp(() => handle = TestWidgetsFlutterBinding.instance.ensureSemantics());
  tearDown(() => handle.dispose());

  group('board semantics', () {
    testWidgets('every cell is published, not just the board', (tester) async {
      final game = await pumpBoard(tester, variant: Variant.nine);

      // A board with no semantics layer publishes one node. This must publish
      // one per cell.
      var described = 0;
      for (var i = 0; i < game.variant.cellCount; i++) {
        if (labelFor(tester, game, i) != null) described++;
      }
      expect(described, game.variant.cellCount);
    });

    testWidgets('the board announces its size and what is left', (
      tester,
    ) async {
      final game = await pumpBoard(tester, variant: Variant.nine);
      expect(
        labels(tester).any(
          (l) =>
              l.contains('Sudoku board, 9 by 9') &&
              l.contains('${game.remaining} cells remaining'),
        ),
        isTrue,
      );
    });

    testWidgets('a clue, an answer and a mistake read differently', (
      tester,
    ) async {
      final game = await pumpBoard(tester);
      // Training shows candidates by default; this test is about the digits.
      game.toggleCandidates();
      await tester.pumpAndSettle();

      final given = game.values.indexWhere((v) => v != 0);
      expect(labelFor(tester, game, given), endsWith('clue'));

      final blank = game.values.indexOf(0);
      expect(labelFor(tester, game, blank), endsWith('empty'));

      final right = game.puzzle.solution[blank];
      game
        ..select(blank)
        ..enterAnswer(right);
      await tester.pumpAndSettle();
      expect(labelFor(tester, game, blank), endsWith('$right, correct'));

      // A different blank, answered wrongly.
      final other = game.values.indexOf(0);
      final wrong = game.puzzle.solution[other] == 1 ? 2 : 1;
      game
        ..select(other)
        ..enterAnswer(wrong);
      await tester.pumpAndSettle();
      expect(labelFor(tester, game, other), endsWith('$wrong, incorrect'));
    });

    testWidgets('pencil marks and candidates are spoken', (tester) async {
      final game = await pumpBoard(tester);
      game.toggleCandidates(); // start from off, so the toggle is observable
      await tester.pumpAndSettle();
      final blank = game.values.indexOf(0);

      game
        ..select(blank)
        ..enterNote(2)
        ..enterNote(4);
      await tester.pumpAndSettle();
      expect(labelFor(tester, game, blank), contains('pencilled 2 and 4'));

      // Clearing them goes back to plain "empty".
      game.clearSelected();
      await tester.pumpAndSettle();
      expect(labelFor(tester, game, blank), endsWith('empty'));

      // Candidates are spoken only once the player asks to see them, so a
      // listener gets the same assistance as everyone else -- not more.
      game.toggleCandidates();
      await tester.pumpAndSettle();
      expect(labelFor(tester, game, blank), contains('candidates'));

      game.toggleCandidates();
      await tester.pumpAndSettle();
      expect(labelFor(tester, game, blank), endsWith('empty'));
    });

    testWidgets('a paused board is hidden from everyone equally', (
      tester,
    ) async {
      final game = await pumpBoard(tester);
      final given = game.values.indexWhere((v) => v != 0);
      expect(labelFor(tester, game, given), endsWith('clue'));

      game.setPaused(paused: true);
      await tester.pumpAndSettle();

      final label = labelFor(tester, game, given)!;
      expect(label, endsWith('hidden while paused'));
      expect(
        label,
        isNot(contains('${game.values[given]},')),
        reason: 'a paused board must not read its digits out',
      );
    });

    testWidgets('settled cells are not offered as actionable', (tester) async {
      final game = await pumpBoard(tester);
      final given = game.values.indexWhere((v) => v != 0);
      final blank = game.values.indexOf(0);

      // Every cell can be activated, because moving the selection onto a
      // clue to read it is legitimate -- the pointer does the same. What a
      // settled cell must not do is offer digits.
      for (final cell in [blank, given]) {
        expect(
          nodeForCell(
            tester,
            game,
            cell,
          )!.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
          reason: 'cell $cell should be reachable',
        );
      }

      final owner = semanticsRoot(tester).owner!;
      owner.performAction(
        nodeForCell(tester, game, given)!.id,
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();
      expect(game.selected, given, reason: 'a clue can still be inspected');
      expect(
        find.text('Answer'),
        findsNothing,
        reason: 'a settled cell must not offer digits',
      );

      owner.performAction(
        nodeForCell(tester, game, blank)!.id,
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();
      expect(find.text('Answer'), findsOneWidget);
    });

    testWidgets('activating a cell selects it and offers the digits', (
      tester,
    ) async {
      final game = await pumpBoard(tester);
      final blank = game.values.indexOf(0);

      final node = nodeForCell(tester, game, blank);
      expect(node, isNotNull);

      semanticsRoot(tester).owner!.performAction(node!.id, SemanticsAction.tap);
      await tester.pumpAndSettle();

      expect(game.selected, blank);
      // The digit menu is built from real widgets, so it is readable already.
      expect(find.text('Answer'), findsOneWidget);
    });

    testWidgets('labels follow the board as it changes size', (tester) async {
      final game = await pumpBoard(tester, variant: Variant.nine);
      expect(labelFor(tester, game, 80), isNotNull);

      game.newGame(variant: Variant.four);
      await tester.pumpAndSettle();

      expect(
        labelFor(tester, game, 15),
        isNotNull,
        reason: 'the last 4x4 cell must be described',
      );
      expect(
        labels(tester).any((l) => l.startsWith('row 9,')),
        isFalse,
        reason: 'cells the smaller board does not have must be gone',
      );
    });
  });

  group('surrounding controls', () {
    testWidgets('the board view exposes a container, not a bare canvas', (
      tester,
    ) async {
      await pumpBoard(tester);
      expect(find.byType(BoardView), findsOneWidget);
      expect(labels(tester).any((l) => l.startsWith('Sudoku board')), isTrue);
    });
  });
}
