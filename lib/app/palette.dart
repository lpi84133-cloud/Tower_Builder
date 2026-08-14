import 'package:flutter/material.dart';

/// Blueprint palette: cold navy chrome, cyan drafting lines, a single amber
/// accent for anything the player earns. The playfield sky is supplied by the
/// selected district (see `build_site/district.dart`), never from here.
class Hue {
  const Hue._();

  // Chrome / surfaces
  static const abyss = Color(0xFF060F22);
  static const navy = Color(0xFF0B1E3C);
  static const navySoft = Color(0xFF122C51);
  static const slate = Color(0xFF1B3559);
  static const card = Color(0xFF102544);
  static const cardEdge = Color(0xFF29527F);

  // Drafting lines / text
  static const chalk = Color(0xFFEDF3FB);
  static const chalkDim = Color(0xFF9FB4CE);
  static const grid = Color(0x332FA8D8);

  // Site HUD chrome. The run screen is graphite rather than navy: the frame
  // climbs past the bars against a bright sky, and a neutral dark reads as
  // site equipment instead of competing with the painted art. Menus keep the
  // blueprint navy above.
  static const rig = Color(0xFF2B2B2D);
  static const rigDeep = Color(0xFF1E1E20);
  static const rigPanel = Color(0xF21F2230);
  static const rigEdge = Color(0x3DFFFFFF); // white24, the panel outline
  static const rigWell = Color(0x1AFFFFFF); // white10, recessed tap targets

  // Moulded blue used by every site action button.
  static const glaze = Color(0xFF63A8F5);
  static const glazeDeep = Color(0xFF1F66C9);
  static const glazeEdge = Color(0xFF12407F);

  // Accents
  static const cyan = Color(0xFF35C2E0);
  static const cyanDeep = Color(0xFF1B8FAD);
  static const amber = Color(0xFFFFB43A);
  static const amberDeep = Color(0xFFCC841D);
  static const lime = Color(0xFF57C77E);
  static const limeDeep = Color(0xFF33995A);
  static const rust = Color(0xFFE2604B);
  static const rustDeep = Color(0xFFB0402E);
  static const violet = Color(0xFF8A6BD8);

  /// Standard vertical wash used by every panel and sheet.
  static const panelWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [card, navy],
  );

  static const shellWash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, abyss],
  );

  /// Graphite wash shared by the site's top bar and bottom deck.
  static const rigWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [rig, rigDeep],
  );
}

/// Thin, reusable decorations so panels look identical everywhere without a
/// widget wrapper for every single box.
class Frames {
  const Frames._();

  static BoxDecoration panel({double radius = 18, Color? edge}) => BoxDecoration(
        gradient: Hue.panelWash,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: edge ?? Hue.cardEdge, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      );

  static BoxDecoration tile({double radius = 14, Color? fill, Color? edge}) =>
      BoxDecoration(
        color: fill ?? Hue.slate,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: edge ?? Hue.cardEdge, width: 1),
      );

  static BoxDecoration pill({Color? fill, Color? edge}) => BoxDecoration(
        color: fill ?? Hue.navySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: edge ?? Hue.cardEdge, width: 1),
      );
}
