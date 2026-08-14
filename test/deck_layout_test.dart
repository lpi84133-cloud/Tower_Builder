import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_builder/app/brand.dart';
import 'package:tower_builder/app/palette.dart';
import 'package:tower_builder/build_site/risk_tier.dart';
import 'package:tower_builder/ui/widgets/budget_bar.dart';
import 'package:tower_builder/ui/widgets/gloss_button.dart';
import 'package:tower_builder/ui/widgets/hazard_trim.dart';
import 'package:tower_builder/ui/widgets/plate_button.dart';
import 'package:tower_builder/ui/widgets/risk_selector.dart';
import 'package:tower_builder/ui/widgets/run_bar.dart';

/// The site chrome has to survive the narrowest phone we support while showing
/// the widest values it can reach. An overflow paints the framework's black and
/// yellow stripes over the deck, and a widget test fails as soon as a RenderFlex
/// overflows — so pumping the chrome is the whole assertion here.
void main() {
  Widget bar() => RunBar(
        brix: 999999,
        rank: 12,
        rankTitle: 'Chief Structural Engineer',
        rankProgress: 0.87,
        plan: RiskPlan.of(RiskTier.reckless),
        onLeave: () {},
      );

  Widget planningDeck() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HazardTrim(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
            color: Hue.abyss,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RiskSelector(
                  selected: RiskTier.standard,
                  onSelect: (_) {},
                  dense: true,
                ),
                const SizedBox(height: 9),
                BudgetBar(
                  budget: 100000,
                  balance: 100000,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 10),
                PlateButton(
                  label: Brand.actionBuild,
                  height: 70,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      );

  Widget liveDeck() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HazardTrim(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
            color: Hue.abyss,
            child: Row(
              children: [
                Expanded(
                  child: GlossButton(
                    label: Brand.actionSignOff,
                    sublabel: '3 812 400 ${Brand.currency}',
                    height: 66,
                    fontSize: 18,
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PlateButton(
                    label: Brand.actionBuild,
                    height: 66,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  for (final size in const [Size(320, 568), Size(360, 800), Size(430, 932)]) {
    for (final deck in {'planning': planningDeck, 'live': liveDeck}.entries) {
      testWidgets('${deck.key} deck lays out at ${size.width.toInt()}dp',
          (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            // Mirrors the run screen: chrome floats over the playfield rather
            // than sharing a column with it.
            body: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF8FC6E4)),
                Align(alignment: Alignment.topCenter, child: bar()),
                Align(alignment: Alignment.bottomCenter, child: deck.value()),
              ],
            ),
          ),
        ));

        expect(tester.takeException(), isNull);
      });
    }
  }
}
