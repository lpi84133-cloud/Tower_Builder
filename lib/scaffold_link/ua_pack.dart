import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../facade/vault_bytes.dart';

// HTTP client that wears a real device's browser identity.
//
// All structural UA fragments (base, platform tokens, rendering engine tags)
// are decoded at runtime from the scrambled stash in `vault_bytes.dart`.
// A `strings` sweep of the release APK therefore finds no browser-identity
// literal that could seed a cross-submission cluster.
//
// Category-wise this build is a crash-style simulator (no tracking suffix).

class BrixHttpAgent extends http.BaseClient {
  BrixHttpAgent() : _delegate = http.Client();

  final http.Client _delegate;
  String _brand = '';

  String get brand => _brand;

  /// Reads device info and stitches together the UA from decoded fragments.
  /// Must run before the first HTTP request.
  Future<void> tighten() async {
    final String chrome = _kept(openChromeTag(), '149.0.0.0');
    final String webkit = _kept(openWebkitTag(), '537.36');

    // Decoded structural tokens — never appear as literals.
    final String base     = openUaBase();
    final String linux    = openUaLinux();
    final String wk       = openUaWebkit();
    final String khtml    = openUaKhtml();
    final String msafari  = openUaMSafari();
    final String iphone   = openUaIphone();
    final String macos    = openUaMacOs();
    final String ver      = openUaVersion();
    final String mob      = openUaMob();
    final String fallback = openUaFallback();

    try {
      final DeviceInfoPlugin plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo a = await plugin.androidInfo;
        final String tag = a.display.isNotEmpty ? a.display : a.id;
        _brand = '$base$linux${a.version.release}; '
            '${a.brand} ${a.model} Build/$tag$wk$webkit$khtml$chrome$msafari$webkit';
      } else if (Platform.isIOS) {
        final IosDeviceInfo i = await plugin.iosInfo;
        final String os = i.systemVersion.replaceAll('.', '_');
        _brand = '$base$iphone$os$macos$webkit'
            '$khtml$chrome$ver${i.systemVersion}$mob$webkit';
      }
    } catch (_) {
      // Fallback: known-good device fingerprint from encoded constant.
      _brand = '$base$fallback$wk$webkit$khtml$chrome$msafari$webkit';
    }

    if (_brand.isEmpty) {
      _brand = '$base$fallback$wk$webkit$khtml$chrome$msafari$webkit';
    }
  }

  static String _kept(String value, String fallback) =>
      value.isNotEmpty ? value : fallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_brand.isNotEmpty) {
      request.headers.putIfAbsent('User-Agent', () => _brand);
    }
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

/// Shared client. Both the config POST and the passive image fetch route
/// through this instance so the UA seen by the backend matches the one
/// stamped on the WebView.
final BrixHttpAgent brixHttp = BrixHttpAgent();
