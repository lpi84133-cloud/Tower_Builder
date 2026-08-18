import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reachability probe. Adapter state alone is not enough (captive-portal
/// networks report a connected adapter without real internet), so the
/// probe also runs a short DNS lookup. Timeout is deliberately generous
/// because a genuine "offline" case throws `SocketException` instantly
/// — there is no cost to a longer window, only benefit on VPN links.
class NetTap {
  NetTap({Connectivity? plugin}) : _plugin = plugin ?? Connectivity();

  final Connectivity _plugin;

  static const Set<ConnectivityResult> _live = <ConnectivityResult>{
    ConnectivityResult.wifi,
    ConnectivityResult.mobile,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
    ConnectivityResult.bluetooth,
    ConnectivityResult.other,
  };

  Future<bool> alive() async {
    final List<ConnectivityResult> now = await _plugin.checkConnectivity();
    if (!now.any(_live.contains)) return false;
    try {
      final List<InternetAddress> probe = await InternetAddress.lookup(
        'cloudflare.com',
      ).timeout(const Duration(seconds: 7));
      return probe.isNotEmpty && probe.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get pulses =>
      _plugin.onConnectivityChanged;
}
