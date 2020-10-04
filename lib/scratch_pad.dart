import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Popup Menu Usage',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: MyHomePage(title: 'Popup Menu Usage'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState(5,9);
}

class _MyHomePageState extends State<MyHomePage> {
  int  _count = 0;
  int _numOpt = 0;
  var _tapPosition;
  _MyHomePageState(final int c,final int n) {
     _count = c;
     _numOpt = n;
  }
  void _showCustomMenu() {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject();

    showMenu(
        context: context,
        items: <PopupMenuEntry<int>>[PlusMinusEntry(_numOpt)],
        position: RelativeRect.fromRect(
            _tapPosition & const Size(40, 40), // smaller rect, the touch area
            Offset.zero & overlay.size   // Bigger rect, the entire screen
        )
    )
    // This is how you handle user selection
        .then<void>((int delta) {
      // delta would be null if user taps on outside the popup menu
      // (causing it to close without making selection)
      if (delta == null) return;

      setState(() {
        _count = delta;
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
      appBar: AppBar(
        title: Text(widget.title),
      ),
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

              child: Container(
                color: Colors.amberAccent,
                padding: const EdgeInsets.all(100.0),
                child: Text(
                  '$_count',
                  style: const TextStyle(
                      fontSize: 100, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlusMinusEntry extends PopupMenuEntry<int> {
  @override
  double height = 100;
  int nrows = 0;
  // height doesn't matter, as long as we are not giving
  // initialValue to showMenu().
  PlusMinusEntry(int n ) {
    nrows = n;
  }
  @override
  bool represents(int n) => n == 1 || n == -1;

  @override
  PlusMinusEntryState createState() => PlusMinusEntryState(nrows );
}

class PlusMinusEntryState extends State<PlusMinusEntry> {
 int nrows = 0;
  PlusMinusEntryState(int n ) {
    nrows = n;
  }
  void _plus1() {
    // This is how you close the popup menu and return user selection.
    Navigator.pop<int>(context, 1);
  }

  void _minus1() {
    Navigator.pop<int>(context, -1);
  }
  void _send(final int a) {
    Navigator.pop<int>(context, a);
  }
  @override
  Widget build(BuildContext context) {
    return Row(
      children: retChildren()
      // children: <Widget>[
      //   Expanded(child: FlatButton(onPressed: () { Navigator.pop(context,5); }  , child: Text('5'))),
      //   Expanded(child: FlatButton(onPressed: _minus1, child: Text('2'))),
      //   Expanded(child: FlatButton(onPressed: _plus1, child: Text('3'))),
      //   Expanded(child: FlatButton(onPressed: _minus1, child: Text('4'))),
      //
      //   Expanded(child: FlatButton(onPressed: _minus1, child: Text('5'))),
      //   Expanded(child: FlatButton(onPressed: _plus1, child: Text('6'))),
      //   Expanded(child: FlatButton(onPressed: _minus1, child: Text('7'))),
      //   Expanded(child: FlatButton(onPressed: _plus1, child: Text('8'))),
      //   Expanded(child: FlatButton(onPressed: _minus1, child: Text('9'))),
      // ],
    );
  }
  List<Expanded>  retChildren() {
    return new List<Expanded>.generate(nrows, (index) => new Expanded(child: FlatButton(onPressed: ()
    {
      Navigator.pop(context,index+1);
    }
    ,child: Text((index+1).toString()),
    )) ) ;
  }
}
