/// Skins: the app's selectable visual identities.
///
/// A skin is more than a palette. It carries the board's proportions, its line
/// weights, its typeface and the shape language of the controls, so switching
/// one changes the app's character rather than merely recolouring it.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The shape language a skin follows.
enum SkinFlavor {
  /// Material: ripples on touch, moderate rounding, Material dialogs.
  material,

  /// Cupertino: no ripple, generous rounding, iOS-style dialogs.
  cupertino,
}

/// One complete visual identity.
@immutable
class Skin {
  /// Creates a skin.
  const Skin({
    required this.id,
    required this.label,
    required this.description,
    required this.flavor,
    required this.seed,
    required this.light,
    required this.dark,
    required this.style,
    this.uiFontFamily,
    this.tertiaryLight,
    this.tertiaryDark,
  });

  /// Stable identifier, used when remembering the choice.
  final String id;

  /// Short name shown in the picker.
  final String label;

  /// One line on what the skin is going for.
  final String description;

  /// Shape language for controls and dialogs.
  final SkinFlavor flavor;

  /// Seed for the generated [ColorScheme].
  final Color seed;

  /// Board colours in light mode.
  final BoardPalette light;

  /// Board colours in dark mode.
  final BoardPalette dark;

  /// Board proportions, line weights and digit typeface.
  final BoardStyle style;

  /// Font for the surrounding interface, or null for the default.
  final String? uiFontFamily;

  /// Teaching accent in light mode, pinned so hints match the board.
  final Color? tertiaryLight;

  /// Teaching accent in dark mode.
  final Color? tertiaryDark;

  /// Every skin the app ships, in the order the picker shows them.
  static const List<Skin> all = [
    slate,
    contrast,
    newsprint,
    terminal,
    cupertino,
    you,
  ];

