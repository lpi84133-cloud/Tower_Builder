import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../build_site/risk_tier.dart';
import '../data/local_vault.dart';
import 'architect.dart';

/// One of the day's jobs-on-the-side. Progress is counted locally and the reward
/// is claimed by hand so the player sees what they earned.
enum ContractGoal {
  seatStoreys,
  signOffJobs,
  reachHeight,
  compoundBonus,
  runJobs,
  boldSignOff,
  bankPayout,
}

class Contract {
  Contract({
    required this.goal,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.claimed = false,
  });

  final ContractGoal goal;
  final int target;
  final int reward;
  int progress;
  bool claimed;

  bool get complete => progress >= target;
  bool get claimable => complete && !claimed;
  double get fraction => (progress / target).clamp(0.0, 1.0);

  String get headline {
    switch (goal) {
      case ContractGoal.seatStoreys:
        return 'Seat $target storeys';
      case ContractGoal.signOffJobs:
        return 'Sign off $target builds';
      case ContractGoal.reachHeight:
        return 'Reach storey $target in one build';
      case ContractGoal.compoundBonus:
        return 'Compound a bonus of x$target';
      case ContractGoal.runJobs:
        return 'Break ground $target times';
      case ContractGoal.boldSignOff:
        return 'Sign off $target builds on Bold or higher';
      case ContractGoal.bankPayout:
        return 'Bank $target BRIX from one build';
    }
  }

  String get detail {
    switch (goal) {
      case ContractGoal.seatStoreys:
        return 'Any risk plan counts.';
      case ContractGoal.signOffJobs:
        return 'Close the job before the frame fails.';
      case ContractGoal.reachHeight:
        return 'Height counts even if the build later fails.';
      case ContractGoal.compoundBonus:
        return 'The running bonus, not a single storey roll.';
      case ContractGoal.runJobs:
        return 'Every job started counts.';
      case ContractGoal.boldSignOff:
        return 'Bold or Reckless plans only.';
      case ContractGoal.bankPayout:
        return 'A single sign-off has to pay it.';
    }
  }

  Map<String, Object?> toRecord() => {
        'g': goal.index,
        't': target,
        'r': reward,
        'p': progress,
        'c': claimed,
      };

  static Contract? fromRecord(Map<String, Object?> record) {
    final goalIndex = record['g'];
    if (goalIndex is! int || goalIndex < 0 || goalIndex >= ContractGoal.values.length) {
      return null;
    }
    return Contract(
      goal: ContractGoal.values[goalIndex],
      target: (record['t'] as num?)?.toInt() ?? 1,
      reward: (record['r'] as num?)?.toInt() ?? 100,
      progress: (record['p'] as num?)?.toInt() ?? 0,
      claimed: record['c'] == true,
    );
  }
}

/// Issues three contracts a day, tracks them against live play and pays them out.
/// The board rolls over at local midnight; the day is stamped as `yyyy-mm-dd`.
class ContractBoard extends ChangeNotifier {
  ContractBoard(this._vault, this._architect) {
    _load();
  }

  final LocalVault _vault;
  final Architect _architect;

  List<Contract> _slate = [];
  String _stamp = '';

  List<Contract> get slate => List.unmodifiable(_slate);
  int get claimableCount => _slate.where((c) => c.claimable).length;
  int get completedCount => _slate.where((c) => c.complete).length;

  static String _today() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  void _load() {
    _stamp = _vault.readString(Field.contractStamp);
    _slate = _vault
        .readRecords(Field.contracts)
        .map(Contract.fromRecord)
        .whereType<Contract>()
        .toList();
    if (_stamp != _today() || _slate.isEmpty) {
      _reroll();
    }
  }

  /// A fresh slate, seeded off the date so the same day always offers the same
  /// three contracts even if the app is restarted.
  void _reroll() {
    final stamp = _today();
    final rng = math.Random(stamp.hashCode);
    final pool = List<ContractGoal>.of(ContractGoal.values)..shuffle(rng);
    _slate = pool.take(3).map((goal) => _draft(goal, rng)).toList();
    _stamp = stamp;
    _persist();
  }

  Contract _draft(ContractGoal goal, math.Random rng) {
    switch (goal) {
      case ContractGoal.seatStoreys:
        final target = 8 + rng.nextInt(8);
        return Contract(goal: goal, target: target, reward: target * 22);
      case ContractGoal.signOffJobs:
        final target = 2 + rng.nextInt(3);
        return Contract(goal: goal, target: target, reward: 150 + target * 90);
      case ContractGoal.reachHeight:
        final target = 4 + rng.nextInt(4);
        return Contract(goal: goal, target: target, reward: 120 + target * 55);
      case ContractGoal.compoundBonus:
        final target = 3 + rng.nextInt(4);
        return Contract(goal: goal, target: target, reward: 180 + target * 70);
      case ContractGoal.runJobs:
        final target = 5 + rng.nextInt(6);
        return Contract(goal: goal, target: target, reward: target * 30);
      case ContractGoal.boldSignOff:
        final target = 1 + rng.nextInt(2);
        return Contract(goal: goal, target: target, reward: 260 + target * 140);
      case ContractGoal.bankPayout:
        final target = (2 + rng.nextInt(4)) * 250;
        return Contract(goal: goal, target: target, reward: 240);
    }
  }

  void _persist() {
    _vault.putAll({
      Field.contractStamp: _stamp,
      Field.contracts: _slate.map((c) => c.toRecord()).toList(),
    });
  }

  /// Roll the board over if the app was left open across midnight.
  void refreshIfStale() {
    if (_stamp != _today()) {
      _reroll();
      notifyListeners();
    }
  }

  void _bump(ContractGoal goal, int by) {
    var touched = false;
    for (final contract in _slate) {
      if (contract.goal == goal && !contract.complete) {
        contract.progress += by;
        touched = true;
      }
    }
    if (touched) {
      _persist();
      notifyListeners();
    }
  }

  void _raiseTo(ContractGoal goal, int value) {
    var touched = false;
    for (final contract in _slate) {
      if (contract.goal == goal && !contract.complete && value > contract.progress) {
        contract.progress = value;
        touched = true;
      }
    }
    if (touched) {
      _persist();
      notifyListeners();
    }
  }

  // --- live play hooks ------------------------------------------------------
  void onGroundBroken() => _bump(ContractGoal.runJobs, 1);

  void onStoreySeated(int storeyCount) {
    _bump(ContractGoal.seatStoreys, 1);
    _raiseTo(ContractGoal.reachHeight, storeyCount);
  }

  void onBonusReached(double bonus) =>
      _raiseTo(ContractGoal.compoundBonus, bonus.floor());

  void onSignOff({required int payout, required RiskTier tier}) {
    _bump(ContractGoal.signOffJobs, 1);
    _raiseTo(ContractGoal.bankPayout, payout);
    if (tier == RiskTier.bold || tier == RiskTier.reckless) {
      _bump(ContractGoal.boldSignOff, 1);
    }
  }

  /// Pay a finished contract out. Returns the reward, or zero if not claimable.
  Future<int> claim(Contract contract) async {
    if (!contract.claimable) return 0;
    contract.claimed = true;
    _persist();
    await _architect.credit(contract.reward);
    notifyListeners();
    return contract.reward;
  }
}
