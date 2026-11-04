import 'package:flutter/material.dart';

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
    required this.teal,
    required this.tealDim,
    required this.tealLine,
    required this.hoverLine,
    required this.onTeal,
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
  final Color teal;
  final Color tealDim;

  /// Borders of teal badges.
  final Color tealLine;

  /// A card's border under the pointer.
  final Color hoverLine;

  /// Text on a teal fill.
  final Color onTeal;
  final Color switchOff;
  final Color knobOff;

  /// Chart lines for the two delegates. The brand teal reads gray in a
  /// line, so the GPU series is a stronger step of its hue; the pair passes
  /// the color-vision checks against each theme's card.
  final Color seriesCpu;
  final Color seriesGpu;

  static const dark = GalleryColors(
    bg: Color(0xFF101314),
    surface: Color(0xFF171A1B),
    surface2: Color(0xFF1D2122),
    line: Color(0xFF2B3031),
    text: Color(0xFFF0F3F2),
    muted: Color(0xFF8D9897),
    soft: Color(0xFFC4CCCA),
    teal: Color(0xFF8CD0D6),
    tealDim: Color(0xFF244247),
    tealLine: Color(0xFF385A5D),
    hoverLine: Color(0xFF526263),
    onTeal: Color(0xFF0B2022),
    switchOff: Color(0xFF3B4243),
    knobOff: Color(0xFF9DA6A5),
    seriesCpu: Color(0xFFD95926),
    seriesGpu: Color(0xFF1FA7B5),
  );

  static const light = GalleryColors(
    bg: Color(0xFFF6F8F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF2F2),
    line: Color(0xFFDCE2E2),
    text: Color(0xFF101314),
    muted: Color(0xFF5E6A69),
    soft: Color(0xFF2E3637),
    teal: Color(0xFF007F8B),
    tealDim: Color(0xFFD5ECEE),
    tealLine: Color(0xFF9CCBD0),
    hoverLine: Color(0xFFA9B6B7),
    onTeal: Color(0xFFFFFFFF),
    switchOff: Color(0xFFCBD3D3),
    knobOff: Color(0xFFFFFFFF),
    seriesCpu: Color(0xFFEB6834),
    seriesGpu: Color(0xFF008E9C),
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
  static const radius = 10.0;
  static const radiusSmall = 7.0;
  static const xs = 11.0;
  static const sm = 13.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 30.0;

  /// The widest a page's content grows, centred in wider windows.
  static const content = 930.0;

  /// At and above this width the sidebar stays in view.
  static const wide = 1200.0;

  /// Below this width settings open as a bottom sheet.
  static const compact = 768.0;
}

/// The design's small uppercase labels ("VISION", "CONFIGURATION").
TextStyle eyebrowStyle(BuildContext context) => TextStyle(
  color: GalleryColors.of(context).muted,
  fontSize: Sizes.xs,
  letterSpacing: Sizes.xs * 0.12,
  fontWeight: FontWeight.w700,
);

ThemeData galleryTheme(Brightness brightness) {
  final c = brightness == Brightness.dark
      ? GalleryColors.dark
      : GalleryColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: c.teal, brightness: brightness)
      .copyWith(
        primary: c.teal,
        onPrimary: c.onTeal,
        secondary: c.teal,
        onSecondary: c.onTeal,
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
    fontFamily: 'Arimo',
  );
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.line,
    extensions: [c],
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    iconTheme: IconThemeData(color: c.muted, size: 15),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.teal,
      linearTrackColor: c.tealDim,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.teal,
      inactiveTrackColor: c.tealDim,
      thumbColor: c.teal,
      overlayColor: c.teal.withValues(alpha: 0.12),
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
      color: c.surface2,
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
        borderSide: BorderSide(color: c.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Sizes.radiusSmall),
        borderSide: BorderSide(color: c.teal),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.teal,
      selectionColor: c.teal.withValues(alpha: 0.3),
      selectionHandleColor: c.teal,
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
