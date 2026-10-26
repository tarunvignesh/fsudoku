/// Entry point.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Right-click and long-press are both game gestures here -- they open the
  // pencil menu. Without this the browser's own context menu opens on top of
  // it. There is nothing on the page to copy, so losing it costs nothing.
  if (kIsWeb) {
    unawaited(BrowserContextMenu.disableContextMenu());
  }

  runApp(const FSudokuApp());
}
