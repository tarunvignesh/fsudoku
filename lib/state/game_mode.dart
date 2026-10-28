/// How much the app tells you while you play.
library;

/// The two ways to play, which differ in how much they give away.
///
/// The app checks every answer against the solution either way -- it has to,
/// to know when you have finished. The mode decides whether it *says* so.
/// Keeping that a choice is what stops the teaching features from quietly
/// removing the deduction they are meant to teach.
enum GameMode {
  /// Shows candidates, flags wrong digits as you type them, and settles the
  /// ones you get right so a stray keystroke cannot undo progress.
  training(
    label: 'Training',
    summary: 'Candidates shown, mistakes flagged, correct cells settle.',
    revealsCorrectness: true,
    showsCandidatesByDefault: true,
  ),

  /// Flags only what breaks a rule. A legal-but-wrong digit stays as you left
  /// it, so you cannot find the answer by trying digits until one sticks.
  play(
    label: 'Play',
    summary: 'Only rule breaks are flagged. The deduction stays yours.',
    revealsCorrectness: false,
    showsCandidatesByDefault: false,
  );

  const GameMode({
    required this.label,
    required this.summary,
    required this.revealsCorrectness,
    required this.showsCandidatesByDefault,
  });

  /// Short name shown in the picker.
  final String label;

  /// One line on what the mode does.
  final String summary;

  /// Whether a wrong answer is marked wrong, and a right one settles.
  final bool revealsCorrectness;

  /// Whether switching to this mode turns the candidate overlay on.
  final bool showsCandidatesByDefault;

  /// The other mode.
  GameMode get other => this == training ? play : training;
}
