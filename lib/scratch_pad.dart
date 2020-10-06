import 'package:flutter/material.dart';
import 'package:sudoku/components/SudokuBrain.dart';

class SudokuCell {
  int index;
  String pos;
  String val;
  Color clr;

  SudokuCell(this.index, this.pos, this.val, this.clr);
}

void main() => runApp(SudokuApp());

class SudokuApp extends StatefulWidget {
  @override
  _SudokuAppState createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> {
  SudokuBrain sb;
  var nine_ =
      '.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....';
  @override
  Widget build(BuildContext context) {
    sb = new SudokuBrain(r: 9, c: 9, grid: nine_);
    sb.solve();

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
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2.0)),
              child: GridView.count(
                  crossAxisCount: sb.getNRows(),

                  // Generate 100 widgets that display their index in the List.
                  children:
                      List.generate(sb.getNRows() * sb.getNCols(), (index) {
                    return new
                        // Text(
                        //   index.toString(),
                        //   style: Theme.of(context).textTheme.headline5,
                        MyHomePage(
                            title: 'Popup Menu Usage',
                            sb: sb,
                            cell: new SudokuCell(
                                index,
                                sb.getPosByIndex(index),
                                sb.getValAtIndex(index),
                                getColor(sb.getBlockIdByIndex(index))),
                            nGrid: sb.getNRows());
                  })),
            ),
          )
          //    body: MyHomePage(title: 'Popup Menu Usage', num: 1, nGrid: 9)
          ),
    );
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
    return (idx % 2 == 0) ? Colors.grey : Colors.white;
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title, this.sb, this.cell, this.nGrid})
      : super(key: key);

  final String title;
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
        .then<void>((String delta) {
      // delta would be null if user taps on outside the popup menu
      // (causing it to close without making selection)
      if (delta == null) return;

      setState(() {
        _cell.val = delta;
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
              onLongPress: _showCustomMenu,
              onTap: _showCustomMenu,
              // Have to remember it on tap-down.
              onTapDown: _storePosition,

              child: GridTile(
                child: Container(
                  color: _cell.clr,
                  child: Center(
                    child: Container(
                      //  padding: const EdgeInsets.all(10.0),
                      child: Text(
                        _cell.val,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
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
        nrows,
        (index) => new Expanded(
                child: FlatButton(
              onPressed: () {
                Navigator.pop(context, (index + 1).toString());
              },
              child: Text((index + 1).toString()),
            )));
  }
}
