// Centralised paths for the site-portal artwork pack. Renaming the
// folder segment or swapping the file names inside is a one-file
// change here + the pubspec `flutter.assets` block; nothing at the
// widget layer hardcodes a raw string.
//
// The addon folder name and each file basename below MUST be unique
// per project — asset paths appear verbatim in the compiled APK and
// two apps sharing them cluster instantly under a store scanner.

class BrixVeil {
  BrixVeil._();

  static const String _pack = 'assets/Tower_Builder_assets';

  static const String verticalLoading = '$_pack/stack_load_v.webp';
  static const String horizontalLoading = '$_pack/stack_load_h.webp';

  static const String verticalNoLink = '$_pack/stack_dark_v.webp';
  static const String horizontalNoLink = '$_pack/stack_dark_h.webp';

  static const String verticalPing = '$_pack/stack_ping_v.webp';
  static const String horizontalPing = '$_pack/stack_ping_h.webp';

  static const String wordmark = '$_pack/stack_wordmark.webp';
  static const String seal = '$_pack/brix_seal.png';
}
