import 'dart:ui';

/// Where the current job stands.
enum RunPhase {
  /// Between jobs: the budget dial and the risk plan are editable.
  planning,

  /// A module hangs from the hook and swings; a PLACE tap releases it.
  swinging,

  /// A released module is in the air.
  falling,

  /// The player signed the build off and banked the bonus.
  signedOff,

  /// A storey failed and the frame came down.
  collapsed,
}

/// Audio/haptic beats the director emits. The screen owns playback so the
/// simulation itself stays free of plugin calls (and stays unit-testable).
enum SiteCue { release, seat, storey, payout, collapse }

/// A module that is standing in the finished stack.
class Storey {
  Storey({
    required this.facade,
    required this.centreX,
    required this.topY,
    required this.width,
    required this.height,
    this.seatTilt = 0,
    this.wobble = 0,
  });

  final int facade;
  final double centreX;
  final double topY;
  final double width;
  final double height;

  /// Permanent skew captured when the module seated, so the stack reads as
  /// hand-placed rather than laser-aligned.
  final double seatTilt;

  /// Impact wobble layered on top of [seatTilt]; decays to zero.
  double wobble;

  double get centreY => topY + height / 2;
}

/// The module in the air between release and its verdict.
class Cargo {
  Cargo({
    required this.facade,
    required this.x,
    required this.y,
    required this.vy,
    required this.width,
    required this.height,
    required this.seatY,
    required this.fails,
    this.vx = 0,
    this.spin = 0,
    this.spinRate = 0,
    this.seatX = 0,
    this.seatTilt = 0,
  });

  final int facade;
  double x;
  double y; // centre Y
  double vy;
  double vx;
  double spin;
  double spinRate;
  final double width;
  final double height;

  /// Centre-Y at which a holding module comes to rest on the stack.
  final double seatY;

  /// Decided at release time from the risk plan's hold chance.
  final bool fails;

  /// Where a holding module eases to as it lands.
  final double seatX;
  final double seatTilt;
}

/// Dust puff, spark or debris mote.
class Mote {
  Mote({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.colour,
    this.gravity = 0,
    this.shrinks = true,
    this.soft = false,
  });

  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double fullLife = 1.0;
  double size;
  final Color colour;
  final double gravity;
  final bool shrinks;

  /// Soft motes render blurred — used for impact dust.
  final bool soft;
}

/// A world-space text pop such as a bonus callout.
class Callout {
  Callout({
    required this.text,
    required this.x,
    required this.y,
    required this.colour,
    this.life = 1.0,
  });

  final String text;
  double x;
  double y;
  final Color colour;
  double life;
}
