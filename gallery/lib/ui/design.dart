import 'package:material_ui/material_ui.dart';

/// The gallery design's tokens: its colors, radii and type sizes.
@immutable
final class GalleryColors extends ThemeExtension<GalleryColors> {
  const GalleryColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.text,
    required this.muted,
    required this.soft,
    required this.accent,
    required this.accentDim,
    required this.accentLine,
    required this.accentText,
    required this.accentHover,
    required this.eyebrow,
    required this.fieldLine,
    required this.hoverLine,
    required this.onAccent,
    required this.switchOff,
    required this.knobOff,
    required this.seriesCpu,
    required this.seriesGpu,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color text;
  final Color muted;

  /// Setting labels: between [text] and [muted].
  final Color soft;
  final Color accent;
  final Color accentDim;

  /// The track of a switch that is on.
  final Color accentLine;

  /// Small accent text: [accent] passes only on white, not on the tints.
  final Color accentText;

  /// A primary button under the pointer.
  final Color accentHover;

  /// [eyebrowStyle]'s labels.
  final Color eyebrow;

  /// The border of a control that has to read as one, 3:1 on the page.
  final Color fieldLine;

  /// A card's border under the pointer.
  final Color hoverLine;

  /// Text on an [accent] fill.
  final Color onAccent;
  final Color switchOff;
  final Color knobOff;

  /// Chart lines for the two delegates. On a light card they measure 3.20
  /// and 4.51 to 1, and stay at least 106 apart (delta E, Machado severity 1)
  /// under each color-vision simulation; theme_contrast_test.dart checks both
  /// themes.
  final Color seriesCpu;
  final Color seriesGpu;

  static const dark = GalleryColors(
    bg: Color(0xFF202124),
    surface: Color(0xFF28292C),
    surface2: Color(0xFF303134),
    line: Color(0xFF3C4043),
    text: Color(0xFFE8EAED),
    muted: Color(0xFF9AA0A6),
    soft: Color(0xFFBDC1C6),
    accent: Color(0xFF8AB4F8),
    accentDim: Color(0xFF2F3F5A),
    accentLine: Color(0xFF3C5478),
    accentText: Color(0xFF8AB4F8),
    accentHover: Color(0xFFAECBFA),
    eyebrow: Color(0xFF8AB4F8),
    fieldLine: Color(0xFF80868B),
    hoverLine: Color(0xFF5F6368),
    onAccent: Color(0xFF202124),
    switchOff: Color(0xFF3C4043),
    knobOff: Color(0xFF9AA0A6),
    seriesCpu: Color(0xFFD95926),
    seriesGpu: Color(0xFF8AB4F8),
  );

  static const light = GalleryColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F3F4),
    line: Color(0xFFDADCE0),
    text: Color(0xFF202124),
    muted: Color(0xFF5F6368),
    soft: Color(0xFF3C4043),
    accent: Color(0xFF1A73E8),
    accentDim: Color(0xFFE8F0FE),
    accentLine: Color(0xFFD2E3FC),
    accentText: Color(0xFF185ABC),
    accentHover: Color(0xFF1557B0),
    eyebrow: Color(0xFF174EA6),
    fieldLine: Color(0xFF80868B),
    hoverLine: Color(0xFFC4C7C5),
    onAccent: Color(0xFFFFFFFF),
    switchOff: Color(0xFFDADCE0),
    knobOff: Color(0xFF5F6368),
    seriesCpu: Color(0xFFEB6834),
    seriesGpu: Color(0xFF1A73E8),
  );

  /// The theme's palette, or the one for its brightness under a theme
  /// that is not the gallery's, as in widget tests.
  static GalleryColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GalleryColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  GalleryColors copyWith() => this;

  @override
  GalleryColors lerp(GalleryColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// The design's measurements.
abstract final class Sizes {
  static const sidebar = 248.0;
  static const settings = 340.0;
  static const radius = 16.0;
  static const radiusSmall = 7.0;
  static const xs = 11.0;
  static const sm = 13.0;
  static const md = 14.0;
  static const lg = 22.0;
  static const xl = 32.0;

  /// The widest a page's content grows, centred in wider windows.
  static const content = 930.0;

  /// At and above this width the sidebar stays in view.
  static const wide = 1200.0;

  /// Below this width settings open as a bottom sheet.
  static const compact = 768.0;
}

/// The design's small uppercase labels ("VISION", "CONFIGURATION").
TextStyle eyebrowStyle(BuildContext context) => TextStyle(
  color: GalleryColors.of(context).eyebrow,
  fontSize: Sizes.xs,
  letterSpacing: Sizes.xs * 0.06,
  fontWeight: FontWeight.w500,
);

/// [theme] without Material's letter spacing, which the design does not use.
TextTheme _untracked(TextTheme theme) {
  TextStyle? untracked(TextStyle? style) => style?.copyWith(letterSpacing: 0);
  return theme.copyWith(
    displayLarge: untracked(theme.displayLarge),
    displayMedium: untracked(theme.displayMedium),
    displaySmall: untracked(theme.displaySmall),
    headlineLarge: untracked(theme.headlineLarge),
    headlineMedium: untracked(theme.headlineMedium),
    headlineSmall: untracked(theme.headlineSmall),
    titleLarge: untracked(theme.titleLarge),
    titleMedium: untracked(theme.titleMedium),
    titleSmall: untracked(theme.titleSmall),
    bodyLarge: untracked(theme.bodyLarge),
    bodyMedium: untracked(theme.bodyMedium),
    bodySmall: untracked(theme.bodySmall),
    labelLarge: untracked(theme.labelLarge),
    labelMedium: untracked(theme.labelMedium),
    labelSmall: untracked(theme.labelSmall),
  );
}

ThemeData galleryTheme(Brightness brightness) {
  final c = brightness == Brightness.dark
      ? GalleryColors.dark
      : GalleryColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
      ).copyWith(
        primary: c.accent,
        onPrimary: c.onAccent,
        secondary: c.accent,
        onSecondary: c.onAccent,
        surface: c.bg,
        onSurface: c.text,
        onSurfaceVariant: c.muted,
        surfaceContainerLowest: c.bg,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surface2,
        surfaceContainerHighest: c.surface2,
        outline: c.line,
        outlineVariant: c.line,
        error: brightness == Brightness.dark
            ? const Color(0xFFF2B8B5)
            : const Color(0xFFB3261E),
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.line,
    extensions: [c],
    textTheme: _untracked(
      base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    ),
    iconTheme: IconThemeData(color: c.muted, size: 15),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.accentDim,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.accent,
      inactiveTrackColor: c.accentLine,
      thumbColor: c.accent,
      overlayColor: c.accent.withValues(alpha: 0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      showValueIndicator: ShowValueIndicator.never,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(Sizes.radiusSmall),
        border: Border.all(color: c.line),
      ),
      textStyle: TextStyle(color: c.text, fontSize: Sizes.xs),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.radius),
        side: BorderSide(color: c.line),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.radiusSmall),
        side: BorderSide(color: c.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bg,
      labelStyle: TextStyle(color: c.muted, fontSize: Sizes.sm),
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sizes.radiusSmall),
        borderSide: BorderSide(color: c.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sizes.radiusSmall),
        borderSide: BorderSide(color: c.fieldLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sizes.radiusSmall),
        borderSide: BorderSide(color: c.accent, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.3),
      selectionHandleColor: c.accent,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: c.surface,
      scrimColor: const Color(0x88000000),
      shape: const RoundedRectangleBorder(),
      width: Sizes.sidebar,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      modalBackgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: c.line),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
