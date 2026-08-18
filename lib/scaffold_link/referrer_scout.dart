import 'package:flutter/services.dart';

/// Verdict returned by the native Play Store referrer check.
enum ReferrerVerdict {
  /// The install referrer string contains AppsFlyer / OneLink markers.
  /// The user tapped a paid link before installing.
  attributed,

  /// The referrer is empty or a plain Google Play organic tag.
  organic,

  /// The Play Store service did not respond (rare). Treated the same
  /// as [organic] — safer to open the game than to block a real user
  /// with a dead-end no-wi-fi screen because of a flaky IPC call.
  unknown,
}

/// Reads the Google Play Install Referrer via a local IPC call to the
/// Play Store process. Works without internet — the referrer data is
/// stored on-device during install.
///
/// Only meaningful on the very FIRST offline launch (DialMode.pending).
/// Once the mode is decided and written to storage this class is no
/// longer called.
class ReferrerScout {
  // Keep in sync with SiteActivity.kt → referralChannel
  static const MethodChannel _ch = MethodChannel('bc.greenfg/referral/v1');

  /// Returns the install verdict.
  ///
  /// Wraps any platform exception in [ReferrerVerdict.unknown] so the
  /// caller never has to guard against errors.
  static Future<ReferrerVerdict> classify() async {
    try {
      final Object? raw = await _ch.invokeMethod<String>('classify');
      switch (raw as String?) {
        case 'attributed':
          return ReferrerVerdict.attributed;
        case 'organic':
          return ReferrerVerdict.organic;
        default:
          return ReferrerVerdict.unknown;
      }
    } on PlatformException {
      return ReferrerVerdict.unknown;
    } on MissingPluginException {
      return ReferrerVerdict.unknown;
    }
  }
}
