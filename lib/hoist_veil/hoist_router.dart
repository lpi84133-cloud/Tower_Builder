import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/asset_paths.dart';
import '../app/routes.dart';
import '../build_site/sprite_bank.dart';
import '../facade/dial_mode.dart';
import '../facade/dial_reply.dart';
import '../facade/manifest.dart';
import '../scaffold_link/attrib_link.dart';
import '../scaffold_link/beacon_link.dart';
import '../scaffold_link/net_dial.dart';
import '../scaffold_link/nettap.dart';
import '../scaffold_link/secret_box.dart';
import '../state/audio_desk.dart';
import 'brix_asset_kit.dart';
import 'tower_push_pane.dart';
import 'outage_gate.dart';
import 'webshell.dart';

/// One screen every install sees on frame 1. Renders the loading
/// artwork with a smooth progress tween while the shell decides —
/// based on pending push links, the cached dial mode and the config
/// gate — where to send the user next.
///
/// The progress bar is driven by a target value we push at each
/// pipeline milestone; the bar itself always eases toward that target
/// on a 350 ms curve, so it never jumps and never freezes at 100 %.
///
/// Offline-on-first-launch UX contract: the very first reachability
/// check fires BEFORE we ignite attribution. On a fail we cap the
/// bar at 0.30 (per TZ — the user must see the offline screen only
/// after the bar shows a genuine "gave up" state) and pause briefly
/// before routing to `OutageGate`.
class HoistRouter extends StatefulWidget {
  const HoistRouter({
    super.key,
    required this.box,
    required this.tap,
    required this.attrib,
    required this.dial,
    required this.beacon,
  });

  final SecretBox box;
  final NetTap tap;
  final AttribLink attrib;
  final NetDial dial;
  final BeaconLink beacon;

  @override
  State<HoistRouter> createState() => _HoistRouterState();
}

