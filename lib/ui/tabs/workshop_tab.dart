import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/asset_paths.dart';
import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../../build_site/district.dart';
import '../../state/architect.dart';
import '../../state/audio_desk.dart';
import '../widgets/site_chrome.dart';

/// Cosmetics only: module kits change what the crane hoists, districts change the
/// sky behind it. Neither touches the odds, and everything here is bought with
/// BRIX earned in play — there is no purchase path.
class WorkshopTab extends StatelessWidget {
  const WorkshopTab({super.key});

  void _toast(BuildContext context, String message, {bool good = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: good ? Hue.card : Hue.rustDeep,
        content: Text(message, style: Type.body(size: 13, color: Hue.chalk)),
      ),
    );
  }

  Future<void> _kitTapped(BuildContext context, ModuleKit kit) async {
    final architect = context.read<Architect>();
    final desk = context.read<AudioDesk>();
    if (architect.ownsKit(kit.facade)) {
      desk.shot(Cue.tap);
      await architect.selectKit(kit.facade);
      return;
    }
    if (architect.rank < kit.rankRequired) {
      _toast(context, 'Reaches rank ${kit.rankRequired} to unlock ${kit.name}.',
          good: false);
      return;
    }
    final bought = await architect.buyKit(kit);
    if (!context.mounted) return;
    if (!bought) {
      _toast(context, 'Not enough ${Brand.currency} for ${kit.name}.',
          good: false);
      return;
    }
    desk.shot(Cue.brix);
    await architect.selectKit(kit.facade);
  }

  Future<void> _districtTapped(BuildContext context, District district) async {
    final architect = context.read<Architect>();
    final desk = context.read<AudioDesk>();
    if (architect.ownsDistrict(district.id)) {
      desk.shot(Cue.tap);
      await architect.selectDistrict(district.id);
      return;
    }
    if (architect.rank < district.rankRequired) {
      _toast(context,
          'Reaches rank ${district.rankRequired} to unlock ${district.name}.',
          good: false);
      return;
    }
    final bought = await architect.buyDistrict(district);
    if (!context.mounted) return;
    if (!bought) {
      _toast(context, 'Not enough ${Brand.currency} for ${district.name}.',
          good: false);
      return;
    }
    desk.shot(Cue.brix);
    await architect.selectDistrict(district.id);
  }

  @override
  Widget build(BuildContext context) {
    final architect = context.watch<Architect>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      children: [
        const SectionHead(text: 'Module kits'),
        _MixedTile(
          selected: architect.activeKit == 0,
          onTap: () {
            context.read<AudioDesk>().shot(Cue.tap);
            architect.selectKit(0);
          },
        ),
        const SizedBox(height: 9),
        for (final kit in ModuleKit.all) ...[
          _KitCard(
            kit: kit,
            owned: architect.ownsKit(kit.facade),
            selected: architect.activeKit == kit.facade,
            rank: architect.rank,
            onTap: () => _kitTapped(context, kit),
          ),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 8),
        const SectionHead(text: 'Districts'),
        for (final district in District.all) ...[
          _DistrictCard(
            district: district,
            owned: architect.ownsDistrict(district.id),
            selected: architect.activeDistrict == district.id,
            rank: architect.rank,
            onTap: () => _districtTapped(context, district),
          ),
          const SizedBox(height: 9),
        ],
        const SizedBox(height: 6),
        const SimulationNote(
          text: 'Cosmetics only. Buying a kit builds the whole tower from that '
              'one facade; kits and districts never change the hold chance or '
              'the bonus range of a risk plan.',
        ),
      ],
    );
  }
}

class _MixedTile extends StatelessWidget {
  const _MixedTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: Frames.tile(
          radius: 15,
          fill: selected ? Hue.cyan.withValues(alpha: 0.15) : Hue.card,
          edge: selected ? Hue.cyan : Hue.cardEdge,
        ),
        child: Row(
          children: [
            const Icon(Icons.shuffle_rounded, size: 19, color: Hue.cyan),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mixed delivery',
                      style: Type.label(size: 14, tracking: 0.2)),
                  const SizedBox(height: 2),
                  Text('Every hoist pulls whatever the yard sends.',
                      style: Type.body(size: 11)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, size: 19, color: Hue.cyan),
          ],
        ),
      ),
    );
  }
}

class _KitCard extends StatelessWidget {
  const _KitCard({
    required this.kit,
    required this.owned,
    required this.selected,
    required this.rank,
    required this.onTap,
  });

  final ModuleKit kit;
  final bool owned;
  final bool selected;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = !owned && rank < kit.rankRequired;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: Frames.panel(
          radius: 18,
          edge: selected ? Hue.cyan : null,
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(4),
              decoration: Frames.tile(radius: 13, fill: Hue.abyss),
              child: Opacity(
                opacity: locked ? 0.35 : 1,
                child: Image.asset(Art.module(kit.facade), fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kit.name, style: Type.label(size: 15, tracking: 0.2)),
                  const SizedBox(height: 3),
                  Text(kit.brief, style: Type.body(size: 11)),
                  const SizedBox(height: 6),
                  _Status(
                    owned: owned,
                    selected: selected,
                    locked: locked,
                    price: kit.price,
                    rankRequired: kit.rankRequired,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistrictCard extends StatelessWidget {
  const _DistrictCard({
    required this.district,
    required this.owned,
    required this.selected,
    required this.rank,
    required this.onTap,
  });

  final District district;
  final bool owned;
  final bool selected;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = !owned && rank < district.rankRequired;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: Frames.panel(
          radius: 18,
          edge: selected ? Hue.cyan : null,
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Hue.cardEdge),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: locked
                      ? [Hue.slate, Hue.navy]
                      : [district.zenith, district.horizon],
                ),
              ),
              child: locked
                  ? const Center(
                      child: Icon(Icons.lock_outline_rounded,
                          size: 20, color: Hue.chalkDim))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(district.name,
                      style: Type.label(size: 15, tracking: 0.2)),
                  const SizedBox(height: 3),
                  Text(district.brief, style: Type.body(size: 11)),
                  const SizedBox(height: 6),
                  _Status(
                    owned: owned,
                    selected: selected,
                    locked: locked,
                    price: district.price,
                    rankRequired: district.rankRequired,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.owned,
    required this.selected,
    required this.locked,
    required this.price,
    required this.rankRequired,
  });

  final bool owned;
  final bool selected;
  final bool locked;
  final int price;
  final int rankRequired;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Hue.cyan),
          const SizedBox(width: 5),
          Text('In use', style: Type.label(size: 11, color: Hue.cyan)),
        ],
      );
    }
    if (owned) {
      return Text('Tap to use', style: Type.label(size: 11, color: Hue.chalkDim));
    }
    if (locked) {
      return Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 13, color: Hue.chalkDim),
          const SizedBox(width: 5),
          Text('Rank $rankRequired',
              style: Type.label(size: 11, color: Hue.chalkDim)),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.view_in_ar_rounded, size: 13, color: Hue.amber),
        const SizedBox(width: 5),
        Text('${Fmt.amount(price)} ${Brand.currency}',
            style: Type.label(size: 11, color: Hue.amber)),
      ],
    );
  }
}
