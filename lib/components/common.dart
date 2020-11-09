import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SudokuCell {
  int index;
  String pos;
  String val;
  Color clr;
  Color tClr;
  Set<String> notedVals;
  double opacity = 1.0;

  SudokuCell(this.index, this.pos, this.val, this.clr, this.tClr, this.opacity,
      this.notedVals);
}

// class DraggablePopupMenuItem extends Draggable<String>
//     with PopupMenuItem<String> {
//   DraggablePopupMenuItem(Widget child, String value)
//       : super(child: child, value: value);
// }
class DraggablePopupMenuItem extends PopupMenuItem<String> {
  DraggablePopupMenuItem(Widget child, String value)
      : super(child: child, value: value);
}

class PuzzleBoardProps {
  int _movesCorrect = 0;
  int _movesWrong = 0;

  int _puzzleDifficulty = 0;
  double _timeTaken;
  int _assistMode = 0;
  void reset() {
    _movesCorrect = 0;
    _movesWrong = 0;
    _timeTaken = 0.0;
    _assistMode = 0;
  }

  void incrCorrect() {
    _movesCorrect++;
  }

  void incrWrong() {
    _movesWrong++;
  }

  int get movesCorrect => _movesCorrect;

  int get movesWrong => _movesWrong;

  int get puzzleDifficulty => _puzzleDifficulty;

  double get timeTaken => _timeTaken;

  int get assistMode => _assistMode;
}
