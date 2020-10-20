import 'package:flutter/material.dart';
import 'package:sudoku/components/SudokuBrain.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:logger/logger.dart';


class SudokuCell {
  int index;
  String pos;
  String val;
  Color clr;
  Color tClr;
  double opacity = 1.0;

  SudokuCell(this.index, this.pos, this.val, this.clr, this.tClr,this.opacity);
}


void main() {
  Logger.level = Level.info;

  String nine_ ='.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....';
  // SudokuBoard board = new  SudokuBoard(9, 9, nine_)..setupScreenGrid();
runApp(SudokuApp());
}

class SudokuApp extends StatefulWidget {
  @override
  _SudokuAppState createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> {
  SudokuBrain _sb = new SudokuBrain(r: 4, c: 4, grid: "2... 13..   ..3.  ...2");
  List<SudokuCell> _ScreenGrid ;
  var _tapPosition;

  // List<MyHomePage> ScreenGrid = List<MyHomePage>();
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  @override
  void initState() {

     logger.i("IN INIT STATE got sb ${_sb.getNRows()}");
     initGrid();
    super.initState();
  }
  void highlightPeers(  SudokuCell c) {
    //   getSolvedGrid();
   logger.i("HIGHLIGHTING PEERS FOR ${c.pos}");
    Set<String> peersList = _sb.getPeers(c.pos);
    _ScreenGrid.forEach((cell) {
      if (peersList.contains(cell.pos)) {
        logger.i("CHANGING OPACITY OF ${cell.pos}");
        cell.opacity = 0.2 ;

      } else
        cell.opacity = 1.0;

    });
    c.opacity = 0.3;
   // _ScreenGrid = tlist;
  //  notifyListeners();

  }

  void highlightCorrect(SudokuCell c) {
    if (_sb.isValidDigitOnGrid(c.val) == false)
      c.tClr = Colors.black;
    else {
      if (_sb.isCorrectAt(c.pos, c.val) == true)
        c.tClr = Colors.black;
      else
        c.tClr = Colors.red;
    }
  }

  Color getColor(final int idx) {
    final List clrs = [
      Colors.lightGreen,
      Colors.lightBlue,
      Colors.lightBlueAccent,
      Colors.lime,
      Colors.blueGrey,
      Colors.teal,
      Colors.brown,
      Colors.indigo,
      Colors.white,
      Colors.orangeAccent,
    ];
    return (idx % 2 == 0) ? Colors.grey : Colors.black12;
  }
  void _showCustomMenu( SudokuCell _cell) {
    // Let us show the pop up menu ONLY if the cell is fillable i.e
    // - It is empty OR
    // - Not already  specified in input

    if (_sb.isInInput(_cell.index, _cell.val)) return;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject();

    showMenu(
        context: context,
        items: <PopupMenuEntry<String>>[PlusMinusEntry(_sb.getNRows())],
        position: RelativeRect.fromRect(
            _tapPosition &
            const Size(40, 40), // smaller rect, the touch area
            Offset.zero & overlay.size // Bigger rect, the entire screen
        ))
    // This is how you handle user selection
        .then<void>((String gval) {
      // delta would be null if user taps on outside the popup menu
      // (causing it to close without making selection)
      if (gval == null) return;

      setState(() {
        if (gval == 'X') {
          _sb.undo();
          _cell.val = _sb.getValAtIndex(_cell.index);
        } else {
         _sb.setValAt(_cell.pos, gval);
          _cell.val = gval;
        }
      //  context.read<SudokuBoard>().highlightCorrect(_cell);
      });
    });

    // Another option:
    //
    // final delta = await showMenu(...);
    //
    // Then process `delta` however you want.
    // Remember to make the surrounding function `async`, that is:
    //
    // void _showCustomMenu() async { ... }
  }

  void _storePosition(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  Widget buildSquare( SudokuCell _cell) {
    return Center(
      child: AnimatedOpacity(
        opacity: _cell.opacity,
        curve: Curves.bounceIn,
        duration: Duration(seconds: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GestureDetector(

              onLongPress: () => _changeOpacity(_cell),
              // This does not give the tap position ...
              onTap: () => highlightPeers(_cell),
        //_showCustomMenu(_cell),
              // Have to remember it on tap-down.
              onTapDown: _storePosition,

              child: Container(
                color: _cell.clr,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(5.0),
                    child: Text(
                      _cell.val,
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: _cell.tClr),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

  }
  SudokuCell getCellAt(final int i)
  {
    return _ScreenGrid[i];
  }
void initGrid(){

    //first lets solve it internally!
    _sb.solve();
    logger.i("WE NOW HAVE GRID ${_sb.getInputAsString()}");
    _ScreenGrid = List.generate(_sb.getNRows() * _sb.getNCols(), (index) {
      logger.i("GETTING ELEM $index");
      //  return new MyHomePage(
      return
        new SudokuCell(
            index,
            _sb.getPosByIndex(index),
            _sb.getValAtIndex(index),
            getColor(_sb.getBlockIdByIndex(index)),
            _sb.isInInput(index, _sb.getValAtIndex(index))
                ? Colors.blue
                : Colors.black,
            1.0);

    });
 logger.i("GOT A GRID for input ${_sb.getInputAsString()}");
  }
  List<Widget> setupScreenGrid() {
   return  List.generate(_sb.getNRows() * _sb.getNCols(), (index) {
      //  return new MyHomePage(
      return buildSquare(
       _ScreenGrid[index]
      );
    });
  }
  void _changeOpacity(SudokuCell _cell) {
    setState(() =>
      _cell.opacity = 0.6

    );
  }

  @override
  Widget build(BuildContext context) {
    logger.i("BUILD CALLED!!");

    return MaterialApp(
      title: 'Popup Menu Usage',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Sudoku'),
        ),
        body: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              // padding: const EdgeInsets.all(8.0),
              // margin: const EdgeInsets.all(8.0),
              // decoration: BoxDecoration(
              //     border: Border.all(color: Colors.black, width: 2.0)),
              child: GridView.count(
                  crossAxisCount: _sb.getNRows()

                  ,
                  //  padding: const EdgeInsets.all(20),
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  children:  setupScreenGrid()
              ),
            )
          //    body: MyHomePage(title: 'Popup Menu Usage', num: 1, nGrid: 9)
        ),
      ),
    );
  }
}





class PlusMinusEntry extends PopupMenuEntry<String> {
  @override
  double height = 100;
  int nrows;
  // height doesn't matter, as long as we are not giving
  // initialValue to showMenu().
  PlusMinusEntry(int n) {
    nrows = n;
  }
  @override
  bool represents(String n) => n.length < 2;

  @override
  PlusMinusEntryState createState() => PlusMinusEntryState(nrows);
}

class PlusMinusEntryState extends State<PlusMinusEntry> {
  int nrows;
  PlusMinusEntryState(int n) {
    nrows = n;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: retChildren());
  }
  Expanded newPopupCell(final String s) {
  return new Expanded(
  child: FlatButton(
  onPressed: () {
  Navigator.pop(context, s);
  },
  child: Text(s)));
  }
  List<Expanded> retChildren() {
    return new List<Expanded>.generate(
        nrows, (index) => newPopupCell((index + 1).toString()))
      ..add(newPopupCell('?'))
      ..add(newPopupCell('X'));
  }


}
