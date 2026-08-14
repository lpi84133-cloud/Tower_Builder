import 'package:flutter/material.dart';

import 'palette.dart';

/// Two bundled families do all the work: `SiteDisplay` (Titan One) for headline
/// slabs and `SiteText` (Barlow) for everything else. Both ship inside the
/// bundle, so typography never depends on a network fetch at runtime.
class Type {
  const Type._();

  static const _display = 'SiteDisplay';
  static const _text = 'SiteText';

  static const _slabShadow = [
    Shadow(color: Color(0xCC000000), offset: Offset(0, 3), blurRadius: 3),
    Shadow(color: Color(0x66000000), offset: Offset(0, 6), blurRadius: 14),
  ];

  /// Big numeric/headline slab (round result, wordmark fallback, rank number).
  static TextStyle slab({double size = 40, Color color = Hue.chalk, bool glow = true}) =>
      TextStyle(
        fontFamily: _display,
        fontSize: size,
        color: color,
        height: 1.04,
        letterSpacing: 0.6,
        shadows: glow ? _slabShadow : null,
      );

  /// Section titles and button captions.
  static TextStyle label({
    double size = 15,
    Color color = Hue.chalk,
    FontWeight weight = FontWeight.w700,
    double tracking = 0.8,
  }) =>
      TextStyle(
        fontFamily: _text,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: tracking,
      );

  /// Running copy.
  static TextStyle body({
    double size = 14,
    Color color = Hue.chalkDim,
    FontWeight weight = FontWeight.w500,
    double height = 1.35,
  }) =>
      TextStyle(
        fontFamily: _text,
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
      );

  /// Tabular-ish figures for balances and multipliers.
  static TextStyle figure({
    double size = 18,
    Color color = Hue.chalk,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily: _text,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: 0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Small all-caps eyebrow above panels.
  static TextStyle eyebrow({double size = 11, Color color = Hue.chalkDim}) =>
      TextStyle(
        fontFamily: _text,
        fontSize: size,
        color: color,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      );
}
