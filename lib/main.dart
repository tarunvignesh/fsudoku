import 'dart:io';
import 'dart:math';
import 'package:flutter_grid_button/flutter_grid_button.dart';
import 'package:flutter/material.dart';
import 'package:sudoku/components/SudokuBrain.dart';

void main() => runApp(SudokuApp());

class SudokuApp extends StatefulWidget {
  @override
  _SudokuState createState() => _SudokuState();
}

class _SudokuState extends State<SudokuApp> {
//class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 26);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Sudoku'),
        ),
        body: Builder(builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(18.0),
            child: GridButton(
              textStyle: textStyle,
              borderColor: Colors.red[200],
              borderWidth: 2,
              onPressed: (dynamic val) {
                Scaffold.of(context).showSnackBar(
                  SnackBar(
                    content: Text(val.toString()),
                    duration: Duration(milliseconds: 700),
                  ),
                );
              },
              items: loadPuzzle(),
            ),
          );
        }),
      ),
    );
  }

  List<List<GridButtonItem>> loadPuzzle() {
    String inp = "2... 13..   ..3.  ...2";
    var nine_ =
        '.8..4....3......1........2...5...4.69..1..8..2...........3.9....6....5.....2.....';
    SudokuBrain sb = new SudokuBrain(r: 9, c: 9, grid: nine_);
    sb.solve();
    List<String> inpL = sb.getSolution();
    int idx = 0;
    Random random = new Random();

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
    return List<List<GridButtonItem>>.generate(
        sb.getNRows(),
        (rC) => new List<GridButtonItem>.generate(
            sb.getNCols(),
            (cC) => new GridButtonItem(
                title: inpL[idx++], color: clrs[sb.getBlockId(rC, cC)])));
  }
}
