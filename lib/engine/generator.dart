/// Puzzle generation.
library;

import 'dart:math';

import 'puzzle.dart';
import 'solver.dart';
import 'variant.dart';

/// Generates puzzles that are guaranteed to have exactly one solution.
///
/// The approach is generate-and-dig: fill a complete random board, then remove
/// clues one at a time, keeping a removal only while the board still admits a
/// single solution. Uniqueness is checked on every dig, which is what the
/// original implementation was missing.
class Generator {
  /// Creates a generator for [variant], optionally with a seeded [random] for
  /// reproducible output in tests.
  Generator(this.variant, {Random? random})
    : _solver = Solver(variant),
      _random = random ?? Random();

  final Variant variant;
  final Solver _solver;
  final Random _random;

  /// A complete, valid, randomly chosen board.
  List<int> completeBoard() =>
      _solver.solve(List<int>.filled(variant.cellCount, 0), random: _random)!;

  /// Generates a puzzle of the requested [difficulty].
  ///
  /// The result always has exactly one solution. Its
  /// [Puzzle.solvableByLogicAlone] flag reports whether deduction alone is
  /// enough, which for [Difficulty.tricky] is discovered rather than imposed.
  Puzzle generate(Difficulty difficulty) {
    final solution = completeBoard();
    final givens = List<int>.of(solution);
    final target = difficulty.targetGivens(variant);

    // Dig in a random order so successive puzzles don't share a shape.
    final order = List<int>.generate(variant.cellCount, (i) => i)
      ..shuffle(_random);

    var revealed = variant.cellCount;
    for (final cell in order) {
      if (revealed <= target) break;

      final removed = givens[cell];
      givens[cell] = 0;

      final stillUnique = _solver.countSolutions(givens, limit: 2) == 1;
      final stillLogical =
          !difficulty.logicOnly || _solver.isSolvableByLogicAlone(givens);

      if (stillUnique && stillLogical) {
        revealed--;
      } else {
        givens[cell] = removed; // put the clue back, it was load-bearing
      }
    }

    return Puzzle(
      variant: variant,
      givens: givens,
      solution: solution,
      requestedDifficulty: difficulty,
      solvableByLogicAlone: _solver.isSolvableByLogicAlone(givens),
    );
  }
}
