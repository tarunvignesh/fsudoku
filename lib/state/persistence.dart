/// Saving and restoring a game in progress, and the choices around it.
library;

import 'dart:convert';

import '../engine/puzzle.dart';
import '../engine/variant.dart';
import '../ui/skins.dart';
import 'game_mode.dart';
import 'storage/key_value_store.dart';

/// Everything needed to put a half-finished game back on screen.
///
/// The solution is stored alongside the givens rather than re-derived. Solving
/// is only a couple of milliseconds, but storing it means a restored game can
/// never disagree with the one that was saved, even if the solver changes.
class GameSnapshot {
  /// Creates a snapshot.
  const GameSnapshot({
    required this.variant,
    required this.difficulty,
    required this.mode,
    required this.givens,
    required this.solution,
    required this.values,
    required this.notes,
    required this.elapsed,
    required this.correctMoves,
    required this.wrongMoves,
    required this.hintsUsed,
    required this.showCandidates,
  });

  /// Rebuilds a snapshot from [json], or null if it is unusable.
  ///
  /// Returns null rather than throwing on anything unexpected. A saved game
  /// from an older build is not worth a crash on startup.
  static GameSnapshot? fromJson(Map<String, dynamic> json) {
    try {
      final variant = Variant.values.firstWhere(
        (v) => v.name == json['variant'],
      );
      final cells = variant.cellCount;

      List<int> ints(Object? raw) =>
          (raw! as List).map((e) => (e as num).toInt()).toList();

      final givens = ints(json['givens']);
      final solution = ints(json['solution']);
      final values = ints(json['values']);
      final notes = ints(json['notes']);
      if (givens.length != cells ||
          solution.length != cells ||
          values.length != cells ||
          notes.length != cells) {
        return null;
      }

      return GameSnapshot(
        variant: variant,
        difficulty: Difficulty.values.firstWhere(
          (d) => d.name == json['difficulty'],
        ),
        mode: GameMode.values.firstWhere((m) => m.name == json['mode']),
        givens: givens,
        solution: solution,
        values: values,
        notes: notes,
        elapsed: Duration(milliseconds: (json['elapsedMs'] as num).toInt()),
        correctMoves: (json['correctMoves'] as num).toInt(),
        wrongMoves: (json['wrongMoves'] as num).toInt(),
        hintsUsed: (json['hintsUsed'] as num).toInt(),
        showCandidates: json['showCandidates'] as bool? ?? false,
      );
    } on Object {
      return null;
    }
  }

  final Variant variant;
  final Difficulty difficulty;
  final GameMode mode;
  final List<int> givens;
  final List<int> solution;
  final List<int> values;
  final List<int> notes;
  final Duration elapsed;
  final int correctMoves;
  final int wrongMoves;
  final int hintsUsed;
  final bool showCandidates;

  /// The puzzle this snapshot was played on.
  Puzzle get puzzle => Puzzle(
    variant: variant,
    givens: givens,
    solution: solution,
    requestedDifficulty: difficulty,
    // Only used for the status line; a restored game re-derives nothing.
    solvableByLogicAlone: true,
  );

  /// True when there is nothing worth restoring.
  bool get isUntouched {
    for (var i = 0; i < values.length; i++) {
      if (values[i] != givens[i]) return false;
      if (notes[i] != 0) return false;
    }
    return true;
  }

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'variant': variant.name,
    'difficulty': difficulty.name,
    'mode': mode.name,
    'givens': givens,
    'solution': solution,
    'values': values,
    'notes': notes,
    'elapsedMs': elapsed.inMilliseconds,
    'correctMoves': correctMoves,
    'wrongMoves': wrongMoves,
    'hintsUsed': hintsUsed,
    'showCandidates': showCandidates,
  };
}

/// The presentation choices worth remembering.
class SettingsSnapshot {
  /// Creates a settings snapshot.
  const SettingsSnapshot({
    required this.skinId,
    required this.themeModeName,
    required this.gridOnly,
    this.speakSelection = false,
  });

  /// Rebuilds from [json], or null if unusable.
  static SettingsSnapshot? fromJson(Map<String, dynamic> json) {
    try {
      return SettingsSnapshot(
        skinId: json['skin'] as String,
        themeModeName: json['themeMode'] as String,
        gridOnly: json['gridOnly'] as bool? ?? false,
        speakSelection: json['speakSelection'] as bool? ?? false,
      );
    } on Object {
      return null;
    }
  }

  final String skinId;
  final String themeModeName;
  final bool gridOnly;

  /// Whether moving the selection is announced aloud.
  final bool speakSelection;

