import 'package:flutter/material.dart';

import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../../build_site/risk_tier.dart';

/// Picks the risk plan for the next build and states its odds outright: the hold
/// chance per storey and the bonus range are both printed, so the trade-off is
/// never hidden behind flavour text.
class RiskSelector extends StatelessWidget {
  const RiskSelector({
    super.key,
    required this.selected,
    required this.onSelect,
    this.dense = false,
  });

  final RiskTier selected;
  final ValueChanged<RiskTier> onSelect;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (dense) {
      return Row(
        children: [
          for (final plan in RiskPlan.all) ...[
            Expanded(
              child: _DenseTab(
                plan: plan,
                selected: plan.tier == selected,
                onTap: () => onSelect(plan.tier),
              ),
            ),
            if (plan.tier != RiskPlan.all.last.tier) const SizedBox(width: 6),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (final plan in RiskPlan.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PlanCard(
              plan: plan,
              selected: plan.tier == selected,
              onTap: () => onSelect(plan.tier),
            ),
          ),
      ],
    );
  }
}

class _DenseTab extends StatelessWidget {
  const _DenseTab({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final RiskPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? plan.accent : Hue.rigPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.white : Hue.rigEdge,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              plan.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.label(
                size: 11,
                color: selected ? Colors.white : Hue.chalkDim,
                tracking: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${Fmt.percent(plan.holdChance)} hold',
              style: Type.body(
                size: 9,
                color: selected
                    ? Colors.white.withValues(alpha: 0.92)
                    : Hue.chalkDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final RiskPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: Frames.tile(
          radius: 15,
          fill: selected ? plan.accent.withValues(alpha: 0.16) : Hue.card,
          edge: selected ? plan.accent : Hue.cardEdge,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: plan.accent.withValues(alpha: selected ? 1 : 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                selected ? Icons.check_rounded : Icons.speed_rounded,
                size: 19,
                color: Hue.abyss,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name, style: Type.label(size: 15, tracking: 0.4)),
                  const SizedBox(height: 2),
                  Text(plan.blurb, style: Type.body(size: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${Fmt.percent(plan.holdChance)} hold',
                    style: Type.figure(size: 13, color: plan.accent)),
                const SizedBox(height: 3),
                Text(
                  'bonus ${Fmt.mult(plan.bonusMin)}\u2013${Fmt.mult(plan.bonusMax)}',
                  style: Type.body(size: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
