/// Tuning for the build site. Everything is expressed in abstract *site units*
/// and the renderer maps [siteWidth] units across the available pixel width, so
/// the frame reads identically on any aspect ratio. Y grows downward while the
/// tower grows upward (decreasing Y), which matches how the crane hangs above it.
class SiteMetrics {
  const SiteMetrics._();

  /// Units across the playfield. Wider site = smaller module footprint on
  /// screen; tuned so a module covers roughly a third of the width.
  static const double siteWidth = 16.0;

  /// Module footprint. Width is fixed so alignment maths stays uniform; the
  /// height of each facade comes from its own aspect at load time, clamped into
  /// [minModuleAspect] .. [maxModuleAspect].
  /// Sprites are cropped to their painted content, so a module fills this
  /// footprint edge to edge — near enough the width of the pad it lands on.
  static const double moduleWidth = 5.2;

  /// The clamp only exists to stop a freak sprite from towering over the frame;
  /// the shipped facades all sit inside it, so none of them is stretched.
  static const double minModuleAspect = 0.78; // height / width
  static const double maxModuleAspect = 1.24;

  /// The painted ground-floor unit that the first storey lands on.
  static const double padWidth = 5.3;
  static const double padHeight = 4.6;

  // --- crane rig ------------------------------------------------------------
  /// The rig is a rigid pendulum about a pivot sitting off the top of the
  /// screen (the boom). Hook and cargo ride concentric arcs about that pivot,
  /// which is what makes the cable poke further out at the bottom of the swing
  /// and retract toward the extremes. Position uses +sin(a); the drawn tilt is
  /// -a. Peak deflection is ~17 degrees.
  static const double swingAmplitude = 0.30;

  /// Pivot height above the camera centre, plus the pivot→cargo and pivot→hook
  /// radii. The hook radius is short enough that the hardware stays clear of the
  /// top HUD bar.
  static const double pivotAboveCamera = 18.0;
  static const double cargoRadius = 13.0;
  static const double hookRadius = 9.0;

  /// Drawn height of the hook hardware, and which bottom fraction of the hook
  /// sprite *is* hardware — the remainder is cable, stretched up to the pivot.
  static const double hookHardwareHeight = 3.0;
  static const double hookHardwareFraction = 0.46;

  /// Seconds for the winch to pay a fresh module down into the swing, and to
  /// reel the empty hook back up after a release.
  static const double winchDuration = 0.35;

  // --- release kinematics ---------------------------------------------------
  static const double fallGravity = 70.0;
  static const double releaseSpeed = 6.0;

  /// A module that holds seats itself slightly off centre with a small skew, so
  /// the stack looks hand-placed. Both are measured from the tower centre line,
  /// which keeps the stack from drifting away over a long run.
  static const double seatOffsetMax = 0.7; // units sideways
  static const double seatTiltMax = 0.06; // radians (~3.4 degrees)

  /// How far a failed module tumbles before it is dropped from the scene.
  static const double tumbleDepth = 16.0;

  // --- camera ---------------------------------------------------------------
  static const double cameraLead = 2.1; // keeps the tower top below centre
  static const double cameraFollow = 6.0; // exponential follow rate

  /// Ground line and the derived top of the foundation pad.
  static const double groundLine = 7.6;
  static double get padTop => groundLine - padHeight;

  // --- economy --------------------------------------------------------------
  static const int minBudget = 10;
  static const int maxBudget = 100000;
  static const List<int> budgetPresets = [50, 100, 250, 500];

  /// Experience awarded per seated storey and per signed-off build.
  static const int xpPerStorey = 6;
  static const int xpPerSignOff = 14;
}
