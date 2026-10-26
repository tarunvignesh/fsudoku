/// Contrast audit for every skin.
///
/// Each skin's colours are hand-picked, which is exactly the situation where
/// something ends up unreadable for someone. This measures every text-on-
/// background pair the board actually produces, including text sitting on a
/// translucent highlight, and holds them to WCAG 2.1 contrast minimums.
///
/// Thresholds follow the standard's text-size rule:
///  - Board digits are large (over 24 logical px at any usable board size),
///    so they need 3.0:1.
///  - Pencil marks and candidates are small, so they need 4.5:1.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsudoku/ui/skins.dart';
import 'package:fsudoku/ui/theme.dart';

/// WCAG 2.1 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Flattens [over] onto [under], since board highlights are translucent.
Color flatten(Color over, Color under) => Color.alphaBlend(over, under);

/// One measured foreground-on-background pair.
class ContrastCheck {
  const ContrastCheck(this.what, this.fg, this.bg, this.min);
  final String what;
  final Color fg;
  final Color bg;
  final double min;

  double get ratio => contrast(fg, bg);
  bool get passes => ratio >= min;
}

/// Every pair worth measuring for one palette.
List<ContrastCheck> checksFor(BoardPalette p) {
  // Large text: 3.0. Small text: 4.5.
  const large = 3.0;
  const small = 4.5;

  final surface = p.surface;
  final tinted = flatten(p.boxTint, surface);
  final selected = flatten(p.selectionFill, surface);
  final peer = flatten(p.peerFill, surface);
  final conflict = flatten(p.conflictFill, surface);
  final hint = flatten(p.hintFill, surface);

  return [
    ContrastCheck('given on surface', p.givenText, surface, large),
    ContrastCheck('given on box tint', p.givenText, tinted, large),
    ContrastCheck('given on selection', p.givenText, selected, large),
    ContrastCheck('given on peer', p.givenText, peer, large),
    ContrastCheck('given on hint', p.givenText, hint, large),
    ContrastCheck('entry on surface', p.entryText, surface, large),
    ContrastCheck('entry on selection', p.entryText, selected, large),
    ContrastCheck('entry on peer', p.entryText, peer, large),
    ContrastCheck('conflict on surface', p.conflictText, surface, large),
    ContrastCheck('conflict on conflict fill', p.conflictText, conflict, large),
    ContrastCheck('note on surface', p.noteText, surface, small),
    ContrastCheck('note on box tint', p.noteText, tinted, small),
    ContrastCheck('note on peer', p.noteText, peer, small),
    ContrastCheck('candidate on surface', p.candidateText, surface, small),
    ContrastCheck('candidate on box tint', p.candidateText, tinted, small),
    ContrastCheck('candidate on peer', p.candidateText, peer, small),
  ];
}

void main() {
  group('skin contrast', () {
    for (final skin in Skin.all) {
      for (final brightness in Brightness.values) {
        final name = '${skin.label} ${brightness.name}';
        test(name, () {
          final palette = brightness == Brightness.dark
              ? skin.dark
              : skin.light;
          final failures = <String>[];

          for (final c in checksFor(palette)) {
            if (!c.passes) {
              failures.add(
                '  ${c.what.padRight(26)} '
                '${c.ratio.toStringAsFixed(2)}:1 '
                '(needs ${c.min.toStringAsFixed(1)}:1)',
              );
            }
          }

          expect(
            failures,
            isEmpty,
            reason: '$name fails WCAG contrast:\n${failures.join('\n')}',
          );
        });
      }
    }
  });

  group('structural accessibility', () {
    test('no skin relies on colour alone to mark a mistake', () {
      // Wrong answers are red, but they are also the only digits that keep
      // their cell unlocked and editable, and conflicts additionally carry a
      // background wash. Colour is reinforcement, not the sole signal.
      for (final skin in Skin.all) {
        for (final p in [skin.light, skin.dark]) {
          expect(
            p.conflictFill.a,
            greaterThan(0),
            reason: '${skin.label}: conflicts need a non-colour cue too',
          );
        }
      }
    });

    test('every skin distinguishes givens from the player\'s answers', () {
      // If these two match, a player cannot tell which digits are theirs.
      for (final skin in Skin.all) {
        for (final p in [skin.light, skin.dark]) {
          expect(
            contrast(p.givenText, p.entryText),
            greaterThan(1.25),
            reason: '${skin.label}: given and entry read the same',
          );
        }
      }
    });

    test('pencil marks are distinguishable from computed candidates', () {
      // They are also told apart by rotation, so this bar is deliberately
      // lower than a text-contrast threshold.
      for (final skin in Skin.all) {
        for (final p in [skin.light, skin.dark]) {
          expect(
            contrast(p.noteText, p.candidateText),
            greaterThan(1.15),
            reason: '${skin.label}: notes and candidates read the same',
          );
        }
      }
    });
  });
}
