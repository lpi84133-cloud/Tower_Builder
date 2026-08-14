import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../../build_site/site_metrics.dart';

/// Sets how much of the balance is committed to the next build.
///
/// The stepper walks a ladder of round figures rather than adding a flat amount,
/// so the same two taps feel useful at 50 BRIX and at 50 000.
class BudgetDial extends StatelessWidget {
  const BudgetDial({
    super.key,
    required this.budget,
    required this.balance,
    required this.onChanged,
    this.onNudge,
  });

  final int budget;
  final int balance;
  final ValueChanged<int> onChanged;

  /// Fired on every accepted change so the caller can click the UI cue.
  final VoidCallback? onNudge;

  static const _ladder = <int>[
    10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000, 100000,
  ];

  int get _ceiling => math.min(SiteMetrics.maxBudget,
      math.max(SiteMetrics.minBudget, balance));

  void _emit(int value) {
    final clamped = value.clamp(SiteMetrics.minBudget, _ceiling);
    if (clamped == budget) return;
    onNudge?.call();
    onChanged(clamped);
  }

  void _step(int direction) {
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
    final presets = SiteMetrics.budgetPresets.where((v) => v <= ceiling).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: Frames.panel(radius: 20),
      child: Column(
        children: [
          Row(
            children: [
              Text('${Brand.budget.toUpperCase()} / BUILD', style: Type.eyebrow()),
              const Spacer(),
              Text('Balance ${Fmt.amount(balance)}',
                  style: Type.body(size: 11, color: Hue.chalkDim)),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _Stepper(
                icon: Icons.remove_rounded,
                enabled: budget > SiteMetrics.minBudget,
                onTap: () => _step(-1),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: Frames.tile(radius: 14, fill: Hue.abyss),
                  child: FittedBox(
                    child: Row(
                      children: [
                        Text(Fmt.amount(budget),
                            style: Type.slab(size: 26, color: Hue.amber)),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(Brand.currency,
                              style: Type.eyebrow(size: 10, color: Hue.amber)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _Stepper(
                icon: Icons.add_rounded,
                enabled: budget < ceiling,
                onTap: () => _step(1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final preset in presets) ...[
                Expanded(
                  child: _Chip(
                    text: Fmt.compact(preset),
                    selected: budget == preset,
                    onTap: () => _emit(preset),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: _Chip(
                  text: 'MAX',
                  selected: budget == ceiling,
                  accent: Hue.amber,
                  onTap: () => _emit(ceiling),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: Frames.tile(
          radius: 14,
          fill: enabled ? Hue.slate : Hue.navy,
          edge: enabled ? Hue.cyanDeep : Hue.cardEdge,
        ),
        child: Icon(icon, color: enabled ? Hue.chalk : Hue.chalkDim, size: 22),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.selected,
    required this.onTap,
    this.accent = Hue.cyan,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: Frames.tile(
          radius: 11,
          fill: selected ? accent.withValues(alpha: 0.22) : Hue.navySoft,
          edge: selected ? accent : Hue.cardEdge,
        ),
        child: Text(
          text,
          maxLines: 1,
          style: Type.label(
            size: 12,
            color: selected ? Hue.chalk : Hue.chalkDim,
            tracking: 0.5,
          ),
        ),
      ),
    );
  }
}
