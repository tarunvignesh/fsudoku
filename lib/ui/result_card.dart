/// The card shown when a puzzle is finished.
library;

import 'package:flutter/material.dart';

import '../state/persistence.dart';
import 'theme.dart';

/// Reports a finished puzzle and how it went.
///
/// Deliberately not a plain alert. Finishing is the one moment the app has to
/// mark, and a line of text is a poor reward for twenty minutes of deduction.
/// The stats arrive one after another rather than all at once, which gives the
/// eye somewhere to land.
class ResultCard extends StatefulWidget {
  /// Creates a result card.
  const ResultCard({
    required this.result,
    required this.onDismiss,
    required this.onNewPuzzle,
    super.key,
  });

  /// What there is to report.
  final GameResult result;

  /// Closes the card, leaving the finished board on screen.
  final VoidCallback onDismiss;

  /// Closes the card and deals a new puzzle.
  final VoidCallback onNewPuzzle;

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Eases one staggered element in, by its position in the sequence.
  double _stage(int index, int count) {
    final start = 0.25 + (index / count) * 0.6;
    final t = ((_controller.value - start) / 0.3).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = theme.extension<BoardPalette>()!;
    final r = widget.result;

    final stats = <({String label, String value, Color? tone})>[
      (label: 'Time', value: _format(r.elapsed), tone: null),
      (label: 'Cells solved', value: '${r.blanks}', tone: null),
      if (r.accuracy != null)
        (
          label: 'Accuracy',
          value: '${(r.accuracy! * 100).round()}%',
          tone: r.accuracy! >= 0.95 ? scheme.tertiary : null,
        ),
      if (r.mode.revealsCorrectness)
        (
          label: 'Mistakes',
          value: '${r.wrongMoves}',
          tone: r.wrongMoves == 0 ? scheme.tertiary : palette.conflictText,
        ),
      (
        label: 'Hints',
        value: '${r.hintsUsed}',
        tone: r.hintsUsed == 0 ? scheme.tertiary : null,
      ),
      if (r.previousBest != null)
        (label: 'Previous best', value: _format(r.previousBest!), tone: null),
    ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final entrance = Curves.easeOutBack.transform(
          (_controller.value / 0.35).clamp(0.0, 1.0),
        );

        return Center(
          child: Transform.scale(
            scale: 0.88 + 0.12 * entrance,
            child: Opacity(
              opacity: (_controller.value / 0.2).clamp(0.0, 1.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  elevation: 10,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(context, scheme),
                        const SizedBox(height: 16),
                        for (var i = 0; i < stats.length; i++)
                          Opacity(
                            opacity: _stage(i, stats.length),
                            child: _StatRow(
                              label: stats[i].label,
                              value: stats[i].value,
                              tone: stats[i].tone,
                            ),
                          ),
                        const SizedBox(height: 18),
                        Opacity(
                          opacity: _stage(stats.length - 1, stats.length),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: widget.onDismiss,
                                  child: const Text('Stay here'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: widget.onNewPuzzle,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('New puzzle'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, ColorScheme scheme) {
    final theme = Theme.of(context);
    final r = widget.result;
    final best = r.isPersonalBest;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            best ? Icons.emoji_events : Icons.check_rounded,
            color: scheme.onTertiaryContainer,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                best ? 'Best time yet' : 'Solved',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${r.variant.label} · ${r.difficulty.label} · ${r.mode.label}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: tone ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
