import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sudoku/components/SudokuBrain.dart';
import 'package:sudoku/components/common.dart';

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
      ..add(newPopupCell('?'))
      ..add(newPopupCell('X'));
    // if (sc.val != '.' && sc.notedVals != null) {
    //   sc.notedVals.forEach((e) {
    //     lst.removeAt(int.parse(e) - 1);
    //   });
    // }
    return lst;
  }
}

class NumberDragEntry extends PopupMenuEntry<String> {
  @override
  double height = 100;
  int nrows;
  SudokuCell sc;
  // height doesn't matter, as long as we are not giving
  // initialValue to showMenu().
  NumberDragEntry(int n, SudokuCell c) {
    nrows = n;
    sc = c;
  }
  @override
  bool represents(String n) => n.length < 2;

  @override
  NumberDragEntryState createState() => NumberDragEntryState(nrows, sc);
}

class NumberDragEntryState extends State<NumberDragEntry> {
  int nrows;
  SudokuCell sc;
  NumberDragEntryState(int n, SudokuCell c) {
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
        child: Row(children: retDraggableChildren()));
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

  Widget newDraggableCell(final String s) {
    return Draggable(
        data: s,
        childWhenDragging: Container(),
        feedback: dragCell(s),
        child: dragCell(s));
  }

  List<Widget> retDraggableChildren() {
    List<Draggable> lst = List<Draggable>.generate(
        nrows, (index) => newDraggableCell((index + 1).toString()));

    return lst;
  }
}
