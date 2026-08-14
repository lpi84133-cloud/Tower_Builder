import 'dart:math' as math;

import 'site_metrics.dart';

/// Kinematics of the tower crane, kept apart from the run logic so the swing and
/// the winch can be reasoned about (and tuned) on their own.
///
/// The rig is a rigid pendulum about a pivot that sits off the top of the screen.
/// Hook and cargo ride concentric arcs about that pivot, so the visible cable
/// length changes across the swing exactly as it would on a real boom. Amplitude
/// scales with how far the winch has paid out, which makes a fresh module lower
/// in straight and then widen into its full arc.
class CraneRig {
  double _phase = 0;
  double _payout = 1;
  double _lockedAngle = 0;

  /// 0 = reeled up to the pivot, 1 = fully paid out.
  double get payout => _payout;

  /// Smoothstep-eased payout; drives both hang distance and swing width.
  double get _eased {
    final t = _payout.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Live pendulum deflection, zero when hanging straight down.
  double get liveAngle =>
      math.sin(_phase) * SiteMetrics.swingAmplitude * _eased;

  /// Deflection captured at the instant of the last release; the empty hook
  /// holds this pose while the module falls.
  double get lockedAngle => _lockedAngle;

  double get hookReach => SiteMetrics.hookRadius * _eased;
  double get cargoReach => SiteMetrics.cargoRadius * _eased;

  double pivotY(double cameraY) => cameraY - SiteMetrics.pivotAboveCamera;

  /// Reset for a new job. Pass `payout: 1` to start already lowered.
  void rest({double payout = 0}) {
    _phase = 0;
    _payout = payout;
  }

  /// Freeze the release pose so the hook keeps the lean it had at the handoff.
  void lockRelease(double angle) => _lockedAngle = angle;

  /// Advance the pendulum. The phase is intentionally never reset between
  /// storeys, so the next module picks the arc up where the last one left it.
  void swing(double dt, double halfPeriod) {
    _phase += dt * (math.pi / halfPeriod);
    if (_phase > math.pi * 2) _phase -= math.pi * 2;
  }

  /// Drive the winch toward [target] (0 reels up, 1 pays out).
  void driveWinch(double dt, double target) {
    final step = dt / SiteMetrics.winchDuration;
    if (_payout < target) {
      _payout = math.min(target, _payout + step);
    } else if (_payout > target) {
      _payout = math.max(target, _payout - step);
    }
  }
}
