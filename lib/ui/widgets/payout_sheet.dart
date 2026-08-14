import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import 'site_chrome.dart';
import 'steel_button.dart';

/// Shown after a sign-off: the job summary and where to go next. Slides up from
/// the bottom edge rather than covering the tower, so the finished frame stays
/// visible behind it.
class PayoutSheet extends StatefulWidget {
  const PayoutSheet({
    super.key,
    required this.storeys,
    required this.bonus,
    required this.payout,
    required this.onNextBuild,
    required this.onLeaveSite,
  });

  final int storeys;
  final double bonus;
  final int payout;
  final VoidCallback onNextBuild;
  final VoidCallback onLeaveSite;

  @override
  State<PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<PayoutSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic);

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: slide,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 90 * (1 - slide.value)),
          child: Opacity(opacity: slide.value, child: child),
        ),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: Frames.panel(radius: 24, edge: Hue.amber),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_turned_in_rounded,
                        color: Hue.amber, size: 20),
                    const SizedBox(width: 8),
                    Text('BUILD SIGNED OFF', style: Type.eyebrow(color: Hue.amber)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('+${Fmt.amount(widget.payout)}',
                    style: Type.slab(size: 52, color: Hue.amber)),
                Text(Brand.currencyLong,
                    style: Type.eyebrow(size: 10, color: Hue.chalkDim)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        caption: 'Height',
                        value: '${widget.storeys} storeys',
                        icon: Icons.apartment_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        caption: '${Brand.bonus} banked',
                        value: Fmt.mult(widget.bonus),
                        icon: Icons.trending_up_rounded,
                        accent: Hue.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SteelButton(
                        label: 'YARD',
                        tone: SteelTone.ghost,
                        height: 52,
                        fontSize: 15,
                        icon: Icons.home_work_outlined,
                        onPressed: widget.onLeaveSite,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SteelButton(
                        label: 'NEXT BUILD',
                        tone: SteelTone.primary,
                        height: 52,
                        fontSize: 16,
                        icon: Icons.play_arrow_rounded,
                        onPressed: widget.onNextBuild,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
