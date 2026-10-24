/// Constraint-propagation Sudoku solver.
///
/// The algorithm is Peter Norvig's: propagate two rules to fixpoint after every
/// assignment, then depth-first search the most-constrained cell first.
///
///   1. If a cell has one candidate left, eliminate it from the cell's peers.
///   2. If a unit has only one place left for a digit, assign it there.
///
/// Candidates are held as bitmasks (bit `d - 1` set means digit `d` is still
/// possible), so a cell is a single int and propagation is bit arithmetic.
/// All masks are at most 9 bits wide, which stays inside the 32-bit range that
/// bitwise operators guarantee on every Dart backend including dart2js.
library;

import 'dart:math';

import 'variant.dart';

/// Bit for [digit], which is one-based.
int digitBit(int digit) => 1 << (digit - 1);

/// Number of set bits in [mask]. [mask] must be at most 9 bits wide.
int popcount(int mask) {
  var m = mask;
  var n = 0;
  while (m != 0) {
    m &= m - 1;
    n++;
  }
  return n;
}

/// The single digit encoded by a one-bit [mask]; undefined for other masks.
int soleDigit(int mask) {
  var d = 1;
  var m = mask;
  while (m > 1) {
    m >>= 1;
    d++;
  }
  return d;
}

/// Every digit present in [mask], ascending.
List<int> digitsOf(int mask) {
  final out = <int>[];
  for (var d = 1; mask >> (d - 1) != 0; d++) {
    if (mask & digitBit(d) != 0) out.add(d);
  }
  return out;
}

/// Solves and analyses boards of one [Variant].
///
/// Stateless and cheap to construct; holds only the shared [Geometry].
class Solver {
  Solver(this.variant) : geometry = Geometry.of(variant);

  final Variant variant;
  final Geometry geometry;

  int get size => variant.size;
  int get cellCount => variant.cellCount;

  /// A fresh candidate list with every digit possible in every cell.
  List<int> emptyCandidates() => List<int>.filled(cellCount, variant.allDigits);

  /// Builds a propagated candidate list from [givens], or null if the givens
  /// already contradict each other.
  ///
  /// [givens] holds one entry per cell: a digit, or 0 for empty.
  List<int>? propagate(List<int> givens) {
    assert(givens.length == cellCount, 'expected $cellCount cells');
    final candidates = emptyCandidates();
    for (var i = 0; i < cellCount; i++) {
      final d = givens[i];
      if (d != 0 && !assign(candidates, i, d)) return null;
    }
    return candidates;
  }

  /// Assigns [digit] to [cell] by eliminating every other candidate from it.
  ///
  /// Mutates [candidates]. Returns false on contradiction, after which
  /// [candidates] is garbage and the caller must discard it.
  bool assign(List<int> candidates, int cell, int digit) {
    final others = candidates[cell] & ~digitBit(digit);
    for (final d in digitsOf(others)) {
      if (!eliminate(candidates, cell, d)) return false;
    }
    return true;
  }

  /// Removes [digit] from [cell] and propagates the consequences.
  ///
  /// Mutates [candidates]. Returns false on contradiction.
  bool eliminate(List<int> candidates, int cell, int digit) {
    final bit = digitBit(digit);
    if (candidates[cell] & bit == 0) return true; // already eliminated

    final remaining = candidates[cell] & ~bit;
    candidates[cell] = remaining;

    if (remaining == 0) return false; // cell has no candidates left

    // Rule 1: a settled cell forbids its digit everywhere it can see.
    if (popcount(remaining) == 1) {
      final settled = soleDigit(remaining);
      for (final peer in geometry.peers[cell]) {
        if (!eliminate(candidates, peer, settled)) return false;
      }
    }

    // Rule 2: if a unit has one place left for [digit], that is where it goes.
    for (final unit in geometry.units[cell]) {
      int? only;
      var places = 0;
      for (final c in unit) {
        if (candidates[c] & bit != 0) {
          only = c;
          if (++places > 1) break;
        }
      }
      if (places == 0) return false; // digit has nowhere to go in this unit
      if (places == 1 && !assign(candidates, only!, digit)) return false;
    }

    return true;
  }

  /// True when every cell of [candidates] is down to a single digit.
  bool isComplete(List<int> candidates) {
    for (final mask in candidates) {
      if (popcount(mask) != 1) return false;
    }
    return true;
  }

  /// True when propagation alone finishes [givens], with no search needed.
  ///
  /// Propagation applies exactly the naked-single and hidden-single techniques,
  /// so this is also the test for "a human can solve this without guessing".
  bool isSolvableByLogicAlone(List<int> givens) {
    final propagated = propagate(givens);
    return propagated != null && isComplete(propagated);
  }

  /// Solves [givens], returning one digit per cell, or null if unsolvable.
  ///
  /// Pass [random] to explore candidates in random order, which turns this into
  /// a generator of random complete boards when [givens] is empty.
  List<int>? solve(List<int> givens, {Random? random}) {
    final propagated = propagate(givens);
    if (propagated == null) return null;
    final solved = _search(propagated, random);
    return solved == null ? null : [for (final m in solved) soleDigit(m)];
  }

  List<int>? _search(List<int> candidates, [Random? random]) {
    var best = -1;
    var bestCount = size + 1;
    for (var i = 0; i < cellCount; i++) {
      final n = popcount(candidates[i]);
      if (n > 1 && n < bestCount) {
        bestCount = n;
        best = i;
        if (n == 2) break; // can't do better than a binary choice
      }
    }
    if (best == -1) return candidates; // nothing left to branch on

    final choices = digitsOf(candidates[best]);
    if (random != null) choices.shuffle(random);

    for (final d in choices) {
      final branch = List<int>.of(candidates);
      if (assign(branch, best, d)) {
        final solved = _search(branch, random);
        if (solved != null) return solved;
      }
    }
    return null;
  }

  /// Counts solutions of [givens], stopping once [limit] have been found.
  ///
  /// Pass `limit: 2` to test uniqueness without solving the board exhaustively.
  int countSolutions(List<int> givens, {int limit = 2}) {
    final propagated = propagate(givens);
    if (propagated == null) return 0;
    return _count(propagated, limit);
  }

  int _count(List<int> candidates, int limit) {
    var best = -1;
    var bestCount = size + 1;
    for (var i = 0; i < cellCount; i++) {
      final n = popcount(candidates[i]);
      if (n > 1 && n < bestCount) {
        bestCount = n;
        best = i;
        if (n == 2) break;
      }
    }
    if (best == -1) return 1;

    var found = 0;
    for (final d in digitsOf(candidates[best])) {
      final branch = List<int>.of(candidates);
      if (assign(branch, best, d)) {
        found += _count(branch, limit - found);
        if (found >= limit) return found;
      }
    }
    return found;
  }
}
