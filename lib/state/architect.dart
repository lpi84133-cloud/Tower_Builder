import 'package:flutter/foundation.dart';

import '../build_site/district.dart';
import '../build_site/risk_tier.dart';
import '../data/local_vault.dart';
import 'rank_ladder.dart';

/// What crossing a rank boundary handed over, so the UI can celebrate it.
@immutable
class Promotion {
  const Promotion({
    required this.happened,
    required this.rank,
    required this.title,
    required this.brixAwarded,
    required this.kitsUnlocked,
  });

  static const none = Promotion(
    happened: false,
    rank: 0,
    title: '',
    brixAwarded: 0,
    kitsUnlocked: [],
  );

  final bool happened;
  final int rank;
  final String title;
  final int brixAwarded;
  final List<int> kitsUnlocked;
}

/// The player's studio: balance, career rank, unlocked cosmetics, site
/// preferences and lifetime stats. Reads through once at construction, then
/// serves every screen from memory and writes changes back to the vault.
class Architect extends ChangeNotifier {
  Architect(this._vault)
      : _brix = _vault.readInt(Field.brix, fallback: 1000),
        _xp = _vault.readInt(Field.xp),
        _ownedKits = _vault.readIntList(Field.ownedKits),
        _activeKit = _vault.readInt(Field.activeKit),
        _ownedDistricts = _vault.readIntList(Field.ownedDistricts),
        _activeDistrict = _vault.readInt(Field.activeDistrict),
        _riskTier = _vault.readInt(Field.riskTier, fallback: 1),
        _lastBudget = _vault.readInt(Field.lastBudget, fallback: 100),
        _soundOn = _vault.readBool(Field.soundOn, fallback: true),
        _musicOn = _vault.readBool(Field.musicOn, fallback: true),
        _hapticsOn = _vault.readBool(Field.hapticsOn, fallback: true),
        _musicLevel = _vault.readDouble(Field.musicLevel, fallback: 0.5),
        _soundLevel = _vault.readDouble(Field.soundLevel, fallback: 0.85),
        _bestPayout = _vault.readInt(Field.bestPayout),
        _bestHeight = _vault.readInt(Field.bestHeight),
        _jobsRun = _vault.readInt(Field.jobsRun),
        _storeysTotal = _vault.readInt(Field.storeysTotal),
        _signOffs = _vault.readInt(Field.signOffs) {
    if (_ownedKits.isEmpty) _ownedKits = [1];
    if (_ownedDistricts.isEmpty) _ownedDistricts = [0];
  }

  final LocalVault _vault;

  int _brix;
  int _xp;
  List<int> _ownedKits;
  int _activeKit;
  List<int> _ownedDistricts;
  int _activeDistrict;
  int _riskTier;
  int _lastBudget;
  bool _soundOn;
  bool _musicOn;
  bool _hapticsOn;
  double _musicLevel;
  double _soundLevel;
  int _bestPayout;
  int _bestHeight;
  int _jobsRun;
  int _storeysTotal;
  int _signOffs;

  // --- balance & career -----------------------------------------------------
  int get brix => _brix;
  int get xp => _xp;
  int get rank => RankLadder.rankFor(_xp);
  String get rankTitle => RankLadder.titleFor(rank);
  double get rankProgress => RankLadder.progress(_xp);
  int get xpInsideRank => RankLadder.xpInsideRank(_xp);
  int get xpSpan => RankLadder.spanOfRank(_xp);

  // --- cosmetics ------------------------------------------------------------
  List<int> get ownedKits => List.unmodifiable(_ownedKits);
  int get activeKit => _activeKit;
  List<int> get ownedDistricts => List.unmodifiable(_ownedDistricts);
  int get activeDistrict => _activeDistrict;
  District get district => District.byId(_activeDistrict);

  // --- site preferences -----------------------------------------------------
  RiskTier get riskTier =>
      RiskTier.values[_riskTier.clamp(0, RiskTier.values.length - 1)];
  RiskPlan get riskPlan => RiskPlan.of(riskTier);
  int get lastBudget => _lastBudget;

  bool get soundOn => _soundOn;
  bool get musicOn => _musicOn;
  bool get hapticsOn => _hapticsOn;
  double get musicLevel => _musicLevel;
  double get soundLevel => _soundLevel;

  // --- lifetime stats -------------------------------------------------------
  int get bestPayout => _bestPayout;
  int get bestHeight => _bestHeight;
  int get jobsRun => _jobsRun;
  int get storeysTotal => _storeysTotal;
  int get signOffs => _signOffs;
  double get signOffRate => _jobsRun == 0 ? 0 : _signOffs / _jobsRun;

  // --- economy --------------------------------------------------------------
  Future<void> credit(int amount) async {
    if (amount <= 0) return;
    _brix += amount;
    await _vault.put(Field.brix, _brix);
    notifyListeners();
  }

  Future<bool> debit(int amount) async {
    if (amount <= 0 || _brix < amount) return false;
    _brix -= amount;
    await _vault.put(Field.brix, _brix);
    notifyListeners();
    return true;
  }

