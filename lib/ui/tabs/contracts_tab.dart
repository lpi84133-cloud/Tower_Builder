import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/asset_paths.dart';
import '../../app/brand.dart';
import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../../state/audio_desk.dart';
import '../../state/contract_board.dart';
import '../widgets/site_chrome.dart';
import '../widgets/steel_button.dart';

/// The day's three side jobs. Progress accrues while playing; rewards are
/// collected by hand so the payout is visible rather than silent.
class ContractsTab extends StatelessWidget {
  const ContractsTab({super.key});

  Future<void> _claim(BuildContext context, Contract contract) async {
    final desk = context.read<AudioDesk>();
    final reward = await context.read<ContractBoard>().claim(contract);
    if (reward <= 0 || !context.mounted) return;
    desk.shot(Cue.brix);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Hue.card,
        content: Text(
          'Contract paid: +${Fmt.amount(reward)} ${Brand.currency}',
          style: Type.body(size: 13, color: Hue.chalk),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<ContractBoard>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      children: [
        SectionHead(
          text: "Today's contracts",
          trailing: Text('${board.completedCount}/${board.slate.length} done',
              style: Type.body(size: 11)),
        ),
        for (final contract in board.slate) ...[
          _ContractCard(
            contract: contract,
            onClaim: () => _claim(context, contract),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: Frames.tile(radius: 14, fill: Hue.card),
          child: Row(
            children: [
              const Icon(Icons.refresh_rounded, size: 16, color: Hue.chalkDim),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'A fresh slate is posted every day at midnight, local time.',
                  style: Type.body(size: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SimulationNote(dense: true),
      ],
    );
  }
}

class _ContractCard extends StatelessWidget {
  const _ContractCard({required this.contract, required this.onClaim});

  final Contract contract;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final done = contract.complete;
    final edge = contract.claimable
        ? Hue.amber
        : done
            ? Hue.lime
            : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: Frames.panel(radius: 18, edge: edge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contract.headline,
                        style: Type.label(size: 14, tracking: 0.2)),
                    const SizedBox(height: 3),
                    Text(contract.detail, style: Type.body(size: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: Frames.pill(fill: Hue.abyss, edge: Hue.amberDeep),
                child: Text('+${Fmt.compact(contract.reward)}',
                    style: Type.figure(size: 12, color: Hue.amber)),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: contract.fraction,
                    minHeight: 6,
                    backgroundColor: Hue.navySoft,
                    valueColor: AlwaysStoppedAnimation(
                        done ? Hue.lime : Hue.cyan),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${contract.progress.clamp(0, contract.target)}/${contract.target}',
                style: Type.figure(size: 12, color: Hue.chalkDim),
              ),
            ],
          ),
          if (contract.claimable) ...[
            const SizedBox(height: 11),
            SteelButton(
              label: 'COLLECT PAYMENT',
              tone: SteelTone.bank,
              height: 44,
              fontSize: 14,
              onPressed: onClaim,
            ),
          ] else if (contract.claimed) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: Hue.lime),
                const SizedBox(width: 6),
                Text('Paid', style: Type.label(size: 11, color: Hue.lime)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
