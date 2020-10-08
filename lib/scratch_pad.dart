import 'package:flutter/material.dart';
import 'package:sudoku/components/SudokuBrain.dart';

class SudokuCell {
  int index;
  String pos;
  String val;
  Color clr;
  Color tClr;

  SudokuCell(this.index, this.pos, this.val, this.clr, this.tClr);
}

void main() => runApp(SudokuApp());

class SudokuApp extends StatefulWidget {
  @override
  _SudokuAppState createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> {
  SudokuBrain sb;
  List<MyHomePage> ScreenGrid = List<MyHomePage>();
  String nine_;

  @override
  void initState() {
    nine_ =
        '.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....';
    sb = new SudokuBrain(r: 9, c: 9, grid: nine_);
    sb.solve();

    ScreenGrid = List.generate(sb.getNRows() * sb.getNCols(), (index) {
      return new MyHomePage(
          title: 'Popup Menu Usage',
          sb: sb,
          cell: new SudokuCell(
              index,
              sb.getPosByIndex(index),
              sb.getValAtIndex(index),
              getColor(sb.getBlockIdByIndex(index)),
              sb.isInInput(index, sb.getValAtIndex(index))
                  ? Colors.blue
                  : Colors.black),
          nGrid: sb.getNRows());
    });
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
                  crossAxisCount: sb.getNRows(),
                  //  padding: const EdgeInsets.all(20),
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  // Generate 100 widgets that display their index in the List.
                  children: ScreenGrid),
            ),
          )
          //    body: MyHomePage(title: 'Popup Menu Usage', num: 1, nGrid: 9)
          ),
    );
  }

  void reRenderPuzzle(final SudokuCell c) {
    //highlight peers
    List<String> peersList = sb.getPeers(c.pos);
    ScreenGrid.forEach((element) {
      if (peersList.contains(element.cell.pos))
        element.cell.clr = Colors.lightGreen;
    });
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
}

class MyHomePage extends StatefulWidget {
  MyHomePage(
      {Key key, this.parentCb, this.title, this.sb, this.cell, this.nGrid})
      : super(key: key);

  final String title;
  Function parentCb;
  SudokuBrain sb;
  SudokuCell cell;
  int nGrid;
  @override
  _MyHomePageState createState() => _MyHomePageState(sb, cell, nGrid);
}

class _MyHomePageState extends State<MyHomePage> {
  SudokuCell _cell;
  int _numOpt = 0;
  var _tapPosition;
  SudokuBrain sb;
  _MyHomePageState(SudokuBrain s, final SudokuCell sc, final int n) {
    sb = s;
    _cell = sc;
    _numOpt = n;
  }
  void _showCustomMenu() {
    // Let us show the pop up menu ONLY if the cell is fillable i.e
    // - It is empty OR
    // - Not already  specified in input
    if (sb.isInInput(_cell.index, _cell.val)) return;
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
          sb.undo();
          _cell.val = sb.getValAtIndex(_cell.index);
        } else {
          sb.setValAt(_cell.pos, gval);
          _cell.val = gval;
        }
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

              onTap: _showCustomMenu,
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

  List<Expanded> retChildren() {
    return new List<Expanded>.generate(
        nrows, (index) => newPopupCell((index + 1).toString()))
      ..add(newPopupCell('?'))
      ..add(newPopupCell('X'));
  }

  Expanded newPopupCell(final String s) {
    return new Expanded(
        child: FlatButton(
            onPressed: () {
              Navigator.pop(context, s);
            },
            child: Text(s)));
  }
}
