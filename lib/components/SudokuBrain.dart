import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:logger/logger.dart';

enum Solve_Strategy { min, max_first, max_last }

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
  Solve_Strategy _strategy;

  bool get solved => _solved;

  set solved(bool value) {
    _solved = value;
  }

  List<String> _input;
  List<String> rows;
  List<String> _solution;
  List<String> cols;
  List<List<String>> blocks;
  List<SCell> movesList = List<SCell>();
  final List<String> adigits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
  final List<String> aletters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
  List<String> digits;
  LinkedHashMap<String, List<String>> boardDict;
  LinkedHashMap<String, List<String>> moveBoard;

  Map<String, String> puzzleBoard;
  var logger = Logger(
    printer: PrettyPrinter(),
  );
  var loggerNoStack = Logger(
    printer: PrettyPrinter(methodCount: 0),
  );
  List<List<String>> unitlist;
  LinkedHashMap<String, List<List<String>>> units;

  LinkedHashMap<String, Set<String>> peers;
  List<String> squares;

  SudokuBrain({int r, int c, String grid}) {
    _strategy = Solve_Strategy.max_first;
    assigns = 0;
    _nrows = r;
    _ncols = c;
    rows = aletters.sublist(0, _nrows);
    cols = adigits.sublist(0, _ncols);
    digits = cols;
    _solution = new List();
    computeInit();
    if (grid.isEmpty) {
      _input = cleanInput(generatePuzzle(r, c).join(''));
    } else
      _input = cleanInput(grid);
  }
  List<String> cleanInput(final String puzz) {
    return puzz
        .toString()
        .replaceAll(new RegExp(r"\s+\b|\b\s|\s|\b"), "")
        .replaceAll(new RegExp(r"0"), ".")
        .replaceAll(new RegExp(r"-"), ".")
        .split('');
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

  void setInput(final String s) {
    _input = cleanInput(s);
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
    logger.i("PUZZLE BOARD IS $puzzleBoard");
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
    return peers[pos].toSet();
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

  String getSolutionAsString(LinkedHashMap<String, List<String>> v) {
    if (v == null || v.isEmpty) return "";
    var s = v.values.map((e) => e.join('')).toList().join('');
    return s;
  }

  String getInputAsString() {
    return _input.join('');
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
    logger.i("SQUARES IS $squares");
    _solved = false;
    int rb =
        _nrows > 3 ? (_nrows ~/ sqrt(_nrows).floor()) : sqrt(_nrows).floor();

    int cb =
        _ncols > 3 ? (_ncols ~/ sqrt(_ncols).ceil()) : sqrt(_nrows).floor();
    int delta = (rb == cb) ? 0 : 1;

    // List<String> rBlock = ['AB', 'CD', 'EF'];
    // List<String> cBlock = ['123', '456'];
    int listctr = 0;
    List<String> rBlock = List<String>.generate(rb, (index) {
      String x = rows.sublist(listctr, listctr + (rb - delta)).join();
      listctr += (rb - delta);
      //  logger.i(" x is $x and lc now is $listctr");

      return x;
    });
    listctr = 0;
    List<String> cBlock = List<String>.generate(cb, (index) {
      String x = cols.sublist(listctr, listctr + (cb + delta)).join();
      listctr += (cb + delta);
      //   logger.i(" x is $x and lc now is $listctr");

      return x;
    });
    // List<String> rBlock = new List<String>.generate(rb,
    //     (i) => rows.sublist(i * (rb - 1), (i * (rb - 1)) + (rb - 1)).join());
    // List<String> cBlock = new List<String>.generate(
    //     cb, (i) => cols.sublist(i * cb, (i * rb) + cb).join());

    logger.i("RB $rBlock , CB $cBlock ");
    blocks = rBlock
        .map((final String rs) => cBlock
            .map((final String cs) => crossprod(rs.split(''), cs.split(''))))
        .expand((var l) => l)
        .toList();
    logger.i("BLOCKS ARE $blocks");
    int i = 0;
    unitlist = cols.map((final String c) => crossprod(rows, [c])).toList() +
        rows.map((final String r) => crossprod([r], cols)).toList() +
        blocks;
    units = new LinkedHashMap();

    for (var elem in squares) {
      units[elem] = unitlist.where((e) => e.contains(elem)).toList();
    }
    peers = new LinkedHashMap();

    //  peers = {
    for (String elem in squares) {
      peers[elem] = units[elem].expand((e) => e).toSet()..remove(elem);
    }
    // };
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

  LinkedHashMap<String, String> grid_values() {
    logger.i("IN GRIDVALUES()");
    List<String> chars = _input
        .map((c) => digits.contains(c) || ['.', '0'].contains(c)
            ? c
            : throw ('Bad input because of entry $c'))
        .toList();
    if (chars.length != _nrows * _ncols)
      throw 'Bad grid input. Num entries is ${chars.length}';
    var it = chars.iterator;
    LinkedHashMap<String, String> m = LinkedHashMap();

    for (var elem in squares) {
      if (it.moveNext()) m[elem] = it.current;
    }

    puzzleBoard = m.map((key, value) => MapEntry(key, value));

    return m;
  }

  LinkedHashMap<String, List<String>> assign(
      Map<String, List<String>> values, String s, String d) {
    List<String> other_values =
        values[s].where((element) => element != d).toList();
    assigns++;
    logger.d('Assigning $d at pos $s i.e eliminating ');
    logger.d('Other values ${other_values}');
    bool ret_null = false;
    for (var d3 in other_values) {
      if (eliminate(values, s, d3) == null) return null;
    }
    return values;
    // List<bool> x = other_values.map((d3) {
    //   var er = eliminate(values, s, d3);
    //   return (er == null ? false : true);
    // }).toList();
    //
    // if (x.every((e) => e != false))
    //   return values;
    // else {
    //   return null;
    // }
  }

  Map<String, List<String>> eliminate(
      Map<String, List<String>> values, String s, String d) {
    if (values[s].contains(d) == false) {
      return values;
    }
    //  print('AFTER ' + values[s]);
    //  print('BEFORE ${values[s]} $s $d ');

    List<String> t = values[s].where((element) => element != d).toList();
    // print('AFTER  ${t} $s $d ');

    // List<String> t = values[s].map((element) => element).toList();
    // t.remove(d);
    //values[s] = values[s]..remove(d);
    if (t.length == 0) {
      logger.e("EMPTY VALUES");
      return null;
    } else {
      values[s] = t;
      if (values[s].length == 1) {
        String d2 = values[s].first;
        // for (var s2 in peers[s]) {
        //   if (eliminate(values, s2, d2) == null) return null;
        // }
        List<String> elemLst = peers[s].toList()
          ..map((s2) => eliminate(values, s2, d2)).toList();

        if (elemLst.every((e) => e != null) == false) {
          //      logger.e("CONTRADICTION SINCE WE COULD NOT ELIMINATE  ");
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
    LinkedHashMap<String, List<String>> values = new LinkedHashMap();
    for (String s in squares) {
      values[s] = digits;
    }
    moveBoard = new LinkedHashMap();
    for (String s in squares) {
      moveBoard[s] = digits;
    }

    for (MapEntry me in grid_values().entries) {
      if (digits.contains(me.value))
        moveBoard[me.key] = List<String>.generate(1, (index) => me.value);

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

  void display_input(Map<String, List<String>> bd) {
    if (bd == null || bd.isEmpty) throw Exception("Nothing to display");
    int width = 1 + bd.values.map((v) => v.length).toList().reduce(max);
    String line = '\n';
    List<String> dlimRow = ['C', 'F'];
    List<String> dlimCol = ['3', '6'];
    line += (new List<String>.generate(sqrt(_nrows).round(),
        (k) => ('-' * (width * sqrt(_ncols).round() + 1))).join('+'));

    rows.forEach((r) {
      cols.forEach((c) {
        String s = bd[r + c].join();

        stdout.write(s.padRight(width, ' ') +
            (dlimCol.isNotEmpty && dlimCol.contains(c) ? '|' : '') +
            ' ');
      });
      if (dlimRow.isNotEmpty && dlimRow.contains(r)) stdout.write(line);
      print('');
    });
  }

  List<String> generatePuzzle(final int nr, final int nc) {
    final int numEnt = (2 * nr) - 1;
    final int uniqDigits = nc - 1;
    final double easyFac = 2.5 * ((nr * nc) - numEnt);
    logger.i("IN GEN PUZZ");
    LinkedHashMap<String, List<String>> values = LinkedHashMap();

    for (var s in squares) {
      values[s] = digits;
    }

    List<String> sq = List<String>();
    sq.addAll(squares);
    sq.shuffle(new Random());

    for (String s in sq) {
      Random r = new Random();

      //  if (assign(values, s, digits.elementAt(r.nextInt(digits.length))) ==

      if (assign(values, s, values[s][(r.nextInt(values[s].length))]) == null) {
        break;
      }
      List<String> t = squares
          .where((s) => values[s].length == 1)
          .map((e) => values[e].join(''))
          .toList();
      logger.i("T IS $t");
      if (t.length >= numEnt && t.toSet().length >= uniqDigits) {
        List<String> pz =
            values.values.map((e) => e.length == 1 ? e.join('') : '.').toList();

        // List<String> onlyOne =
        //     values.keys.toList().where((e) => values[e].length == 1).toList();
        // onlyOne.shuffle(new Random());
        // List<String> others =
        //     values.keys.toList().where((e) => values[e].length > 1).toList();
        // List<String> sl = onlyOne.sublist(0, (nr / 2).round());
        // List<String> pz = values.keys
        //     .map((e) => sl.contains(e) ? values[e].join('') : '.')
        //     .toList();
        setInput(pz.join(''));
        // if (passesTriage(5))
        //   solve();
        // else
        //   continue;
        solve();
        logger.i("SOLVED IN $getAssigns");
        if (isSolved()
            //&&
            // values.values
            //         .where((e) => e.length > 1)
            //         .fold(0, (pv, el) => pv + el.length) <=
            //     easyFac

            )
          return pz;
        else
          continue;
      }
    }
    return generatePuzzle(nr, nc);
  }

  void display() {
    if (boardDict == null || boardDict.isEmpty)
      throw Exception("Nothing to display");
    int width = 1 + boardDict.values.map((v) => v.length).toList().reduce(max);
    String line = '\n';
    // List<String> dlimRow = ['B', 'D'];
    // List<String> dlimCol = ['3', '6'];
    List<String> dlimRow = ['B', 'F'];
    List<String> dlimCol = ['3', '6'];
    line += (new List<String>.generate(sqrt(_nrows).round(),
        (k) => ('-' * (width * sqrt(_ncols).round() + 1))).join('+'));
    int rc = 0;
    int cc = 0;
    rows.forEach((r) {
      cols.forEach((c) {
        String s = boardDict[r + c].join();

        if (_input.elementAt((rc * _nrows) + cc) != '.') s += "i";
        stdout.write(s.padRight(width, ' ') +
            (dlimCol.isNotEmpty && dlimCol.contains(c) ? '|' : '') +
            ' ');
        cc++;
      });
      if (dlimRow.isNotEmpty && dlimRow.contains(r)) stdout.write(line);
      print('');
      rc++;
      cc = 0;
    });
  }

  // List<String> neighbors(final String pos )
  // {
  //     String r = pos[0];
  //     String c = pos[1];
  //
  // }
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

  LinkedHashMap<String, List<String>> solve(
      {Solve_Strategy ss = Solve_Strategy.min}) {
    assigns = 0;
    LinkedHashMap<String, List<String>> pg = parse_grid();
    boardDict = search(pg, min_: ss);
    _solved = isSolved();
    if (_solved) {
      return boardDict;
    } else {
      print("Unsolvable ");
      return null;
    }
  }

  // LinkedHashMap<String, List<String>> tsolve() {
  //   assigns = 0;
  //
  //   LinkedHashMap<String, List<String>> pg = parse_grid();
  //   boardDict = search(pg, min_: 0);
  //   String sol = getSolutionAsString(boardDict);
  //   _solved = isSolved();
  //   if (_solved) {
  //     if (sol == getSolutionAsString(search(pg, min_: 1)) &&
  //         sol == getSolutionAsString(search(pg, min_: 2))) {
  //       print("UNIQUE!!");
  //
  //       return boardDict;
  //     } else {
  //       print('Multiple solutions to the puzzle ');
  //       // lets try making a puzzle
  //       return tweakInput(_input.join(''), sol);
  //       //   return null;
  //     }
  //   } else {
  //     print("Unsolvable ");
  //     return null;
  //   }
  // }

  void reset() {
    boardDict.clear();
    puzzleBoard.clear();
    movesList.clear();
  }

  LinkedHashMap<String, List<String>> search(
      LinkedHashMap<String, List<String>> values,
      {Solve_Strategy min_: Solve_Strategy.min}) {
    loggerNoStack.v("SEARCHING  $values");
    if (values == null || values.isEmpty) return null;

    if (values.values.every((e) => e.length == 1)) {
      boardDict = values;
      return values;
    }

    String minSzKey = values.keys
        .where((e) => values[e].length > 1)
        .reduce((p, c) => (min_ == Solve_Strategy.min)
            ? (values[p].length <= values[c].length ? p : c)
            : (min_ == Solve_Strategy.max_first)
                ? (values[p].length >= values[c].length ? p : c)
                : (values[p].length > values[c].length ? p : c));
    // String minSzKey = values.keys.where((e) => values[e].length > 1).reduce(
    //     (p, c) => min_
    //         ? (values[p].length <= values[c].length ? p : c)
    //         : (values[p].length >= values[c].length ? p : c));

    int n = values[minSzKey].length;
    //  loggerNoStack.wtf("N is $n , s is $minSzKey");

    for (String d in (values[minSzKey])) {
      LinkedHashMap<String, List<String>> res = search(
          assign(new LinkedHashMap()..addAll(values), minSzKey, d),
          min_: min_);
      if (res != null) {
        return res;
      }
    }

    return null;
  }

  bool passesTriage(final int maxPossibilities) {
    parse_grid();
    for (var v in boardDict.values) {
      if (v.length >= maxPossibilities) return false;
    }
    return true;

    // return boardDict.values
    //     .where((element) => element.length > maxPossibilities)
    //     .toList()
    //     .isEmpty;
  }

  LinkedHashMap<String, List<String>> assignMove(String pos, String val) {
    moveBoard = assign(moveBoard, pos, val);
    return moveBoard;
  }
}

bool checkUniqueSolution(final SudokuBrain sb, final String newInput) {
  //if (input.isEmpty) newInput = sb.getInputAsString();
  print(" CHECKING for:\n${sb.getInputAsString()}\n$newInput");
  String sol = sb.getSolution().join('');
  if (sb.isSolved()) {
    SudokuBrain sb1 =
        new SudokuBrain(r: sb.getNRows(), c: sb.getNCols(), grid: newInput);

    sb1.solve(ss: Solve_Strategy.max_first);
    String sol1 = sb1.getSolution().join('');

    SudokuBrain sb2 =
        new SudokuBrain(r: sb.getNRows(), c: sb.getNCols(), grid: newInput);
    sb2.solve(ss: Solve_Strategy.max_last);
    String sol2 = sb2.getSolution().join('');

    if (sol == sol1 && sol == sol2) {
      print("UNIQUE!!");
      return true;
    }
  }
  return false;
}

// Class ends here
String tsolve(final SudokuBrain sb, String newInput) {
  String sol = sb.getSolution().join('');
  if (checkUniqueSolution(sb, newInput)) return newInput;

  print('Multiple solutions to the puzzle ');
  // lets try making a puzzle by picking the solution  square val in the input
  List<String> solList = sol.split('');
  List<String> inp = newInput.split('');

  List<int> emptyValues =
      inp.asMap().keys.where((idx) => inp[idx] != sol[idx]).toList();

  // for (var idx in emptyValues) {
  //   List<String> inList = List();
  //   inList.addAll(inp);
  //   inList[idx] = solList[idx];
  //   if (checkUniqueSolution(sb, inList.join(''))) return inList.join('');
  // }
  for (int i = 0; i < 100; i++) {
    emptyValues.shuffle(new Random());
    // List<String> inList = List();
    List<String> inList = List();
    inList.addAll(inp);
    List<String> tryList = swapEntries(inList, solList, emptyValues, 1);

    if (checkUniqueSolution(sb, tryList.join(''))) return tryList.join('');
  }
  return null;
}

List<String> swapEntries(
    List<String> i, List<String> s, List<int> emptyList, int n) {
  List<String> outList = new List()..addAll(i);
  for (int id = 0; id < n; id++) {
    Random r = new Random();

    int rndIdx = r.nextInt(emptyList.length);
    outList[emptyList[rndIdx]] = s[emptyList[rndIdx]];
  }
  return outList;
}
//
// List<String> genPuzzles({final int no, final int r, final int c}) {
//   List<String> puzzles = new List();
//   for (int i = 1; i < no; i++) {
//     SudokuBrain sb1 = new SudokuBrain(r: r, c: c, grid: "");
//
//     sb1.displayPuzzle(sb1.getInputAsList());
//     print("INP IS ${sb1.getInputAsString()}");
//     print("SOLUTION:--");
//
//     if (sb1.tsolve() == null) {
//       print("Can't make a puzzle. Continuging ");
//       continue;
//     }
//     print("INP IS ${sb1.getInputAsString()}");
//     print(sb1.getSolution().join(''));
//
//     print("PUZZLE SOLVED IN ${sb1.getAssigns} moves");
//     sb1.display();
//     puzzles.add(sb1.getInputAsString());
//   }
//
//   print("PUZZLES ");
//
//   return puzzles;
// }

bool onePuzzle(int r, int c, final String g) {
  SudokuBrain sb = new SudokuBrain(r: r, c: c, grid: g);
  print("${sb.getInputAsString()}");
  sb.displayPuzzle(sb.getInputAsList());

  sb.display_input((sb.parse_grid()));
  if (sb.solve(ss: Solve_Strategy.min) == null) {
    print("No Solution ");
    return false;
  }

  List<String> sol = sb.getSolution();
  sb.display();
  List<String> trySolve = new List();
  trySolve.addAll(sol);
  List<int> idxList =
      List.generate(sb.getNRows() * sb.getNCols(), (index) => index);
  idxList.shuffle(new Random());
  int iter = 0;
  int prevIdx = idxList.first;
  for (int i in idxList) {
    int n = trySolve.fold(
        0,
        (previousValue, e) =>
            (sb.digits.contains(e)) ? previousValue + 1 : previousValue);
    if (n >= (2 * sb.getNCols()) - 1 &&
        (n <= ((2 * sb.getNCols()) + 3)) &&
        trySolve.toSet().length >= sb.getNRows() - 1) {
      SudokuBrain sb1 = new SudokuBrain(r: r, c: c, grid: trySolve.join(''));
      sb1.solve(ss: Solve_Strategy.max_last);
      if (sb1.isSolved() &&
          sb1.getSolution().join('') == sb.getSolution().join('')) {
        print("GOT IT !! INPUT ${trySolve.join('')}");
        sb1.display_input(sb1.parse_grid());

        return true;
      } else
        trySolve[prevIdx] = sol[prevIdx];
    }

    List<String> p = searchForInput(r, c, sol.join(''), trySolve.join(''), i);
    if (p != null) trySolve = p;
    iter++;
    prevIdx = i;
  }
  print("IN ITERATAIONS $iter");
  // if (trySolve != null && trySolve.isNotEmpty)
  //   print(
  //       "INPUT IS \n${sb.getInputAsString()} WellF IS \n${trySolve.join('')}");
  print("COULD NOT FIND A WELL FORMED INPUT $trySolve");
  return false;
}

List<String> searchForInput(int r, int c, String sol, String inp, int idx) {
  List<String> inl = inp.split('');
  inl[idx] = '.';
  SudokuBrain sb = new SudokuBrain(r: r, c: c, grid: inl.join(''));
  sb.solve();
  if (sb.isSolved() && (sol == sb.getSolution().join('')))
    return inl;
  else
    return null;
}

void tryStrategy(int r, int c) {
  SudokuBrain sb =
      new SudokuBrain(r: r, c: c, grid: "1.64..52.........3.1...5453...26....");
  sb.solve();
  SudokuBrain sb1 =
      new SudokuBrain(r: r, c: c, grid: "1.64..52.........3.1...5453...26....");
  sb1.solve(ss: Solve_Strategy.max_first);
  if (sb1.getSolution().join('') == sb.getSolution().join(''))
    print("YYOWEEWEE");
}

main() {
  Logger.level = Level.nothing;
  // SudokuBrain sb = new SudokuBrain(
  //     r: 9,
  //     c: 9,
  //     grid:
  //         '.....3.17.15..9..8.6.......1....7.....9...2.....5....4.......2.5..6..34.34.2.....');
  // sb.solve();
  // print(checkUniqueSolution(sb,
  //     '.....3.17.15..9..8.6.......1....7.....9...2.....5....4.......2.5..6..34.34.2.....'));

  for (int i = 0; i < 10; i++) if (onePuzzle(6, 6, "")) break;
  // if (x != null) print("GOT A VALID INPUT $x");
//  tryStrategy(6, 6);
  final int no = 10;
  // List<String> pz = genPuzzles(no: no, r: 9, c: 9);
  // for (var p in pz) {
  //   print(p);
  // }
  // print("Found percentage ${(pz.length / no) * 100}");
  // SudokuBrain sb = new SudokuBrain(r: 9, c: 9, grid: "");
  // sb.solve();
  // if (sb.isSolved()) {
  //   // lets run it through tsolve to see if it is a unique puzzle
  //
  //   //   String i = tsolve(sb, sb.getInputAsString());
  //   //   if (i != null && i.isNotEmpty)
  //   //     print(
  //   //         "UNIQUE IN  $i . Entries ${i.split('').fold(0, (previousValue, e) => e == '.' ? previousValue : previousValue + 1)}");
  //   //   else
  //   //     print("Could not find unique puzzle");
  // }
  // onePuzzle(9, 9,
  //     "..8....7.25317986447.....2..6.4...8...7....49.42.............3.....2..9....9....8");
}
