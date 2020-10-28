import 'dart:io';
import 'dart:math';
import 'package:logger/logger.dart';

class SCell {
  String position;
  String value;
  SCell(this.position, this.value);
  bool operator ==(o) =>
      o is SCell && this.position == o.position && this.value == o.value;
  int get hashCode => position.hashCode ^ value.hashCode;
}

class SudokuBrain {
  int _nrows = 0;

  int _ncols = 0;
  int assigns = 0;
  bool debugMode = false;
  bool _solved = false;

  bool get solved => _solved;

  set solved(bool value) {
    _solved = value;
  }

  List<String> _input;
  List<String> rows;
  List<String> cols;
  List<List<String>> blocks;
  List<SCell> movesList = List<SCell>();
  final List<String> adigits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
  final List<String> aletters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
  List<String> digits;
  Map<String, List<String>> boardDict;
  Map<String, String> puzzleBoard;
  var logger = Logger(
    printer: PrettyPrinter(),
  );
  var loggerNoStack = Logger(
    printer: PrettyPrinter(methodCount: 0),
  );
  List<List<String>> unitlist;
  Map<String, List<List<String>>> units;
  var peers;
  List<String> squares;
  SudokuBrain({int r, int c, String grid}) {
    _input = grid
        .toString()
        .replaceAll(new RegExp(r"\s+\b|\b\s|\s|\b"), "")
        .split('');

    assigns = 0;
    _nrows = r;
    _ncols = c;
    rows = aletters.sublist(0, _nrows);
    cols = adigits.sublist(0, _ncols);
    digits = cols;
    computeInit();
  }
  List<String> getInputAsList() {
    return _input;
  }

  bool makeMove(final String pos, final String val) {}
  void undo() {
    if (movesList.isEmpty) return;
    SCell l = movesList.last;
    movesList.remove(l);
    // find last value
    SCell prevE = movesList.lastWhere(
        (element) => element.position == l.position,
        orElse: () => new SCell(l.position, "."));
    puzzleBoard[prevE.position] = prevE.value;
  }

  void setValAt(final String pos, final String val) {
    SCell s = new SCell(pos, val);
    if (movesList.contains(s) == false) movesList.add(s);

    logger.i("PUZB[$pos]=$val");
    puzzleBoard[pos] = val;
  }

  bool haveUndos() {
    return movesList.isNotEmpty;
  }

  bool isInInput(final int idx, final String val) {
    var v = _input[idx];
    //  logger.i("IS INPUT OF $idx for val $val->$v");
    return cols.contains(_input[idx]) && _input[idx] == val;
  }

  String getValueAtPos(final String pos) {
    return puzzleBoard[pos];
  }

  String getValAtIndex(final int i) {
    // logger.i("GETTING VAL AT IDX $i");
    if (i >= _nrows * _ncols || i < 0)
      throw ('Bad index $i for current $_nrows X $_ncols grid');

    String pos = getPosByIndex(i);
    //  logger.i("POS IS $pos  at $puzzleBoard[pos]");
    return puzzleBoard[pos];
  }

  bool puzzleSolved() {
    bool res = _solved &
        boardDict.keys.every((k) => boardDict[k].join('') == puzzleBoard[k]);
    logger.i("PUZZLESOLVED() $res _solved is $_solved");
    return res;
  }

  String getSolutionValAtPos(final String pos) {
    return boardDict[pos].join('');
  }

  Set<String> getPeers(final String pos) {
    // logger.i("PEERS ${peers[pos]} and type is ${peers[pos].runtimeType} ");
    return peers[pos];
  }

  List<List<String>> getUnits(final String pos) {
    return units[pos];
  }

  String getPosByIndex(final int i) {
    if (i >= _nrows * _ncols || i < 0)
      throw ('Bad index $i for current $_nrows X $_ncols grid');
    return rows[(i / _nrows).floor()] + cols[i % _ncols];
  }

  bool isValidDigitOnGrid(final String v) {
    return digits.contains(v);
  }

  String getPosByXY(final int r, final int c) {
    if (r > _nrows || c > _ncols)
      throw ('Bad Coordinates to request board position $r,$c');

    return rows[r] + cols[c];
  }

  bool isCorrectAt(final String pos, final String d) {
    return boardDict[pos].length == 1 && boardDict[pos].first == d
        ? true
        : false;
  }

  int getBlockIdByIndex(final int idx) {
    String pos = getPosByIndex(idx);

    int i = 0;
    for (List<String> p in blocks) {
      if (p.contains(pos)) return i;
      i++;
    }
    return -1;
  }

