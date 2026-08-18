import 'package:flutter/material.dart';

import '../facade/manifest.dart';
import '../scaffold_link/beacon_link.dart';
import '../scaffold_link/nettap.dart';
import '../scaffold_link/secret_box.dart';
import 'brix_asset_kit.dart';
import 'glow_button.dart';
import 'webshell.dart';

/// Push-permission promo. Rendered without a SafeArea so the artwork
/// reaches the physical screen edges — the buttons row is positioned
/// relative to the raw viewport height, not the safe-area inset, so a
/// notched device does not push the CTAs off-centre in landscape.
class TowerPushPane extends StatelessWidget {
  const TowerPushPane({
    super.key,
    required this.box,
    required this.beacon,
    required this.tap,
    required this.link,
  });

  final SecretBox box;
  final BeaconLink beacon;
  final NetTap tap;
  final String link;

  Future<void> _accept(BuildContext context) async {
    final bool granted = await beacon.askPermission();
    if (!granted) {
      await box.writeInviteCooldown(_cooldownStamp());
    }
    if (context.mounted) _forward(context);
  }

  Future<void> _skip(BuildContext context) async {
    await box.writeInviteCooldown(_cooldownStamp());
    if (context.mounted) _forward(context);
  }

  int _cooldownStamp() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      BrixManifest.inviteCoolSeconds;

  void _forward(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => WebShell(
          link: link,
          box: box,
          beacon: beacon,
          tap: tap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? BrixVeil.horizontalPing
        : BrixVeil.verticalPing;

    // Both buttons share the same width so the pair reads as one
    // choice, not a call-to-action with an afterthought. Skip uses
    // the same shape family as Accept — never a plain text link, per
    // the final-checklist rule (§"Skip button is a real gradient
    // button"). Landscape stacks them horizontally to keep them
    // clear of the artwork; portrait stacks them vertically so a
    // fat thumb never trips the wrong one.
    final double buttonWidth = landscape
        ? (size.width * 0.24).clamp(150.0, 220.0)
        : (size.width * 0.72).clamp(220.0, 380.0);

    final Widget acceptBtn = GlowPill(
      label: 'Accept',
      compact: landscape,
      width: buttonWidth,
      onTap: () => _accept(context),
    );
    final Widget skipBtn = GlowPill(
      label: 'Skip',
      compact: landscape,
      width: buttonWidth,
      onTap: () => _skip(context),
    );

    final Widget actions = landscape
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              acceptBtn,
              const SizedBox(width: 14),
              skipBtn,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              acceptBtn,
              const SizedBox(height: 14),
              skipBtn,
            ],
          );

    return Scaffold(
      backgroundColor: const Color(0xFF0B1E3C),
      // Deliberately no SafeArea: the artwork is designed to reach the
      // physical edges, and the buttons live below in a Positioned
      // rooted to the raw viewport centre.
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            bg,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x88000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.06 : 0.06),
            child: Center(child: actions),
          ),
        ],
      ),
    );
  }
}
