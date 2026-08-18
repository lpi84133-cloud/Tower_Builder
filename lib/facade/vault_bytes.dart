import '../mixer/scrambler.dart';

// Byte-packed opaque strings for the site-portal stack. Every constant
// here decodes through the shared scrambler under the seed / stream length
// pinned in `mixer/scrambler.dart`. The plaintext is never written here —
// if a value needs to rotate, edit `tool/vault_packer.dart`, rerun it
// with the matching seed, and drop the fresh integer lists over the ones
// below. Any drift between the packer's seed and the scrambler's seed
// silently corrupts every value.

const List<int> _gatePost = <int>[
  119, 232, 188, 161, 43, 22, 100, 217, 109, 117, 121, 176, 206, 54, 3, 16,
  159, 238, 123, 185, 189, 131, 89, 94, 200, 172, 46, 225, 117, 100, 234, 178,
  220, 13, 99, 30,
];

const List<int> _gcdBase = <int>[
  119, 232, 188, 161, 43, 22, 100, 217, 126, 121, 106, 166, 216, 63, 88, 24,
  131, 242, 108, 186, 163, 212, 95, 67, 139, 224, 34, 227, 52, 107, 237, 166,
  134, 28, 103, 2, 138, 80, 84, 87, 151, 182, 5, 103, 116, 254, 146,
];

const List<int> _chromeTag = <int>[
  46, 168, 241, 255, 104, 2, 124, 206, 44, 35, 32, 228, 142, 101,
];

const List<int> _webkitTag = <int>[
  42, 175, 255, 255, 107, 26,
];

// UA structural fragments — assembled at runtime to avoid `strings` hits
// on browser-identity tokens. Re-generate with `dart run tool/vault_packer.dart`.
const List<int> _uaBase = <int>[82, 243, 178, 184, 52, 64, 42, 217, 44, 52, 62, 245, 148];
const List<int> _uaLinux = <int>[83, 245, 166, 164, 32, 23, 107, 183, 119, 126, 124, 186, 213, 48, 86];
const List<int> _uaIphone = <int>[118, 204, 160, 190, 54, 73, 112, 214, 90, 74, 91, 245, 213, 4, 30, 22, 157, 231, 63, 147, 156, 141];
const List<int> _uaMacOs = <int>[63, 240, 161, 186, 61, 12, 6, 151, 122, 58, 65, 134, 156, 12, 95, 89, 178, 242, 111, 176, 170, 250, 95, 83, 238, 234, 57, 161];
const List<int> _uaWebkit = <int>[54, 188, 137, 161, 40, 64, 46, 161, 124, 120, 69, 188, 200, 123];
const List<int> _uaKhtml = <int>[63, 180, 131, 153, 12, 97, 7, 218, 57, 118, 103, 190, 217, 116, 49, 28, 144, 233, 112, 245, 239, 238, 82, 67, 202, 238, 40, 161];
const List<int> _uaMSafari = <int>[63, 209, 167, 179, 49, 64, 46, 214, 74, 123, 104, 180, 206, 61, 89];
const List<int> _uaVersion = <int>[73, 249, 186, 162, 49, 67, 37, 217];
const List<int> _uaMob = <int>[63, 209, 167, 179, 49, 64, 46, 217, 40, 47, 75, 228, 136, 108, 86, 42, 146, 228, 126, 174, 166, 130];
const List<int> _uaFallback = <int>[83, 245, 166, 164, 32, 23, 107, 183, 119, 126, 124, 186, 213, 48, 86, 72, 199, 185, 63, 140, 166, 213, 95, 93, 133, 187, 109, 204, 110, 107, 239, 177, 221, 40, 90, 95, 148, 26, 7, 23, 198, 171, 67, 102];

const List<int> _tracerKey = <int>[
  123, 215, 172, 144, 51, 92, 19, 176, 125, 84, 66, 150, 236, 12, 49, 42,
  165, 206, 103, 145, 190, 239,
];

const List<int> _messagingId = <int>[
  41, 174, 249, 233, 96, 20, 124, 206, 40, 40, 60, 228,
];

String openGatePost() => unmix(_gatePost);
String openTracerKey() => unmix(_tracerKey);
String openMessagingId() => unmix(_messagingId);
String openChromeTag() => unmix(_chromeTag);
String openWebkitTag() => unmix(_webkitTag);

// UA fragment openers — used by ua_pack.dart only.
String openUaBase() => unmix(_uaBase);
String openUaLinux() => unmix(_uaLinux);
String openUaIphone() => unmix(_uaIphone);
String openUaMacOs() => unmix(_uaMacOs);
String openUaWebkit() => unmix(_uaWebkit);
String openUaKhtml() => unmix(_uaKhtml);
String openUaMSafari() => unmix(_uaMSafari);
String openUaVersion() => unmix(_uaVersion);
String openUaMob() => unmix(_uaMob);
String openUaFallback() => unmix(_uaFallback);

/// Assembles the GCD (Get Conversion Data) retry URL. Returns an empty
/// string if either the base or the tracer key are still unpacked —
/// callers must treat "" as "no GCD retry, keep whatever attribution
/// the SDK originally reported".
String buildGcdUrl(String appId, String deviceId) {
  final String base = unmix(_gcdBase);
  final String key = openTracerKey();
  if (base.isEmpty || key.isEmpty) return '';
  return '$base$appId?devkey=$key&device_id=$deviceId';
}
