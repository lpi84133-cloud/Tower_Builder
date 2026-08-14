import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../../state/architect.dart';

/// Non-blocking promotion notice: drops in from under the top bar, holds, then
/// lifts away on its own. Never interrupts a live build.
class PromotionBanner extends StatefulWidget {
  const PromotionBanner({
    super.key,
    required this.promotion,
    required this.onFinished,
  });

  final Promotion promotion;
  final VoidCallback onFinished;

  @override
  State<PromotionBanner> createState() => _PromotionBannerState();
}

class _PromotionBannerState extends State<PromotionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    _timeline
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onFinished();
      })
      ..forward();
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promotion = widget.promotion;

    return AnimatedBuilder(
      animation: _timeline,
      builder: (context, _) {
        final t = _timeline.value;
        // Drop in over the first 12%, hold, lift away over the last 15%.
        final entry = Curves.easeOutBack.transform((t / 0.12).clamp(0.0, 1.0));
        final exit = t < 0.85 ? 0.0 : ((t - 0.85) / 0.15).clamp(0.0, 1.0);
        final offset = -70 * (1 - entry) - 70 * exit;

        return Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Transform.translate(
              offset: Offset(0, offset + 54),
              child: Opacity(
                opacity: (1 - exit).clamp(0.0, 1.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: Frames.panel(radius: 18, edge: Hue.cyan),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Hue.cyanDeep,
                          shape: BoxShape.circle,
                        ),
                        child: Text('${promotion.rank}',
                            style: Type.figure(size: 17)),
                      ),
                      const SizedBox(width: 11),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('PROMOTED \u2014 ${promotion.title}',
                              style: Type.label(size: 13, tracking: 0.6)),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (promotion.brixAwarded > 0)
                                '+${Fmt.amount(promotion.brixAwarded)} ${Brand.currency}',
                              if (promotion.kitsUnlocked.isNotEmpty)
                                'new module kit unlocked',
                            ].join(' \u00B7 '),
                            style: Type.body(size: 11, color: Hue.amber),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
