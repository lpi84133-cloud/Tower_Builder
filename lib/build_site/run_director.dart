import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../app/palette.dart';
import 'crane_rig.dart';
import 'risk_tier.dart';
import 'site_entities.dart';
import 'site_metrics.dart';
import 'sprite_bank.dart';

/// Immutable HUD snapshot. Pushed through [RunDirector.board] so the overlay
/// widgets rebuild only when a discrete value moves, not on every painted frame.
@immutable
class RunBoard {
  const RunBoard({
    required this.phase,
    required this.storeys,
    required this.bonus,
    required this.lastRoll,
    required this.projected,
    required this.budget,
    required this.canSignOff,
    required this.rolls,
    required this.verdictReady,
  });

  final RunPhase phase;
  final int storeys;

  /// Compounded payout bonus (product of every storey that held).
  final double bonus;

  /// The most recent storey's own roll — the value the big headline shows.
  final double lastRoll;

  /// What signing off right now would pay.
  final int projected;
  final int budget;
  final bool canSignOff;

  /// Newest-first log of per-storey rolls.
  final List<double> rolls;

  /// True once the result sheet may appear, a beat after the headline lands.
  final bool verdictReady;

  static const blank = RunBoard(
    phase: RunPhase.planning,
    storeys: 0,
    bonus: 0,
    lastRoll: 0,
    projected: 0,
    budget: 0,
    canSignOff: false,
    rolls: [],
    verdictReady: false,
  );
}

/// Runs one build job: the crane swings a module, a PLACE tap releases it, the
/// risk plan decides whether that storey holds, and every storey that holds
/// compounds the payout bonus. Signing off banks the bonus; a failure ends the
/// job and the frame comes down.
///
/// Drives the renderer through [ChangeNotifier] and the HUD through [board].
/// Sound and haptics are emitted as [SiteCue]s for the screen to play, so this
/// class stays free of plugin calls.
class RunDirector extends ChangeNotifier {
  RunDirector({
    required this.sprites,
    required this.pickFacade,
    required RiskPlan plan,
  }) : _plan = plan {
    _facade = pickFacade();
    _cameraY = SiteMetrics.padTop - SiteMetrics.cameraLead;
  }

  final SpriteBank sprites;

  /// Supplies the facade for the next module (the workshop selection, or a
  /// random owned kit when the player picked "mixed").
  final int Function() pickFacade;

  final math.Random _rng = math.Random();
  final CraneRig _rig = CraneRig();

  RiskPlan _plan;

  /// HUD channel.
  final ValueNotifier<RunBoard> board = ValueNotifier(RunBoard.blank);

  // --- job state ------------------------------------------------------------
  RunPhase _phase = RunPhase.planning;
  int _budget = 0;
  int _storeys = 0;
  double _bonus = 0;
  double _lastRoll = 0;
  bool _verdictReady = false;
  final List<double> _rolls = [];
  final List<Storey> _stack = [];
  Cargo? _cargo;
  int _facade = 1;

  // --- scene ----------------------------------------------------------------
  double _cameraY = 0;
  double _driftPhase = 0;
  double _jolt = 0;
  final List<Mote> _motes = [];
  final List<Callout> _callouts = [];

  // --- outward hooks --------------------------------------------------------
  void Function(SiteCue cue)? onCue;
  void Function(int storey)? onStoreySeated;
  void Function(int storey)? onCollapse;
  void Function(int storey, int payout)? onSignOff;

  // --- read models for the renderer ----------------------------------------
  RunPhase get phase => _phase;
  RiskPlan get plan => _plan;
  double get cameraY => _cameraY;
  double get driftPhase => _driftPhase;
  double get jolt => _jolt;
  int get storeys => _storeys;
  List<Storey> get stack => _stack;
  Cargo? get cargo => _cargo;
  List<Mote> get motes => _motes;
  List<Callout> get callouts => _callouts;
  int get facade => _facade;
  double get facadeHeight => sprites.moduleHeight(_facade);

