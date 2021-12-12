import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sudoku/components/SudokuBrain.dart';
import 'package:sudoku/components/common.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class NumberTapEntry extends PopupMenuEntry<String> {
  @override
  double height = 100;
  int nrows;
  SudokuCell sc;
  // height doesn't matter, as long as we are not giving
  // initialValue to showMenu().
  NumberTapEntry(int n, SudokuCell c) {
    nrows = n;
    sc = c;
  }
  @override
  bool represents(String n) => n.length < 2;

  @override
  NumberTapEntryState createState() => NumberTapEntryState(nrows, sc);
}

class NumberTapEntryState extends State<NumberTapEntry> {
  int nrows;
  SudokuCell sc;
  NumberTapEntryState(int n, SudokuCell c) {
    nrows = n;
    sc = c;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Row(children: retChildren()));
  }

  Expanded newPopupCell(final String s) {
    return new Expanded(
        // data: s,
        // childWhenDragging: Container(),
        // feedback: Text(s),
        child: FlatButton(
            onPressed: () {
              Navigator.pop(context, s);
            },
            child: Text(s)));
  }

  List<Widget> retChildren() {
    List<Expanded> lst = List<Expanded>.generate(
        nrows, (index) => newPopupCell((index + 1).toString()))
      ..add(newPopupCell('?'));
    //  ..add(newPopupCell('X'));
    // if (sc.val != '.' && sc.notedVals != null) {
    //   sc.notedVals.forEach((e) {
    //     lst.removeAt(int.parse(e) - 1);
    //   });
    // }
    return lst;
  }
}

class NumberPencilEntry extends PopupMenuEntry<String> {
  @override
  double height = 100;
  int nrows;
  SudokuCell sc;
  // height doesn't matter, as long as we are not giving
  // initialValue to showMenu().
  NumberPencilEntry(int n, SudokuCell c) {
    nrows = n;
    sc = c;
  }

  @override
  bool represents(String n) => n.length < 2;

  @override
  NumberPencilEntryState createState() => NumberPencilEntryState(nrows, sc);
}

class NumberPencilEntryState extends State<NumberPencilEntry> {
  int nrows;
  SudokuCell sc;
  NumberPencilEntryState(int n, SudokuCell c) {
    nrows = n;
    sc = c;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        color: Colors.blueGrey,
        elevation: 10,
        child: Row(
            children: retChildren()
              ..insert(
                  0,
                  Expanded(
                      child: CircleAvatar(
                          child: FaIcon(FontAwesomeIcons.penFancy))))));

    // return SafeArea(child: Row(children: retChildren()));
  }

  Expanded newPopupCell(final String s) {
    bool alreadyPencilled = sc.notedVals.contains(s);
    return new Expanded(
        // data: s,
        // childWhenDragging: Container(),
        // feedback: Text(s),
        child: Column(children: <Widget>[
      IconButton(
        onPressed: () {
          print("YO IN PRESSED $alreadyPencilled");
          if (alreadyPencilled)
            Navigator.pop(context, "-" + s);
          else
            Navigator.pop(context, s);
        },
        icon: alreadyPencilled
            ? FaIcon(FontAwesomeIcons.eraser)
            : FaIcon(FontAwesomeIcons.pencilAlt),
      ),
      Text(s)
    ]));
  }

  List<Widget> retChildren() {
    List<Expanded> lst = List<Expanded>.generate(
        nrows, (index) => newPopupCell((index + 1).toString()));
    // if (sc.val != '.' && sc.notedVals != null) {
    //   sc.notedVals.forEach((e) {
    //     lst.removeAt(int.parse(e) - 1);
    //   });
    //  }
    return lst;
  }
}

// class NumberDragEntry extends PopupMenuEntry<String> {
//   @override
//   double height = 100;
//   int nrows;
//   SudokuCell sc;
//   // height doesn't matter, as long as we are not giving
//   // initialValue to showMenu().
//   NumberDragEntry(int n, SudokuCell c) {
//     nrows = n;
//     sc = c;
//   }
//   // @override
//   bool represents(String n) => true;
//
//   @override
//   NumberDragEntryState createState() => NumberDragEntryState(nrows, sc);
// }
//
// class NumberDragEntryState extends State<NumberDragEntry> {
//   int nrows;
//   SudokuCell sc;
//   NumberDragEntryState(int n, SudokuCell c) {
//     nrows = n;
//     sc = c;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     print("CONTEXT IN NuDrE is $context");
//     return Card(
//         shape:
//             RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
//         color: Colors.blueGrey,
//         elevation: 10,
//         child: Row(children: retDraggableChildren()));
//   }
//
//   Widget dragCell(final String s) {
//     return Card(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(15.0),
//         ),
//         color: Colors.teal,
//         elevation: 5,
//         child: Text(s,
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));
//   }
//
//   Widget newDraggableCell(final String s) {
//     return Draggable<String>(
//         data: s,
//         childWhenDragging: Container(),
//         feedback: dragCell(s),
//         onDragStarted: () {
//           print("YO DRAGGING to ${sc.pos}  $s");
//         },
//         child: dragCell(s));
//   }
//
//   List<Widget> retDraggableChildren() {
//     List<Draggable> lst = List<Draggable>.generate(
//         nrows, (index) => newDraggableCell((index + 1).toString()));
//
//     return lst;
//   }
// }
