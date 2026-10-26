/// Presentation settings: which skin, and light or dark.
library;

import 'package:flutter/material.dart';

import '../ui/skins.dart';

/// Holds the chosen skin and brightness.
///
/// Kept apart from [GameController] because none of it belongs to a game: a
/// skin outlives any particular puzzle.
class SettingsController extends ChangeNotifier {
  /// Creates settings, optionally starting from a given [skin] and [themeMode].
  SettingsController({Skin? skin, ThemeMode themeMode = ThemeMode.system}) {
    _skin = skin ?? Skin.slate;
    _themeMode = themeMode;
  }

  late Skin _skin;
  late ThemeMode _themeMode;

  /// The active visual identity.
  Skin get skin => _skin;

  /// Whether to follow the system, or force light or dark.
  ThemeMode get themeMode => _themeMode;

  set skin(Skin value) {
    if (_skin.id == value.id) return;
    _skin = value;
    notifyListeners();
  }

  set themeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
  }

  /// Steps system -> light -> dark -> system.
  void cycleThemeMode() {
    themeMode = switch (_themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }

  /// Icon representing the current mode.
  IconData get themeModeIcon => switch (_themeMode) {
    ThemeMode.system => Icons.brightness_auto,
    ThemeMode.light => Icons.light_mode,
    ThemeMode.dark => Icons.dark_mode,
  };

  /// Name of the current mode.
  String get themeModeLabel => switch (_themeMode) {
    ThemeMode.system => 'Auto',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}
