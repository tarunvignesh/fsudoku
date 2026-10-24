/// Board geometry for the supported Sudoku sizes.
///
/// Everything in this library is pure Dart with no platform imports, so the
/// same engine runs unchanged on web, iOS, Android and the Dart VM (tests).
library;

/// A supported board size and its box (sub-grid) shape.
///
/// Boxes are not always square: a 6x6 board uses boxes that are 2 rows tall
/// and 3 columns wide, which is what makes 6x6 a genuine stepping stone
/// between 4x4 and 9x9 rather than a toy.
enum Variant {
  /// 4x4 with 2x2 boxes. Teaches the three constraints with almost no search.
  four(size: 4, boxRows: 2, boxCols: 2, label: '4x4'),

  /// 6x6 with 2x3 boxes. Introduces non-square box scanning.
  six(size: 6, boxRows: 2, boxCols: 3, label: '6x6'),

  /// 9x9 with 3x3 boxes. Standard Sudoku.
  nine(size: 9, boxRows: 3, boxCols: 3, label: '9x9');

  const Variant({
    required this.size,
    required this.boxRows,
    required this.boxCols,
    required this.label,
  });

  /// Cells per row, per column, per box, and the number of distinct digits.
  final int size;

  /// Box height in cells.
  final int boxRows;

  /// Box width in cells.
  final int boxCols;

  /// Short human-readable name, e.g. `9x9`.
  final String label;

  /// Total cell count.
  int get cellCount => size * size;

  /// Number of box-bands down the board.
  int get bandRows => size ~/ boxRows;

  /// Number of box-bands across the board.
  int get bandCols => size ~/ boxCols;

  /// Bitmask with one bit set per legal digit, i.e. all candidates.
  int get allDigits => (1 << size) - 1;
}

/// Precomputed index arithmetic, units and peers for one [Variant].
///
/// Built once per variant and shared; treat every exposed list as read-only.
class Geometry {
  Geometry._(
    this.variant,
    this.rowOf,
    this.colOf,
    this.boxOf,
    this.units,
    this.peers,
  );

  /// Returns the shared [Geometry] for [variant], building it on first use.
  factory Geometry.of(Variant variant) =>
      _cache.putIfAbsent(variant, () => _build(variant));

  /// Cached instances, so repeated lookups cost nothing.
  static final Map<Variant, Geometry> _cache = {};

  final Variant variant;

  /// Row index of each cell, by cell index.
  final List<int> rowOf;

  /// Column index of each cell, by cell index.
  final List<int> colOf;

  /// Box index of each cell, by cell index.
  final List<int> boxOf;

  /// The three units (row, column, box) containing each cell, by cell index.
  ///
  /// Each inner list has `variant.size` entries and includes the cell itself.
  final List<List<List<int>>> units;

  /// Every cell sharing a unit with each cell, excluding itself, by cell index.
  ///
  /// Uniform within a variant, since the box overlaps the row and column by the
  /// same amount everywhere: 7 peers on 4x4, 12 on 6x6, 20 on 9x9.
  final List<List<int>> peers;

  int get size => variant.size;
  int get cellCount => variant.cellCount;

  /// Cell index from zero-based [row] and [col].
  int indexOf(int row, int col) => row * size + col;

  static Geometry _build(Variant v) {
    final n = v.size;
    final count = v.cellCount;

    final rowOf = List<int>.filled(count, 0);
    final colOf = List<int>.filled(count, 0);
    final boxOf = List<int>.filled(count, 0);

    for (var i = 0; i < count; i++) {
      final r = i ~/ n;
      final c = i % n;
      rowOf[i] = r;
      colOf[i] = c;
      // Box index runs left-to-right, then top-to-bottom.
      boxOf[i] = (r ~/ v.boxRows) * v.bandCols + (c ~/ v.boxCols);
    }

    // Group cells into rows, columns and boxes.
    final rows = List.generate(n, (_) => <int>[], growable: false);
    final cols = List.generate(n, (_) => <int>[], growable: false);
    final boxes = List.generate(n, (_) => <int>[], growable: false);
    for (var i = 0; i < count; i++) {
      rows[rowOf[i]].add(i);
      cols[colOf[i]].add(i);
      boxes[boxOf[i]].add(i);
    }

    final units = List.generate(
      count,
      (i) => List<List<int>>.unmodifiable([
        List<int>.unmodifiable(rows[rowOf[i]]),
        List<int>.unmodifiable(cols[colOf[i]]),
        List<int>.unmodifiable(boxes[boxOf[i]]),
      ]),
      growable: false,
    );

    final peers = List.generate(count, (i) {
      final set = <int>{
        ...rows[rowOf[i]],
        ...cols[colOf[i]],
        ...boxes[boxOf[i]],
      }..remove(i);
      return List<int>.unmodifiable(set.toList()..sort());
    }, growable: false);

    return Geometry._(v, rowOf, colOf, boxOf, units, peers);
  }
}
