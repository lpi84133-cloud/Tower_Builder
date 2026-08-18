// Byte-level packer for the site-portal opaque strings.
//
// Change any of the plaintext values below (or the seed / stream length
// in `lib/mixer/scrambler.dart`) and re-run:
//
//   dart run tool/vault_packer.dart
//
// Paste the emitted `const List<int> _foo = <int>[...]` lines over the
// matching declarations in `lib/facade/vault_bytes.dart`. The scrambler
// on the decode side is symmetric, so a mismatched seed silently
// corrupts every value.

const String _seed = 'Xr7#Br1x_h9Wm';
const int _len = 29;

List<int> _weave() {
  int h = 0x811C9DC5;
  for (final int c in _seed.codeUnits) {
    h = (h ^ c) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  int s = h == 0 ? 0x9E3779B9 : h;
  final List<int> out = List<int>.filled(_len, 0);
  for (int i = 0; i < _len; i++) {
    s ^= (s << 13) & 0xFFFFFFFF;
    s ^= s >> 17;
    s ^= (s << 5) & 0xFFFFFFFF;
    s &= 0xFFFFFFFF;
    out[i] = (s >> 16) & 0xFF;
  }
  return out;
}

List<int> _pack(String plain, List<int> stream) {
  final List<int> bytes = plain.codeUnits;
  return List<int>.generate(
    bytes.length,
    (int i) => (bytes[i] ^ stream[i % _len] ^ (i & 0xFF)) & 0xFF,
  );
}

void main() {
  final List<int> stream = _weave();

  const Map<String, String> values = <String, String>{
    '_gatePost':    'https://towerbuillder.com/config.php',
    '_gcdBase':     'https://gcdsdk.appsflyer.com/install_data/v4.0/',
    '_chromeTag':   '149.0.7859.121',
    '_webkitTag':   '537.36',
    '_tracerKey':   'dKdAkpXFdNLCPXGSVLxMqB',
    '_messagingId': '621888781221',
    // UA fragments — prevents a plain `strings` sweep finding
    // browser-identity tokens in the compiled binary.
    '_uaBase':      'Mozilla/5.0 (',
    '_uaLinux':     'Linux; Android ',
    '_uaIphone':    'iPhone; CPU iPhone OS ',
    '_uaMacOs':     ' like Mac OS X) AppleWebKit/',
    '_uaWebkit':    ') AppleWebKit/',
    '_uaKhtml':     ' (KHTML, like Gecko) Chrome/',
    '_uaMSafari':   ' Mobile Safari/',
    '_uaVersion':   'Version/',
    '_uaMob':       ' Mobile/15E148 Safari/',
    '_uaFallback':  'Linux; Android 14; Pixel 8 Build/UQ1A.240205',
  };

  final StringBuffer buf = StringBuffer();
  values.forEach((String name, String plain) {
    final List<int> packed = _pack(plain, stream);
    buf.writeln('// $name  <= ${_dartString(plain)}');
    buf.write('const List<int> $name = <int>[');
    buf.write(packed.join(', '));
    buf.writeln('];\n');
  });
  print(buf.toString());
}

String _dartString(String v) => "'${v.replaceAll("'", r"\'")}'";
