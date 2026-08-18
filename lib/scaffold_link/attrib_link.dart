import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../facade/manifest.dart';
import '../facade/vault_bytes.dart';
import 'ua_pack.dart';

// AppsFlyer bridge: collects install-conversion payloads, deep-link
// clicks and app-open attribution, then folds the merged bag into the
// gate request body. If the first onInstallConversionData callback
// arrives with `af_status == "Organic"` on what may have been a paid
// install, we back off and re-query the GCD endpoint once — the
// second answer wins.
//
// The bridge short-circuits when the tracer key is still blank, so a
// fresh clone of the template compiles + boots without hanging in
// waitFor* futures for 30s before falling back to the yard.

class AttribLink {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installData;
  Map<String, dynamic>? _deepLinkData;
  Map<String, dynamic>? _appOpenData;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _lit = false;

  Future<void> ignite() async {
    if (_lit) return;
    _lit = true;

    final String key = BrixManifest.tracerKey;
    if (key.isEmpty) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions opts = AppsFlyerOptions(
      afDevKey: key,
      appId: BrixManifest.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(opts);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic res) async {
      final Map<String, dynamic> bag = _flatten(res);
      final String? status = bag['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: BrixManifest.organicRecheckSeconds),
        );
        final Map<String, dynamic>? recheck = await _gcdSweep();
        _installData = recheck ?? bag;
      } else {
        _installData = bag;
      }
      _finishInstall(_installData ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic res) {
      _appOpenData = _flatten(res);
    });

    sdk.onDeepLinking((DeepLinkResult r) {
      final Map<String, dynamic>? click = r.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkData = Map<String, dynamic>.from(click);
      }
      _finishDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
    }
  }

  Future<Map<String, dynamic>> waitForInstall({int seconds = 28}) {
    return _installReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  Future<void> waitForDeepLink() {
    return _deepLinkReady.future.timeout(
      Duration(seconds: BrixManifest.deepLinkWaitSeconds),
      onTimeout: () {},
    );
  }

  /// True when the Android Intent carried OneLink / deep-link parameters
  /// that were delivered via `onDeepLinking` without a network round-trip.
  /// Use this in the offline-first-launch branch to distinguish a OneLink
  /// install (needs internet for web content) from an organic install
  /// (can play the game offline).
  bool get hasDeepLink =>
      _deepLinkData != null && _deepLinkData!.isNotEmpty;

  /// True when the install-conversion callback actually delivered data.
  /// Use this to detect an attribution TIMEOUT: if `waitForInstall`
  /// timed out the payload is null/empty — we must NOT permanently lock
  /// the install as native in that case (the gate body was empty, so
  /// any ok:false answer from the gate is unreliable).
  bool get hasAttributionData =>
      _installData != null && _installData!.isNotEmpty;

  Future<String?> uid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Merges every source into a single flat body — never nests, never
  /// filters. Attribution + deep-link + app-open first (priority order
  /// from the guide), then device-side fields last so they overwrite.
  Future<Map<String, dynamic>> pressGateBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installData != null) body.addAll(_installData!);
    _deepLinkData?.forEach((String k, dynamic v) {
      body.putIfAbsent(k, () => v);
    });
    _appOpenData?.forEach((String k, dynamic v) {
      body.putIfAbsent(k, () => v);
    });

    body['af_id'] = await uid() ?? '';
    body['bundle_id'] = BrixManifest.packageId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = BrixManifest.storeId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String proj = BrixManifest.messagingId;
    if (proj.isNotEmpty) {
      body['firebase_project_id'] = proj;
    }

    if (kDebugMode) {
      debugPrint('[AttribLink] gate body: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _gcdSweep() async {
    try {
      final String? deviceId = await uid();
      if (deviceId == null) return null;
      final String appId = Platform.isIOS
          ? BrixManifest.storeNumericId
          : BrixManifest.packageId;
      final String url = buildGcdUrl(appId, deviceId);
      if (url.isEmpty) return null;

      final dynamic res = await brixHttp.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${BrixManifest.tracerKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall(Map<String, dynamic> bag) {
    if (!_installReady.isCompleted) _installReady.complete(bag);
  }

  void _finishDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _flatten(dynamic res) {
    if (res is! Map) return <String, dynamic>{};
    final dynamic inner = res['payload'] ?? res['data'] ?? res;
    if (inner is Map) {
      return inner.map<String, dynamic>((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
