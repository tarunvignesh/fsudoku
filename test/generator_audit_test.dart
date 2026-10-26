/// Cross-checks the generator against an independent implementation.
///
/// `engine_test.dart` verifies the generator using the same [Solver] the
/// generator itself uses, which shows the two agree but not that either is
/// right. Everything here counts solutions by plain backtracking, deriving
/// row/column/box membership from arithmetic rather than from [Geometry], so a
/// shared bug cannot hide behind a shared assumption.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsudoku/engine/generator.dart';
import 'package:fsudoku/engine/hint.dart';
import 'package:fsudoku/engine/puzzle.dart';
import 'package:fsudoku/engine/solver.dart';
import 'package:fsudoku/engine/variant.dart';

int _boxRows(int n) => n == 9 ? 3 : 2;
int _boxCols(int n) => n == 4 ? 2 : 3;

/// Whether [d] may go in cell [i] of [board], checked straight from the rules.
bool _legal(List<int> board, int n, int i, int d) {
  final r = i ~/ n;
  final c = i % n;
  for (var k = 0; k < n; k++) {
    if (board[r * n + k] == d) return false;
    if (board[k * n + c] == d) return false;
  }
  final br = (r ~/ _boxRows(n)) * _boxRows(n);
  final bc = (c ~/ _boxCols(n)) * _boxCols(n);
  for (var rr = br; rr < br + _boxRows(n); rr++) {
    for (var cc = bc; cc < bc + _boxCols(n); cc++) {
      if (board[rr * n + cc] == d) return false;
    }
  }
  return true;
}

/// Naive backtracking solution count, stopping once [limit] are found.
int bruteCount(List<int> board, int n, int limit) {
  final first = board.indexOf(0);
  if (first == -1) return 1;

  var found = 0;
  for (var d = 1; d <= n; d++) {
    if (!_legal(board, n, first, d)) continue;
    board[first] = d;
    found += bruteCount(board, n, limit - found);
    board[first] = 0;
    if (found >= limit) break;
  }
  return found;
}

/// Checks a filled board against the rules without using the engine.
bool validComplete(List<int> cells, int n) {
  for (var i = 0; i < cells.length; i++) {
    final d = cells[i];
    if (d < 1 || d > n) return false;
    cells[i] = 0;
    final ok = _legal(cells, n, i, d);
    cells[i] = d;
    if (!ok) return false;
  }
  return true;
}

void main() {
  // Kept modest so CI stays quick; a wider sweep lives in tool/.
  const trials = {Variant.four: 12, Variant.six: 8, Variant.nine: 3};

  group('generator cross-check', () {
    test('brute force agrees that every puzzle has one solution', () {
      for (final v in Variant.values) {
        final engine = Solver(v);
        for (final d in Difficulty.values) {
          final gen = Generator(v, random: Random(99));
          for (var t = 0; t < trials[v]!; t++) {
            final p = gen.generate(d);
            final byEngine = engine.countSolutions(p.givens, limit: 2);
            final byBrute = bruteCount(List<int>.of(p.givens), v.size, 2);
            expect(
              byBrute,
              1,
              reason: '${v.label} ${d.label}: brute force found $byBrute',
            );
            expect(byEngine, byBrute, reason: '${v.label} ${d.label}');
          }
        }
      }
    });

    test('solutions are valid and consistent with the givens', () {
      for (final v in Variant.values) {
        for (final d in Difficulty.values) {
          final gen = Generator(v, random: Random(7));
          for (var t = 0; t < trials[v]!; t++) {
            final p = gen.generate(d);
            expect(
              validComplete(List<int>.of(p.solution), v.size),
              isTrue,
              reason: '${v.label} ${d.label} solution breaks a rule',
            );
            for (var i = 0; i < v.cellCount; i++) {
              if (p.givens[i] != 0) {
                expect(p.givens[i], p.solution[i], reason: 'cell $i');
              }
            }
          }
        }
      }
    });

    test('the logic-only claim holds under the separate hint path', () {
      // BoardAnalysis derives candidates by peer elimination, not by the
      // propagation isSolvableByLogicAlone uses, so this is a second opinion.
      for (final v in Variant.values) {
        final gen = Generator(v, random: Random(31));
        for (var t = 0; t < trials[v]!; t++) {
          final p = gen.generate(Difficulty.steady);
          if (!p.solvableByLogicAlone) continue;

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

    test('successive puzzles differ', () {
      // A generator that lost its randomness would still pass every
      // correctness check above while being useless.
      for (final v in Variant.values) {
        final gen = Generator(v, random: Random(5));
        final seen = <String>{};
        for (var t = 0; t < trials[v]!; t++) {
          seen.add(gen.generate(Difficulty.gentle).givens.join(','));
        }
        expect(seen.length, trials[v], reason: '${v.label} repeated a puzzle');
      }
    });

    test('the same seed reproduces the same puzzle', () {
      for (final v in Variant.values) {
        final a = Generator(
          v,
          random: Random(1234),
        ).generate(Difficulty.steady);
        final b = Generator(
          v,
          random: Random(1234),
        ).generate(Difficulty.steady);
        expect(a.givens, b.givens, reason: v.label);
        expect(a.solution, b.solution, reason: v.label);
      }
    });

    test('generation always terminates', () {
      // The original generatePuzzle() recursed on failure with no bound and
      // could spin; this one digs a bounded list and returns.
      for (final v in Variant.values) {
        for (final d in Difficulty.values) {
          final gen = Generator(v, random: Random(2026));
          for (var t = 0; t < 3; t++) {
            expect(
              () => gen.generate(d),
              returnsNormally,
              reason: '${v.label} ${d.label}',
            );
          }
        }
      }
    });
  });
}
