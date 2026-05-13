import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.canvasGradient,
    required this.heroGradient,
    required this.panelBackground,
    required this.panelStroke,
    required this.panelShadow,
    required this.accent,
    required this.accentMuted,
    required this.warn,
    required this.success,
    required this.chrome,
    required this.radiusLarge,
    required this.radiusMedium,
    required this.radiusSmall,
  });

  final List<Color> canvasGradient;
  final List<Color> heroGradient;
  final Color panelBackground;
  final Color panelStroke;
  final Color panelShadow;
  final Color accent;
  final Color accentMuted;
  final Color warn;
  final Color success;
  final Color chrome;
  final double radiusLarge;
  final double radiusMedium;
  final double radiusSmall;

  @override
  ThemeExtension<AppThemeTokens> copyWith({
    List<Color>? canvasGradient,
    List<Color>? heroGradient,
    Color? panelBackground,
    Color? panelStroke,
    Color? panelShadow,
    Color? accent,
    Color? accentMuted,
    Color? warn,
    Color? success,
    Color? chrome,
    double? radiusLarge,
    double? radiusMedium,
    double? radiusSmall,
  }) {
    return AppThemeTokens(
      canvasGradient: canvasGradient ?? this.canvasGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      panelBackground: panelBackground ?? this.panelBackground,
      panelStroke: panelStroke ?? this.panelStroke,
      panelShadow: panelShadow ?? this.panelShadow,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      warn: warn ?? this.warn,
      success: success ?? this.success,
      chrome: chrome ?? this.chrome,
      radiusLarge: radiusLarge ?? this.radiusLarge,
      radiusMedium: radiusMedium ?? this.radiusMedium,
      radiusSmall: radiusSmall ?? this.radiusSmall,
    );
  }

  @override
  ThemeExtension<AppThemeTokens> lerp(
    covariant ThemeExtension<AppThemeTokens>? other,
    double t,
  ) {
    if (other is! AppThemeTokens) {
      return this;
    }

    return AppThemeTokens(
      canvasGradient: _lerpColorList(canvasGradient, other.canvasGradient, t),
      heroGradient: _lerpColorList(heroGradient, other.heroGradient, t),
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      panelStroke: Color.lerp(panelStroke, other.panelStroke, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      success: Color.lerp(success, other.success, t)!,
      chrome: Color.lerp(chrome, other.chrome, t)!,
      radiusLarge: lerpDouble(radiusLarge, other.radiusLarge, t)!,
      radiusMedium: lerpDouble(radiusMedium, other.radiusMedium, t)!,
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall, t)!,
    );
  }
}

List<Color> _lerpColorList(List<Color> a, List<Color> b, double t) {
  final int count = a.length < b.length ? a.length : b.length;
  return List<Color>.generate(
    count,
    (index) => Color.lerp(a[index], b[index], t)!,
    growable: false,
  );
}
