/// Small display helpers shared by the HUD and the shell screens.
class Fmt {
  const Fmt._();

  /// Groups thousands with a thin space: `12500` -> `12 500`.
  static String amount(int value) {
    final digits = value.abs().toString();
    final buf = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('\u2009');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  /// Compact balance for tight pills: `1 240` -> `1.2K`.
  static String compact(int value) {
    if (value < 10000) return amount(value);
    if (value < 1000000) return '${(value / 1000).toStringAsFixed(value < 100000 ? 1 : 0)}K';
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }

  /// Bonus multipliers always read with two decimals and a leading cross.
  static String mult(double value) => 'x${value.toStringAsFixed(2)}';

  /// Tighter multiplier for the results strip, where a column of six has to
  /// stay narrow: `x1.45`, `x0.5`, `x1`.
  static String roll(double value) {
    var text = value.toStringAsFixed(2);
    while (text.contains('.') && (text.endsWith('0') || text.endsWith('.'))) {
      text = text.substring(0, text.length - 1);
    }
    return 'x$text';
  }

  static String percent(double unit) => '${(unit * 100).round()}%';

  /// `2` -> `2nd`, used for storey and rank ordinals.
  static String ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }
}
