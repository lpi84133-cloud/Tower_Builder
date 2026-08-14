import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';

/// Balance readout. Always carries the currency name so the on-screen economy is
/// never mistaken for money.
class BrixPill extends StatelessWidget {
  const BrixPill({super.key, required this.amount, this.compact = false});

  final int amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: Frames.pill(fill: Hue.abyss, edge: Hue.amberDeep),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_in_ar_rounded, size: 15, color: Hue.amber),
          const SizedBox(width: 6),
          Text(
            compact ? Fmt.compact(amount) : Fmt.amount(amount),
            style: Type.figure(size: 15, color: Hue.chalk),
          ),
          const SizedBox(width: 5),
          Text(Brand.currency, style: Type.eyebrow(size: 9, color: Hue.amber)),
        ],
      ),
    );
  }
}

/// Rank badge with a thin progress arc underneath.
class RankChip extends StatelessWidget {
  const RankChip({
    super.key,
    required this.rank,
    required this.title,
    required this.progress,
  });

  final int rank;
  final String title;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: Frames.pill(fill: Hue.abyss, edge: Hue.cyanDeep),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Hue.cyanDeep, shape: BoxShape.circle),
            child: Text('$rank', style: Type.figure(size: 12, color: Hue.chalk)),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Type.label(size: 11, tracking: 0.4)),
              const SizedBox(height: 3),
              SizedBox(
                width: 74,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: Hue.slate,
                    valueColor: const AlwaysStoppedAnimation(Hue.cyan),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The bar across the top of every screen: optional back affordance, rank, brix.
class SiteTopBar extends StatelessWidget {
  const SiteTopBar({
    super.key,
    required this.brix,
    required this.rank,
    required this.rankTitle,
    required this.rankProgress,
    this.onBack,
    this.trailing,
  });

  final int brix;
  final int rank;
  final String rankTitle;
  final double rankProgress;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF2081733), Color(0x00081733)],
          ),
        ),
        child: Row(
          children: [
            if (onBack != null)
              _IconTap(icon: Icons.chevron_left_rounded, onTap: onBack!),
            if (onBack != null) const SizedBox(width: 8),
            RankChip(rank: rank, title: rankTitle, progress: rankProgress),
            const Spacer(),
            BrixPill(amount: brix, compact: true),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: Frames.tile(radius: 12, fill: Hue.abyss),
        child: Icon(icon, color: Hue.chalk, size: 22),
      ),
    );
  }
}

/// Small caps heading used above every panel.
class SectionHead extends StatelessWidget {
  const SectionHead({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: Type.eyebrow()),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// One figure with a caption; used across the site and rivals tabs.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.caption,
    required this.value,
    this.icon,
    this.accent = Hue.cyan,
  });

  final String caption;
  final String value;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: Frames.tile(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: accent),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(caption.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.eyebrow(size: 9)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.figure(size: 19, color: Hue.chalk)),
        ],
      ),
    );
  }
}

/// The standing reminder that the economy is simulated. Rendered anywhere a
/// balance, a budget or a payout is on screen.
class SimulationNote extends StatelessWidget {
  const SimulationNote({super.key, this.dense = false, this.text});

  final bool dense;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 7 : 11),
      decoration: Frames.tile(
        radius: 12,
        fill: Hue.abyss.withValues(alpha: 0.7),
        edge: Hue.cardEdge.withValues(alpha: 0.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Hue.chalkDim),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text ??
                  'Simulation only. ${Brand.currency} are virtual and cannot be '
                      'exchanged for money or prizes.',
              style: Type.body(size: dense ? 11 : 12, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
