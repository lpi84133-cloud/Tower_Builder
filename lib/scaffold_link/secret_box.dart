import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../facade/dial_mode.dart';

/// Persistence layer for the site-portal. Terse, neutral key names so a
/// prefs dump does not spell out the intent. URLs land in secure storage
/// (encrypted at rest); flags and integers live in `SharedPreferences`.
class SecretBox {
  SecretBox({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const String _kDial = 'tw_dial_v2';
  static const String _kCached = 'tw_ln_blob';
  static const String _kTtl = 'tw_ln_ttl';
  static const String _kInvite = 'tw_invite_at';
  static const String _kAllow = 'tw_allow';
  static const String _kOsBlock = 'tw_os_block';
  static const String _kPend = 'tw_pnd_blob';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> warmUp() async {
    _prefs = await SharedPreferences.getInstance();
    await _migrateKeys();
  }

  /// One-time migration: keys were renamed from the `br_` prefix to `tw_`
  /// (fingerprint diversification, v1.3.1). Devices that had the old keys
  /// written would lose push-permission state and cached links without this.
  Future<void> _migrateKeys() async {
    // SharedPreferences booleans
    for (final List<String> pair in <List<String>>[
      <String>['br_allow', _kAllow],
      <String>['br_os_block', _kOsBlock],
    ]) {
      final bool? v = _prefs.getBool(pair[0]);
      if (v != null && _prefs.getBool(pair[1]) == null) {
        await _prefs.setBool(pair[1], v);
        await _prefs.remove(pair[0]);
      }
    }
    // SharedPreferences strings
    final String? dial = _prefs.getString('br_dial_v2');
    if (dial != null && _prefs.getString(_kDial) == null) {
      await _prefs.setString(_kDial, dial);
      await _prefs.remove('br_dial_v2');
    }
    // SharedPreferences ints
    for (final List<String> pair in <List<String>>[
      <String>['br_ln_ttl', _kTtl],
      <String>['br_invite_at', _kInvite],
    ]) {
      final int? v = _prefs.getInt(pair[0]);
      if (v != null && _prefs.getInt(pair[1]) == null) {
        await _prefs.setInt(pair[1], v);
        await _prefs.remove(pair[0]);
      }
    }
    // Secure storage (encrypted) — cached link and pending push link
    for (final List<String> pair in <List<String>>[
      <String>['br_ln_blob', _kCached],
      <String>['br_pnd_blob', _kPend],
    ]) {
      final String? v = await _secure.read(key: pair[0]);
      if (v != null) {
        final String? already = await _secure.read(key: pair[1]);
        if (already == null) {
          await _secure.write(key: pair[1], value: v);
        }
        await _secure.delete(key: pair[0]);
      }
    }
  }

  // ── Dial ──
  DialMode readDial() => DialMode.decode(_prefs.getString(_kDial));

  Future<void> writeDial(DialMode d) => _prefs.setString(_kDial, d.encode());

  // ── Cached link ──
  Future<String?> readCachedLink() => _secure.read(key: _kCached);

  Future<void> writeCachedLink(String link) =>
      _secure.write(key: _kCached, value: link);

  int? readLinkTtl() => _prefs.getInt(_kTtl);

  Future<void> writeLinkTtl(int unixSeconds) =>
      _prefs.setInt(_kTtl, unixSeconds);

  bool isLinkStale() {
    final int? t = readLinkTtl();
    if (t == null) return true;
    return _now() >= t;
  }

  // ── Push permission state ──
  bool isPushAllowed() => _prefs.getBool(_kAllow) ?? false;

  Future<void> markPushAllowed(bool value) =>
      _prefs.setBool(_kAllow, value);

  /// True once the OS-level dialog was denied — Android silently drops
  /// further requestPermission() calls afterwards, so the invite screen
  /// must not reappear.
  bool isPushBlockedByOs() => _prefs.getBool(_kOsBlock) ?? false;

  Future<void> markPushBlockedByOs() => _prefs.setBool(_kOsBlock, true);

  int? readInviteCooldown() => _prefs.getInt(_kInvite);

  Future<void> writeInviteCooldown(int unixSeconds) =>
      _prefs.setInt(_kInvite, unixSeconds);

  bool shouldOfferPushInvite() {
    if (isPushAllowed()) return false;
    if (isPushBlockedByOs()) return false;
    final int? until = readInviteCooldown();
    if (until == null) return true;
    return _now() >= until;
  }

  // ── One-time push link ──
  Future<void> stashPendingLink(String? link) async {
    if (link == null) {
      await _secure.delete(key: _kPend);
    } else {
      await _secure.write(key: _kPend, value: link);
    }
  }

  Future<String?> takePendingLink() async {
    final String? link = await _secure.read(key: _kPend);
    if (link != null) await _secure.delete(key: _kPend);
    return link;
  }

  static int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
