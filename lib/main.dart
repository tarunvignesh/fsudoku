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
import 'package:sudoku/components/cell_menu.dart';
import 'package:sudoku/components/common.dart';

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
  //SudokuBrain _sb = new SudokuBrain(r: 4, c: 4, grid: "2... 13..   ..3.  ...2");
  //SudokuBrain _sb = new SudokuBrain(r: 4, c: 4, grid: "2413 1324   4231  314.");

  final TimerDeps = new Dependencies();
  bool paused = false;
  SudokuCell SelectedCell;
  PuzzleBoardProps puzzleProps;

  // SudokuBrain _sb =
  //     new SudokuBrain(r: 6, c: 6, grid: "21--43--------62----34--------34--56");

  SudokuBrain _sb = new SudokuBrain(
      r: 9,
      c: 9,
      grid:
          "003020600900305001001806400008102900700000008006708200002609500800203009005010300");
  //'.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....');

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
  List<SudokuCell> _DragList;
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
      c.spotlight = true;

      Set<String> peersList = _sb.getPeers(c.pos);
      _ScreenGrid.forEach((cell) {
        if (peersList.contains(cell.pos)) {
          //  logger.i("CHANGING OPACITY OF ${cell.pos}");
          cell.opacity = 0.4;
          cell.clr = Colors.lightBlueAccent;
        } else
          cell.opacity = 1.0;
      });
      c.opacity = 0.3;
      if (c.spotlight)
        c.clr = Colors.redAccent[100];
      else
        c.clr = getColor(_sb.getBlockIdByIndex(c.index));
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
      cell.spotlight = false;
      cell.animateblock = false;
      cell.clr = getColor(_sb.getBlockIdByIndex(cell.index));
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

  void showDrag() {
    logger.i("DRAGLIST IS ${_DragList.map((e) => e.index)}");
    clearOpacities();
    setState(() {
      for (var cell in _ScreenGrid) {
        if (cell.index >= _DragList[0].index ||
            cell.index == _DragList[1].index) {
          logger.i("DRAGLIST HAS ${cell.pos}");
          cell.clr = Colors.redAccent;
          cell.opacity = 0.2;
          if (cell.index == _DragList[1].index) break;
        }
      }
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
          if (highLightUnits.contains(cell.pos)) {
            cell.opacity = 0.2;
            cell.animateblock = true;
          }
        });
      });
    }
  }

  void highlightCorrect(SudokuCell c) {
    if (_sb.isValidDigitOnGrid(c.val) == false)
      c.tClr = Colors.black;
    else {
      if (c.isCorrect == true) {
        puzzleProps.incrCorrect();

        c.tClr = Colors.black;
        animatePeer(c);
      } else {
        puzzleProps.incrWrong();
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
  //  return (idx % 2 == 0) ? Colors.brown[100] : Colors.limeAccent;
     return Colors.teal;
  }

  void _showPencilMenuItems(SudokuCell _cell) {
    SelectedCell = _cell;
    BuildContext context = _gk.currentContext;
    if (_sb.isInInput(_cell.index, _cell.val)) return;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject();
    showMenu(
            context: context,
            items: <PopupMenuEntry<String>>[
              NumberPencilEntry(_sb.getNRows(), _cell)
            ],
            // items: List.generate(
            //     _sb.getNRows(),
            //     (index) => PopupMenuItem<String>(
            //         child: newDraggableCell(_cell, (index + 1).toString()),
            //         value: (index + 1).toString())),
            elevation: 8,
            position: RelativeRect.fromRect(
                _tapPosition &
                    const Size(40, 40), // smaller rect, the touch area
                Offset.zero & overlay.size // Bigger rect, the entire screen
                ))
        .then((String gval) {
      if (gval == null) return;

      setState(() {
        logger.i(("GOT IN SS() $gval"));
        if (int.parse(gval) < 0)
          _cell.notedVals.remove(gval[1]);
        else
          _cell.notedVals.add(gval);

        //  context.read<SudokuBoard>().highlightCorrect(_cell);
      });
    });
    // This is how you handle user selectio

    // Another option:
    //
    // final delta = await showMenu(...);
    //
    // Then process `delta` however you want.
    // Remember to make the surrounding function `async`, that is:
    //
    // void _showCustomMenu() async { ... }
  }

  Widget dragCell(final String s) {
    return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        color: Colors.teal,
        elevation: 5,
        child: Text(s,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
  }

  Widget newDraggableCell(final SudokuCell sc, final String s) {
    return new Draggable<String>(
        data: s,
        childWhenDragging: dragCell(s),
        feedback: Container(
            color: Colors.lightGreen,
            child: Text(s, style: TextStyle(fontSize: 30))),
        //feedback: dragCell(s),

        onDragCompleted: () {
          logger.i("DRAG DONE");
        },
        onDragStarted: () {
          print("YO DRAGGING to ${sc.pos}  $s");
        },
        child: dragCell(s));
  }

  void _showCustomMenu(SudokuCell _cell) {
    // Let us show the pop up menu ONLY if the cell is fillable i.e
    // - It is empty OR
    // - Not already  specified in input
    SelectedCell = _cell;
    if (_sb.isInInput(_cell.index, _cell.val)) return;
    BuildContext context = _gk.currentContext;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject();
    showMenu(
            context: context,
            items: <PopupMenuEntry<String>>[
              NumberTapEntry(_sb.getNRows(), _cell)
            ],
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
          _cell.val = gval;

          _sb.setValAt(_cell.pos, gval);
          //   _cell.notedVals.add(gval);
        }
        _cell.isCorrect = _sb.isCorrectAt(_cell.pos, _cell.val);
        if(_cell.isCorrect)
          _cell.notedVals.clear();
        highlightCorrect(_cell);
        if (isSolved()) {
          TimerDeps.stopwatch.stop();
          AwesomeDialog(
            context: context,
            dialogType: DialogType.SUCCES,
            animType: AnimType.BOTTOMSLIDE,
            title: 'Puzzle solved!',
            btnOkText: 'New Puzzle',
            btnOkColor: Colors.blue,
            btnCancelColor: Colors.blue,
            btnCancelText: 'Dismiss',
            desc:
                'Solved board in ${puzzleProps.movesWrong + puzzleProps.movesCorrect} moves!.\n And took ${TimerDeps.stopwatch.elapsed.inMinutes}: ${TimerDeps.stopwatch.elapsed.inSeconds.round()}',
            btnCancelOnPress: () {},
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

  void spotlightCell(final SudokuCell cell) {
    setState(() {
      cell.spotlight = true;
    });
  }

  BoxDecoration getBoxDecorationForSquare(final SudokuCell _cell) {
    bool leftBold = false;
    bool rightBold = false;
    bool topBold = false;
    bool botBold = false;
    final cBlkId = _sb.getBlockIdByIndex(_cell.index);

    const double borderWidth = 1.0;
    const double blockSepWidth = 2.0;
    final Color borderColor = Colors.transparent;
    final Color blockEdgeColor = Colors.red;
    if (_cell.pos[1] == '1' ||
        ((_cell.index - 1) > -1 &&
            _sb.getBlockIdByIndex(_cell.index - 1) != cBlkId)) {
      leftBold = true;
    }
    if (_cell.pos[1] == _sb.getNCols().toString() ||
        ((_cell.index + 1) < _sb.getNCols() &&
            _sb.getBlockIdByIndex(_cell.index + 1) != cBlkId)) {
      rightBold = true;
    }
    if (_cell.pos[0] == 'A' ||
        ((_cell.index - (_sb.getNRows())) > -1 &&
            _sb.getBlockIdByIndex(_cell.index - (_sb.getNRows())) != cBlkId)) {
      topBold = true;
    }
    if (_cell.pos[0] == _sb.rows[_sb.getNRows() - 1] ||
        ((_cell.index + _sb.getNCols()) < _sb.getNCols() &&
            _sb.getBlockIdByIndex(_cell.index + _sb.getNCols()) != cBlkId)) {
      botBold = true;
    }
    return BoxDecoration(
        color: _cell.clr,
        //   borderRadius: BorderRadius.all(Radius.circular(10)),
        //  borderRadius: BorderRadius.only(topLeft: Radius.circular(10) ),
        border: Border(
          top: topBold
              ? BorderSide(width: blockSepWidth, color: blockEdgeColor)
              : BorderSide(color: borderColor, width: borderWidth),
          bottom: botBold
              ? BorderSide(width: blockSepWidth, color: blockEdgeColor)
              : BorderSide(color: borderColor, width: borderWidth),
          left: leftBold
              ? BorderSide(width: blockSepWidth, color: blockEdgeColor)
              : BorderSide(color: borderColor, width: borderWidth),
          right: rightBold
              ? BorderSide(width: blockSepWidth, color: blockEdgeColor)
              : BorderSide(color: borderColor, width: borderWidth),
        ));
  }

  Widget buildSquare(SudokuCell _cell) {
    _cell.isCorrect = _sb.isCorrectAt(_cell.pos, _cell.val);
    return RotatedBox(
      // padding: const EdgeInsets.all(8.0),
      quarterTurns: _cell.notedVals.isNotEmpty? 1:0,

      child: AnimatedOpacity(
          opacity: _cell.opacity,
          curve: (_cell.animateblock == true)
              ? Curves.decelerate
              : Curves.easeInCirc,
          duration:
              Duration(milliseconds: (_cell.animateblock == true) ? 400 : 100),
          child:
              //   children: <Widget>[
              GestureDetector(
                  //    debugPaintPointersEnabled:true,
                  onHorizontalDragStart: (d) {
                    _DragList.clear();
                    _DragList.add(_cell);
                  },
                  onHorizontalDragUpdate: (d) {
                    _DragList.add(_cell);

                    showDrag();
                  },
                  onTapDown: (TapDownDetails d) {
                    _storePosition(d);
                    highlightPeers(_cell);
                  },
                  // onTapUp: (TapUpDetails t) => clearHighLights() ,
                  onTap: () => _showCustomMenu(_cell),
                  onLongPress: () => _showPencilMenuItems(_cell),

                  // This does not give the tap position ...
                  //  onTap: () => _showCustomMenu(_cell) ,
                  //_showCustomMenu(_cell),
                  // Have to remember it on tap-down.
                  //    onTapDown: _storePosition,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 1000),
                    // Provide an optional curve to make the animation feel smoother.
                    curve: Curves.bounceInOut,
                    decoration: getBoxDecorationForSquare(_cell),

                    // BoxDecoration(
                    //     color: _cell.clr,
                    //     border: Border.all(color: Colors.black, width: 3),
                    //     borderRadius: BorderRadius.all(Radius.circular(10))),
                    //    color: _cell.clr,
                    child: Center(
                      child: Container(

                        child: Row(
                          children: [
                          //  _cell.notedVals.isNotEmpty ? FaIcon(FontAwesomeIcons.pencilAlt) : Container(),

                            Text(
                              _cell.notedVals.isNotEmpty
                                  ? _cell.notedVals.join(",")
                                  : _cell.val.toString(),
                              style: TextStyle(
                                  fontSize: _cell.notedVals.isNotEmpty ?  15:20,
                                  fontWeight: FontWeight.w900,
                                  color: _cell.tClr),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ))),
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
    _sb.display();
    logger.i("${_sb.boardDict}");

    if (_sb.isSolved() == false) {
      _sb.displayPuzzle(_sb.getInputAsList());
      logger.i("${_sb.boardDict}");
      ;
      throw ('Cannot not solve the input grid ');
    }
    logger.i("WE NOW HAVE GRID ${_sb.getInputAsString()}} with solution ");
    _sb.display();
    _DragList = List();
    _ScreenGrid = List.generate(_sb.getNRows() * _sb.getNCols(), (index) {
      //logger.i("GETTING ELEM $index");
      //  return new MyHomePage(
      return new SudokuCell(
          index,
          _sb.getPosByIndex(index),
          _sb.getValAtIndex(index),
          getColor(_sb.getBlockIdByIndex(index)),
          _sb.isInInput(index, _sb.getValAtIndex(index))
              ? Colors.indigo
              : Colors.black,
          1.0,
          Set());
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
    setState(() => _cell.opacity = 0.0);
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
                                            puzzleProps.movesWrong.toString(),
                                            style: TextStyle(
                                                color: Colors.white))),
                                  ],
                                ),
                              ],
                            ),
                          )),
                    ])),
                Expanded(
                  flex: 4,
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

                      child: Stack(
                        children: <Widget>[
                          // Card(
                          //   color: Colors.orangeAccent[50],
                          //   child: Column(
                          //       mainAxisAlignment:
                          //           MainAxisAlignment.spaceEvenly,
                          //       children: List.generate(
                          //           sqrt(_sb.getNCols()).floor() - 1,
                          //           (index) => Container(
                          //               // child: buildSquare(SudokuCell(
                          //               //     0,
                          //               //     'A0',
                          //               //     '',
                          //               //     Colors.transparent,
                          //               //     Colors.transparent,
                          //               //     0.0,
                          //               //     Set<String>())),
                          //               //     margin: const EdgeInsets.all(15.0),
                          //               //   padding: const EdgeInsets.all(3.0),
                          //               decoration: BoxDecoration(
                          //                   border:
                          //                       Border.all(color: Colors.blue)),
                          //               child: Container()))),
                          // ),
                          // Container(
                          //   color: Colors.pink[90],
                          //   child: Row(
                          //       mainAxisAlignment:
                          //           MainAxisAlignment.spaceEvenly,
                          //       //     crossAxisAlignment: CrossAxisAlignment.baseline,
                          //       children: List.generate(
                          //           sqrt(_sb.getNRows()).floor() - 1,
                          //           (index) => Container(
                          //               // child: buildSquare(SudokuCell(
                          //               //     0,
                          //               //     'A0',
                          //               //     '',
                          //               //     Colors.transparent,
                          //               //     Colors.transparent,
                          //               //     0.0,
                          //               //     Set<String>())),
                          //               //     margin: const EdgeInsets.all(15.0),
                          //               //   padding: const EdgeInsets.all(3.0),
                          //               decoration: BoxDecoration(
                          //                   border: Border.all(
                          //                       color: Colors.green)),
                          //               child: Container()))),
                          // ),
                          CustomScrollView(
                            primary: false,
                            slivers: <Widget>[
                              SliverPadding(
                                padding: const EdgeInsets.all(4),
                                sliver: SliverGrid.count(
                                    crossAxisSpacing: 2,
                                    mainAxisSpacing: 2,
                                    crossAxisCount: _sb.getNRows(),
                                    children: setupScreenGrid()),
                              ),
                            ],
                          ),
                        ],
                      )),
                ),
                // Expanded(
                //     flex: 1,
                //     child: Card(
                //       color: Colors.pinkAccent,
                //       shape: RoundedRectangleBorder(
                //           borderRadius: BorderRadius.circular(15.0)),
                //       child: Container(
                //           child: Row(
                //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //               children: List.generate(
                //                   3,
                //                   (index) => new Draggable<String>(
                //                       data: index.toString(),
                //                       feedback: Container(
                //                           color: Colors.blue,
                //                           child: Text(index.toString())),
                //                       childWhenDragging: Container(
                //                           color: Colors.blue,
                //                           child: Text(index.toString())),
                //                       child: Container(
                //                           color: Colors.blue,
                //                           child: Text(index.toString())))))
                //           // color: Colors.lightBlue,
                //           ),
                //     )),
                // Expanded(
                //   flex: 1,
                //   child: DragTarget<String>(builder:
                //       (context, List<String> candidateData, rejectedData) {
                //     logger.i("WE ARE IN DRAGTARGET $candidateData");
                //
                //     return Card(
                //       color: Colors.teal,
                //       shape: RoundedRectangleBorder(
                //           borderRadius: BorderRadius.circular(15.0)),
                //       child: Container(
                //           // color: Colors.lightBlue,
                //           ),
                //     );
                //   }, onAccept: (String data) {
                //     setState(() {
                //       logger.i("GOT DATA $data");
                //     });
                //   }, onWillAccept: (String data) {
                //     return true;
                //   }),
                // )
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
