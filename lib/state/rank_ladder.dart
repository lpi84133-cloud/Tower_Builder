/// The career ladder. Ranks are pure functions of lifetime XP, so nothing about
/// progression has to be stored beyond the XP total itself.
class RankLadder {
  const RankLadder._();

  static const topRank = 50;

  /// XP needed to move from [rank] to the next one. The step grows linearly,
  /// which keeps early ranks quick and later ones a slow burn.
  static int _step(int rank) => 70 + (rank - 1) * 40;

  /// Cumulative XP required to *reach* [rank] (rank 1 sits at zero).
  static int thresholdFor(int rank) {
    var total = 0;
    for (var r = 1; r < rank; r++) {
      total += _step(r);
    }
    return total;
  }

  static int rankFor(int xp) {
    var rank = 1;
    while (rank < topRank && xp >= thresholdFor(rank + 1)) {
      rank++;
    }
    return rank;
  }

  static int xpInsideRank(int xp) => xp - thresholdFor(rankFor(xp));

  static int spanOfRank(int xp) {
    final rank = rankFor(xp);
    if (rank >= topRank) return 1;
    return thresholdFor(rank + 1) - thresholdFor(rank);
  }

  static double progress(int xp) {
    final span = spanOfRank(xp);
    if (span <= 0) return 1;
    return (xpInsideRank(xp) / span).clamp(0.0, 1.0);
  }

  /// BRIX granted on reaching [rank].
  static int reward(int rank) => 120 + rank * 60;

  static const _titles = <int, String>{
    1: 'Apprentice',
    3: 'Rigger',
    5: 'Site Foreman',
    8: 'Draughtsman',
    12: 'Structural Lead',
    17: 'Project Architect',
    23: 'Chief Engineer',
    30: 'Studio Partner',
    40: 'Master Builder',
  };

  /// The job title held at [rank] — the highest title at or below it.
  static String titleFor(int rank) {
    var title = _titles[1]!;
    for (final entry in _titles.entries) {
      if (rank >= entry.key) title = entry.value;
    }
    return title;
  }

  /// Module kits handed over for free on reaching [rank].
  static List<int> kitsUnlockedAt(int rank) {
    switch (rank) {
      case 2:
        return const [2];
      case 4:
        return const [3];
      case 7:
        return const [4];
      default:
        return const [];
    }
  }
}