  double get crownY => _stack.isEmpty ? SiteMetrics.padTop : _stack.last.topY;

  /// True while a module is actually attached to the hook.
  bool get isLoaded =>
      _phase == RunPhase.planning || _phase == RunPhase.swinging;

  double get swingAngle => isLoaded ? _rig.liveAngle : _rig.lockedAngle;
  double get pivotY => _rig.pivotY(_cameraY);
  double get hookReach => _rig.hookReach;

  double get hookTipX => hookReach * math.sin(swingAngle);
  double get hookTipY => pivotY + hookReach * math.cos(swingAngle);
  double get cargoHangX => _rig.cargoReach * math.sin(swingAngle);
  double get cargoHangY => pivotY + _rig.cargoReach * math.cos(swingAngle);

  double get bonus => _bonus;
  double get lastRoll => _lastRoll;
  int get projectedPayout => (_budget * _bonus).floor();

  // --- control --------------------------------------------------------------
  void adoptPlan(RiskPlan plan) {
    _plan = plan;
    _publish();
  }

  /// Start a job with an already-affordable [budget]. The screen debits the
  /// budget before calling this. The first module is released immediately from
  /// wherever the crane happens to be.
  void breakGround(int budget) {
    if (_phase != RunPhase.planning) return;
    _budget = budget;
    _storeys = 0;
    _bonus = 0;
    _lastRoll = 0;
    _rolls.clear();
    _stack.clear();
    _motes.clear();
    _callouts.clear();
    _cargo = null;
    _rig.rest(payout: 1);
    _cameraY = SiteMetrics.padTop - SiteMetrics.cameraLead;
    _phase = RunPhase.swinging;
    _release();
  }

  /// PLACE tap: hands the hanging module over to gravity.
  void place() {
    if (_phase != RunPhase.swinging) return;
    _release();
  }

  void _release() {
    final angle = swingAngle;
    final facade = _facade;
    final height = sprites.moduleHeight(facade);
    _rig.lockRelease(angle);

    // Pure chance. There is no aim or timing window: the risk plan's hold
    // chance alone decides the verdict, so a release cannot be "played well".
    final holds = _rng.nextDouble() <= _plan.holdChance;
    final lean = angle == 0 ? 1.0 : angle.sign;

    // A module that holds seats a touch off centre with a slight skew — random,
    // but measured from the tower centre line so the stack never walks away.
    final seatX = (_rng.nextDouble() * 2 - 1) * SiteMetrics.seatOffsetMax;
    final seatTilt = (_rng.nextDouble() * 2 - 1) * SiteMetrics.seatTiltMax;

    _cargo = Cargo(
      facade: facade,
      x: cargoHangX,
      y: cargoHangY,
      vy: SiteMetrics.releaseSpeed,
      width: SiteMetrics.moduleWidth,
      height: height,
      seatY: crownY - height / 2,
      fails: !holds,
      vx: holds ? 0 : lean * 1.4,
      // Drawn tilt is -angle (see SiteCanvas), so the module keeps the exact
      // lean it had on the hook.
      spin: -angle,
      spinRate: holds ? 0 : lean * 1.8,
      seatX: seatX,
      seatTilt: seatTilt,
    );
    _phase = RunPhase.falling;
    onCue?.call(SiteCue.release);
    _publish();
  }

  /// Bank the compounded bonus and close the job.
  void signOff() {
    if (_phase != RunPhase.swinging || _storeys < 1) return;
    final payout = projectedPayout;
    _phase = RunPhase.signedOff;
    _verdictReady = false;
    _jolt = 0.3;
    _spawnPayoutBurst();
    onCue?.call(SiteCue.payout);
    onSignOff?.call(_storeys, payout);
    _publish();
    _armVerdict();
  }