  int getBlockId(final int r, final int c) {
    String pos = getPosByXY(r, c);
    // logger.i("POS IS $pos");
    int i = 0;
    for (List<String> p in blocks) {
      if (p.contains(pos)) return i;
      i++;
    }
    return -1;
  }

  List<String> getPossibleAt(final String pos) {
    return boardDict[pos];
  }

  List<String> getSolution() {
    if (isSolved()) {
      return boardDict.values.map((e) => e.join('')).toList();
    } else
      return null;
  }

  String getInputAsString() {
    return _input.toString();
  }

  int getNRows() {
    return _nrows;
  }

  int getNCols() {
    return _ncols;
  }

  int get getAssigns {
    return assigns;
  }

  void debugPrint(final String s) {
    if (debugMode) print(s);
  }

  void computeInit() {
    squares = crossprod(rows, cols);
    _solved = false;
    int rb = sqrt(_nrows).round();

    int cb = sqrt(_ncols).round();

    List<String> rBlock = new List<String>.generate(
        rb, (i) => rows.sublist(i * rb, (i * rb) + rb).join());
    List<String> cBlock = new List<String>.generate(
        cb, (i) => cols.sublist(i * cb, (i * rb) + cb).join());

    logger.d("SQUARES IS $squares");
    blocks = rBlock
        .map((final String rs) => cBlock
            .map((final String cs) => crossprod(rs.split(''), cs.split(''))))
        .expand((var l) => l)
        .toList();
    int i = 0;
    unitlist = cols.map((final String c) => crossprod(rows, [c])).toList() +
        rows.map((final String r) => crossprod([r], cols)).toList() +
        blocks;

    units = {
      for (var elem in squares)
        elem: unitlist.where((e) => e.contains(elem)).toList()
    };

    peers = {
      for (var elem in squares)
        elem: units[elem].expand((e) => e).toSet()..remove(elem)
    };
    logger.d('done with computeInit ');
  }

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

  Map<String, String> grid_values() {
    logger.i("IN GRIDVALUES()");
    List<String> chars = _input
        .map((c) => digits.contains(c) || ['.', '0'].contains(c)
            ? c
            : throw ('Bad input because of entry $c'))
        .toList();
    if (chars.length != _nrows * _ncols)
      throw 'Bad grid input. Num entries is ${chars.length}';
    int idx = 0;
    Map<String, String> m = {for (var elem in squares) elem: chars[idx++]};
    puzzleBoard = m.map((key, value) => MapEntry(key, value));

    return m;
  }

  Map<String, List<String>> assign(
      Map<String, List<String>> values, String s, String d) {
    List<String> other_values = values[s].map((element) => element).toList();
    if (other_values.length == 1) {
      return values;
    }
    if (values.keys.where((k) => values[k].length == 1).toList().contains(d)) {
      logger.e("$d already solved ");
      return null;
    }
    other_values.remove(d);
    assigns++;
    logger.d('Assigning $d at pos $s i.e eliminating ');
    logger.d('Other values ${other_values}');

    List<bool> x = other_values.map((d3) {
      var er = eliminate(values, s, d3);
      return (er == null ? false : true);
    }).toList();

    if (x.every((e) => e != false))
      return values;
    else {
      return null;
    }
  }

  Map<String, List<String>> eliminate(
      Map<String, List<String>> values, String s, String d) {
    if (values[s].contains(d) == false) {
      return values;
    }
    List<String> t = values[s].map((element) => element).toList();
    t.remove(d);
    if (t.length == 0) {
      logger.e("EMPTY VALUES");
      return null;
    } else {
      values[s] = t;
      if (values[s].length == 1) {
        String d2 = values[s].first;
        List<dynamic> elemLst =
            peers[s].map((s2) => eliminate(values, s2, d2)).toList();

        if (elemLst.any((e) => e != null) == false) {
          logger.e("CONTRADICTION SINCE WE COULD NOT ELIMINATE  ");
          return null;
        }
      }
    }
    for (List<String> u in units[s]) {
      List<String> dplaces = u.where((v) => values[v].contains(d)).toList();
      if (dplaces.isEmpty) {
        loggerNoStack.e("CONTRADICTION no place at  for this val");
        return null;
      } else if (dplaces.length == 1) {
        loggerNoStack.d("DPLACES LEN IS 1 $dplaces for $d");
        if (assign(values, dplaces.first, d) == null) {
          return null;
        }
      }
    }
    return values;
  }