  /// Top up an empty site so the game is never a dead end. Only ever fires when
  /// the balance is below one minimum budget.
  Future<bool> claimSiteGrant(int amount) async {
    if (_brix >= amount) return false;
    _brix = amount;
    await _vault.put(Field.brix, _brix);
    notifyListeners();
    return true;
  }

  // --- experience -----------------------------------------------------------
  Future<Promotion> awardXp(int amount) async {
    if (amount <= 0) return Promotion.none;
    final before = rank;
    _xp += amount;
    final after = RankLadder.rankFor(_xp);

    var brixAwarded = 0;
    final unlocked = <int>[];
    if (after > before) {
      for (var r = before + 1; r <= after; r++) {
        brixAwarded += RankLadder.reward(r);
        for (final kit in RankLadder.kitsUnlockedAt(r)) {
          if (!_ownedKits.contains(kit)) {
            _ownedKits = [..._ownedKits, kit]..sort();
            unlocked.add(kit);
          }
        }
      }
      _brix += brixAwarded;
    }

    await _vault.putAll({
      Field.xp: _xp,
      Field.brix: _brix,
      Field.ownedKits: _ownedKits,
    });
    notifyListeners();

    if (after == before) return Promotion.none;
    return Promotion(
      happened: true,
      rank: after,
      title: RankLadder.titleFor(after),
      brixAwarded: brixAwarded,
      kitsUnlocked: unlocked,
    );
  }

  // --- stats ----------------------------------------------------------------
  Future<void> logJob({
    required int payout,
    required int storeys,
    required bool signedOff,
  }) async {
    _jobsRun += 1;
    _storeysTotal += storeys;
    if (signedOff) _signOffs += 1;
    if (payout > _bestPayout) _bestPayout = payout;
    if (storeys > _bestHeight) _bestHeight = storeys;
    await _vault.putAll({
      Field.jobsRun: _jobsRun,
      Field.storeysTotal: _storeysTotal,
      Field.signOffs: _signOffs,
      Field.bestPayout: _bestPayout,
      Field.bestHeight: _bestHeight,
    });
    notifyListeners();
  }

  // --- workshop -------------------------------------------------------------
  bool ownsKit(int facade) => _ownedKits.contains(facade);
  bool ownsDistrict(int id) => _ownedDistricts.contains(id);

  Future<bool> buyKit(ModuleKit kit) async {
    if (ownsKit(kit.facade)) return true;
    if (rank < kit.rankRequired) return false;
    if (!await debit(kit.price)) return false;
    _ownedKits = [..._ownedKits, kit.facade]..sort();
    await _vault.put(Field.ownedKits, _ownedKits);
    notifyListeners();
    return true;
  }

  Future<void> selectKit(int facade) async {
    if (facade != 0 && !ownsKit(facade)) return;
    _activeKit = facade;
    await _vault.put(Field.activeKit, facade);
    notifyListeners();
  }

  Future<bool> buyDistrict(District district) async {
    if (ownsDistrict(district.id)) return true;
    if (rank < district.rankRequired) return false;
    if (!await debit(district.price)) return false;
    _ownedDistricts = [..._ownedDistricts, district.id]..sort();
    await _vault.put(Field.ownedDistricts, _ownedDistricts);
    notifyListeners();
    return true;
  }

  Future<void> selectDistrict(int id) async {
    if (!ownsDistrict(id)) return;
    _activeDistrict = id;
    await _vault.put(Field.activeDistrict, id);
    notifyListeners();
  }

  // --- preferences ----------------------------------------------------------
  Future<void> setRiskTier(RiskTier tier) async {
    _riskTier = tier.index;
    await _vault.put(Field.riskTier, _riskTier);
    notifyListeners();
  }

  Future<void> rememberBudget(int budget) async {
    _lastBudget = budget;
    await _vault.put(Field.lastBudget, budget);
    notifyListeners();
  }

  Future<void> setSoundOn(bool on) async {
    _soundOn = on;
    await _vault.put(Field.soundOn, on);
    notifyListeners();
  }

  Future<void> setMusicOn(bool on) async {
    _musicOn = on;
    await _vault.put(Field.musicOn, on);
    notifyListeners();
  }

  Future<void> setHapticsOn(bool on) async {
    _hapticsOn = on;
    await _vault.put(Field.hapticsOn, on);
    notifyListeners();
  }

  Future<void> setMusicLevel(double level) async {
    _musicLevel = level.clamp(0.0, 1.0);
    await _vault.put(Field.musicLevel, _musicLevel);
    notifyListeners();
  }

  Future<void> setSoundLevel(double level) async {
    _soundLevel = level.clamp(0.0, 1.0);
    await _vault.put(Field.soundLevel, _soundLevel);
    notifyListeners();
  }

  /// Wipe every trace of progress from the device.
  Future<void> eraseEverything() async {
    await _vault.wipeProgress();
    _brix = _vault.readInt(Field.brix, fallback: 1000);
    _xp = 0;
    _ownedKits = [1];
    _activeKit = 0;
    _ownedDistricts = [0];
    _activeDistrict = 0;
    _riskTier = 1;
    _lastBudget = 100;
    _bestPayout = 0;
    _bestHeight = 0;
    _jobsRun = 0;
    _storeysTotal = 0;
    _signOffs = 0;
    notifyListeners();
  }
}
