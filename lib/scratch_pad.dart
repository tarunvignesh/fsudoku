import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sudoku/components/SudokuBrain.dart';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:fab_circular_menu/fab_circular_menu.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Timer.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:badges/badges.dart';

class SudokuCell {
  int index;
  String pos;
  String val;
  Color clr;
  Color tClr;
  double opacity = 1.0;

  SudokuCell(this.index, this.pos, this.val, this.clr, this.tClr, this.opacity);
}

class PuzzleBoardProps {
  int _movesCorrect = 0;
  int _movesWrong = 0;

  int get movesCorrect => _movesCorrect;
  int _puzzleDifficulty = 0;
  double _timeTaken;
  int _assistMode = 0;
  void reset() {
    _movesCorrect = 0;
    _movesWrong = 0;
    _timeTaken = 0.0;
    _assistMode = 0;
  }

  int get movesWrong => _movesWrong;

  int get puzzleDifficulty => _puzzleDifficulty;

  double get timeTaken => _timeTaken;

  int get assistMode => _assistMode;
}

void main() {
  Logger.level = Level.info;

  runApp(SudokuApp());
}

class SudokuApp extends StatefulWidget {
  @override
  _SudokuAppState createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> {
  String nine_ =
      '.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....';
  SudokuBrain _sb = new SudokuBrain(r: 4, c: 4, grid: "2... 13..   ..3.  ...2");
  // SudokuBrain _sb = new SudokuBrain(r: 4, c: 4, grid: "2413 1324   4231  314.");

  final TimerDeps = new Dependencies();
  bool paused = false;
  PuzzleBoardProps puzzleProps;
  // SudokuBrain _sb = new SudokuBrain(
  //     r: 9,
  //     c: 9,
  //     grid:
  //         '.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....');

  List<SudokuCell> _ScreenGrid;
  // Assisted mode -> Display only possible values in the pop up menu
  // Animate cells
  // Timer
  // Track mistakes
  // Home page with  Grid SIZE
  // Animated transtions
  // Feedback on mistakes , time up.
  // Proper icons for undo ,
  // Show why wrong by highlinting conflict
  // Enter your number?

  GlobalKey _gk = GlobalKey();
  var _tapPosition;

  // List<MyHomePage> ScreenGrid = List<MyHomePage>();
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  @override
  void initState() {
    //   logger.i("IN INIT STATE got sb ${_sb.getNRows()}");
    initGrid();
    TimerDeps.stopwatch.start();
    paused = false;
    puzzleProps = new PuzzleBoardProps();
    super.initState();
  }

  void highlightPeers(SudokuCell c) {
    //   getSolvedGrid();
    setState(() {
      clearHighLights();
      Set<String> peersList = _sb.getPeers(c.pos);
      _ScreenGrid.forEach((cell) {
        if (peersList.contains(cell.pos)) {
          //  logger.i("CHANGING OPACITY OF ${cell.pos}");
          cell.opacity = 0.4;
        } else
          cell.opacity = 1.0;
      });
      c.opacity = 0.3;
    });

    // _ScreenGrid = tlist;
    //  notifyListeners();
  }

  bool isSolved() {
    return _sb.puzzleSolved();
  }

  void clearOpacities() {
    _ScreenGrid.forEach((cell) {
      cell.opacity = 1;
    });
  }

  void clearHighLights() {
    setState(() {
      clearOpacities();
    });
  }

  void blurGrid(final bool paused) {
    double opacity = paused ? 0.0 : 1.0;
    _ScreenGrid.forEach((cell) {
      cell.opacity = opacity;
    });
  }

  void animatePeer(final SudokuCell c) {
    List<String> highLightUnits = _sb
        .getUnits(c.pos)
        .where((u) => u.every((element) =>
            _sb.getValueAtPos(element) == _sb.getSolutionValAtPos(element)))
        .expand((element) => element)
        .toList();
    if (highLightUnits.isNotEmpty) {
      clearOpacities();
      setState(() {
        _ScreenGrid.forEach((cell) {
          if (highLightUnits.contains(cell.pos)) cell.opacity = 0.2;
        });
      });
    }
  }

  void highlightCorrect(SudokuCell c) {
    if (_sb.isValidDigitOnGrid(c.val) == false)
      c.tClr = Colors.black;
    else {
      if (_sb.isCorrectAt(c.pos, c.val) == true) {
        puzzleProps._movesCorrect++;

        c.tClr = Colors.black;
        animatePeer(c);
      } else {
        puzzleProps._movesWrong++;
        c.tClr = Colors.red;
      }
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
    return (idx % 2 == 0) ? Colors.brown[100] : Colors.limeAccent;
  }

  void _showCustomMenu(SudokuCell _cell) {
    // Let us show the pop up menu ONLY if the cell is fillable i.e
    // - It is empty OR
    // - Not already  specified in input

    if (_sb.isInInput(_cell.index, _cell.val)) return;
    BuildContext context = _gk.currentContext;
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
        highlightCorrect(_cell);
        if (isSolved()) {
          TimerDeps.stopwatch.stop();
          AwesomeDialog(
            context: context,
            dialogType: DialogType.SUCCES,
            animType: AnimType.BOTTOMSLIDE,
            title: 'Puzzle solved!',
            btnOkText: 'Restart Puzzle',
            btnOkColor: Colors.blue,
            btnCancelColor: Colors.blue,
            btnCancelText: 'New Puzzle',
            desc:
                'Solved board in ${puzzleProps._movesWrong + puzzleProps._movesCorrect} moves!.\n And took ${TimerDeps.stopwatch.elapsed.inMinutes}: ${TimerDeps.stopwatch.elapsed.inSeconds.round()}',
            btnCancelOnPress: () {
              setState(() {
                reset();
              });
            },
            btnOkOnPress: () {
              setState(() {
                reset();
              });
            },
          ).show();
          print("SOLVED YO!!");
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

  Widget buildSquare(SudokuCell _cell) {
    return AspectRatio(
      // padding: const EdgeInsets.all(8.0),
      aspectRatio: 0.5,
      child: AnimatedOpacity(
        opacity: _cell.opacity,
        curve: Curves.easeInCirc,
        duration: Duration(milliseconds: 100),
        child:
            //   children: <Widget>[
            GestureDetector(
          //    debugPaintPointersEnabled:true,
          onTapDown: (TapDownDetails d) {
            _storePosition(d);
            highlightPeers(_cell);
          },
          // onTapUp: (TapUpDetails t) => clearHighLights() ,
          onTap: () => _showCustomMenu(_cell),
          // This does not give the tap position ...
          //  onTap: () => _showCustomMenu(_cell) ,
          //_showCustomMenu(_cell),
          // Have to remember it on tap-down.
          //    onTapDown: _storePosition,

          child: Container(
            decoration: BoxDecoration(
                color: _cell.clr,
                border: Border.all(color: Colors.black, width: 3),
                borderRadius: BorderRadius.all(Radius.circular(10))),
            //    color: _cell.clr,
            child: Center(
              child: Container(
                child: Text(
                  _cell.val,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: _cell.tClr),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget fillSquare(final idx) {
    return Card(
      color: Colors.red[100],

      //   padding: const EdgeInsets.all(8),
      child: ConstrainedBox(
        constraints: BoxConstraints.expand(),
        child: Center(
            child: const Text("Y",
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold))),
      ),
    );
  }

  SudokuCell getCellAt(final int i) {
    return _ScreenGrid[i];
  }

  void initGrid() {
    //first lets solve it internally!
    _sb.solve();
    logger.i("WE NOW HAVE GRID ${_sb.getInputAsString()}");
    _ScreenGrid = List.generate(_sb.getNRows() * _sb.getNCols(), (index) {
      logger.i("GETTING ELEM $index");
      //  return new MyHomePage(
      return new SudokuCell(
          index,
          _sb.getPosByIndex(index),
          _sb.getValAtIndex(index),
          getColor(_sb.getBlockIdByIndex(index)),
          _sb.isInInput(index, _sb.getValAtIndex(index))
              ? Colors.indigo
              : Colors.black,
          1.0);
    });
    logger.i("GOT A GRID for input ${_sb.getInputAsString()}");
  }

  List<Widget> setupScreenGrid() {
    return List.generate(_sb.getNRows() * _sb.getNCols(), (index) {
      //  return new MyHomePage(
      return
          //   fillSquare(index);
          buildSquare(_ScreenGrid[index]);
    });
  }

  void _changeOpacity(SudokuCell _cell) {
    setState(() => _cell.opacity = 0.3);
  }

  void reset() {
    _ScreenGrid.clear();
    TimerDeps.stopwatch.reset();
    _sb.reset();
    puzzleProps.reset();
    initGrid();
  }

  @override
  Widget build(BuildContext context) {
    //  logger.i("BUILD CALLED!!");
    return MaterialApp(
      // builder: (context, widget) => ResponsiveWrapper.builder(
      //     maxWidth: 1200,
      //     minWidth: 480,
      //     defaultScale: true,
      //     breakpoints: [
      //       ResponsiveBreakpoint.resize(480, name: MOBILE),
      //       ResponsiveBreakpoint.autoScale(800, name: TABLET),
      //       ResponsiveBreakpoint.resize(1000, name: DESKTOP),
      //     ],
      //     background: Container(color: Color(0xFFF5F5F5))),
      title: 'Popup Menu Usage',
      theme: ThemeData.dark().copyWith(
        primaryColor: Color(0xFF0A0E21),
        scaffoldBackgroundColor: Color(0xFF0A0E21),
      ),
      home: Scaffold(
          // appBar: AppBar(
          //   title: Text('Sudoku'),
          // ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                    flex: 0,
                    child: Row(children: <Widget>[
                      Expanded(
                          flex: 3,
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            //  color: Colors.teal,
                            elevation: 5,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Row(
                                  children: [
                                    FaIcon(FontAwesomeIcons.clock),
                                    TimerText(dependencies: TimerDeps),
                                    IconButton(
                                        color: Colors.pink,
                                        icon: paused
                                            ? FaIcon(FontAwesomeIcons.play)
                                            : FaIcon(FontAwesomeIcons.pause),
                                        onPressed: () {
                                          setState(() {
                                            if (paused) {
                                              TimerDeps.stopwatch.start();
                                              paused = false;
                                            } else {
                                              TimerDeps.stopwatch.stop();
                                              paused = true;
                                            }
                                            blurGrid(paused);
                                          });
                                        }),
                                    Badge(
                                        toAnimate: true,
                                        shape: BadgeShape.circle,
                                        badgeColor: Colors.green,
                                        borderRadius: BorderRadius.circular(8),
                                        badgeContent: Text(
                                            '${puzzleProps.movesCorrect.toString()}',
                                            style: TextStyle(
                                                fontSize: 30,
                                                color: Colors.white))),
                                    Badge(
                                        toAnimate: true,
                                        shape: BadgeShape.circle,
                                        badgeColor: Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                        badgeContent: Text(
                                            '${puzzleProps._movesWrong.toString()}',
                                            style: TextStyle(
                                                color: Colors.white))),
                                  ],
                                ),
                              ],
                            ),
                          )),
                    ])),
                Expanded(
                  flex: 8,
                  child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15.0)),
                      color: const Color(0xFF192A56),
                      elevation: 5,
                      //  decoration: const BoxDecoration(color: Colors.teal),
                      // height: double.infinity,
                      // width: double.infinity,
                      key: _gk,
                      //  color: Colors.indigoAccent,
                      //    padding: const EdgeInsets.all(1.0),
                      //   margin: const EdgeInsets.all(4.0),
                      // decoration: BoxDecoration(
                      //     border: Border.all(color: Colors.black, width: 2.0)),

                      child: CustomScrollView(primary: false, slivers: <Widget>[
                        SliverPadding(
                          padding: const EdgeInsets.all(4),
                          sliver: SliverGrid.count(
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                              crossAxisCount: _sb.getNRows(),
                              children: setupScreenGrid()),
                        ),
                      ])),
                ),
              ],
            ),
          ),
          floatingActionButton: FabCircularMenu(
              alignment: Alignment.bottomCenter,
              ringColor: Colors.white.withAlpha(25),
              fabColor: Colors.white,
              fabMargin: const EdgeInsets.all(16.0),
              animationDuration: const Duration(milliseconds: 100),
              animationCurve: Curves.easeInOutCirc,
              fabIconBorder: CircleBorder(),
              children: <Widget>[
                IconButton(
                    icon: FaIcon(FontAwesomeIcons.affiliatetheme),
                    onPressed: () {
                      setState(() {
                        reset();
                      });
                    }),
                IconButton(
                    icon: Icon(Icons.favorite),
                    onPressed: () {
                      print('Favorite');
                    })
              ])),
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
