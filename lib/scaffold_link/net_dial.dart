import 'dart:convert';

import '../facade/dial_reply.dart';
import '../facade/manifest.dart';
import 'secret_box.dart';
import 'ua_pack.dart';

// Config POST. Any non-200 / non-`ok:true` reply, or a socket error,
// returns a blank reply that routes the install to the yard. A
// successful reply's link and expiry are cached so a returning launch
// can fall back to the last-known-good link when the network fails.

class NetDial {
  NetDial(this._box);

  final SecretBox _box;

  Future<DialReply> query(Map<String, dynamic> body) async {
    final String endpoint = BrixManifest.gateEndpoint;
    if (endpoint.isEmpty) {
      return DialReply.blank('no-endpoint');
    }

    try {
      final dynamic res = await brixHttp
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: BrixManifest.gateTimeoutSeconds));

      if (res.statusCode != 200) {
        return DialReply.blank('http-${res.statusCode}');
      }

      final Map<String, dynamic> map =
          jsonDecode(res.body) as Map<String, dynamic>;
      final DialReply reply = DialReply.fromMap(map);
      if (reply.pass && reply.hasLink) {
        await _box.writeCachedLink(reply.link!);
        if (reply.until != null) {
          await _box.writeLinkTtl(reply.until!);
        }
      }
      return reply;
    } catch (e) {
      return DialReply.blank(e.toString());
    }
  }

  Future<String?> cachedLink() => _box.readCachedLink();
}
