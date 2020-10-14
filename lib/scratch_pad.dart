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

  SudokuCell(this.index, this.pos, this.val, this.clr, this.tClr);
}

class MyHomePage extends StatefulWidget {
  MyHomePage(
      {Key key, this.title,this.cell, this.nGrid})
      : super(key: key);

  final String title;
  SudokuCell cell;
  int nGrid;
  @override
  _MyHomePageState createState() => _MyHomePageState( cell, nGrid);
}

class _MyHomePageState extends State<MyHomePage> {
  SudokuCell _cell;
  int _numOpt = 0;
  var _tapPosition;
  _MyHomePageState( final SudokuCell sc, final int n) {
    _cell = sc;
    _numOpt = n;
  }
  void _showCustomMenu() {
    // Let us show the pop up menu ONLY if the cell is fillable i.e
    // - It is empty OR
    // - Not already  specified in input
    context.read<SudokuBoard>().highlightPeers(_cell);

    if (context.read<SudokuBoard>().sb.isInInput(_cell.index, _cell.val)) return;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject();

    showMenu(
        context: context,
        items: <PopupMenuEntry<String>>[PlusMinusEntry(_numOpt)],
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
          context.read<SudokuBoard>().sb.undo();
          _cell.val = context.read<SudokuBoard>().sb.getValAtIndex(_cell.index);
        } else {
          context.read<SudokuBoard>().sb.setValAt(_cell.pos, gval);
          _cell.val = gval;
        }
        context.read<SudokuBoard>().highlightCorrect(_cell);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(widget.title),
      // ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            GestureDetector(
              // This does not give the tap position ...

              onTap:  _showCustomMenu,
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
}
class SudokuBoard   with ChangeNotifier{
  var logger = Logger(
    printer: PrettyPrinter(),
  );
  int _nrows  ;
   int _ncols ;
   String _input = "";
   SudokuBrain _sb ;

   SudokuBrain get sb => _sb;
  List<MyHomePage> _ScreenGrid;

   List<MyHomePage> get ScreenGrid => _ScreenGrid;

   String get input => _input;

   SudokuBoard(this._ncols,this._nrows,this._input) {
     _sb = new SudokuBrain(r: _nrows, c: _ncols, grid: _input);
     sb.solve();

   //  setupScreenGrid();

   }
   void highlightCorrect ( SudokuCell c ){
     if(_sb.isValidDigitOnGrid(c.val) == false )

       c.tClr = Colors.black;
     else {
       if (_sb.isCorrectAt(c.pos, c.val) == true)
         c.tClr = Colors.black;
       else
         c.tClr = Colors.red;
     }
      notifyListeners();
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
     void setupScreenGrid() {
       _ScreenGrid = List.generate(_sb.getNRows() * _sb.getNCols(), (index) {
         return new MyHomePage(
             title: 'Popup Menu Usage',
             cell: new SudokuCell(
                 index,
                 _sb.getPosByIndex(index),
                 _sb.getValAtIndex(index),
                 getColor(_sb.getBlockIdByIndex(index)),
                 _sb.isInInput(index, _sb.getValAtIndex(index))
                     ? Colors.blue
                     : Colors.black),
             nGrid: _nrows);


       });
     }
      void reset() {
        _sb.reset();

        setupScreenGrid();

        notifyListeners();

      }
      // void clearHighlightPeers() {
      //   ScreenGrid.forEach((element) {
      //         element.cell.
      //       }
      //       notifyListeners();
      //
      //   }
      void highlightPeers( final SudokuCell c) {
        Set<String> peersList = _sb.getPeers(c.pos);
        ScreenGrid.forEach((element) {
          if (peersList.contains(element.cell.pos)) {
            logger.i("CHANGING COLOR OF ${element.cell.pos}");
            element.cell.clr = Colors.lightGreen;
          }
        });
    notifyListeners();
      }

   int get nrows => _nrows;

   int get ncols => _ncols;


}



void main() {
  Logger.level = Level.info;

  String nine_ ='.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....';
  SudokuBoard board = new  SudokuBoard(9, 9, nine_)..setupScreenGrid();
  runApp (
    MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => board ),
        ],child: SudokuApp()

),

);
}

class SudokuApp extends StatefulWidget {
  @override
  _SudokuAppState createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> {
  List<MyHomePage> ScreenGrid = List<MyHomePage>();

  @override
  void initState() {
    //  sb = new SudokuBrain(r: 4, c: 4, grid: "2... 13..   ..3.  ...2");

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
                  crossAxisCount: context
                      .watch<SudokuBoard>()
                      .sb.getNRows(),
                  //  padding: const EdgeInsets.all(20),
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  children: context
                      .watch<SudokuBoard>()
                      .ScreenGrid
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