  /// Looks a skin up by [id], falling back to the default.
  static Skin byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => slate);

  // ------------------------------------------------------------------ skins

  /// The default: cool neutrals, a crisp grid, no decoration.
  static const Skin slate = Skin(
    id: 'slate',
    label: 'Slate',
    description: 'Cool neutrals and a crisp grid.',
    flavor: SkinFlavor.material,
    seed: Color(0xFF2563C9),
    tertiaryLight: Color(0xFF17A398),
    tertiaryDark: Color(0xFF33D6C8),
    light: BoardPalette.light,
    dark: BoardPalette.dark,
    style: BoardStyle(
      fontFamily: null,
      gridLineScale: 1,
      boxLineScale: 1,
      cornerRadiusScale: 0.22,
      boxTint: BoxTint.checker,
      digitScale: 0.56,
      noteScale: 0.24,
      givenWeight: FontWeight.w600,
      entryWeight: FontWeight.w500,
    ),
  );

  /// Maximum separation between every pair the board can produce.
  ///
  /// Built for low vision rather than for looks: pure black on white (and the
  /// reverse), heavy rules, no box wash to muddy the text behind it, and
  /// larger digits. Every pair still goes through the same contrast audit as
  /// the rest, which here clears AAA rather than AA.
  static const Skin contrast = Skin(
    id: 'contrast',
    label: 'High contrast',
    description: 'Maximum legibility: heavy rules, large digits.',
    flavor: SkinFlavor.material,
    seed: Color(0xFF0040A0),
    tertiaryLight: Color(0xFF005C2E),
    tertiaryDark: Color(0xFF5CFFA8),
    light: BoardPalette(
      surface: Color(0xFFFFFFFF),
      boxTint: Color(0x00000000),
      gridLine: Color(0x66000000),
      boxLine: Color(0xFF000000),
      givenText: Color(0xFF000000),
      entryText: Color(0xFF0040A0),
      conflictText: Color(0xFFB00000),
      conflictFill: Color(0x33B00000),
      selectionFill: Color(0x3D0040A0),
      peerFill: Color(0x140040A0),
      hintFill: Color(0x33005C2E),
      hintEvidenceFill: Color(0x14005C2E),
      noteText: Color(0xFF333333),
      candidateText: Color(0xFF595959),
      completedUnitFill: Color(0x33005C2E),
    ),
    dark: BoardPalette(
      surface: Color(0xFF000000),
      boxTint: Color(0x00000000),
      gridLine: Color(0x80FFFFFF),
      boxLine: Color(0xFFFFFFFF),
      givenText: Color(0xFFFFFFFF),
      entryText: Color(0xFF7FC4FF),
      conflictText: Color(0xFFFF7A7A),
      conflictFill: Color(0x40FF7A7A),
      selectionFill: Color(0x4D7FC4FF),
      peerFill: Color(0x1F7FC4FF),
      hintFill: Color(0x4D5CFFA8),
      hintEvidenceFill: Color(0x1A5CFFA8),
      noteText: Color(0xFFD9D9D9),
      candidateText: Color(0xFFA6A6A6),
      completedUnitFill: Color(0x4D5CFFA8),
    ),
    style: BoardStyle(
      fontFamily: 'Inter',
      gridLineScale: 1.4,
      boxLineScale: 1.6,
      cornerRadiusScale: 0.04,
      boxTint: BoxTint.none,
      digitScale: 0.64,
      noteScale: 0.27,
      givenWeight: FontWeight.w700,
      entryWeight: FontWeight.w700,
    ),
  );

  /// Warm paper and a serif, like a puzzle torn out of a newspaper.
  static const Skin newsprint = Skin(
    id: 'newsprint',
    label: 'Newsprint',
    description: 'Warm paper, serif digits, hairline rules.',
    flavor: SkinFlavor.material,
    seed: Color(0xFF8A5A2B),
    uiFontFamily: 'SourceSerif4',
    tertiaryLight: Color(0xFF4F6B4A),
    tertiaryDark: Color(0xFF9BC095),
    light: BoardPalette(
      surface: Color(0xFFF7F1E4),
      boxTint: Color(0x0F6B4E2E),
      gridLine: Color(0x3D6B4E2E),
      boxLine: Color(0xB24A3A26),
      givenText: Color(0xFF2B2117),
      entryText: Color(0xFF8A5A2B),
      conflictText: Color(0xFFA32F28),
      conflictFill: Color(0x1FA32F28),
      selectionFill: Color(0x338A5A2B),
      peerFill: Color(0x148A5A2B),
      hintFill: Color(0x3D4F6B4A),
      hintEvidenceFill: Color(0x144F6B4A),
      noteText: Color(0xFF60503B),
      candidateText: Color(0xFF716553),
      completedUnitFill: Color(0x3D4F6B4A),
    ),
    dark: BoardPalette(
      surface: Color(0xFF221C14),
      boxTint: Color(0x12E8D9BF),
      gridLine: Color(0x2EE8D9BF),
      boxLine: Color(0x80E8D9BF),
      givenText: Color(0xFFF2E8D5),
      entryText: Color(0xFFD9A05B),
      conflictText: Color(0xFFE88A7D),
      conflictFill: Color(0x2EE8705C),
      selectionFill: Color(0x3DD9A05B),
      peerFill: Color(0x1FD9A05B),
      hintFill: Color(0x4D9BC095),
      hintEvidenceFill: Color(0x1A9BC095),
      noteText: Color(0xFFC4B296),
      candidateText: Color(0xFFA1937C),
      completedUnitFill: Color(0x4D9BC095),
    ),
    style: BoardStyle(
      fontFamily: 'SourceSerif4',
      gridLineScale: 0.8,
      boxLineScale: 0.85,
      cornerRadiusScale: 0.06,
      boxTint: BoxTint.bands,
      digitScale: 0.6,
      noteScale: 0.26,
      givenWeight: FontWeight.w600,
      entryWeight: FontWeight.w400,
    ),
  );

  /// Phosphor on black, monospaced, square corners.
  static const Skin terminal = Skin(
    id: 'terminal',
    label: 'Terminal',
    description: 'Phosphor green on black, monospaced.',
    flavor: SkinFlavor.material,
    seed: Color(0xFF2BD96B),
    uiFontFamily: 'JetBrainsMono',
    tertiaryLight: Color(0xFFB08400),
    tertiaryDark: Color(0xFFFFC53D),
    light: BoardPalette(
      surface: Color(0xFFF2F5F0),
      boxTint: Color(0x0F0A3318),
      gridLine: Color(0x2E0A3318),
      boxLine: Color(0xCC0A3318),
      givenText: Color(0xFF0A2314),
      entryText: Color(0xFF127A3C),
      conflictText: Color(0xFFBA1A1A),
      conflictFill: Color(0x1FBA1A1A),
      selectionFill: Color(0x33127A3C),
      peerFill: Color(0x14127A3C),
      hintFill: Color(0x3DB08400),
      hintEvidenceFill: Color(0x14B08400),
      noteText: Color(0xFF3B5A46),
      candidateText: Color(0xFF576D5F),
      completedUnitFill: Color(0x3DB08400),
    ),
    dark: BoardPalette(
      surface: Color(0xFF060A07),
      boxTint: Color(0x122BD96B),
      gridLine: Color(0x2E2BD96B),
      boxLine: Color(0x992BD96B),
      givenText: Color(0xFFBFF5D2),
      entryText: Color(0xFF2BD96B),
      conflictText: Color(0xFFFF6B5E),
      conflictFill: Color(0x33FF6B5E),
      selectionFill: Color(0x3D2BD96B),
      peerFill: Color(0x1F2BD96B),
      hintFill: Color(0x4DFFC53D),
      hintEvidenceFill: Color(0x1AFFC53D),
      noteText: Color(0xFF6FAE88),
      candidateText: Color(0xFF689179),
      completedUnitFill: Color(0x4DFFC53D),
    ),
    style: BoardStyle(
      fontFamily: 'JetBrainsMono',
      gridLineScale: 1,
      boxLineScale: 1.25,
      cornerRadiusScale: 0,
      boxTint: BoxTint.none,
      digitScale: 0.52,
      noteScale: 0.22,
      givenWeight: FontWeight.w600,
      entryWeight: FontWeight.w400,
    ),
  );

  /// Soft, rounded and airy, in the manner of iOS.
  static const Skin cupertino = Skin(
    id: 'cupertino',
    label: 'Cupertino',
    description: 'Soft, rounded and airy, iOS in feel.',
    flavor: SkinFlavor.cupertino,
    seed: Color(0xFF0A84FF),
    uiFontFamily: 'Inter',
    tertiaryLight: Color(0xFF30A14E),
    tertiaryDark: Color(0xFF32D74B),
    light: BoardPalette(
      surface: Color(0xFFFFFFFF),
      boxTint: Color(0x0A000000),
      gridLine: Color(0x1F3C3C43),
      boxLine: Color(0x593C3C43),
      givenText: Color(0xFF1C1C1E),
      entryText: Color(0xFF0B7FF4),
      conflictText: Color(0xFFFF3B30),
      conflictFill: Color(0x1FFF3B30),
      selectionFill: Color(0x2E0A84FF),
      peerFill: Color(0x140A84FF),
      hintFill: Color(0x3330A14E),
      hintEvidenceFill: Color(0x1230A14E),
      noteText: Color(0xFF5A5A5E),
      candidateText: Color(0xFF6F6F72),
      completedUnitFill: Color(0x3330A14E),
    ),
    dark: BoardPalette(
      surface: Color(0xFF1C1C1E),
      boxTint: Color(0x14FFFFFF),
      gridLine: Color(0x29FFFFFF),
      boxLine: Color(0x66FFFFFF),
      givenText: Color(0xFFF2F2F7),
      entryText: Color(0xFF0A84FF),
      conflictText: Color(0xFFFF453A),
      conflictFill: Color(0x33FF453A),
      selectionFill: Color(0x3D0A84FF),
      peerFill: Color(0x1F0A84FF),
      hintFill: Color(0x4D32D74B),
      hintEvidenceFill: Color(0x1A32D74B),
      noteText: Color(0xFFAFAFB3),
      candidateText: Color(0xFF959599),
      completedUnitFill: Color(0x4D32D74B),
    ),
    style: BoardStyle(
      fontFamily: 'Inter',
      gridLineScale: 0.85,
      boxLineScale: 0.9,
      cornerRadiusScale: 0.34,
      boxTint: BoxTint.checker,
      digitScale: 0.54,
      noteScale: 0.23,
      givenWeight: FontWeight.w600,
      entryWeight: FontWeight.w500,
    ),
  );

  /// Saturated and chunky, in the manner of Material You on Android.
  static const Skin you = Skin(
    id: 'you',
    label: 'Material You',
    description: 'Saturated, chunky, Android in feel.',
    flavor: SkinFlavor.material,
    seed: Color(0xFF6750A4),
    tertiaryLight: Color(0xFF7D5260),
    tertiaryDark: Color(0xFFEFB8C8),
    light: BoardPalette(
      surface: Color(0xFFFFFBFE),
      boxTint: Color(0x126750A4),
      gridLine: Color(0x1F1D1B20),
      boxLine: Color(0x8C6750A4),
      givenText: Color(0xFF1D1B20),
      entryText: Color(0xFF6750A4),
      conflictText: Color(0xFFB3261E),
      conflictFill: Color(0x1FB3261E),
      selectionFill: Color(0x3D6750A4),
      peerFill: Color(0x1A6750A4),
      hintFill: Color(0x3D7D5260),
      hintEvidenceFill: Color(0x147D5260),
      noteText: Color(0xFF49454F),
      candidateText: Color(0xFF6C6971),
      completedUnitFill: Color(0x3D7D5260),
    ),
    dark: BoardPalette(
      surface: Color(0xFF1D1B20),
      boxTint: Color(0x1FD0BCFF),
      gridLine: Color(0x29E6E0E9),
      boxLine: Color(0x99D0BCFF),
      givenText: Color(0xFFE6E0E9),
      entryText: Color(0xFFD0BCFF),
      conflictText: Color(0xFFF2B8B5),
      conflictFill: Color(0x33F2B8B5),
      selectionFill: Color(0x4DD0BCFF),
      peerFill: Color(0x24D0BCFF),
      hintFill: Color(0x4DEFB8C8),
      hintEvidenceFill: Color(0x1AEFB8C8),
      noteText: Color(0xFFCAC4D0),
      candidateText: Color(0xFF9F9AA3),
      completedUnitFill: Color(0x4DEFB8C8),
    ),
    style: BoardStyle(
      fontFamily: null,
      gridLineScale: 1,
      boxLineScale: 1.15,
      cornerRadiusScale: 0.4,
      boxTint: BoxTint.checker,
      digitScale: 0.58,
      noteScale: 0.25,
      givenWeight: FontWeight.w700,
      entryWeight: FontWeight.w500,
    ),
  );
}

