import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/asset_paths.dart';
import '../../app/routes.dart';
import '../../build_site/sprite_bank.dart';
import '../../state/audio_desk.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startFakeProgress();
    _prepare();
  }

  // Animates the bar from 0 → 90 % while real loading happens, then jumps to
  // 100 % when _prepare() finishes and we navigate away.
  void _startFakeProgress() {
    const interval = Duration(milliseconds: 40);
    _ticker = Timer.periodic(interval, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        // Ease towards 90 %; never reaches 100 % on its own.
        _progress += (0.90 - _progress) * 0.04;
      });
    });
  }

  Future<void> _prepare() async {
    final started = DateTime.now();
    await SpriteBank.shared.warmUp();
    if (!mounted) return;

    await precacheImage(const AssetImage(Art.plateBlank), context);
    if (!mounted) return;

    final elapsed = DateTime.now().difference(started);
    const minimum = Duration(milliseconds: 1400);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
    if (!mounted) return;

    // Snap to 100 % before navigating so the user sees a full bar.
    setState(() => _progress = 1.0);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    _ticker?.cancel();
    await context.read<AudioDesk>().playBed(Bed.shell);
    if (!mounted) return;

    await Navigator.of(context).pushReplacementNamed(Routes.home);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final loadingImage =
        isLandscape ? Art.loadingHorizontal : Art.loadingVertical;
    final pct = (_progress * 100).round();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(loadingImage, fit: BoxFit.cover),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                const Text(
                  'Loading.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _FancyBar(progress: _progress),
                ),
                const SizedBox(height: 8),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color: Color(0xFF4FC3F7),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FancyBar extends StatelessWidget {
  const _FancyBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          children: [
            // Filled portion
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0288D1),
                      Color(0xFF4FC3F7),
                      Color(0xFF81D4FA),
                    ],
                  ),
                ),
              ),
            ),
            // Shine overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
