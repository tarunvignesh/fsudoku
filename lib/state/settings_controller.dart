/// Presentation settings: which skin, and light or dark.
library;

import 'package:flutter/material.dart';

import '../ui/skins.dart';
import 'persistence.dart';

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

  /// Whether to show the board alone, hiding the side panel.
  ///
  /// Small viewports get this regardless; on a large one it is a choice, so
  /// that someone who wants only the grid can have it on any screen.
  bool get gridOnly => _gridOnly;
  bool _gridOnly = false;

  set gridOnly(bool value) {
    if (_gridOnly == value) return;
    _gridOnly = value;
    notifyListeners();
  }

  /// Flips between the board alone and the full layout.
  void toggleGridOnly() => gridOnly = !_gridOnly;

  /// Captures the current choices for saving.
  SettingsSnapshot snapshot() => SettingsSnapshot(
    skinId: _skin.id,
    themeModeName: _themeMode.name,
    gridOnly: _gridOnly,
  );

  /// Applies a saved [snapshot].
  void restore(SettingsSnapshot snapshot) {
    _skin = snapshot.skin;
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == snapshot.themeModeName,
      orElse: () => ThemeMode.system,
    );
    _gridOnly = snapshot.gridOnly;
    notifyListeners();
  }
}
