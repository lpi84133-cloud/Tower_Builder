/// Product-level naming and the wording used for anything a store reviewer or a
/// player might read. Kept in one place so the vocabulary stays consistent: this
/// is a construction-site simulation, the on-screen economy is a virtual site
/// budget, and nothing here is exchangeable for money.
class Brand {
  const Brand._();

  static const title = 'Tower Builder';
  static const tagline = 'Hoist it. Stack it. Sign it off.';
  static const studio = 'Steelnest';

  /// Kept in step with `version:` in pubspec.yaml.
  static const version = '1.0.0';

  /// Display + short form of the soft currency. Deliberately not "coins" or
  /// "chips": it is a stock of prefabricated modules credited to the site.
  static const currency = 'BRIX';
  static const currencyLong = 'BRIX credits';

  /// Player-facing verbs. One action drives the whole run — it commits the
  /// budget on the first press and releases the hook on every press after that,
  /// so it carries the same word throughout. The safe action closes the job and
  /// banks the bonus.
  static const actionBuild = 'BUILD';
  static const actionSignOff = 'SIGN OFF';

  static const storey = 'Storey';
  static const bonus = 'Bonus';
  static const budget = 'Budget';

  /// The legal texts ship inside the build (see `LegalScreen`); the store listing
  /// hosts the same wording for the reviewer-facing URL, so the app itself needs
  /// no network access.
  static const supportEmail = 'support@steelnest.games';

  /// Shown on the boot screen, in Options and next to every balance so the
  /// simulated nature of the economy is never ambiguous.
  static const simulationNotice =
      'Tower Builder is a construction simulation played for entertainment. '
      'BRIX are virtual site credits with no monetary value. They cannot be '
      'bought, sold, cashed out or exchanged for money, goods or prizes, and '
      'no real-world winnings are possible.';

  static const noPurchaseNotice =
      'This game contains no purchases, no advertising and no real-money '
      'wagering of any kind.';

  static const responsiblePlayNotice =
      'Take a break whenever a session stops being fun. Progress is saved on '
      'this device only, and you can wipe it at any time from Options.';

  static const minimumAge = 18;
}
