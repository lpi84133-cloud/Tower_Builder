import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device save file.
///
/// Everything the game remembers lives in a single JSON document under one
/// preferences key. That keeps saves atomic (no half-written multi-key state if
/// the process dies mid-write), makes a full wipe trivial, and means adding a
/// field never needs a new key constant. Nothing here leaves the device.
class LocalVault {
  LocalVault._(this._prefs, this._doc);

  static const _documentKey = 'tb.save';
  static const _schemaField = 'schema';
  static const _schema = 1;

  final SharedPreferences _prefs;
  Map<String, Object?> _doc;

  /// Values a brand-new save starts from.
  static Map<String, Object?> get _factoryDefaults => <String, Object?>{
        _schemaField: _schema,
        Field.brix: 1000,
        Field.xp: 0,
        Field.ownedKits: <Object?>[1],
        Field.activeKit: 0, // 0 = rotate through everything owned
        Field.ownedDistricts: <Object?>[0],
        Field.activeDistrict: 0,
        Field.riskTier: 1, // Standard
        Field.lastBudget: 100,
        Field.soundOn: true,
        Field.musicOn: true,
        Field.hapticsOn: true,
        Field.musicLevel: 0.5,
        Field.soundLevel: 0.85,
        Field.bestPayout: 0,
        Field.bestHeight: 0,
        Field.jobsRun: 0,
        Field.storeysTotal: 0,
        Field.signOffs: 0,
        Field.checkInDay: 0,
        Field.checkInStamp: '',
        Field.contractStamp: '',
        Field.contracts: <Object?>[],
        Field.rivalWeek: -1,
        Field.rivalHeight: 0,
        Field.rivalEarnings: 0,
      };

  static Future<LocalVault> open() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_documentKey);
    Map<String, Object?> doc;
    if (raw == null) {
      doc = Map<String, Object?>.from(_factoryDefaults);
      await prefs.setString(_documentKey, jsonEncode(doc));
    } else {
      doc = _decode(raw);
    }
    return LocalVault._(prefs, doc);
  }

  static Map<String, Object?> _decode(String raw) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        // Unknown/missing fields fall back to the factory value, so a save from
        // an older build keeps working after an update.
        return <String, Object?>{..._factoryDefaults, ...parsed.cast<String, Object?>()};
      }
    } catch (error) {
      debugPrint('LocalVault: unreadable save discarded ($error)');
    }
    return Map<String, Object?>.from(_factoryDefaults);
  }

  Future<void> _flush() => _prefs.setString(_documentKey, jsonEncode(_doc));

  // --- typed reads ----------------------------------------------------------
  int readInt(String field, {int fallback = 0}) {
    final value = _doc[field];
    if (value is int) return value;
    if (value is num) return value.round();
    return fallback;
  }

  double readDouble(String field, {double fallback = 0}) {
    final value = _doc[field];
    return value is num ? value.toDouble() : fallback;
  }

  bool readBool(String field, {bool fallback = false}) {
    final value = _doc[field];
    return value is bool ? value : fallback;
  }

  String readString(String field, {String fallback = ''}) {
    final value = _doc[field];
    return value is String ? value : fallback;
  }

  List<int> readIntList(String field) {
    final value = _doc[field];
    if (value is! List) return const [];
    return value.whereType<num>().map((n) => n.toInt()).toList()..sort();
  }

  List<Map<String, Object?>> readRecords(String field) {
    final value = _doc[field];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((m) => m.cast<String, Object?>())
        .toList(growable: false);
  }

  // --- writes ---------------------------------------------------------------
  Future<void> put(String field, Object? value) {
    _doc[field] = value;
    return _flush();
  }

  /// Commit several fields in one write — used whenever a single player action
  /// touches more than one field (a payout moves brix, xp and stats at once).
  Future<void> putAll(Map<String, Object?> patch) {
    _doc.addAll(patch);
    return _flush();
  }

  /// Reset to a brand-new save.
  Future<void> wipeProgress() {
    _doc = Map<String, Object?>.from(_factoryDefaults);
    return _flush();
  }
}

/// Field names used inside the save document.
class Field {
  const Field._();

  static const brix = 'brix';
  static const xp = 'xp';

  static const ownedKits = 'kits';
  static const activeKit = 'kit';
  static const ownedDistricts = 'districts';
  static const activeDistrict = 'district';

  static const riskTier = 'risk';
  static const lastBudget = 'budget';

  static const soundOn = 'sfx';
  static const musicOn = 'music';
  static const hapticsOn = 'haptics';
  static const musicLevel = 'musicLevel';
  static const soundLevel = 'sfxLevel';

  static const bestPayout = 'bestPayout';
  static const bestHeight = 'bestHeight';
  static const jobsRun = 'jobs';
  static const storeysTotal = 'storeys';
  static const signOffs = 'signOffs';

  static const checkInDay = 'checkInDay';
  static const checkInStamp = 'checkInStamp';

  static const contractStamp = 'contractStamp';
  static const contracts = 'contractList';

  static const rivalWeek = 'rivalWeek';
  static const rivalHeight = 'rivalHeight';
  static const rivalEarnings = 'rivalEarnings';
}
