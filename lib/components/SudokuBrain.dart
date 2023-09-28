// dummy
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
enum Solve_Strategy {
   MIN,
   MAX,
  RANDOM
}

class SudokuBrain {
  int _nrows = 0;
  int _ncols = 0;
  int assigns = 0;
  bool debugMode = false;
  bool _solved = false;
  Solve_Strategy _solve_strategy = Solve_Strategy.MIN;
  bool _genMode = false;
  bool get solved => _solved;

  set solved(bool value) {
    _solved = value;
  }

  late List<String> _input;
  late List<String> rows;
  late List<String> cols;
  late List<List<String>> blocks;
  late List<SCell> movesList ;
  //List<SCell>();
  final List<String> adigits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
  final List<String> aletters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'];
 late  List<String> digits;
  late Map<String, List<String>> ? boardDict;
 late  Map<String, List<String>>? moveBoard;

  late Map<String, String> puzzleBoard;
  var logger = Logger(
    printer: PrettyPrinter(),
    output: null,
    level: Level.warning
  );
  var loggerNoStack = Logger(
    printer: PrettyPrinter(methodCount: 0),
  );


  late List<List<String>> unitlist;
  late Map<String, List<List<String>>> units;
  late var peers;
  late List<String> squares;
  SudokuBrain({required int r, required int c, required String grid , Solve_Strategy ss = Solve_Strategy.MIN}) {


    assigns = 0;
    _nrows = r;
    _ncols = c;
    _genMode = false;

    rows = aletters.sublist(0, _nrows);
    cols = adigits.sublist(0, _ncols);
    digits = cols;
    computeInit();
   if(grid.isEmpty)
     _input= List<String>.generate(_ncols * _nrows, (index) => '.');
   else
      _input = filterInput(grid);
   // _solve_strategy = _genMode && grid.isEmpty ? Solve_Strategy.RANDOM : Solve_Strategy.MIN;
  //  _solve_strategy = _genMode && grid.isEmpty ? Solve_Strategy.RANDOM : Solve_Strategy.MIN;

    movesList = [];
  }
  List<String> filterInput( String g)
  {
    return  g
        .toString()
        .replaceAll(new RegExp(r"\s+\b|\b\s|\s|\b"), "")
        .replaceAll(new RegExp(r"0"), ".")
        .replaceAll(new RegExp(r"-"), ".")
        .split('');
  }
  List<String> getInputAsList() {
    return _input;
  }

  bool makeMove(final String pos, final String val) {return false;}
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

  void setValAt(final String? pos, final String? val) {
    SCell s = new SCell(pos!, val!);
    if (movesList.contains(s) == false) movesList.add(s);

    logger.i("PUZB[$pos]=$val");
    puzzleBoard[pos] = val;
  }

  bool haveUndos() {
    return movesList.isNotEmpty;
  }

  bool isInInput(final int idx, final String? val) {
    var v = _input[idx];
    //  logger.i("IS INPUT OF $idx for val $val->$v");
    return cols.contains(_input[idx]) && _input[idx] == val;
  }

  String? getValueAtPos(final String? pos) {
    return puzzleBoard[pos];
  }

  String? getValAtIndex(final int i) {
    // logger.i("GETTING VAL AT IDX $i");
    if (i >= _nrows * _ncols || i < 0)
      throw ('Bad index $i for current $_nrows X $_ncols grid');

    String pos = getPosByIndex(i);
    //  logger.i("POS IS $pos  at $puzzleBoard[pos]");
    return puzzleBoard[pos];
  }
  bool puzzleSolved() {
    logger.i("PUZZLE BOARD IS $puzzleBoard");
    String p = puzzleBoard.values.reduce((value, element) => value + element );

    print("BOARD-> ${p}");
   // print("SOLUT-> ${boardDict.values.expand((element) => element).join('')} ");
    print("SOLUT-> ${getSolution()?.join('')} ");
   // res = p == getSolution().join(''))

    logger.i("BOARD DICT IS $boardDict");
    bool res = _solved  &&  ( p == getSolution()?.join(''));

   // boardDict.keys.every((k) => boardDict[k].join('').;
    logger.i("PUZZLESOLVED() $res _solved is $_solved");
    return res;
  }


