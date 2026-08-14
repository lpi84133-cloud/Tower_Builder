import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A skyline backdrop for the playfield. Districts are cosmetic only: they never
/// touch the odds, the bonus spread or the crane timing.
@immutable
class District {
  const District({
    required this.id,
    required this.name,
    required this.brief,
    required this.zenith,
    required this.horizon,
    required this.price,
    required this.rankRequired,
  });

  final int id;
  final String name;
  final String brief;

  /// Vertical sky wash, top to bottom.
  final Color zenith;
  final Color horizon;

  /// Cost in BRIX; zero means it ships unlocked.
  final int price;
  final int rankRequired;

  static const all = <District>[
    District(
      id: 0,
      name: 'Harbour Flats',
      brief: 'Clear morning over the docks.',
      zenith: Color(0xFF8FC6E4),
      horizon: Color(0xFFD3ECF5),
      price: 0,
      rankRequired: 0,
    ),
    District(
      id: 1,
      name: 'Ironworks',
      brief: 'Low sun through the stacks.',
      zenith: Color(0xFFE8994F),
      horizon: Color(0xFFF3C58A),
      price: 1500,
      rankRequired: 0,
    ),
    District(
      id: 2,
      name: 'Glass Quarter',
      brief: 'Blue hour on the curtain walls.',
      zenith: Color(0xFF4E63A6),
      horizon: Color(0xFF9E8CD0),
      price: 3000,
      rankRequired: 3,
    ),
    District(
      id: 3,
      name: 'Night Shift',
      brief: 'Floodlights and cold steel.',
      zenith: Color(0xFF15213C),
      horizon: Color(0xFF33456B),
      price: 6000,
      rankRequired: 6,
    ),
    District(
      id: 4,
      name: 'Salt Terrace',
      brief: 'Sea haze, long shadows.',
      zenith: Color(0xFF2E8C8A),
      horizon: Color(0xFFB6E3D4),
      price: 9000,
      rankRequired: 9,
    ),
  ];

  static District byId(int id) =>
      all.firstWhere((d) => d.id == id, orElse: () => all.first);
}

/// Cosmetic module sets sold in the workshop. Facade ids line up with the
/// sprites in `assets/art/site/module_0N.webp`.
@immutable
class ModuleKit {
  const ModuleKit({
    required this.facade,
    required this.name,
    required this.brief,
    required this.price,
    required this.rankRequired,
  });

  final int facade;
  final String name;
  final String brief;
  final int price;
  final int rankRequired;

  static const all = <ModuleKit>[
    ModuleKit(
      facade: 1,
      name: 'Hex Cabin',
      brief: 'Standard issue prefab.',
      price: 0,
      rankRequired: 0,
    ),
    ModuleKit(
      facade: 2,
      name: 'Terrace Flat',
      brief: 'Shuttered balconies, plaster finish.',
      price: 900,
      rankRequired: 2,
    ),
    ModuleKit(
      facade: 3,
      name: 'Timber Loft',
      brief: 'Stacked beams, deep sills.',
      price: 2200,
      rankRequired: 4,
    ),
    ModuleKit(
      facade: 4,
      name: 'Brick Round',
      brief: 'Porthole glazing, fired brick.',
      price: 4200,
      rankRequired: 7,
    ),
  ];

  static ModuleKit byFacade(int facade) =>
      all.firstWhere((k) => k.facade == facade, orElse: () => all.first);
}
