import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../../build_site/risk_tier.dart';
import 'hazard_trim.dart';

/// Solid status bar across the top of the site, closed off with warning tape.
///
/// Unlike the shell's translucent bar this one is opaque: the frame climbs past
/// it during a run, and the readouts have to stay legible against whatever is
/// behind them.
class RunBar extends StatelessWidget {
  const RunBar({
    super.key,
    required this.brix,
    required this.rank,
    required this.rankTitle,
    required this.rankProgress,
    required this.plan,
    required this.onLeave,
  });

  final int brix;
  final int rank;
  final String rankTitle;
  final double rankProgress;
  final RiskPlan plan;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: Hue.rigWash,
            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8)],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 10, 8),
              child: Row(
                children: [
                  _Round(icon: Icons.chevron_left_rounded, onTap: onLeave),
                  const SizedBox(width: 9),
                  // Lean rank tag rather than the shell's chip: the bar also has
                  // to fit the balance and the plan odds on a 360dp screen.
                  Flexible(
                    child: _RankTag(rank: rank, title: rankTitle),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BrixReadout(amount: brix),
                        const SizedBox(height: 3),
                        // The plan's odds stay on screen for the whole run, in
                        // the slot the reference gives the account line.
                        Text(
                          '${plan.name.toUpperCase()} \u00B7 '
                          '${Fmt.percent(plan.holdChance)} HOLD',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Type.eyebrow(size: 8, color: Hue.chalkDim),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const HazardTrim(),
      ],
    );
  }
}

/// Rank badge: a moulded blue pill, same shape as the balance readout beside it.
class _RankTag extends StatelessWidget {
  const _RankTag({required this.rank, required this.title});

  final int rank;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 11, 5),
      decoration: BoxDecoration(
        color: Hue.glazeDeep,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Hue.glazeEdge, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Hue.glaze,
              shape: BoxShape.circle,
            ),
            child: Text('$rank',
                style: Type.figure(size: 12, color: Colors.white)),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.eyebrow(size: 9, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Balance readout: a recessed pill with the BRIX token struck on the left.
class _BrixReadout extends StatelessWidget {
  const _BrixReadout({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 5, 12, 5),
      decoration: BoxDecoration(
        color: Hue.rigWell,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Hue.rigEdge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Hue.amber, Color(0xFFE0A11A)]),
            ),
            child: const Text(
              'B',
              style: TextStyle(
                fontFamily: 'SiteText',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7A5300),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              Fmt.amount(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.figure(size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 4),
          Text(Brand.currency, style: Type.eyebrow(size: 9)),
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 26, color: Colors.white),
        ),
      ),
    );
  }
}
