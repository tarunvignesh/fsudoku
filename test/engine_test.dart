import 'dart:math';

import 'package:fsudoku/engine/generator.dart';
import 'package:fsudoku/engine/hint.dart';
import 'package:fsudoku/engine/puzzle.dart';
import 'package:fsudoku/engine/solver.dart';
import 'package:fsudoku/engine/variant.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parses a puzzle string, treating `.`, `-` and `0` as empty.
List<int> parse(String s, Variant v) {
  final chars = s.replaceAll(RegExp(r'\s'), '').split('');
  expect(chars.length, v.cellCount);
  return [
    for (final c in chars)
      if (c == '.' || c == '-' || c == '0') 0 else int.parse(c),
  ];
}

/// Checks a filled board against the rules directly, without the solver.
void expectValidSolution(List<int> cells, Variant v) {
  final g = Geometry.of(v);
  for (var i = 0; i < v.cellCount; i++) {
    expect(cells[i], inInclusiveRange(1, v.size), reason: 'cell $i');
    for (final p in g.peers[i]) {
      expect(cells[p] == cells[i], isFalse, reason: 'cell $i clashes with $p');
    }
  }
}

void main() {
  group('Geometry', () {
    test('boxes partition the board for every variant', () {
      for (final v in Variant.values) {
        final g = Geometry.of(v);
        final byBox = <int, List<int>>{};
        for (var i = 0; i < v.cellCount; i++) {
          byBox.putIfAbsent(g.boxOf[i], () => []).add(i);
        }
        expect(byBox.length, v.size, reason: '${v.label} box count');
        for (final cells in byBox.values) {
          expect(cells.length, v.size, reason: '${v.label} box size');
        }
      }
    });

    test('peer counts are uniform and correct', () {
      expect(_peerCounts(Variant.four), {7});
      expect(_peerCounts(Variant.six), {12});
      expect(_peerCounts(Variant.nine), {20});
    });

    test('a cell is never its own peer', () {
      for (final v in Variant.values) {
        final g = Geometry.of(v);
        for (var i = 0; i < v.cellCount; i++) {
          expect(g.peers[i], isNot(contains(i)));
        }
      }
    });

    test('peering is symmetric', () {
      for (final v in Variant.values) {
        final g = Geometry.of(v);
        for (var i = 0; i < v.cellCount; i++) {
          for (final p in g.peers[i]) {
            expect(g.peers[p], contains(i), reason: '$i <-> $p in ${v.label}');
          }
        }
      }
    });

    test('instances are cached per variant', () {
      expect(Geometry.of(Variant.nine), same(Geometry.of(Variant.nine)));
    });
  });

  group('bitmask helpers', () {
    test('popcount counts set bits', () {
      expect(popcount(0), 0);
      expect(popcount(0x1FF), 9);
      expect(popcount(digitBit(4)), 1);
    });

    test('soleDigit inverts digitBit', () {
      for (var d = 1; d <= 9; d++) {
        expect(soleDigit(digitBit(d)), d);
      }
    });

    test('digitsOf lists digits ascending', () {
      final mask = digitBit(2) | digitBit(7) | digitBit(9);
      expect(digitsOf(mask), [2, 7, 9]);
    });
  });

  group('Solver', () {
    test('solves the 6x6 board the old app shipped with', () {
      const grid = '21--43--------62----34--------34--56';
      final solver = Solver(Variant.six);
      final solved = solver.solve(parse(grid, Variant.six));
      expect(solved, isNotNull);
      expectValidSolution(solved!, Variant.six);
    });

    test('solves a 9x9 with 17 givens, the known minimum', () {
      const grid =
          '000000010400000000020000000000050407008000300'
          '001090000300400200050100000000806000';
      final solver = Solver(Variant.nine);
      final solved = solver.solve(parse(grid, Variant.nine));
      expect(solved, isNotNull);
      expectValidSolution(solved!, Variant.nine);
      expect(solver.countSolutions(parse(grid, Variant.nine)), 1);
    });

    test('givens are preserved in the solution', () {
      const grid =
          '003020600900305001001806400008102900700000008'
          '006708200002609500800203009005010300';
      final givens = parse(grid, Variant.nine);
      final solved = Solver(Variant.nine).solve(givens)!;
      for (var i = 0; i < givens.length; i++) {
        if (givens[i] != 0) expect(solved[i], givens[i]);
      }
    });

    test('rejects givens that already contradict', () {
      // Two 5s in the top row.
      final givens = List<int>.filled(81, 0);
      givens[0] = 5;
      givens[1] = 5;
      expect(Solver(Variant.nine).propagate(givens), isNull);
      expect(Solver(Variant.nine).solve(givens), isNull);
      expect(Solver(Variant.nine).countSolutions(givens), 0);
    });

    test('countSolutions stops at the limit', () {
      final empty = List<int>.filled(16, 0);
      expect(Solver(Variant.four).countSolutions(empty, limit: 2), 2);
      expect(Solver(Variant.four).countSolutions(empty, limit: 5), 5);
    });

    test('an empty board has many solutions but still solves', () {
      for (final v in Variant.values) {
        final solver = Solver(v);
        final solved = solver.solve(List<int>.filled(v.cellCount, 0));
        expect(solved, isNotNull, reason: v.label);
        expectValidSolution(solved!, v);
      }
    });

    test('seeded random search is reproducible', () {
      final a = Solver(Variant.nine)
          .solve(List<int>.filled(81, 0), random: Random(42));
      final b = Solver(Variant.nine)
          .solve(List<int>.filled(81, 0), random: Random(42));
      expect(a, b);
    });
  });

  group('Generator', () {
    test('every generated puzzle has exactly one solution', () {
      for (final v in Variant.values) {
        final solver = Solver(v);
        for (final d in Difficulty.values) {
          final gen = Generator(v, random: Random(3));
          for (var i = 0; i < 6; i++) {
            final p = gen.generate(d);
            expect(
              solver.countSolutions(p.givens, limit: 2),
              1,
              reason: '${v.label} ${d.label}',
            );
          }
        }
      }
    });

    test('stored solution is valid and matches the givens', () {
      for (final v in Variant.values) {
        final gen = Generator(v, random: Random(5));
        final p = gen.generate(Difficulty.steady);
        expectValidSolution(p.solution, v);
        for (var i = 0; i < v.cellCount; i++) {
          if (p.givens[i] != 0) expect(p.givens[i], p.solution[i]);
        }
        expect(Solver(v).solve(p.givens), p.solution);
      }
    });

    test('logic-only tiers really are solvable without guessing', () {
      for (final v in Variant.values) {
        final gen = Generator(v, random: Random(9));
        for (final d in [Difficulty.gentle, Difficulty.steady]) {
          final p = gen.generate(d);
          expect(
            p.solvableByLogicAlone,
            isTrue,
            reason: '${v.label} ${d.label}',
          );
        }
      }
    });

    test('harder tiers reveal fewer cells', () {
      final gen = Generator(Variant.nine, random: Random(13));
      final gentle = gen.generate(Difficulty.gentle).givenCount;
      final tricky = gen.generate(Difficulty.tricky).givenCount;
      expect(tricky, lessThan(gentle));
    });

    test('puzzles are immutable', () {
      final p = Generator(
        Variant.four,
        random: Random(1),
      ).generate(Difficulty.gentle);
      expect(() => p.givens[0] = 9, throwsUnsupportedError);
      expect(() => p.solution[0] = 9, throwsUnsupportedError);
    });

    test('givenCount and blankCount agree with the board', () {
      final p = Generator(
        Variant.six,
        random: Random(2),
      ).generate(Difficulty.steady);
      expect(p.givenCount + p.blankCount, Variant.six.cellCount);
    });
  });

  group('BoardAnalysis', () {
    test('candidates exclude digits already placed by peers', () {
      final values = List<int>.filled(81, 0);
      values[1] = 5; // same row as cell 0
      values[9] = 7; // same column as cell 0
      final a = BoardAnalysis(Variant.nine, values);
      expect(a.candidateDigits(0), isNot(contains(5)));
      expect(a.candidateDigits(0), isNot(contains(7)));
      expect(a.candidateDigits(0), contains(1));
    });

    test('filled cells have no candidates', () {
      final values = List<int>.filled(16, 0);
      values[0] = 3;
      expect(BoardAnalysis(Variant.four, values).candidateDigits(0), isEmpty);
    });

    test('detects a duplicate and names both cells', () {
      final values = List<int>.filled(81, 0);
      values[0] = 4;
      values[8] = 4; // same row
      final conflicts = BoardAnalysis(Variant.nine, values).conflicts();
      expect(conflicts.map((c) => c.cell), containsAll([0, 8]));
      expect(conflicts.first.unit, UnitKind.row);
      expect(conflicts.first.digit, 4);
    });

    test('a clean board reports no conflicts', () {
      final p = Generator(
        Variant.nine,
        random: Random(4),
      ).generate(Difficulty.gentle);
      expect(BoardAnalysis(Variant.nine, p.givens).conflicts(), isEmpty);
      expect(BoardAnalysis(Variant.nine, p.solution).conflicts(), isEmpty);
    });

    test('isSolved only accepts a full, correct board', () {
      final p = Generator(
        Variant.six,
        random: Random(6),
      ).generate(Difficulty.gentle);
      expect(BoardAnalysis(Variant.six, p.givens).isSolved, isFalse);
      expect(BoardAnalysis(Variant.six, p.solution).isSolved, isTrue);
    });

    test('starvedCells finds a blank with nothing left to put in it', () {
      // Fill row 0 and column 0 around cell 0 with 1..8 plus a 9 in its box,
      // leaving cell 0 with no legal digit.
      final values = List<int>.filled(81, 0);
      for (var c = 1; c <= 8; c++) {
        values[c] = c; // row 0 gets 1..8
      }
      values[9 * 1 + 1] = 9; // a 9 inside cell 0's box
      final starved = BoardAnalysis(Variant.nine, values).starvedCells();
      expect(starved, contains(0));
    });
  });

  group('Hints', () {
    test('a hint never contradicts the unique solution', () {
      for (final v in Variant.values) {
        final gen = Generator(v, random: Random(21));
        for (var t = 0; t < 8; t++) {
          final p = gen.generate(Difficulty.gentle);
          final board = List<int>.of(p.givens);
          var guard = 0;
          while (board.contains(0) && guard++ <= v.cellCount) {
            final hint = BoardAnalysis(v, board).nextHint();
            if (hint == null) break;
            expect(
              hint.digit,
              p.solution[hint.cell],
              reason: '${v.label} cell ${hint.cell}',
            );
            expect(board[hint.cell], 0, reason: 'hint on a filled cell');
            board[hint.cell] = hint.digit;
          }
        }
      }
    });

    test('hints alone finish any logic-solvable board', () {
      for (final v in Variant.values) {
        final gen = Generator(v, random: Random(31));
        for (var t = 0; t < 5; t++) {
          final p = gen.generate(Difficulty.steady);
          final board = List<int>.of(p.givens);
          var guard = 0;
          while (board.contains(0) && guard++ <= v.cellCount) {
            final hint = BoardAnalysis(v, board).nextHint();
            expect(hint, isNotNull, reason: '${v.label} stalled');
            board[hint!.cell] = hint.digit;
          }
          expect(board, p.solution, reason: v.label);
        }
      }
    });

    test('a naked single is found and explained', () {
      // Cell 0 is the only blank in its row, column and box region.
      final solution = Solver(Variant.four).solve(List<int>.filled(16, 0))!;
      final board = List<int>.of(solution)..[0] = 0;
      final hint = BoardAnalysis(Variant.four, board).nextHint();
      expect(hint, isNotNull);
      expect(hint!.cell, 0);
      expect(hint.digit, solution[0]);
      expect(hint.technique, Technique.nakedSingle);
      expect(hint.explanation, contains('row 1, column 1'));
    });

    test('a solved board yields no hint', () {
      final p = Generator(
        Variant.four,
        random: Random(8),
      ).generate(Difficulty.gentle);
      expect(BoardAnalysis(Variant.four, p.solution).nextHint(), isNull);
    });

    test('hint evidence only cites real cells', () {
      final p = Generator(
        Variant.nine,
        random: Random(17),
      ).generate(Difficulty.gentle);
      final hint = BoardAnalysis(Variant.nine, p.givens).nextHint()!;
      for (final c in hint.because) {
        expect(c, inInclusiveRange(0, 80));
        expect(c, isNot(hint.cell));
      }
    });
  });
}

Set<int> _peerCounts(Variant v) {
  final g = Geometry.of(v);
  return {for (var i = 0; i < v.cellCount; i++) g.peers[i].length};
}
