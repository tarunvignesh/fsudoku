/// What the launch URL asks for.
///
/// Lets a link — or a home-screen shortcut on an installed app — open straight
/// into a particular board rather than whatever was last played:
/// `?size=4`, `?size=9&difficulty=tricky&mode=play`.
library;

import '../engine/puzzle.dart';
import '../engine/variant.dart';
import 'game_mode.dart';

/// Board, difficulty and mode requested by the URL, where given.
class LaunchOptions {
  /// Creates launch options.
  const LaunchOptions({this.variant, this.difficulty, this.mode});

  /// Reads the options out of [uri]'s query string.
  ///
  /// Unknown or malformed values are ignored rather than rejected: a bad link
  /// should open the app, not an error.
  factory LaunchOptions.fromUri(Uri uri) {
    final q = uri.queryParameters;

    Variant? variant;
    final size = int.tryParse(q['size'] ?? '');
    for (final v in Variant.values) {
      if (v.size == size || v.label == q['size']) variant = v;
    }

    Difficulty? difficulty;
    for (final d in Difficulty.values) {
      if (d.name == q['difficulty']?.toLowerCase()) difficulty = d;
    }

    GameMode? mode;
    for (final m in GameMode.values) {
      if (m.name == q['mode']?.toLowerCase()) mode = m;
    }

    return LaunchOptions(variant: variant, difficulty: difficulty, mode: mode);
  }

  /// Reads the options from the URL the app was launched with.
  ///
  /// `Uri.base` is the page URL on the web and the working directory
  /// elsewhere, where it simply yields nothing.
  factory LaunchOptions.fromPlatform() => LaunchOptions.fromUri(Uri.base);

  /// The board size asked for, if any.
  final Variant? variant;

  /// The difficulty asked for, if any.
  final Difficulty? difficulty;

  /// The mode asked for, if any.
  final GameMode? mode;

  /// Whether the URL asked for anything at all.
  bool get isEmpty => variant == null && difficulty == null && mode == null;

  /// Whether the URL asked for a specific board.
  ///
  /// A saved game is only set aside when it did: arriving by a plain link
  /// should resume what you were playing.
  bool get wantsNewGame => !isEmpty;
}
