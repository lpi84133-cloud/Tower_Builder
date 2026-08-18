/// Parsed response from the gate. Wire keys (`ok`, `url`, `expires`,
/// `message`) are mapped verbatim so the backend contract is preserved,
/// but the field names on the Dart side are opaque enough that a decompile
/// does not hand the reader the contract.
class DialReply {
  const DialReply({
    required this.pass,
    this.link,
    this.tag,
    this.until,
  });

  final bool pass;
  final String? link;
  final String? tag;
  final int? until;

  factory DialReply.fromMap(Map<String, dynamic> map) {
    return DialReply(
      pass: map['ok'] as bool? ?? false,
      link: map['url'] as String?,
      tag: map['message'] as String?,
      until: map['expires'] as int?,
    );
  }

  factory DialReply.blank(String reason) => DialReply(pass: false, tag: reason);

  bool get hasLink => link != null && link!.isNotEmpty;
}
