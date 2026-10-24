/// Puzzle model and difficulty tiers.
library;

import 'variant.dart';

/// How hard a generated puzzle should be.
///
/// Difficulty is expressed as how much of the board is revealed *and* whether
/// pure logic suffices, because for a learner those are the two things that
/// actually change the experience. [gentle] and [steady] are always solvable by
/// deduction alone; [tricky] may require trial and error.
enum Difficulty {
  /// Roughly half the board revealed, always solvable by deduction alone.
  gentle(label: 'Gentle', givensFraction: 0.50, logicOnly: true),

  /// Fewer givens, still solvable by deduction alone.
  steady(label: 'Steady', givensFraction: 0.38, logicOnly: true),

  /// Dug as deep as uniqueness allows; may need trial and error.
  tricky(label: 'Tricky', givensFraction: 0.26, logicOnly: false);

  const Difficulty({
    required this.label,
    required this.givensFraction,
    required this.logicOnly,
  });

  /// Short human-readable name.
  final String label;

  /// Target share of cells left filled in.
  final double givensFraction;

  /// Whether every dig must keep the board solvable without guessing.
  final bool logicOnly;

  /// Target number of revealed cells for [variant].
  ///
  /// Floored at the size of one unit, below which boards stop being pleasant
  /// regardless of whether they are technically unique.
  int targetGivens(Variant variant) {
    final target = (variant.cellCount * givensFraction).round();
    return target < variant.size ? variant.size : target;
  }
}

/// An immutable puzzle: the revealed cells, the unique solution it admits, and
/// what it took to get there.
class Puzzle {
  /// Creates a puzzle. Prefer [Generator] over calling this directly.
  Puzzle({
    required this.variant,
    required List<int> givens,
    required List<int> solution,
    required this.requestedDifficulty,
    required this.solvableByLogicAlone,
  }) : givens = List<int>.unmodifiable(givens),
       solution = List<int>.unmodifiable(solution);

  /// Board geometry this puzzle is posed on.
  final Variant variant;

  /// One entry per cell: the revealed digit, or 0 if the player must find it.
  final List<int> givens;

  /// One entry per cell: the digit of the unique solution.
  final List<int> solution;

  /// The tier this puzzle was generated for.
  final Difficulty requestedDifficulty;

  /// Whether the board can be finished by deduction alone, with no guessing.
  ///
  /// Measured on the generated board rather than assumed from
  /// [requestedDifficulty], so [Difficulty.tricky] boards report the truth.
  final bool solvableByLogicAlone;

  /// Number of revealed cells.
  int get givenCount => givens.where((d) => d != 0).length;

  /// Number of cells the player has to fill.
  int get blankCount => variant.cellCount - givenCount;

  /// True when [cell] was revealed from the start and cannot be edited.
  bool isGiven(int cell) => givens[cell] != 0;
}
