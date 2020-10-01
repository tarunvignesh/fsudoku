import 'dart:io';

void printBoard(var arr) {
  int i = 0;
  arr.forEach((x) {
    print(x);
    i++;
    if (i % 9 == 0) print("\n");
  });
}

List<String> crossprod(List<String> a, List<String> b) {
  return a
      .map((e) => b.map((i) => (e + i).toString()).toList())
      .toList()
      .expand((e) => e)
      .toList();
}

main() {
  List<String> rows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
  List<String> cols = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];

  var squares = crossprod(rows, cols);
  // print(squares);
  printBoard(squares);

// var f=  z.expand((i) => i).toList();
  var unitlist = cols.map((final String c) => crossprod(rows, [c])).toList() +
      rows.map((final String r) => crossprod([r], cols)).toList() +
      ['ABC', 'DEF', 'GHI']
          .map((final String rs) => ['123', '456', '789']
              .map((final String cs) => crossprod(rs.split(''), cs.split(''))))
          .expand((var l) => l)
          .toList();

  var unitsDict =
      // squares.map((elem) => unitlist.where((e) => e.contains(elem)).toList() ).toList();

      {
    for (var elem in squares)
      elem: unitlist.where((e) => e.contains(elem)).toList()
  };

  // print(unitsDict);

//   var peers = unitsDict.map((k,v ) => k : v.expand(( e) =>  e ).toSet().remove(k));

  var peers = {
    for (var elem in squares)
      elem: unitsDict[elem].expand((e) => e).toSet()..remove(elem)
  };

//   var peers =
//      unitsDict.map((k,v) =>  (k:v.expand(( e) => e).toSet()..remove(k)));

  var c2 = peers['C2'];
  var r = [
    'A2',
    'B2',
    'D2',
    'E2',
    'F2',
    'G2',
    'H2',
    'I2',
    'C1',
    'C3',
    'C4',
    'C5',
    'C6',
    'C7',
    'C8',
    'C9',
    'A1',
    'A3',
    'B1',
    'B3'
  ].toSet();

  assert(c2.containsAll(r) && r.containsAll(c2));

  print(c2);

  if (c2.containsAll(r) && r.containsAll(c2))
    print("YAYY");
  else
    print("AGGGGH");

  List<String> digits = cols;

  Map<String, String> grid_values(final List<String> grid) {
    List<String> chars = grid
        .map((c) => digits.contains(c) || ['.', '0'].contains(c)
            ? c
            : throw ('Bad input'))
        .toList();
    if (chars.length != cols.length * rows.length) throw 'Bad grid input';
    int idx = 0;
    Map<String, String> m = {for (var elem in squares) elem: chars[idx++]};

    return m;
  }

  void displayPuzzle(final List<String> values) {
    int rowCtr = 0;
    int blockCtr = 0;
    final int width = rows.length;
    final int height = cols.length;
    values.forEach((c) {
      stdout.write(c);
      if (blockCtr++ == width / 3) {
        stdout.write('|');
        blockCtr = 0;
      }
      if (rowCtr++ == width) {
        stdout.write('\n');
        rowCtr = 0;
      }
    });
  }

//   def display(values):
//     "Display these values as a 2-D grid."
//     width = 1+max(len(values[s]) for s in squares)
//     line = '+'.join(['-'*(width*3)]*3)
//     for r in rows:
//         print ''.join(values[r+c].center(width)+('|' if c in '36' else '')
//                       for c in cols)
//         if r in 'CF': print line
//     print

  var gr =
      '4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......'
          .split('');
  print(gr);
  print(grid_values(gr));
  displayPuzzle(gr);

//   def grid_values(grid):
//     "Convert grid into a dict of {square: char} with '0' or '.' for empties."
//     chars = [c for c in grid if c in digits or c in '0.']
//     assert len(chars) == 81
//     return dict(zip(squares, chars))

//   def parse_grid(grid):
//     """Convert grid to a dict of possible values, {square: digits}, or
//     return False if a contradiction is detected."""
//     ## To start, every square can be any digit; then assign values from the grid.
//     values = dict((s, digits) for s in squares)
//     for s,d in grid_values(grid).items():
//         if d in digits and not assign(values, s, d):
//             return False ## (Fail if we can't assign d to square s.)
//     return values

//     rows.map((final String rs)=> cols.map((final String cs)  => crossprod([rs],[cs])).toList()).toList();

  // print(unitlist);
}
