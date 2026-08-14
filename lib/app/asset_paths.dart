/// Bundle paths, in one registry so a rename is a single-file change.
///
/// `audioplayers` resolves its sources relative to the bundle's `assets/`
/// directory, hence the separate [Cue] table without the leading segment.
class Art {
  const Art._();

  static const _site = 'assets/art/site';
  static const _shell = 'assets/art/shell';

  // Playfield. The sky is painted from the district's two colours, so no sky
  // texture ships at all.
  static const skylineStrip = '$_site/skyline_strip.webp';
  static const foundationPad = '$_site/foundation_pad.webp';
  static const craneHook = '$_site/crane_hook.webp';
  static const cloudA = '$_site/cloud_a.webp';
  static const cloudB = '$_site/cloud_b.webp';

  /// Module facades the crane hoists. Indexed 1..[moduleCount].
  static const moduleCount = 4;
  static String module(int index) =>
      '$_site/module_0${index.clamp(1, moduleCount)}.webp';
  static List<String> get allModules =>
      [for (var i = 1; i <= moduleCount; i++) module(i)];

  // Shell
  static const wordmark = '$_shell/wordmark.webp';

  /// Warning-tape plate behind the site's primary action. Carries no lettering,
  /// so it can be stretched to any width and captioned in code.
  static const plateBlank = '$_shell/plate_blank.webp';
}

/// Audio cue file names, relative to the bundle's `assets/` root.
class Cue {
  const Cue._();

  static const tap = 'audio/ui_tap.wav';
  static const release = 'audio/release.wav';
  static const seat = 'audio/module_seat.wav';
  static const storey = 'audio/storey_ok.wav';
  static const payout = 'audio/payout.wav';
  static const brix = 'audio/brix.wav';
  static const collapse = 'audio/collapse.wav';
  static const rankUp = 'audio/rank_up.wav';

  static const bedShell = 'audio/bed_shell.wav';
  static const bedSite = 'audio/bed_site.wav';
}
