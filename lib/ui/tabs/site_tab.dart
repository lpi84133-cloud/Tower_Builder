import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/asset_paths.dart';
import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/routes.dart';
import '../../app/type_scale.dart';
import '../../build_site/site_metrics.dart';
import '../../state/architect.dart';
import '../../state/audio_desk.dart';
import '../../state/site_check_in.dart';
import '../widgets/risk_selector.dart';
import '../widgets/site_chrome.dart';
import '../widgets/steel_button.dart';

/// Career hub: the day's check-in, the risk plan the next build will use, the
/// active district and lifetime figures. The playable site is one tap away.
class SiteTab extends StatelessWidget {
  const SiteTab({super.key});

  Future<void> _checkIn(BuildContext context) async {
    final desk = context.read<AudioDesk>();
    final reward = await context.read<SiteCheckIn>().collect();
    if (reward <= 0 || !context.mounted) return;
    desk.shot(Cue.brix);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Hue.card,
        content: Text(
          'Check-in banked: +${Fmt.amount(reward)} ${Brand.currency}',
          style: Type.body(size: 13, color: Hue.chalk),
        ),
      ),
    );
  }

  Future<void> _openSite(BuildContext context) async {
    final architect = context.read<Architect>();
    context.read<AudioDesk>().shot(Cue.tap);
    // Never leave the player stranded with an unplayable balance.
    if (architect.brix < SiteMetrics.minBudget) {
      await architect.claimSiteGrant(1000);
    }
    if (!context.mounted) return;
    await Navigator.of(context).pushNamed(Routes.run);
  }

  @override
  Widget build(BuildContext context) {
    final architect = context.watch<Architect>();
    final checkIn = context.watch<SiteCheckIn>();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            children: [
              _CheckInCard(
                available: checkIn.availableToday,
                bankedDays: checkIn.bankedDays,
                reward: checkIn.nextReward,
                onCollect: () => _checkIn(context),
              ),
              const SizedBox(height: 16),
              const SectionHead(text: 'Site plan'),
              RiskSelector(
                selected: architect.riskTier,
                onSelect: (tier) {
                  context.read<AudioDesk>().shot(Cue.tap);
                  architect.setRiskTier(tier);
                },
              ),
              const SizedBox(height: 6),
              const SectionHead(text: 'Location'),
              _DistrictStrip(),
              const SizedBox(height: 16),
              const SectionHead(text: 'Studio record'),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      caption: 'Best payout',
                      value: Fmt.amount(architect.bestPayout),
                      icon: Icons.workspace_premium_outlined,
                      accent: Hue.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatTile(
                      caption: 'Tallest frame',
                      value: '${architect.bestHeight}',
                      icon: Icons.apartment_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      caption: 'Builds run',
                      value: Fmt.amount(architect.jobsRun),
                      icon: Icons.construction_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatTile(
                      caption: 'Signed off',
                      value: Fmt.percent(architect.signOffRate),
                      icon: Icons.task_alt_rounded,
                      accent: Hue.lime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      caption: 'Storeys seated',
                      value: Fmt.amount(architect.storeysTotal),
                      icon: Icons.layers_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatTile(
                      caption: 'Career rank',
                      value: '${architect.rank} \u00B7 ${architect.rankTitle}',
                      icon: Icons.badge_outlined,
                      accent: Hue.violet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const SimulationNote(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: SteelButton(
            label: 'HEAD TO THE SITE',
            sublabel: '${architect.riskPlan.name} plan \u00B7 '
                '${Fmt.percent(architect.riskPlan.holdChance)} hold per storey',
            height: 64,
            fontSize: 18,
            icon: Icons.precision_manufacturing_rounded,
            onPressed: () => _openSite(context),
          ),
        ),
      ],
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.available,
    required this.bankedDays,
    required this.reward,
    required this.onCollect,
  });

  final bool available;
  final int bankedDays;
  final int reward;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: Frames.panel(radius: 20, edge: available ? Hue.amber : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                available ? Icons.how_to_reg_rounded : Icons.schedule_rounded,
                size: 17,
                color: available ? Hue.amber : Hue.chalkDim,
              ),
              const SizedBox(width: 7),
              Text('SITE CHECK-IN',
                  style: Type.eyebrow(
                      color: available ? Hue.amber : Hue.chalkDim)),
              const Spacer(),
              Text('Day ${bankedDays.clamp(0, SiteCheckIn.ladder.length)}/7',
                  style: Type.body(size: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var day = 0; day < SiteCheckIn.ladder.length; day++) ...[
                Expanded(
                  child: _Rung(
                    amount: SiteCheckIn.ladder[day],
                    banked: day < bankedDays,
                    next: available && day == bankedDays % SiteCheckIn.ladder.length,
                  ),
                ),
                if (day < SiteCheckIn.ladder.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SteelButton(
            label: available
                ? 'COLLECT +${Fmt.amount(reward)} ${Brand.currency}'
                : 'COLLECTED \u2014 BACK TOMORROW',
            tone: available ? SteelTone.bank : SteelTone.ghost,
            height: 48,
            fontSize: 15,
            onPressed: available ? onCollect : null,
          ),
        ],
      ),
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({
    required this.amount,
    required this.banked,
    required this.next,
  });

  final int amount;
  final bool banked;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final fill = banked
        ? Hue.lime.withValues(alpha: 0.22)
        : next
            ? Hue.amber.withValues(alpha: 0.22)
            : Hue.navySoft;
    final edge = banked
        ? Hue.lime
        : next
            ? Hue.amber
            : Hue.cardEdge;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      alignment: Alignment.center,
      decoration: Frames.tile(radius: 9, fill: fill, edge: edge),
      child: Column(
        children: [
          Icon(
            banked ? Icons.check_rounded : Icons.view_in_ar_rounded,
            size: 13,
            color: banked ? Hue.lime : (next ? Hue.amber : Hue.chalkDim),
          ),
          const SizedBox(height: 3),
          Text(Fmt.compact(amount),
              style: Type.figure(
                  size: 10,
                  color: banked || next ? Hue.chalk : Hue.chalkDim)),
        ],
      ),
    );
  }
}

class _DistrictStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final district = context.watch<Architect>().district;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: Frames.panel(radius: 18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Hue.cardEdge),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [district.zenith, district.horizon],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(district.name, style: Type.label(size: 15, tracking: 0.3)),
                const SizedBox(height: 3),
                Text(district.brief, style: Type.body(size: 12)),
              ],
            ),
          ),
          Text('WORKSHOP', style: Type.eyebrow(size: 9, color: Hue.cyan)),
        ],
      ),
    );
  }
}
