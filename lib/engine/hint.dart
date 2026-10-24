/// Candidate analysis, conflict detection and explained hints.
///
/// This is the teaching layer. Everything here works from what the player can
/// actually see on the board, using plain peer elimination rather than the full
/// constraint propagation in [Solver]. That distinction matters: propagation
/// chains deductions many steps ahead, so a hint derived from it would point at
/// a cell the player has no way to reason about yet.
library;

import 'solver.dart';
import 'variant.dart';

/// A deduction technique, in the order a learner meets them.
enum Technique {
  /// The cell has only one digit left that its peers permit.
  nakedSingle('Last remaining digit'),

  /// Within one unit, only this cell can still hold the digit.
  hiddenSingle('Only place in unit');

  const Technique(this.label);

  /// Short human-readable name.
  final String label;
}

/// Which kind of unit a deduction was made in.
enum UnitKind {
  row('row'),
  column('column'),
  box('box');

  const UnitKind(this.noun);

  /// The word to use when explaining a deduction about this unit.
  final String noun;
}

/// A single next move, with the reasoning behind it.
class Hint {
  /// Creates a hint. Produced by [BoardAnalysis.nextHint].
  const Hint({
    required this.cell,
    required this.digit,
    required this.technique,
    required this.because,
    required this.explanation,
    this.unit,
  });

  /// The cell this hint resolves.
  final int cell;

  /// The digit that belongs there.
  final int digit;

  /// How the deduction was made.
  final Technique technique;

  /// The unit the deduction was made in, for [Technique.hiddenSingle].
  final UnitKind? unit;

  /// Cells to highlight as the evidence for this hint.
  final List<int> because;

  /// One sentence a learner can follow.
  final String explanation;
}

/// A cell holding a digit that conflicts with one of its peers.
class Conflict {
  /// Creates a conflict record.
  const Conflict({
    required this.cell,
    required this.digit,
    required this.collidesWith,
    required this.unit,
  });

  /// The offending cell.
  final int cell;

  /// The duplicated digit.
  final int digit;

  /// Peers of [cell] already holding [digit].
  final List<int> collidesWith;

  /// The unit the duplication occurs in.
  final UnitKind unit;

  /// One sentence naming the clash.
  String describe(Geometry geometry) =>
      '$digit already appears in this ${unit.noun}.';
}

/// Derived facts about a board position: candidates, conflicts and hints.
///
/// Construct one per analysis; it is a cheap snapshot, not long-lived state.
class BoardAnalysis {
  /// Analyses [values], which holds one digit per cell with 0 for empty.
  BoardAnalysis(this.variant, List<int> values)
    : geometry = Geometry.of(variant),
      _values = values {
    assert(values.length == variant.cellCount, 'wrong cell count');
    _candidates = _computeCandidates();
  }

  final Variant variant;
  final Geometry geometry;
  final List<int> _values;
  late final List<int> _candidates;

  int get size => variant.size;

  /// Candidate bitmask for each cell, by simple peer elimination.
  ///
  /// Filled cells get a mask of 0; this describes what *could* go in the blanks.
  List<int> get candidates => _candidates;

  /// Digits still permitted in [cell], ascending. Empty for a filled cell.
  List<int> candidateDigits(int cell) => digitsOf(_candidates[cell]);

  List<int> _computeCandidates() {
    final result = List<int>.filled(variant.cellCount, 0);
    for (var i = 0; i < variant.cellCount; i++) {
      if (_values[i] != 0) continue;
      var mask = variant.allDigits;
      for (final peer in geometry.peers[i]) {
        final v = _values[peer];
        if (v != 0) mask &= ~digitBit(v);
      }
      result[i] = mask;
    }
    return result;
  }

  /// Which unit of [cell] contains [other].
  UnitKind _sharedUnit(int cell, int other) {
    if (geometry.rowOf[cell] == geometry.rowOf[other]) return UnitKind.row;
    if (geometry.colOf[cell] == geometry.colOf[other]) return UnitKind.column;
    return UnitKind.box;
  }