/// Builds the app theme for [skin] at [brightness].
ThemeData buildAppTheme(Skin skin, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? skin.dark : skin.light;
  final cupertino = skin.flavor == SkinFlavor.cupertino;

  // Overriding `tertiary` alone is not enough: fromSeed derives the container
  // roles from the seed, not from the override, so the hint panel would keep
  // the seed's own hue while the hint icon changed.
  final accent = isDark ? skin.tertiaryDark : skin.tertiaryLight;
  final scheme = ColorScheme.fromSeed(
    seedColor: skin.seed,
    brightness: brightness,
    tertiary: accent,
    tertiaryContainer: accent == null
        ? null
        : Color.alphaBlend(
            accent.withValues(alpha: isDark ? 0.26 : 0.24),
            isDark ? const Color(0xFF14171D) : const Color(0xFFFFFFFF),
          ),
    onTertiaryContainer: accent == null
        ? null
        : (isDark ? const Color(0xFFEAFFFB) : const Color(0xFF07231F)),
  );

  // Cupertino rounds more and never ripples; Material does the opposite.
  final radius = cupertino ? 14.0 : 12.0;

  return ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: skin.uiFontFamily,
    scaffoldBackgroundColor: Color.alphaBlend(
      palette.surface.withValues(alpha: isDark ? 0.55 : 0.5),
      scheme.surface,
    ),
    splashFactory: cupertino ? NoSplash.splashFactory : InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    extensions: [palette, skin.style],
    textTheme: isDark
        ? Typography.material2021().white
        : Typography.material2021().black,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius - 2),
          ),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cupertino ? 20 : 16),
      ),
    ),
  );
}
