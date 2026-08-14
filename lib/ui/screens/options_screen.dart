import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/asset_paths.dart';
import '../../app/brand.dart';
import '../../app/palette.dart';
import '../../app/routes.dart';
import '../../app/type_scale.dart';
import '../../state/architect.dart';
import '../../state/audio_desk.dart';
import '../widgets/blueprint_backdrop.dart';
import '../widgets/site_chrome.dart';
import 'legal_screen.dart';

/// Audio, legal texts, and the switch that wipes the save.
class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  Future<void> _confirmErase(BuildContext context) async {
    final architect = context.read<Architect>();
    final wipe = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Hue.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Erase progress?', style: Type.label(size: 17)),
        content: Text(
          'This clears your ${Brand.currency} balance, career rank, unlocked '
          'cosmetics, contracts and standings from this device. It cannot be '
          'undone.',
          style: Type.body(size: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep it', style: Type.label(size: 13, color: Hue.chalkDim)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Erase', style: Type.label(size: 13, color: Hue.rust)),
          ),
        ],
      ),
    );
    if (wipe != true) return;
    await architect.eraseEverything();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Hue.card,
        content: Text('Save erased. Fresh site issued.',
            style: Type.body(size: 13, color: Hue.chalk)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final architect = context.watch<Architect>();
    final desk = context.read<AudioDesk>();

    return Scaffold(
      backgroundColor: Hue.navy,
      body: BlueprintBackdrop(
        glow: false,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: Hue.chalk, size: 28),
                    ),
                    Text('Options', style: Type.label(size: 17)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const SectionHead(text: 'Sound'),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      decoration: Frames.panel(radius: 18),
                      child: Column(
                        children: [
                          _Toggle(
                            icon: Icons.graphic_eq_rounded,
                            label: 'Sound effects',
                            value: architect.soundOn,
                            onChanged: (v) {
                              architect.setSoundOn(v);
                              if (v) desk.shot(Cue.tap);
                            },
                          ),
                          _LevelRow(
                            label: 'Effect level',
                            value: architect.soundLevel,
                            enabled: architect.soundOn,
                            onChanged: architect.setSoundLevel,
                            onSettled: () => desk.shot(Cue.tap),
                          ),
                          const Divider(color: Hue.cardEdge, height: 20),
                          _Toggle(
                            icon: Icons.music_note_rounded,
                            label: 'Music bed',
                            value: architect.musicOn,
                            onChanged: architect.setMusicOn,
                          ),
                          _LevelRow(
                            label: 'Music level',
                            value: architect.musicLevel,
                            enabled: architect.musicOn,
                            onChanged: architect.setMusicLevel,
                          ),
                          const Divider(color: Hue.cardEdge, height: 20),
                          _Toggle(
                            icon: Icons.vibration_rounded,
                            label: 'Haptics',
                            value: architect.hapticsOn,
                            onChanged: (v) {
                              architect.setHapticsOn(v);
                              if (v) desk.buzz();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const SectionHead(text: 'Good to know'),
                    Container(
                      decoration: Frames.panel(radius: 18),
                      child: Column(
                        children: [
                          _DocRow(
                            icon: Icons.privacy_tip_outlined,
                            label: 'Privacy policy',
                            onTap: () => Navigator.of(context).pushNamed(
                                Routes.legal,
                                arguments: LegalDoc.privacy),
                          ),
                          _DocRow(
                            icon: Icons.gavel_rounded,
                            label: 'Terms of use',
                            onTap: () => Navigator.of(context).pushNamed(
                                Routes.legal,
                                arguments: LegalDoc.terms),
                          ),
                          _DocRow(
                            icon: Icons.self_improvement_rounded,
                            label: 'Playing responsibly',
                            onTap: () => Navigator.of(context).pushNamed(
                                Routes.legal,
                                arguments: LegalDoc.responsible),
                            last: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const SimulationNote(text: Brand.simulationNotice),
                    const SizedBox(height: 10),
                    const SimulationNote(text: Brand.noPurchaseNotice),
                    const SizedBox(height: 10),
                    const SimulationNote(
                      text: 'Intended for players ${Brand.minimumAge} and over. '
                          '${Brand.responsiblePlayNotice}',
                    ),
                    const SizedBox(height: 18),
                    const SectionHead(text: 'This device'),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      decoration: Frames.panel(radius: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your save lives only on this device. Nothing is '
                            'uploaded, and there is no account to sign in to.',
                            style: Type.body(size: 12),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _confirmErase(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 11),
                              decoration: Frames.tile(
                                radius: 12,
                                fill: Hue.rust.withValues(alpha: 0.14),
                                edge: Hue.rust,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline_rounded,
                                      size: 17, color: Hue.rust),
                                  const SizedBox(width: 9),
                                  Text('Erase progress',
                                      style: Type.label(
                                          size: 13, color: Hue.rust)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          Text('${Brand.title}  v${Brand.version}',
                              style: Type.label(size: 12)),
                          const SizedBox(height: 4),
                          Text(Brand.studio,
                              style: Type.body(size: 11)),
                          const SizedBox(height: 4),
                          Text('Fonts under the SIL Open Font License',
                              style: Type.body(size: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: value ? Hue.cyan : Hue.chalkDim),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: Type.label(size: 14, tracking: 0.2))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Hue.chalk,
          activeTrackColor: Hue.cyanDeep,
          inactiveThumbColor: Hue.chalkDim,
          inactiveTrackColor: Hue.slate,
        ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.onSettled,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final VoidCallback? onSettled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label,
              style: Type.body(
                  size: 11, color: enabled ? Hue.chalkDim : Hue.slate)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: enabled ? Hue.cyan : Hue.slate,
              inactiveTrackColor: Hue.slate,
              thumbColor: enabled ? Hue.chalk : Hue.chalkDim,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? (_) => onSettled?.call() : null,
            ),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text('${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: Type.figure(size: 12, color: Hue.chalkDim)),
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: Hue.cardEdge, width: 0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Hue.chalkDim),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label, style: Type.label(size: 14, tracking: 0.2))),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: Hue.chalkDim),
          ],
        ),
      ),
    );
  }
}
