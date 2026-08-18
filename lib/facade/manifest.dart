import 'public_urls.dart';
import 'vault_bytes.dart';

/// Single point of access for every long-lived constant the site-portal
/// stack reads. Identity fields are plaintext (the store listing declares
/// them anyway); credentials and endpoints resolve lazily through the
/// scrambler so no plaintext lands in the compiled binary.
class BrixManifest {
  BrixManifest._();

  // Identity — kept in triple sync with:
  //   • android/app/build.gradle.kts → applicationId + namespace
  //   • android/app/src/main/kotlin/**/SiteActivity.kt → package
  //   • android/app/google-services.json → package_name
  static const String packageId = 'bc.greenfggames.towerbuilder';
  static const String storeId = 'bc.greenfggames.towerbuilder';
  static const String displayName = 'Tower Builder';

  /// iOS App Store numeric id — empty on Android-only builds. If an
  /// iOS submission is ever added, this is what carries the `idNNNN`
  /// value the config endpoint expects.
  static const String storeNumericId = '';

  // Endpoints / credentials — lazily unwrapped.
  static String get gateEndpoint => openGatePost();
  static String get tracerKey => openTracerKey();
  static String get messagingId => openMessagingId();

  // Public URLs (plaintext, non-sensitive).
  static const String privacyUrl = privacyPage;
  static const String supportUrl = supportPage;
  static const String homeUrl = siteHome;

  // ── Timing knobs ──

  /// Cool-down between two push-invite prompts after a Skip. 3 days is
  /// the acceptance-checklist minimum — do not lower without approval.
  static const int inviteCoolSeconds = 3 * 24 * 60 * 60;

  /// Delay before a GCD retry when the first install-conversion payload
  /// reported `af_status: "Organic"` on what may have been paid traffic.
  static const int organicRecheckSeconds = 5;

  /// Config POST timeout window.
  static const int gateTimeoutSeconds = 18;

  /// First-launch wait for the install-conversion callback.
  static const int firstWaitSeconds = 28;

  /// Returning-launch wait for the install-conversion callback.
  static const int returnWaitSeconds = 7;

  /// Deep-link callback wait.
  static const int deepLinkWaitSeconds = 5;
}
