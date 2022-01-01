import 'dart:collection';
import 'dart:io';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:tuple/tuple.dart';

enum Solve_Strategy { min, max_first, max_last, rnd, mid_lseq }

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
      //random_puzzle(1));
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
      Map<String, List<String>> values, String s, String d,
      [bool cnt = true]) {
    List<String> other_values =
        values[s].where((element) => element != d).toList();
    logger.d('Assigning $d at pos $s i.e eliminating ');
    logger.d('Other values ${other_values}');
    bool ret_null = false;
    for (var d3 in other_values) {
      if (eliminate(values, s, d3) == null) return null;
    }
    if (cnt && (values != null || values.isNotEmpty)) assigns++;

    return values;
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
      if (_input.contains(me.value)) {
        List<String> t = List<String>.generate(1, (index) => me.value);
        moveBoard[me.key] = t;
        //   values[me.key] = t;
      }
      if (digits.contains(me.value) &&
          assign(values, me.key, me.value, false) == null) return null;
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
      //  print("T IS $t");
      if (t.length >= numEnt) {
        List<String> pz =
            values.values.map((e) => e.length == 1 ? e.join('') : '.').toList();

        SudokuBrain sTemp = new SudokuBrain(r: nr, c: nc, grid: pz.join(''));

        sTemp.solve();
        //  logger.i("SOLVED IN $sTemp.get");
        if (sTemp.isSolved())
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

  String random_puzzle([int stopLimit = 1]) {
    List<String> inp = [];

    void gen() {
      if (inp.length == stopLimit) return;

      List<String> sq = [];
      sq.addAll(squares);
      sq.shuffle(new Random());

      LinkedHashMap<String, List<String>> values = new LinkedHashMap();
      for (String s in squares) {
        values[s] = digits;
      }
      for (String s in sq) {
        if (assign(
                values, s, values[s][new Random().nextInt(values[s].length)]) ==
            null) break;
        List<String> t = squares
            .map((s) => values[s].length == 1 ? values[s].join('') : '.')
            .toList();
        if (t.where((element) => digits.contains(element)).length >=
                2 * _nrows - 1 &&
            t.toSet().length >= _nrows) if (inp.length == stopLimit)
          return;
        else
          inp.add(t.join(''));
      }
      gen();
    }

    gen();

    print("We have rnd puzzles ");
    inp.forEach((element) {
      print(
          "${element} len -> ${element.split('').fold(0, (p, e) => digits.contains(e) ? p + 1 : p)}");
    });
    return inp.first;
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

// Returns index of start of longest seq
  Tuple2<int, int> longestSeq(
      String char, LinkedHashMap<String, List<String>> vals) {
    int mrun = 0;
    int lmrun = 0;
    int end = 0;
    int i = 0;
    int findMaxRun(p, e) {
      if (e == 1 && lmrun == 0) lmrun = 1;

      if (p == 1 && e == 1) {
        lmrun++;
      } else {
        // remember the last max run
        if ((mrun < lmrun)) {
          end = i;
          mrun = lmrun;
        }
        lmrun = 0;
      }
      i++;
      return e;
    }

    vals.keys
        .map((element) => ((vals[element].length > 1) ||
                (vals[element].length == 1 && vals[element].first == char))
            ? 1
            : 0)
        .fold(0, findMaxRun);

    //   if (mrun >= 1) mrun++;
    if (lmrun > mrun) {
      mrun = lmrun;
      end = i;
    }

    print(
        "GOT RUN OF LENGTH ${mrun} starting at ${end - (mrun == 1 ? 0 : mrun)} ");
    return Tuple2<int, int>(end - (mrun == 1 ? 0 : mrun), mrun);
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
    String minSzKey = values.keys.first;

    // pick a random
    List<String> gtThanOneList =
        values.keys.where((element) => values[element].length > 1).toList();

    switch (min_) {
      case Solve_Strategy.mid_lseq:
        {
          Tuple2<int, int> t = longestSeq('.', values);
          minSzKey = values.keys.elementAt(t.item1 + (t.item2 ~/ 2));
          break;
        }
      case Solve_Strategy.rnd:
        {
          minSzKey = gtThanOneList
              .elementAt(new Random().nextInt(gtThanOneList.length));
          break;
        }
      case Solve_Strategy.min:
        {
          minSzKey = gtThanOneList
              .reduce((p, c) => values[p].length <= values[c].length ? p : c);

          break;
        }
      case Solve_Strategy.max_first:
        {
          minSzKey = gtThanOneList
              .reduce((p, c) => values[p].length >= values[c].length ? p : c);
          break;
        }
      case Solve_Strategy.max_last:
        {
          minSzKey = gtThanOneList
              .reduce((p, c) => values[p].length > values[c].length ? p : c);
          break;
        }
    }
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

// Test a solution by solving inp and compare if sol(inp)== s. If so return
// Do this by testing with max_last,max_first strategies . They should all result in same solution.

String improvePuzzle(String sol, SudokuBrain sb) {}
String testSolution(SudokuBrain orig, String inp, String s) {
  SudokuBrain p =
      new SudokuBrain(r: orig.getNRows(), c: orig.getNCols(), grid: inp);
  p.solve(ss: Solve_Strategy.max_last);

  SudokuBrain q =
      new SudokuBrain(r: orig.getNRows(), c: orig.getNCols(), grid: inp);
  q.solve(ss: Solve_Strategy.max_first);

  SudokuBrain rn;
  for (int i = 0; i < 10; i++) {
    rn = new SudokuBrain(r: orig.getNRows(), c: orig.getNCols(), grid: inp);
    rn.solve(ss: Solve_Strategy.rnd);

    if (rn.isSolved() && rn.getSolution().join() != s) return '';
  }
  SudokuBrain ls =
      new SudokuBrain(r: orig.getNRows(), c: orig.getNCols(), grid: inp);
  ls.solve(ss: Solve_Strategy.mid_lseq);

  if (p.isSolved() &&
      q.isSolved() &&
      ls.isSolved() &&
      p.getSolution().join('') == s &&
      q.getSolution().join('') == s &&
      ls.getSolution().join('') == s)
    return s;
  else {
    print("We have different solutions");
    return '';
  }
}

void backtrack(SudokuBrain sb) {
  List<String> inp = sb.getInputAsList();
  String sol = sb.getSolution().join('');
  int nsol = 0;
  Map<String, int> inpList = new Map<String, int>();
  List<int> idx =
      List.generate(sb.getNRows() * sb.getNCols(), (index) => index).toList();

  idx.shuffle(new Random());
  List<String> trySolve = new List<String>();
  trySolve.addAll(sb.getSolution());

  for (int i in idx) {
    String c = trySolve[i];
    // Remove a random char
    trySolve[i] = '.';
    // test for puzzle solution with that ch
    String testi = trySolve.join('');
    if (testSolution(sb, testi, sol).isNotEmpty) {
      inpList[testi] = trySolve.fold(
          0,
          (previousValue, e) =>
              (sb.digits.contains(e)) ? previousValue + 1 : previousValue);
    } else {
      // put back char since it does not lead to a puzzle with solution sol
      trySolve[i] = c;
    }
  }
  print(" ORIG SOLUTION IS ${sol} for input ${inp} solved in ${sb.getAssigns}");
  if (inpList.isEmpty) print("Puzzle could not be generated");
  inpList.forEach((key, value) {
    SudokuBrain sq =
        new SudokuBrain(r: sb.getNRows(), c: sb.getNCols(), grid: key);
    if (value >= (2 * sb.getNRows() - 1) &&
        value <= (3 * sb.getNRows()) &&
        key
                .split('')
                .where((element) => sq.digits.contains(element))
                .toSet()
                .length >
            sb.getNRows() - 1) {
      sq.solve();
      print("${key}->${value} ");
    }
  });
}

bool onePuzzle(int r, int c, final String g) {
  SudokuBrain sb = new SudokuBrain(r: r, c: c, grid: g);
  print("${sb.getInputAsString()}");
  // sb.displayPuzzle(sb.getInputAsList());

  //sb.display_input((sb.parse_grid()));
  if (sb.solve(ss: Solve_Strategy.min) == null) {
    print("No Solution ");
    return false;
  }

  List<String> sol = sb.getSolution();
  sb.display();
  backtrack(sb);

  return true;
}

void testLongSeq() {
  List<String> g =
      //  "268751349379248651415369287756812934894635712132974865681597423527..319694312657."
      //'..78..64...........6.....18.5..7...........26193.2..5...6..18...7...23..93...5.7.'
      //  '.....4..997..16.3.4..9...6.....4.5.3..2......1...6..9...62.5.8.3......52.1.......'
      "2687513493792486514153692877568129348946357121329748656815974235274831969431265.9"
          .split('');

  var it = g.iterator;
  LinkedHashMap<String, List<String>> m = LinkedHashMap();
  SudokuBrain s = new SudokuBrain(r: 9, c: 9, grid: g.join(''));

  for (var elem in s.squares) {
    if (it.moveNext()) {
      m[elem] = new List<String>();
      m[elem].add(it.current);
    }
  }
  int idx = 0;
  m.keys.forEach((k) {
    print("idx ${idx} ${k}-> ${m[k]}");
    idx++;
  });
  s.longestSeq('.', m);
}

main() {
  Logger.level = Level.nothing;
  //testLongSeq();
  onePuzzle(9, 9, "");

  // // SudokuBrain s = new SudokuBrain(
  //     r: 9,
  //     c: 9,
  //     grid:
  //         "26875134937924865141536928775681293489463571213297486568159742352748319694312657.");
  // s.solve();
  // s.display();
  // print("ASSIGNS is ${s.getAssigns}");
  final int no = 10;
}