  bool puzzleSolvedStrict() {
    logger.i("PUZZLE BOARD IS $puzzleBoard");
    bool res = _solved &&
        boardDict!.keys.every((k) => boardDict?[k]?.join('') == puzzleBoard[k]);
    logger.i("PUZZLESOLVED() $res _solved is $_solved");
    return res;
  }

  String? getSolutionValAtPos(final String pos) {
    return boardDict?[pos]?.join('');
  }

  Set<String> getPeers(final String? pos) {
    // logger.i("PEERS ${peers[pos]} and type is ${peers[pos].runtimeType} ");
    return peers[pos];
  }

  List<List<String>>? getUnits(final String? pos) {
    return units[pos];
  }

  String getPosByIndex(final int i) {
    if (i >= _nrows * _ncols || i < 0)
      throw ('Bad index $i for current $_nrows X $_ncols grid');
    return rows[(i / _nrows).floor()] + cols[i % _ncols];
  }

  bool isValidDigitOnGrid(final String? v) {
    return digits.contains(v);
  }

  String getPosByXY(final int r, final int c) {
    if (r > _nrows || c > _ncols)
      throw ('Bad Coordinates to request board position $r,$c');

    return rows[r] + cols[c];
  }

  bool isCorrectAt(final String? pos, final String? d) {
    return boardDict?[pos]?.length == 1 && boardDict?[pos]?.first == d
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

  List<String>? getPossibleAt(final String pos) {
    return boardDict?[pos];
  }

  List<String>? getSolution() {
    if (isSolved()) {
      return boardDict?.values.map((e) => e.join('')).toList();
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

    units = {
      for (var elem in squares)
        elem: unitlist.where((e) => e.contains(elem)).toList()
    };

    peers = {
      for (var elem in squares)
        elem: units[elem]?.expand((e) => e).toSet()?..remove(elem)
    };
    logger.d('done with computeInit ');
  }

  void printBoard(var arr) {
    int i = 0;
    arr.forEach((x) {
      print(x);
      i++;
      if (i % _ncols == 0) print("\n");
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
    if (chars.length != _nrows * _ncols
         )
      throw 'Bad grid input. Num entries is ${chars.length}';
    int idx = 0;
    Map<String, String> m = {for (var elem in squares) elem: chars[idx++]};
    puzzleBoard = m.map((key, value) => MapEntry(key, value));

    return m;
  }

  Map<String, List<String>>? assign(
      Map<String, List<String>> values, String s, String d) {
    List<String>? other_values = values[s]?.map((element) => element).toList();
    if (other_values?.length == 1) {
      return values;
    }
    if (values.keys.where((k) => values[k]?.length == 1).toList().contains(d)) {
      logger.e("$d already solved ");
      return null;
    }
    other_values?.remove(d);
    assigns++;
    logger.d('Assigning $d at pos $s i.e eliminating ');
    logger.d('Other values ${other_values}');

    List<bool>? x = other_values?.map((d3) {
      var er = eliminate(values, s, d3);
      return (er == null ? false : true);
    }).toList();

    if (x!.every((e) => e != false))
      return values;
    else {
      return null;
    }
  }

  Map<String, List<String>>? eliminate(
      Map<String, List<String>> values, String s, String d) {
    if (values[s]?.contains(d) == false) {
      return values;
    }
    List<String>? t = values[s]?.map((element) => element).toList();
    t?.remove(d);
    if (t?.length == 0) {
      logger.e("EMPTY VALUES");
      return null;
    } else {
      values[s] = t!;
      if (values[s]?.length == 1) {
        String? d2 = values[s]?.first;
        List<dynamic> elemLst =
            peers[s].map((s2) => eliminate(values, s2, d2!)).toList();

        if (elemLst.any((e) => e != null) == false) {
          logger.e("CONTRADICTION SINCE WE COULD NOT ELIMINATE  ");
          return null;
        }
      }
    }
    for (List<String> u in units[s]!) {
      List<String> dplaces = u.where((v) => values[v]!.contains(d)).toList();
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

  Map<String, List<String>>? parse_grid() {
    Map<String, List<String>> values = {for (String s in squares) s: digits};
    moveBoard = {for (String s in squares) s: digits};

    for (MapEntry me in grid_values().entries) {
      if (digits.contains(me.value))
        moveBoard?[me.key] = List<String>.generate(1, (index) => me.value);

      if (digits.contains(me.value) && assign(values, me.key, me.value) == null)
        return null;
    }

    boardDict = values;
    return values;
  }

  bool isSolved() {
    if (boardDict == null || boardDict!.isEmpty) return false;
    for (MapEntry me in boardDict!.entries) {
      if (me.value.length > 1)
        return false;
      else
        for (var p in peers[me.key])
          if (boardDict?[p] != null && boardDict![p]!.contains(me.value)) return false;
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
        String? s = bd[r + c]?.join();

        stdout.write(s!.padRight(width, ' ') +
            (dlimCol.isNotEmpty && dlimCol.contains(c) ? '|' : '') +
            ' ');
      });
      if (dlimRow.isNotEmpty && dlimRow.contains(r)) stdout.write(line);
      print('');
    });
  }
  // List<String> backTrackGenPuz() {
  //
  //
  // }
  List<String> generatePuzzle( ){
     final int numEnt = 2*_nrows -1;  // Min number of provided filled in input squares

     final int uniqDigits = _nrows -1;
     logger.i("IN GEN PUZZ");
     Map<String, List<String>> values = {for (String s in squares) s: digits};
     List<String>  sq = [...squares];

     sq.shuffle(new Random());
     for ( String s  in sq) {
       Random r = new Random();
       if (assign(
           values, s, values[s]!.elementAt(r.nextInt(values[s]!.length))) ==
           null) {
         break;
       }
       List t = squares.where((s) => values[s]?.length == 1).map((
           e) => values[e]).toList().expand((element) => element!).toList();
       logger.i("T IS $t");
       if (t.length >= numEnt && t
           .toSet()
           .length >= uniqDigits) {
         logger.i("RETURNING VALUES $values");
         return values.values.map((e) => e.length == 1 ? e : ['.'])
             .toList()
             .expand((element) => element)
             .toList();
       }
        }
     return generatePuzzle();


  }
  void display() {
    if (boardDict == null || boardDict!.isEmpty)
      throw Exception("Nothing to display");
    int width = 1 + boardDict!.values.map((v) => v.length).toList().reduce(max);
    String line = '\n';
    List<String> dlimRow = ['C', 'F'];
    List<String> dlimCol = ['3', '6'];
    line += (new List<String>.generate(sqrt(_nrows).round(),
        (k) => ('-' * (width * sqrt(_ncols).round() - 1))).join('+'));

    rows.forEach((r) {
      cols.forEach((c) {
        String? s = boardDict?[r + c]?.join();

        stdout.write(s!.padRight(width, ' ') +
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
     int bwidth = sqrt(cols.length).ceil() ;
     int bheight = sqrt(rows.length).floor();
    // if( bwidth == 6 && bheight == 6) {
    //   bwidth = bwidth+1 ;
    //   bheight = bheight-1  ;
    // }
     List<String> out = new List<String>.empty(growable: true);
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
         //  print((List.generate(width + bwidth - 1, (index) => '-')).join(' '));
         }
       }
     });
   }


  Map<String, List<String>>? solve() {
    boardDict = search(parse_grid());
    _solved = isSolved();
    return boardDict;
  }

  void reset() {
    boardDict?.clear();
    puzzleBoard.clear();
    movesList.clear();
  }

  Map<String, List<String>> ?search(Map<String, List<String>>? values) {
    loggerNoStack.v("SEARCHING  $values");
    if (values == null || values.isEmpty) return null;

    if (values.values.every((e) => e.length == 1)) {
      boardDict = values;
      return values;
    }


    Map<String, int> ord = {
      for (var k in values.keys)
        if (values[k]!.length > 1)  k:values[k]!.length
    };
    Random rnd = new Random();

    String? minSzKey = "";
    switch (_solve_strategy)  {

      case Solve_Strategy.MIN : {
    Map<int, String> ord = {
    for (var k in values.keys)
    if (values[k]!.length > 1) values[k]!.length: k
    };

        minSzKey = ord[ord.keys.reduce(min)];
    }
      break;
     case (Solve_Strategy.RANDOM) : {
    Map<String, int> ord = {
      for (var k in values.keys)
        if (values[k]!.length > 1)  k :values[k]!.length
    };
    logger.i(" ORED IS $ord \n values $values" );

    minSzKey = ord.keys.toList()[rnd.nextInt(ord.length)];

    }

      default : {}
      break;

    }
    // minSzKey = ord[ord.keys.reduce(min)];

    for (String d in values[minSzKey]!) {
      Map<String, List<String>>? res = search(assign(
          values.map((key, value) => MapEntry(key, value)), minSzKey!, d));
      if (res != null && res.isNotEmpty) {
        return res;
      }
    }
    return null;
  }

  Map<String, List<String>>? assignMove(String pos, String val) {
    moveBoard = assign(moveBoard!, pos, val)!;
    return moveBoard;
  }
}

main() {
  Logger.level = Level.info;

  var gr =
      '.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....'
          .split('');

  var grb =
      '98.244..3......1........2...5...4.69..1..8..2...........3.9....6....5.....2....1.'
          .split('');

  var sm = "201002022".split('');
  var zeroLst = new List<String>.generate(9, (index) => '0');
  String tbt = "2... 13..   ..3.  ...2";
  // SudokuBrain sb = new SudokuBrain(r: 4, c: 4, grid: "2... 13..   ..3.  ...2");

   SudokuBrain sb =
   new SudokuBrain(r: 6, c: 6, grid: "");



 // new SudokuBrain(r: 6, c: 6, grid: "21--43--------62----34--------34--56");
 // SudokuBrain sb = new SudokuBrain(r: 4, c: 4, grid: "2... 13..   ..3.  ...2");
  List<String> inp= sb.generatePuzzle();
  //print(sb.generatePuzzle());
//   sb.displayPuzzle(inp);
   SudokuBrain sbs = new SudokuBrain(r: 6, c:6, grid: inp.join(''));
   sbs.solve();
// //  sbs.displayPuzzle(sol);
//   sbs.displayPuzzle(inp);
// sbs.puzzleSolved();
//   sbs.display();
//   sbs.displayPuzzle(inp);
//   print(inp.join(''));

  if(checkPuzz(inp, 6, 6, sbs.getSolution() ,64))
  {
    sbs.displayPuzzle(inp);
     sbs.display();

    print("VALID INPUT!! $inp\n ${inp.join('')} ");

  } else
    print("BAD input and not consistently solvable $inp\n");

  //sbs.getInputAsList();
  //new SudokuBrain(r: 3, c: 3, grid: "1.2 2.3 ..1");

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

 // sb.solve();
  // sb.parse_grid();
  // sb.display_input(sb.moveBoard);
  //
  // print("AFTER ASS A2->4");
  // sb.assignMove("A2", "4");
  // if (sb.moveBoard == null || sb.moveBoard.isEmpty)
  //   print("ASSIGNMENT CAN'T BE MADe");
  // else
  //   sb.display_input(sb.moveBoard);

  // print(sb.moveBoard);

  // sb.d1();
  // if (sb.isSolved())
  //   sb.display();
  // else
  //   print("No solution for input ");
  //
//  print(sb.getAssigns);
}
bool checkPuzzleWithStrategy(final List<String> inp , final int ro, final int co,final List<String>? sol,Solve_Strategy ss)
{
    SudokuBrain sb1 = new SudokuBrain(r: ro, c: co, grid: inp.join(''), ss: ss);
    sb1.solve();
    if(sb1.isSolved() == false)
      return false;


   // sb1.displayPuzzle(inp);
    return  (sol?.join('') == sb1.getSolution()?.join(''));

}

bool checkPuzz(final List<String> inp , final int ro, final int co,final List<String>? sol, final int loopSz ) {
  bool valid = true;

  for ( int i = 0; i< loopSz; i++) {


    if(checkPuzzleWithStrategy(inp,ro,co,sol,Solve_Strategy.RANDOM))
     continue;
    else {
      print("NO MAS FOR YOU $inp");
      return false ;
    }
  }
 return valid && checkPuzzleWithStrategy(inp,ro,co,sol,Solve_Strategy.MIN) && checkPuzzleWithStrategy(inp,ro,co,sol,Solve_Strategy.MAX);

}