  /// The skin this refers to, falling back to the default if it is gone.
  Skin get skin => Skin.byId(skinId);

  /// Serialises to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'skin': skinId,
    'themeMode': themeModeName,
    'gridOnly': gridOnly,
    'speakSelection': speakSelection,
  };
}

/// A finished puzzle, and how it went.
class GameResult {
  /// Creates a result.
  const GameResult({
    required this.variant,
    required this.difficulty,
    required this.mode,
    required this.elapsed,
    required this.correctMoves,
    required this.wrongMoves,
    required this.hintsUsed,
    required this.blanks,
    this.previousBest,
  });

  final Variant variant;
  final Difficulty difficulty;
  final GameMode mode;
  final Duration elapsed;
  final int correctMoves;
  final int wrongMoves;
  final int hintsUsed;

  /// How many cells the player had to fill.
  final int blanks;

  /// The best time for this combination before this game, if any.
  final Duration? previousBest;

  /// Share of answers that were right first time, 0 to 1.
  ///
  /// Null in play mode, where mistakes are never counted.
  double? get accuracy {
    if (!mode.revealsCorrectness) return null;
    final total = correctMoves + wrongMoves;
    return total == 0 ? 1.0 : correctMoves / total;
  }

  /// Whether this run beat the previous best.
  bool get isPersonalBest => previousBest == null || elapsed < previousBest!;

  /// How this combination is keyed in the records table.
  String get recordKey => '${variant.name}/${difficulty.name}/${mode.name}';

  /// A copy of this result that knows what the previous best was.
  GameResult against(Duration? best) => GameResult(
    variant: variant,
    difficulty: difficulty,
    mode: mode,
    elapsed: elapsed,
    correctMoves: correctMoves,
    wrongMoves: wrongMoves,
    hintsUsed: hintsUsed,
    blanks: blanks,
    previousBest: best,
  );
}

/// Reads and writes snapshots through a [KeyValueStore].
///
/// Every failure is swallowed deliberately. Persistence is a convenience here;
/// nothing it can do is worth taking the app down for.
class GameRepository {
  /// Creates a repository over [store].
  GameRepository(this.store);

  /// Uses whatever store the platform provides.
  factory GameRepository.forPlatform() => GameRepository(createStore());

  final KeyValueStore store;

  static const _gameKey = 'fsudoku.game.v1';
  static const _settingsKey = 'fsudoku.settings.v1';
  static const _recordsKey = 'fsudoku.records.v1';

  /// The saved game, or null.
  GameSnapshot? loadGame() => _read(_gameKey, GameSnapshot.fromJson);

  /// The saved settings, or null.
  SettingsSnapshot? loadSettings() =>
      _read(_settingsKey, SettingsSnapshot.fromJson);

  /// Saves [snapshot], or clears the slot when there is nothing to keep.
  void saveGame(GameSnapshot snapshot) {
    if (snapshot.isUntouched) {
      clearGame();
      return;
    }
    _write(_gameKey, snapshot.toJson());
  }

  /// Saves [snapshot].
  void saveSettings(SettingsSnapshot snapshot) =>
      _write(_settingsKey, snapshot.toJson());

  /// Best times, keyed by [GameResult.recordKey].
  Map<String, Duration> loadRecords() {
    final raw = _read<Map<String, dynamic>>(_recordsKey, (json) => json);
    if (raw == null) return {};
    final out = <String, Duration>{};
    raw.forEach((key, value) {
      if (value is num) out[key] = Duration(milliseconds: value.toInt());
    });
    return out;
  }

  /// Records [result] if it beats what is stored, and returns the previous
  /// best so the result can say whether it was beaten.
  Duration? recordIfBest(GameResult result) {
    final records = loadRecords();
    final previous = records[result.recordKey];
    if (previous == null || result.elapsed < previous) {
      records[result.recordKey] = result.elapsed;
      _write(_recordsKey, {
        for (final e in records.entries) e.key: e.value.inMilliseconds,
      });
    }
    return previous;
  }

  /// Forgets the saved game.
  void clearGame() {
    try {
      store.delete(_gameKey);
    } on Object {
      // Nothing to do.
    }
  }

  T? _read<T>(String key, T? Function(Map<String, dynamic>) parse) {
    try {
      final raw = store.read(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return parse(decoded);
    } on Object {
      // Corrupt or from an incompatible build; start fresh.
      return null;
    }
  }

  void _write(String key, Map<String, dynamic> json) {
    try {
      store.write(key, jsonEncode(json));
    } on Object {
      // Out of quota, or storage disabled. The game continues regardless.
    }
  }
}
