import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_builder/build_site/risk_tier.dart';
import 'package:tower_builder/state/rank_ladder.dart';

void main() {
  group('risk plans', () {
    test('every tier publishes a usable hold chance and bonus band', () {
      for (final plan in RiskPlan.all) {
        expect(plan.holdChance, greaterThan(0));
        expect(plan.holdChance, lessThanOrEqualTo(1));
        expect(plan.bonusMin, lessThan(plan.bonusMax));
        expect(plan.floorHalfPeriod, lessThanOrEqualTo(plan.baseHalfPeriod));
      }
    });

    test('bolder tiers trade hold chance for a higher bonus ceiling', () {
      final tiers = RiskPlan.all;
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i].holdChance, lessThan(tiers[i - 1].holdChance));
        expect(tiers[i].bonusMax, greaterThan(tiers[i - 1].bonusMax));
      }
    });

    test('rolled bonus stays inside the published band', () {
      final rng = math.Random(1234);
      for (final plan in RiskPlan.all) {
        for (var i = 0; i < 500; i++) {
          final roll = plan.rollBonus(rng);
          expect(roll, greaterThanOrEqualTo(plan.bonusMin - 0.005));
          expect(roll, lessThanOrEqualTo(plan.bonusMax + 0.005));
        }
      }
    });

    test('the crane speeds up with height but never past its floor', () {
      for (final plan in RiskPlan.all) {
        expect(plan.halfPeriodAt(0), plan.baseHalfPeriod);
        expect(plan.halfPeriodAt(3), lessThan(plan.halfPeriodAt(1)));
        expect(plan.halfPeriodAt(999), plan.floorHalfPeriod);
      }
    });
  });

  group('rank ladder', () {
    test('rank one starts at zero xp and thresholds increase', () {
      expect(RankLadder.rankFor(0), 1);
      expect(RankLadder.thresholdFor(1), 0);
      for (var rank = 1; rank < RankLadder.topRank; rank++) {
        expect(RankLadder.thresholdFor(rank + 1),
            greaterThan(RankLadder.thresholdFor(rank)));
      }
    });

    test('progress is bounded and consistent with the rank', () {
      for (final xp in [0, 35, 70, 200, 5000, 500000]) {
        final progress = RankLadder.progress(xp);
        expect(progress, inInclusiveRange(0.0, 1.0));
        expect(RankLadder.xpInsideRank(xp), greaterThanOrEqualTo(0));
      }
    });

    test('the ladder caps out at the top rank', () {
      expect(RankLadder.rankFor(1 << 30), RankLadder.topRank);
    });
  });
}
