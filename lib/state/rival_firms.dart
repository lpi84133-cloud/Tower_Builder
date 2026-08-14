import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/local_vault.dart';

/// One row of the weekly board.
@immutable
class FirmStanding {
  const FirmStanding({
    required this.firm,
    required this.height,
    required this.earnings,
    required this.isPlayer,
  });

  final String firm;
  final int height;
  final int earnings;
  final bool isPlayer;
}

/// A weekly standings board built entirely on-device.
///
/// There is no server and no account: the rival firms are generated from a seed
/// derived from the ISO week number, so the table is stable all week, refreshes
/// every Monday, and never sends or receives anything over the network.
class RivalFirms extends ChangeNotifier {
  RivalFirms(this._vault)
      : _week = _vault.readInt(Field.rivalWeek, fallback: -1),
        _height = _vault.readInt(Field.rivalHeight),
        _earnings = _vault.readInt(Field.rivalEarnings) {
    _rollOverIfNeeded();
  }

  final LocalVault _vault;

  int _week;
  int _height;
  int _earnings;

  static const _firmNames = <String>[
    'Keystone & Vale',
    'Northgate Steel',
    'Marlow Rigging',
    'Ferro Civic',
    'Halden Works',
    'Ostrand Frames',
    'Pike & Draper',
    'Ashcroft Union',
    'Verity Structures',
    'Brandt Lifting',
    'Solberg Concrete',
    'Cranefield Co.',
  ];

  int get weekHeight => _height;
  int get weekEarnings => _earnings;

  /// ISO-8601 week number, used as the board's seed and rollover marker.
  static int isoWeek(DateTime when) {
    final thursday = when.add(Duration(days: 4 - (when.weekday)));
    final firstDay = DateTime(thursday.year, 1, 1);
    final week = ((thursday.difference(firstDay).inDays) / 7).floor() + 1;
    return thursday.year * 100 + week;
  }

  void _rollOverIfNeeded() {
    final current = isoWeek(DateTime.now());
    if (_week == current) return;
    _week = current;
    _height = 0;
    _earnings = 0;
    _vault.putAll({
      Field.rivalWeek: _week,
      Field.rivalHeight: 0,
      Field.rivalEarnings: 0,
    });
  }

  /// Fold a finished job into this week's personal totals.
  Future<void> recordJob({required int height, required int earnings}) async {
    _rollOverIfNeeded();
    var touched = false;
    if (height > _height) {
      _height = height;
      touched = true;
    }
    if (earnings > 0) {
      _earnings += earnings;
      touched = true;
    }
    if (!touched) return;
    await _vault.putAll({
      Field.rivalHeight: _height,
      Field.rivalEarnings: _earnings,
    });
    notifyListeners();
  }

  /// The full table, sorted by height then earnings, with the player folded in.
  List<FirmStanding> table() {
    _rollOverIfNeeded();
    final rng = math.Random(_week);
    final names = List<String>.of(_firmNames)..shuffle(rng);

    // Rivals are pitched around the player's own week so the board stays a
    // meaningful target rather than an unreachable wall.
    final anchor = math.max(6, _height + 2);
    final rows = <FirmStanding>[
      for (var i = 0; i < 9; i++)
        FirmStanding(
          firm: names[i],
          height: math.max(1, anchor - i + rng.nextInt(4) - 1),
          earnings: (anchor - i + 2) * (420 + rng.nextInt(680)),
          isPlayer: false,
        ),
      FirmStanding(
        firm: 'Your studio',
        height: _height,
        earnings: _earnings,
        isPlayer: true,
      ),
    ];

    rows.sort((a, b) {
      final byHeight = b.height.compareTo(a.height);
      return byHeight != 0 ? byHeight : b.earnings.compareTo(a.earnings);
    });
    return rows;
  }

  /// The player's 1-based position on the board.
  int get placement {
    final rows = table();
    return rows.indexWhere((row) => row.isPlayer) + 1;
  }
}
