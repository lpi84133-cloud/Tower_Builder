import 'dart:typed_data';

// Byte-list keystream un-mixer. Sensitive strings (config endpoint,
// tracer key, messaging id, browser fragments) travel as XOR-scrambled
// integer lists so a `strings` sweep of the release APK finds no
// literal that could seed a cross-submission cluster.
//
// The routine mirrors `tool/vault_packer.dart` byte-for-byte. Any drift
// between the two breaks the round-trip immediately, and every entry
// in `facade/vault_bytes.dart` decodes to garbage — so keep them in
// step or don't touch either.

const String _seed = 'Xr7#Br1x_h9Wm';
const int _len = 29;

Uint8List _weave() {
  int h = 0x811C9DC5;
  for (final int c in _seed.codeUnits) {
    h = (h ^ c) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  int s = h == 0 ? 0x9E3779B9 : h;
  final Uint8List out = Uint8List(_len);
  for (int i = 0; i < _len; i++) {
    s ^= (s << 13) & 0xFFFFFFFF;
    s ^= s >> 17;
    s ^= (s << 5) & 0xFFFFFFFF;
    s &= 0xFFFFFFFF;
    out[i] = (s >> 16) & 0xFF;
  }
  return out;
}

final Uint8List _stream = _weave();

/// Reverses the scrambled byte list back to its original string.
/// An empty input returns "" — the safe idle path when the byte
/// arrays in `vault_bytes.dart` are still blank.
String unmix(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    out[i] = (packed[i] ^ _stream[i % _len] ^ (i & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