  /// Hold the result sheet back for a beat so the headline roll reads first.
  void _armVerdict() {
    final captured = _phase;
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (_phase == captured && !_verdictReady) {
        _verdictReady = true;
        _publish();
      }
    });
  }

  /// Clear the site and return to planning. The camera is deliberately not
  /// snapped: it flies back down to the pad on its own.
  void clearSite() {
    _phase = RunPhase.planning;
    _verdictReady = false;
    _storeys = 0;
    _bonus = 0;
    _lastRoll = 0;
    _rolls.clear();
    _stack.clear();
    _motes.clear();
    _callouts.clear();
    _cargo = null;
    _facade = pickFacade();
    _rig.rest();
    _publish();
  }

  // --- frame ----------------------------------------------------------------
  void advance(double dt) {
    // Clamp a long stall so nothing teleports through the frame.
    dt = dt.clamp(0.0, 1 / 30);
    _driftPhase += dt * 0.04;
    if (_jolt > 0) _jolt = math.max(0, _jolt - dt * 1.2);

    // Pay a fresh module out while planning or swinging; reel the empty hook
    // back up while a released module is in the air.
    _rig.driveWinch(dt, _phase == RunPhase.falling ? 0.0 : 1.0);
    if (isLoaded) _rig.swing(dt, _plan.halfPeriodAt(_storeys));

    if (_phase == RunPhase.falling && _cargo != null) _stepCargo(dt);

    _stepCamera(dt);
    _stepMotes(dt);
    _stepCallouts(dt);
    _settleCrown(dt);

    notifyListeners();
  }

  void _stepCargo(double dt) {
    final c = _cargo!;
    c.vy += SiteMetrics.fallGravity * dt;
    c.y += c.vy * dt;
    c.x += c.vx * dt;
    c.spin += c.spinRate * dt;

    if (!c.fails) {
      // Ease toward the seat target on the way down so the module settles into
      // its offset instead of snapping to it.
      final k = math.min(1.0, dt * 12);
      c.x += (c.seatX - c.x) * k;
      c.spin += (c.seatTilt - c.spin) * k;
      if (c.y >= c.seatY) _seat(c);
      return;
    }

    // Failed: let it tumble past the crown, then call the collapse once it is
    // clearly below the seat line.
    if (_phase == RunPhase.falling && c.y > c.seatY + c.height * 0.9) {
      _collapse();
    }
    if (c.y > _cameraY + SiteMetrics.tumbleDepth) _cargo = null;
  }

  void _seat(Cargo c) {
    final storey = Storey(
      facade: c.facade,
      centreX: c.seatX,
      topY: crownY - c.height,
      width: c.width,
      height: c.height,
      seatTilt: c.seatTilt,
      wobble: c.spin - c.seatTilt, // residual, decays to zero
    );
    _stack.add(storey);
    _cargo = null;
    _storeys += 1;

    // Each storey rolls its own bonus; the payout bonus is the running product.
    _lastRoll = _plan.rollBonus(_rng);
    _bonus = _bonus <= 0 ? _lastRoll : _bonus * _lastRoll;
    _bonus = (_bonus * 100).round() / 100;
    _rolls.insert(0, _lastRoll);
    _jolt = 0.3;

    _spawnImpactDust(storey);
    _spawnSeatSparks(storey);

    onCue?.call(SiteCue.seat);
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (_phase == RunPhase.swinging || _phase == RunPhase.falling) {
        onCue?.call(SiteCue.storey);
      }
    });
    onStoreySeated?.call(_storeys);

    // Next module: the winch pays a fresh one down from the pivot. The swing
    // phase carries over untouched.
    _facade = pickFacade();
    _rig.rest();
    _phase = RunPhase.swinging;
    _publish();
  }

  void _collapse() {
    _phase = RunPhase.collapsed;
    _verdictReady = false;
    _jolt = 0.6;
    onCue?.call(SiteCue.collapse);
    onCollapse?.call(_storeys);
    _publish();
    // No failure sheet: after a brief beat the site is cleared and the camera
    // flies back down to the pad.
    Future<void>.delayed(const Duration(milliseconds: 750), () {
      if (_phase == RunPhase.collapsed) clearSite();
    });
  }

  void _stepCamera(double dt) {
    final target = crownY - SiteMetrics.cameraLead;
    // Follows the crown while building; once the site is cleared the target
    // drops back to the pad and the camera glides home.
    _cameraY +=
        (target - _cameraY) * (1 - math.exp(-dt * SiteMetrics.cameraFollow));
  }

  void _stepMotes(double dt) {
    for (final m in _motes) {
      m.vy += m.gravity * dt;
      m.x += m.vx * dt;
      m.y += m.vy * dt;
      m.life -= dt;
    }
    _motes.removeWhere((m) => m.life <= 0);
  }

  void _stepCallouts(double dt) {
    for (final c in _callouts) {
      c.y -= dt * 1.3;
      c.life -= dt * 0.8;
    }
    _callouts.removeWhere((c) => c.life <= 0);
  }

  /// Bleed the impact wobble out of the topmost storey.
  void _settleCrown(double dt) {
    if (_stack.isEmpty) return;
    final crown = _stack.last;
    if (crown.wobble.abs() > 0.0005) {
      crown.wobble *= math.pow(0.0025, dt).toDouble();
    } else {
      crown.wobble = 0;
    }
  }

  // --- effects --------------------------------------------------------------
  void _spawnImpactDust(Storey s) {
    final base = s.topY + s.height; // underside of the module that just landed
    final halfWidth = s.width / 2;
    for (var i = 0; i < 24; i++) {
      final side = i.isEven ? -1 : 1;
      final spread = _rng.nextDouble();
      _motes.add(Mote(
        x: s.centreX + side * halfWidth * (0.25 + spread * 0.9),
        y: base - 0.1 - _rng.nextDouble() * 0.35,
        vx: side * (1.4 + _rng.nextDouble() * 3.4),
        vy: -0.3 - _rng.nextDouble() * 1.1,
        life: 0.55 + _rng.nextDouble() * 0.5,
        size: 0.32 + _rng.nextDouble() * 0.5,
        colour: const Color(0xFFE8EEF6),
        gravity: 2.6,
        soft: true,
      ));
    }
  }

  void _spawnSeatSparks(Storey s) {
    for (var i = 0; i < 16; i++) {
      final a = (i / 16) * math.pi * 2;
      _motes.add(Mote(
        x: s.centreX,
        y: s.topY,
        vx: math.cos(a) * (2.2 + _rng.nextDouble()),
        vy: math.sin(a) * (2.2 + _rng.nextDouble()),
        life: 0.4 + _rng.nextDouble() * 0.3,
        size: 0.1 + _rng.nextDouble() * 0.12,
        colour: Hue.cyan,
        gravity: 1.5,
      ));
    }
  }

  void _spawnPayoutBurst() {
    final crown = crownY;
    for (var i = 0; i < 24; i++) {
      final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 1.6;
      final speed = 3.0 + _rng.nextDouble() * 4.0;
      _motes.add(Mote(
        x: (_rng.nextDouble() - 0.5) * 2,
        y: crown,
        vx: math.cos(a) * speed,
        vy: math.sin(a) * speed,
        life: 0.7 + _rng.nextDouble() * 0.5,
        size: 0.16 + _rng.nextDouble() * 0.12,
        colour: Hue.amber,
        gravity: 9.0,
      ));
    }
  }

  void _publish() {
    board.value = RunBoard(
      phase: _phase,
      storeys: _storeys,
      bonus: _bonus,
      lastRoll: _lastRoll,
      projected: projectedPayout,
      budget: _budget,
      canSignOff: _phase == RunPhase.swinging && _storeys >= 1,
      rolls: List.unmodifiable(_rolls),
      verdictReady: _verdictReady,
    );
  }

  @override
  void dispose() {
    board.dispose();
    super.dispose();
  }
}