class _HoistRouterState extends State<HoistRouter>
    with TickerProviderStateMixin {
  double _target = 0.02;
  double _visible = 0.0;
  bool _routed = false;
  Timer? _bump;
  Timer? _watchdog;
  late final AnimationController _dots;

  // Safety net: if the whole pipeline (attribution → gate) fails to
  // resolve in a bounded window we escalate to outage. The pipeline
  // has its own timeouts (28s install + 18s gate ≈ 46s worst case),
  // but a plugin livelock — e.g. AppsFlyer never calling either the
  // conversion callback or the deep-link callback — can leave both
  // futures parked indefinitely.
  static const Duration _hardCap = Duration(seconds: 65);

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    // Smoothly walk `_visible` toward `_target` on a 60 fps ticker.
    // Every pipeline milestone lifts the target, and the bar catches
    // up without the perceived jumpiness of a direct setState swap.
    _bump = Timer.periodic(const Duration(milliseconds: 32), (_) {
      if (!mounted) return;
      if ((_visible - _target).abs() < 0.002) return;
      setState(() {
        _visible += (_target - _visible) * 0.08;
      });
    });
    widget.beacon.onTokenRotated = _repostToken;
    _watchdog = Timer(_hardCap, () {
      if (!mounted || _routed) return;
      debugPrint('[HoistRouter] watchdog fired — forcing outage');
      _toOutage();
    });
    _drive();
  }

  @override
  void dispose() {
    widget.beacon.onTokenRotated = null;
    _bump?.cancel();
    _watchdog?.cancel();
    _dots.dispose();
    super.dispose();
  }

  void _lift(double v) {
    if (!mounted) return;
    setState(() => _target = v.clamp(0.0, 1.0));
  }

  Future<void> _drive() async {
    _lift(0.06);
    await widget.beacon.boot();
    _lift(0.18);

    // A pending push URL wins over every other consideration — killed
    // taps stashed the URL from `getInitialMessage()` before we even
    // ran, and a warm tap that arrived while we were booting also
    // ends up in the pending slot.
    final String? pending = await widget.box.takePendingLink();
    if (pending != null) {
      _lift(1.0);
      await _breath();
      _toWeb(pending);
      return;
    }

    switch (widget.box.readDial()) {
      case DialMode.native:
        // Cached: organic user — go to the yard even offline.
        await _goYard();
        break;
      case DialMode.web:
        await _returnLink();
        break;
      case DialMode.pending:
        await _firstDial();
        break;
    }
  }

  Future<void> _firstDial() async {
    if (!await widget.tap.alive()) {
      // ── Offline first launch ──────────────────────────────────────
      // Fresh install with no internet: there is NO reliable way to
      // classify OneLink vs organic in this state.
      //   • The Play Store Install Referrer API only works for Play
      //     Store installs — APK sideloads (adb, file manager) return
      //     an empty referrer regardless of whether the user tapped a
      //     OneLink beforehand.
      //   • AppsFlyer's attribution needs the network.
      // So we show the no-wi-fi screen and let the user press Retry
      // once they have connectivity. The full pipeline then routes:
      //   • OneLink click → DialMode.web  → outage or cached link.
      //   • Organic       → DialMode.native → yard opens offline next
      //                     time the user launches the app.
      // DialMode stays `pending` here so the next launch with internet
      // fires the full attribution pipeline.
      await _stallToOutage();
      return;
    }
    _lift(0.38);

    await widget.attrib.ignite();
    await Future.wait<void>(<Future<void>>[
      widget.attrib.waitForInstall(seconds: BrixManifest.firstWaitSeconds),
      widget.attrib.waitForDeepLink(),
    ]);
    _lift(0.68);

    // Second reachability check right before the config POST: DNS
    // can go stale during the attribution wait, and firing the POST
    // over a dead link burns the full 18 s timeout for no reason.
    if (!await widget.tap.alive()) {
      await _stallToOutage();
      return;
    }

    final DialReply reply = await _ask();
    if (reply.pass && reply.hasLink) {
      await widget.box.writeDial(DialMode.web);
      _lift(1.0);
      await _breath();
      _toWeb(reply.link!);
    } else {
      // We ONLY commit permanent native lock when the gate gave us a
      // clean "organic" answer AND attribution data actually arrived.
      //
      // If attribution timed out (empty payload — common on warm-start
      // Retry after the offline branch) the gate body was missing
      // all AppsFlyer fields, so an ok:false reply is UNRELIABLE. In
      // that case we keep DialMode.pending so the next launch (or the
      // next Retry) runs the full pipeline again. For this session we
      // go to OutageGate — the user can press Retry once more.
      //
      // Same treatment for network-level failures (DNS, TLS, 5xx):
      // the gate never actually saw the request, so we must not lock.
      final bool attributionArrived = widget.attrib.hasAttributionData;
      if (_looksLikeNetworkFailure(reply.tag) || !attributionArrived) {
        await _stallToOutage();
      } else {
        await widget.box.writeDial(DialMode.native);
        await _goYard();
      }
    }
  }

  Future<void> _returnLink() async {
    if (!await widget.tap.alive()) {
      await _stallToOutage();
      return;
    }
    _lift(0.4);

    final String? cached = await widget.box.readCachedLink();

    await widget.attrib.ignite();
    await Future.wait<void>(<Future<void>>[
      widget.attrib.waitForInstall(seconds: BrixManifest.returnWaitSeconds),
      widget.attrib.waitForDeepLink(),
    ]);
    _lift(0.7);

    if (!await widget.tap.alive()) {
      if (cached != null) {
        _lift(1.0);
        await _breath();
        _toWeb(cached);
      } else {
        await _stallToOutage();
      }
      return;
    }

    final DialReply reply = await _ask();
    _lift(1.0);
    await _breath();

    if (reply.pass && reply.hasLink) {
      _toWeb(reply.link!);
    } else if (cached != null) {
      // Per §9 of the guide: on a returning launch, a failed gate
      // must still load the last-known-good link. Never fall back to
      // the yard for a `web`-locked install.
      _toWeb(cached);
    } else {
      _toOutage();
    }
  }

  Future<DialReply> _ask() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.attrib.pressGateBody(
      locale: locale,
      pushToken: widget.beacon.token,
    );
    return widget.dial.query(body);
  }

  void _repostToken(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body = await widget.attrib.pressGateBody(
      locale: locale,
      pushToken: token,
    );
    widget.dial.query(body);
  }

  Future<void> _breath() =>
      Future<void>.delayed(const Duration(milliseconds: 350));

  // Offline hold: cap the bar at 0.30 so it visibly stalls, wait a
  // beat for the visible tween to catch up, then route to outage.
  Future<void> _stallToOutage() async {
    _lift(0.30);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _toOutage();
  }

  Future<void> _goYard() async {
    // Take the yard's boot chores over from BootScreen so the user
    // does not see a second loader (blue bar / black frame) after
    // ours. Sprite decode + one image precache is what the yard
    // needs before HomeShell can paint its first frame; anything
    // else warms lazily on demand.
    await SpriteBank.shared.warmUp();
    if (!mounted) return;
    try {
      await precacheImage(const AssetImage(Art.plateBlank), context);
    } catch (_) {}
    if (!mounted) return;

    _lift(1.0);
    await _breath();
    if (_routed || !mounted) return;
    _routed = true;

    // Kick off the shell audio bed before the transition so the
    // yard already sounds alive on its first frame.
    try {
      await context.read<AudioDesk>().playBed(Bed.shell);
    } catch (_) {}
    if (!mounted) return;

    await Navigator.of(context).pushReplacementNamed(Routes.home);
  }

  void _toWeb(String link) {
    if (_routed || !mounted) return;
    _routed = true;
    if (widget.box.shouldOfferPushInvite()) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TowerPushPane(
            box: widget.box,
            beacon: widget.beacon,
            tap: widget.tap,
            link: link,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => WebShell(
            link: link,
            box: widget.box,
            beacon: widget.beacon,
            tap: widget.tap,
          ),
        ),
      );
    }
  }

  void _toOutage() {
    if (_routed || !mounted) return;
    _routed = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OutageGate(
          onRetryBuild: (_) => HoistRouter(
            box: widget.box,
            tap: widget.tap,
            attrib: widget.attrib,
            dial: widget.dial,
            beacon: widget.beacon,
          ),
        ),
      ),
    );
  }

  static bool _looksLikeNetworkFailure(String? tag) {
    if (tag == null) return false;
    final String s = tag.toLowerCase();
    return s.contains('socketexception') ||
        s.contains('handshakeexception') ||
        s.contains('timeoutexception') ||
        s.contains('failed host lookup') ||
        s.contains('no address associated') ||
        s.contains('network is unreachable') ||
        s.contains('connection reset') ||
        s.contains('connection closed') ||
        s.contains('no-endpoint') ||
        s.contains('http-5'); // 5xx server errors — gate didn't process us
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? BrixVeil.horizontalLoading
        : BrixVeil.verticalLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1E3C),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(bg, fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(34, 0, 34, 46),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _dots,
                      builder: (BuildContext context, _) {
                        final int n = (_dots.value * 4).floor() % 4;
                        return Text(
                          'Loading${'.' * n}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            shadows: <Shadow>[
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _LiftBar(value: _visible),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiftBar extends StatelessWidget {
  const _LiftBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        return Container(
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.75),
              width: 2,
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: c.maxWidth * value.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFFFD35A), Color(0xFFEE8A2E)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      },
    );
  }
}
