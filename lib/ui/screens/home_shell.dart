import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/asset_paths.dart';
import '../../app/palette.dart';
import '../../app/routes.dart';
import '../../app/type_scale.dart';
import '../../state/architect.dart';
import '../../state/audio_desk.dart';
import '../../state/contract_board.dart';
import '../tabs/contracts_tab.dart';
import '../tabs/rivals_tab.dart';
import '../tabs/site_tab.dart';
import '../tabs/workshop_tab.dart';
import '../widgets/blueprint_backdrop.dart';
import '../widgets/site_chrome.dart';

/// The yard: a four-tab shell that keeps state alive across switches, so walking
/// to the workshop and back never resets a scroll position or a check-in
/// animation. The playable site is pushed on top of it as its own route.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AudioDesk>().playBed(Bed.shell);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back after midnight should show today's contracts, not yesterday's.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ContractBoard>().refreshIfStale();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _select(int index) {
    if (index == _tab) return;
    context.read<AudioDesk>().shot(Cue.tap);
    setState(() => _tab = index);
  }

  @override
  Widget build(BuildContext context) {
    final architect = context.watch<Architect>();
    final claimable = context.watch<ContractBoard>().claimableCount;

    return Scaffold(
      backgroundColor: Hue.navy,
      body: BlueprintBackdrop(
        child: Column(
          children: [
            SiteTopBar(
              brix: architect.brix,
              rank: architect.rank,
              rankTitle: architect.rankTitle,
              rankProgress: architect.rankProgress,
              trailing: GestureDetector(
                onTap: () {
                  context.read<AudioDesk>().shot(Cue.tap);
                  Navigator.of(context).pushNamed(Routes.options);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: Frames.tile(radius: 11, fill: Hue.abyss),
                  child: const Icon(Icons.tune_rounded,
                      size: 19, color: Hue.chalkDim),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  SiteTab(),
                  ContractsTab(),
                  WorkshopTab(),
                  RivalsTab(),
                ],
              ),
            ),
            _YardNav(
              index: _tab,
              badge: claimable,
              onSelect: _select,
            ),
          ],
        ),
      ),
    );
  }
}

class _YardNav extends StatelessWidget {
  const _YardNav({
    required this.index,
    required this.badge,
    required this.onSelect,
  });

  final int index;
  final int badge;
  final ValueChanged<int> onSelect;

  static const _items = <(IconData, String)>[
    (Icons.foundation_rounded, 'Site'),
    (Icons.assignment_outlined, 'Contracts'),
    (Icons.handyman_outlined, 'Workshop'),
    (Icons.emoji_events_outlined, 'Rivals'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Hue.abyss,
        border: Border(top: BorderSide(color: Hue.cardEdge)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavCell(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    active: i == index,
                    badge: i == 1 ? badge : 0,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.icon,
    required this.label,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = active ? Hue.cyan : Hue.chalkDim;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? Hue.cyan.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 21, color: tint),
                if (badge > 0)
                  Positioned(
                    right: -6,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Hue.amber,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$badge',
                          style: Type.figure(size: 9, color: Hue.abyss)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: Type.label(size: 10, color: tint, tracking: 0.3)),
          ],
        ),
      ),
    );
  }
}
