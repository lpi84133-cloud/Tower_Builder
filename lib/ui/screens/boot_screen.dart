import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/asset_paths.dart';
import '../../app/brand.dart';
import '../../app/palette.dart';
import '../../app/routes.dart';
import '../../app/type_scale.dart';
import '../../build_site/sprite_bank.dart';
import '../../state/audio_desk.dart';
import '../widgets/blueprint_backdrop.dart';

/// Warms the sprite cache while the wordmark settles, then hands off to the yard.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final started = DateTime.now();
    await SpriteBank.shared.warmUp();
    if (!mounted) return;

    // The plate is the only sprite drawn through the widget tree rather than the
    // painter, so it needs the image cache warmed separately — otherwise the
    // site's main action shows up a frame late.
    await precacheImage(const AssetImage(Art.plateBlank), context);
    if (!mounted) return;

    // Hold the splash for a beat even on a fast device so the handoff is not a
    // single-frame flash.
    final elapsed = DateTime.now().difference(started);
    const minimum = Duration(milliseconds: 1100);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
    if (!mounted) return;

    await context.read<AudioDesk>().playBed(Bed.shell);
    if (!mounted) return;

    await Navigator.of(context).pushReplacementNamed(Routes.home);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);

    return Scaffold(
      backgroundColor: Hue.navy,
      body: BlueprintBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: Tween(begin: 0.86, end: 1.0).animate(
                    CurvedAnimation(parent: _intro, curve: Curves.easeOutBack),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Image.asset(Art.wordmark, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FadeTransition(
                opacity: fade,
                child: Text(Brand.tagline,
                    style: Type.body(size: 13, color: Hue.chalkDim)),
              ),
              const Spacer(flex: 2),
              const SizedBox(
                width: 132,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Hue.slate,
                  valueColor: AlwaysStoppedAnimation(Hue.cyan),
                ),
              ),
              const SizedBox(height: 14),
              Text('Preparing the site\u2026', style: Type.eyebrow(size: 10)),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                    '${Brand.studio} \u00B7 ${Brand.minimumAge}+ \u00B7 '
                    'simulation only',
                    style: Type.body(size: 11, color: Hue.chalkDim)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
