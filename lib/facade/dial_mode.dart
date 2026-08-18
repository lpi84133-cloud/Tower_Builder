/// Which face of the shell the install has locked onto.
///
/// Once [DialMode.web] or [DialMode.native] lands in the vault it stays
/// there for the lifetime of the install — reinstall is the only reset.
enum DialMode {
  web,
  native,
  pending;

  static DialMode decode(String? raw) {
    switch (raw) {
      case 'w':
        return DialMode.web;
      case 'n':
        return DialMode.native;
      default:
        return DialMode.pending;
    }
  }

  String encode() {
    switch (this) {
      case DialMode.web:
        return 'w';
      case DialMode.native:
        return 'n';
      case DialMode.pending:
        return 'p';
    }
  }
}
