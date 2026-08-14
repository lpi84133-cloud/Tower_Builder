import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/palette.dart';

/// The risk dial the player sets before breaking ground. A bolder plan swings
/// the crane faster, makes each storey less likely to hold, and rolls a wider
/// (higher-ceiling) bonus on the storeys that do hold.
enum RiskTier { measured, standard, bold, reckless }

@immutable
class RiskPlan {
  const RiskPlan({
    required this.tier,
    required this.name,
    required this.blurb,
    required this.accent,
    required this.baseHalfPeriod,
    required this.halfPeriodStepPerStorey,
    required this.floorHalfPeriod,
    required this.holdChance,
    required this.bonusMin,
    required this.bonusMax,
  });

  final RiskTier tier;
  final String name;
  final String blurb;
  final Color accent;

  /// Seconds for the crane to cross from one extreme to the other on the ground
  /// floor. Each further storey shaves [halfPeriodStepPerStorey] off it, never
  /// dropping below [floorHalfPeriod].
  final double baseHalfPeriod;
  final double halfPeriodStepPerStorey;
  final double floorHalfPeriod;

  /// Probability in 0..1 that a released module holds. This is the whole game of
  /// chance: there is no aim or timing window to master, so the outcome cannot be
  /// influenced by how well the release is judged.
  final double holdChance;

  /// Every storey that holds rolls its *own* bonus in [bonusMin]..[bonusMax].
  /// The payout bonus is the running product of those rolls, so a long run
  /// compounds — and a single failure ends it.
  final double bonusMin;
  final double bonusMax;

  /// Roll this plan's per-storey bonus, quantised to two decimals.
  double rollBonus(math.Random rng) {
    final raw = bonusMin + rng.nextDouble() * (bonusMax - bonusMin);
    return (raw * 100).round() / 100;
  }

  /// Crane half-period once [storey] storeys are standing.
  double halfPeriodAt(int storey) => math.max(
        floorHalfPeriod,
        baseHalfPeriod - storey * halfPeriodStepPerStorey,
      );

  /// Rough expected value of one storey, used only to describe the plan in the
  /// UI so the trade-off is legible before committing a budget.
  double get expectedBonus => holdChance * (bonusMin + bonusMax) / 2;

  static const _table = <RiskTier, RiskPlan>{
    RiskTier.measured: RiskPlan(
      tier: RiskTier.measured,
      name: 'Measured',
      blurb: 'Slow winch, forgiving frame.',
      accent: Hue.lime,
      baseHalfPeriod: 1.55,
      halfPeriodStepPerStorey: 0.03,
      floorHalfPeriod: 0.75,
      holdChance: 0.88,
      bonusMin: 0.85,
      bonusMax: 1.45,
    ),
    RiskTier.standard: RiskPlan(
      tier: RiskTier.standard,
      name: 'Standard',
      blurb: 'Site defaults. Balanced spread.',
      accent: Hue.cyan,
      baseHalfPeriod: 1.2,
      halfPeriodStepPerStorey: 0.04,
      floorHalfPeriod: 0.6,
      holdChance: 0.775,
      bonusMin: 0.7,
      bonusMax: 1.95,
    ),
    RiskTier.bold: RiskPlan(
      tier: RiskTier.bold,
      name: 'Bold',
      blurb: 'Thin tolerances, fatter bonus.',
      accent: Hue.amber,
      baseHalfPeriod: 0.92,
      halfPeriodStepPerStorey: 0.05,
      floorHalfPeriod: 0.48,
      holdChance: 0.625,
      bonusMin: 0.6,
      bonusMax: 2.7,
    ),
    RiskTier.reckless: RiskPlan(
      tier: RiskTier.reckless,
      name: 'Reckless',
      blurb: 'No margin. Huge swings.',
      accent: Hue.rust,
      baseHalfPeriod: 0.66,
      halfPeriodStepPerStorey: 0.06,
      floorHalfPeriod: 0.38,
      holdChance: 0.485,
      bonusMin: 0.5,
      bonusMax: 3.8,
    ),
  };

  static RiskPlan of(RiskTier tier) => _table[tier]!;

  static RiskPlan byIndex(int index) =>
      of(RiskTier.values[index.clamp(0, RiskTier.values.length - 1)]);

  static List<RiskPlan> get all =>
      [for (final tier in RiskTier.values) of(tier)];
}