  /// Every filled cell that duplicates a digit within one of its units.
  ///
  /// Both cells of a clash are reported, so the UI can mark the pair.
  List<Conflict> conflicts() {
    final out = <Conflict>[];
    for (var i = 0; i < variant.cellCount; i++) {
      final d = _values[i];
      if (d == 0) continue;
      final clashes = <int>[];
      for (final peer in geometry.peers[i]) {
        if (_values[peer] == d) clashes.add(peer);
      }
      if (clashes.isNotEmpty) {
        out.add(
          Conflict(
            cell: i,
            digit: d,
            collidesWith: clashes,
            unit: _sharedUnit(i, clashes.first),
          ),
        );
      }
    }
    return out;
  }

  /// Blank cells with no candidate left, i.e. positions already made unsolvable.
  ///
  /// A board can be conflict-free and still dead, which is worth telling the
  /// player before they spend ten more minutes on it.
  List<int> starvedCells() {
    final out = <int>[];
    for (var i = 0; i < variant.cellCount; i++) {
      if (_values[i] == 0 && _candidates[i] == 0) out.add(i);
    }
    return out;
  }

  /// True when every cell is filled and nothing conflicts.
  bool get isSolved => !_values.contains(0) && conflicts().isEmpty;

  /// Human-readable coordinates, one-based, as a learner would say them.
  String describeCell(int cell) =>
      'row ${geometry.rowOf[cell] + 1}, column ${geometry.colOf[cell] + 1}';

  /// The next move that follows by deduction, or null if none does.
  ///
  /// Prefers [Technique.nakedSingle] because it is the easier pattern to see,
  /// then falls back to [Technique.hiddenSingle].
  Hint? nextHint() => _nakedSingle() ?? _hiddenSingle();

  Hint? _nakedSingle() {
    for (var i = 0; i < variant.cellCount; i++) {
      if (_values[i] != 0 || popcount(_candidates[i]) != 1) continue;
      final digit = soleDigit(_candidates[i]);

      // Evidence: the filled peers that ruled out everything else.
      final because = [
        for (final p in geometry.peers[i])
          if (_values[p] != 0) p,
      ];

      return Hint(
        cell: i,
        digit: digit,
        technique: Technique.nakedSingle,
        because: because,
        explanation:
            'Every other digit already appears in this cell\'s row, '
            'column or box, so ${describeCell(i)} can only be $digit.',
      );
    }
    return null;
  }

  Hint? _hiddenSingle() {
    for (var unitIndex = 0; unitIndex < variant.size; unitIndex++) {
      for (final kind in UnitKind.values) {
        final unit = _unitCells(kind, unitIndex);
        for (var digit = 1; digit <= size; digit++) {
          final bit = digitBit(digit);

          // Skip digits already placed in this unit.
          if (unit.any((c) => _values[c] == digit)) continue;

          int? only;
          var places = 0;
          for (final c in unit) {
            if (_values[c] == 0 && _candidates[c] & bit != 0) {
              only = c;
              if (++places > 1) break;
            }
          }
          if (places != 1) continue;

          // Evidence: the rest of the unit, which is where it cannot go.
          final because = [
            for (final c in unit)
              if (c != only) c,
          ];

          return Hint(
            cell: only!,
            digit: digit,
            technique: Technique.hiddenSingle,
            unit: kind,
            because: because,
            explanation:
                'In this ${kind.noun}, $digit fits nowhere except '
                '${describeCell(only)}.',
          );
        }
      }
    }
    return null;
  }

  List<int> _unitCells(UnitKind kind, int index) {
    final cells = <int>[];
    for (var i = 0; i < variant.cellCount; i++) {
      final match = switch (kind) {
        UnitKind.row => geometry.rowOf[i] == index,
        UnitKind.column => geometry.colOf[i] == index,
        UnitKind.box => geometry.boxOf[i] == index,
      };
      if (match) cells.add(i);
    }
    return cells;
  }
}