  Map<String, List<String>> parse_grid() {
    Map<String, List<String>> values = {for (String s in squares) s: digits};

    for (MapEntry me in grid_values().entries) {
      if (digits.contains(me.value) && assign(values, me.key, me.value) == null)
        return null;
    }

    boardDict = values;
    return values;
  }

  bool isSolved() {
    if (boardDict == null || boardDict.isEmpty) return false;
    for (MapEntry me in boardDict.entries) {
      if (me.value.length > 1)
        return false;
      else
        for (var p in peers[me.key])
          if (boardDict[p].contains(me.value)) return false;
    }
    ;
    return true;
  }

  void display() {
    if (boardDict == null || boardDict.isEmpty)
      throw Exception("Nothing to display");
    int width = 1 + boardDict.values.map((v) => v.length).toList().reduce(max);
    String line = '\n';
    List<String> dlimRow = ['C', 'F'];
    List<String> dlimCol = ['3', '6'];
    line += (new List<String>.generate(sqrt(_nrows).round(),
        (k) => ('-' * (width * sqrt(_ncols).round() + 1))).join('+'));

    rows.forEach((r) {
      cols.forEach((c) {
        String s = boardDict[r + c].join();

        stdout.write(s.padRight(width, ' ') +
            (dlimCol.isNotEmpty && dlimCol.contains(c) ? '|' : '') +
            ' ');
      });
      if (dlimRow.isNotEmpty && dlimRow.contains(r)) stdout.write(line);
      print('');
    });
  }

  void displayPuzzle(final List<String> values) {
    int colCtr = 0;
    double blockCtr = 0;
    int rowCtr = 0;

    final int width = rows.length;
    final int height = cols.length;
    final int bwidth = sqrt(cols.length).round();
    final int bheight = sqrt(rows.length).round();
    List<String> out = new List<String>();
    values.forEach((c) {
      out.add(c);
      colCtr++;

      if (colCtr % bwidth == 0 && colCtr < width) {
        out.add('|');
      }
      if (colCtr == (width)) {
        print(out.join(' '));
        out.clear();
        rowCtr++;
        colCtr = 0;
        if (rowCtr % bheight == 0 && rowCtr < height) {
          print((List.generate(width + bwidth - 1, (index) => '-')).join(' '));
        }
      }
    });
  }

  Map<String, List<String>> solve() {
    boardDict = search(parse_grid());
    _solved = isSolved();
    return boardDict;
  }

  void reset() {
    boardDict.clear();
    puzzleBoard.clear();
    movesList.clear();
  }

  Map<String, List<String>> search(Map<String, List<String>> values) {
    loggerNoStack.v("SEARCHING  $values");
    if (values == null || values.isEmpty) return null;

    if (values.values.every((e) => e.length == 1)) {
      boardDict = values;
      return values;
    }
    Map<int, String> ord = {
      for (var k in values.keys)
        if (values[k].length > 1) values[k].length: k
    };
    String minSzKey = ord[ord.keys.reduce(min)];
    for (String d in values[minSzKey]) {
      Map<String, List<String>> res = search(assign(
          values.map((key, value) => MapEntry(key, value)), minSzKey, d));
      if (res != null && res.isNotEmpty) {
        return res;
      }
    }
    return null;
  }
}

main_() {
  Logger.level = Level.info;

  var gr =
      '.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....'
          .split('');

  var grb =
      '98.244..3......1........2...5...4.69..1..8..2...........3.9....6....5.....2....1.'
          .split('');

  var sm = "201002022".split('');
  var zeroLst = new List<String>.generate(9, (index) => '0');
  // SudokuBrain sb = new SudokuBrain(r: 4, c: 4, grid: "2... 13..   ..3.  ...2");
  SudokuBrain sb = new SudokuBrain(r: 3, c: 3, grid: "1.2 2.3 ..1");

  // SudokuBrain sb = new SudokuBrain(
  //     r: 9,
  //     c: 9,
  //     grid:
  //         "3...8.......7....51..............36...2..4....7...........6.13..452...........8..");
  // sb.displayPuzzle(grb);

  // sb.display();
  // sb.parse_grid();
  //sb.display();
//  sb.parse_grid(grb);

  sb.solve();
  print("SOLUTION IS ");

  // sb.d1();
  if (sb.isSolved())
    sb.display();
  else
    print("No solution for input ");
  print(sb.getAssigns);
}
