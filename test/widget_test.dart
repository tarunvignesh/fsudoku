import 'package:fsudoku/engine/variant.dart';
import 'package:fsudoku/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends a key through the real shortcut handling, as a player would.
Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Reads the digits currently painted on the board.
///
/// The board is a single canvas, so there is nothing in the widget tree to
/// query; the status line is the observable surface instead.
String statusLine(WidgetTester tester) {
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((s) => s.contains('cells to go'), orElse: () => '');
}

void main() {
  // The board renders to a canvas sized by the viewport, so give tests a
  // desktop-shaped window and reset it afterwards.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1600, 1100);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('boots to a playable 9x9 board', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    expect(find.text('Sudoku Trainer'), findsOneWidget);
    for (final v in Variant.values) {
      expect(find.text(v.label), findsOneWidget);
    }
    expect(find.text('Hint'), findsOneWidget);
    expect(statusLine(tester), contains('cells to go'));
  });

  testWidgets('the digit pad shows one button per digit', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    // 9x9 by default, so digits 1 through 9 each appear on the pad.
    for (var d = 1; d <= 9; d++) {
      expect(find.text('$d'), findsWidgets, reason: 'digit $d');
    }
  });

  testWidgets('switching to 4x4 reduces the digit pad', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    await tester.tap(find.text('4x4'));
    await tester.pumpAndSettle();

    // 4x4 has no 9, on the pad or anywhere else.
    expect(find.text('9'), findsNothing);
    expect(find.text('4'), findsWidgets);
  });

  testWidgets('keyboard entry changes the board', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    await tester.tap(find.text('4x4'));
    await tester.pumpAndSettle();

    final before = statusLine(tester);

    // Select the top-left cell, then walk right until an editable cell takes
    // a digit. Which cells are blank depends on the generated puzzle.
    await press(tester, LogicalKeyboardKey.arrowRight);
    for (var i = 0; i < 16; i++) {
      await press(tester, LogicalKeyboardKey.digit1);
      if (statusLine(tester) != before) break;
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowDown);
    }

    expect(statusLine(tester), isNot(before));
  });

  testWidgets('H surfaces an explained hint, space places it', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    expect(find.textContaining('can only be'), findsNothing);

    await press(tester, LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();

    // The explanation names the technique and the reasoning.
    expect(find.text('Last remaining digit'), findsOneWidget);
    expect(find.textContaining('can only be'), findsOneWidget);
    expect(find.textContaining('Place '), findsOneWidget);

    final before = statusLine(tester);
    await press(tester, LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(statusLine(tester), isNot(before));
  });

  testWidgets('N toggles notes mode and C toggles candidates', (tester) async {
    await tester.pumpWidget(const FSudokuApp());
    await tester.pump();

    // Both start off; toggling is reflected in the tool buttons' styling,
    // which switches between outlined and filled.
    final outlinedAtRest = tester
        .widgetList(find.byType(OutlinedButton))
        .length;

    await press(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(
      tester.widgetList(find.byType(OutlinedButton)).length,
      lessThan(outlinedAtRest),
    );

    await press(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(
      tester.widgetList(find.byType(OutlinedButton)).length,
      outlinedAtRest,
    );

    await press(tester, LogicalKeyboardKey.keyC);
    await tester.pumpAndSettle();
    expect(
      tester.widgetList(find.byType(OutlinedButton)).length,
      lessThan(outlinedAtRest),
    );
  });

  testWidgets('renders narrow layouts without overflowing', (tester) async {
    final view = tester.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;

    await tester.pumpWidget(const FSudokuApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sudoku Trainer'), findsOneWidget);
  });

  testWidgets('renders in light and dark without throwing', (tester) async {
    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpWidget(const FSudokuApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$brightness');
    }
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}
