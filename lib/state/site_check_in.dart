import 'package:flutter/foundation.dart';

import '../data/local_vault.dart';
import 'architect.dart';

/// The seven-day site check-in. Showing up on consecutive days walks the ladder
/// up; missing a day drops it back to the first rung. Purely a returning-player
/// reward — there is nothing to buy and no wager involved.
class SiteCheckIn extends ChangeNotifier {
  SiteCheckIn(this._vault, this._architect)
      : _day = _vault.readInt(Field.checkInDay),
        _stamp = _vault.readString(Field.checkInStamp);

  final LocalVault _vault;
  final Architect _architect;

  int _day;
  String _stamp;

  /// BRIX for each rung of the ladder.
  static const ladder = <int>[200, 300, 450, 650, 900, 1300, 2000];

  /// How many days have been banked so far (0..7).
  int get bankedDays => _day.clamp(0, ladder.length);

  /// Index of the rung the next check-in will pay.
  int get nextRung => bankedDays >= ladder.length ? 0 : bankedDays;

  int get nextReward => ladder[nextRung];

  bool get availableToday => _stamp != _dateKey(DateTime.now());

  static String _dateKey(DateTime when) {
    final month = when.month.toString().padLeft(2, '0');
    final day = when.day.toString().padLeft(2, '0');
    return '${when.year}-$month-$day';
  }

  /// Take today's check-in. Returns the BRIX paid, or zero if already taken.
  Future<int> collect() async {
    final now = DateTime.now();
    final today = _dateKey(now);
    if (_stamp == today) return 0;

    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final consecutive = _stamp == yesterday;
    // A broken streak restarts at rung one; a full ladder wraps back around.
    final rung = (!consecutive || _day >= ladder.length) ? 0 : _day;

    final reward = ladder[rung];
    _day = rung + 1;
    _stamp = today;
    await _vault.putAll({
      Field.checkInDay: _day,
      Field.checkInStamp: _stamp,
    });
    await _architect.credit(reward);
    notifyListeners();
    return reward;
  }
}
