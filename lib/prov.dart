// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:floating_action_bubble/floating_action_bubble.dart';
/// This is a reimplementation of the default Flutter application using provider + [ChangeNotifier].

void main() {
  runApp(
    /// Providers are above [MyApp] instead of inside it, so that tests
    /// can use [MyApp] while mocking the providers
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Counter(4,"KUTTE")),
      ],
      child: MyApp(),
    ),
  );
}

/// Mix-in [DiagnosticableTreeMixin] to have access to [debugFillProperties] for the devtool


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}
class Counter with ChangeNotifier, DiagnosticableTreeMixin {
  int _count = 0;
  int get count => _count;
  String _greeting = "";

  String get greeting => _greeting;
  Counter(this._count,this._greeting);
  void increment() {
    _count++;
    notifyListeners();
  }
  void decrement() {
    _count--;
    notifyListeners();
  }
  void reset() {
    _count = 0;
    notifyListeners();
  }
  /// Makes `Counter` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('count', count));
  }
}
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>  with SingleTickerProviderStateMixin {
  Animation<double> _animation;
  AnimationController _animationController;

  @override
  void initState(){

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 260),
    );

    final curvedAnimation = CurvedAnimation(curve: Curves.easeInOut, parent: _animationController);
    _animation = Tween<double>(begin: 0, end: 1).animate(curvedAnimation);

    super.initState();


  }
  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: const Text('Example'),
      ),
      body: Center(

        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),

            /// Extracted as a separate widget for performance optimization.
            /// As a separate widget, it will rebuild independently from [MyHomePage].
            ///
            /// This is totally optional (and rarely needed).
            /// Similarly, we could also use [Consumer] or [Selector].
            const Count(),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   /// Calls `context.read` instead of `context.watch` so that it does not rebuild
      //   /// when [Counter] changes.
      //   onPressed: () => context.read<Counter>().decrement(),
      //   tooltip: 'Increment',
      //   child: const Icon(Icons.add),
      // ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        //Init Floating Action Bubble

        //Init Floating Action Bubble
        floatingActionButton: FloatingActionBubble(
          // Menu items
          items: <Bubble>[

            // Floating action menu item
            Bubble(
              title:"Reset",
              iconColor :Colors.white,
              bubbleColor : Colors.blue,
              icon:Icons.cake_sharp,
              titleStyle:TextStyle(fontSize: 16 , color: Colors.white),
              onPress: () {
                context.read<Counter>().reset();
                _animationController.reverse();
              },
            ),
            // Floating action menu item
            Bubble(
              title:"Subtract",
              iconColor :Colors.white,
              bubbleColor : Colors.blue,
              icon:Icons.auto_delete,
              titleStyle:TextStyle(fontSize: 16 , color: Colors.white),
              onPress: () {
                context.read<Counter>().decrement();
                _animationController.reverse();
              },
            ),
            //Floating action menu item
            Bubble(
              title:"Add",
              iconColor :Colors.white,
              bubbleColor : Colors.blue,
              icon:Icons.add,
              titleStyle:TextStyle(fontSize: 16 , color: Colors.white),
              onPress: () {
                context.read<Counter>().increment();

                _animationController.reverse();
              },
            ),
          ],

          // animation controller
          animation: _animation,

          // On pressed change animation state
          onPress: () => _animationController.isCompleted
              ? _animationController.reverse()
              : _animationController.forward(),

          // Floating Action button Icon color
          iconColor: Colors.blue,

          // Flaoting Action button Icon
         // iconData: const IconData(0xe900, fontFamily: 'icomoon'),
          animatedIconData: AnimatedIcons.add_event,
        )

    );
  }
}

class Count extends StatelessWidget {
  const Count({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(

      /// Calls `context.watch` to make [MyHomePage] rebuild when [Counter] changes.
        '${context.watch<Counter>().count}',
        style: Theme.of(context).textTheme.headline4);
  }
}