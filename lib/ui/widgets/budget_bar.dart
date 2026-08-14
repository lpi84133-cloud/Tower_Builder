import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../../build_site/site_metrics.dart';
import 'gloss_button.dart';

/// The single-row budget deck the site uses while planning: jump to the whole
/// balance, walk a ladder of round figures, or double what is committed.
///
/// The ladder means two taps stay useful at 50 BRIX and at 50 000, which a flat
/// increment does not manage.
class BudgetBar extends StatelessWidget {
  const BudgetBar({
    super.key,
    required this.budget,
    required this.balance,
    required this.onChanged,
    this.onNudge,
    this.height = 54,
  });

  final int budget;
  final int balance;
  final ValueChanged<int> onChanged;
  final VoidCallback? onNudge;
  final double height;

  static const _ladder = <int>[
    10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000,
  ];

  int get _ceiling =>
      math.min(SiteMetrics.maxBudget, math.max(SiteMetrics.minBudget, balance));

  void _emit(int value) {
    final clamped = value.clamp(SiteMetrics.minBudget, _ceiling);
    if (clamped == budget) return;
    onNudge?.call();
    onChanged(clamped);
  }

  void _walk(int direction) {
    if (direction < 0) {
      final below = _ladder.where((v) => v < budget);
      _emit(below.isEmpty ? SiteMetrics.minBudget : below.last);
    } else {
      final above = _ladder.where((v) => v > budget && v <= _ceiling);
      _emit(above.isEmpty ? _ceiling : above.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ceiling = _ceiling;

    return Row(
      children: [
        GlossButton(
          label: 'MAX',
          width: 88,
          height: height,
          fontSize: 16,
          onPressed: balance >= SiteMetrics.minBudget
              ? () => _emit(ceiling)
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Hue.rigPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Hue.rigEdge),
            ),
            child: Row(
              children: [
                _Nudge(
                  icon: Icons.remove_rounded,
                  enabled: budget > SiteMetrics.minBudget,
                  onTap: () => _walk(-1),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Six-figure budgets on a narrow phone leave very little
                      // room here, so the figure shrinks instead of wrapping.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Fmt.amount(budget),
                          maxLines: 1,
                          style: Type.figure(size: 22, color: Colors.white),
                        ),
                      ),
                      Text(
                        Brand.budget.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: Type.eyebrow(size: 9),
                      ),
                    ],
                  ),
                ),
                _Nudge(
                  icon: Icons.add_rounded,
                  enabled: budget < ceiling,
                  onTap: () => _walk(1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GlossButton(
          label: '\u00D72',
          width: 68,
          height: height,
          fontSize: 18,
          onPressed: budget < ceiling ? () => _emit(budget * 2) : null,
        ),
      ],
    );
  }
}

class _Nudge extends StatelessWidget {
  const _Nudge({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Hue.rigWell,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 26,
              color: enabled ? Colors.white : Hue.chalkDim.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
