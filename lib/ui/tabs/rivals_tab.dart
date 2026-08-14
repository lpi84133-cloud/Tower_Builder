import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/format.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../../state/rival_firms.dart';
import '../widgets/site_chrome.dart';

/// Weekly standings against generated rival firms. Everything on this screen is
/// produced on the device from the week number, so there is no account, no
/// network traffic and nothing to compare against other players.
class RivalsTab extends StatelessWidget {
  const RivalsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final rivals = context.watch<RivalFirms>();
    final rows = rivals.table();
    final place = rivals.placement;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          decoration: Frames.panel(radius: 20, edge: Hue.violet),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('THIS WEEK', style: Type.eyebrow(color: Hue.violet)),
                  const SizedBox(height: 6),
                  Text(Fmt.ordinal(place),
                      style: Type.slab(size: 34, color: Hue.chalk)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Tallest frame ${rivals.weekHeight}',
                      style: Type.figure(size: 14)),
                  const SizedBox(height: 5),
                  Text('Banked ${Fmt.amount(rivals.weekEarnings)}',
                      style: Type.body(size: 12)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHead(text: 'Standings'),
        Container(
          decoration: Frames.panel(radius: 18),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                _Row(
                  place: i + 1,
                  standing: rows[i],
                  last: i == rows.length - 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SimulationNote(
          text: 'Rival firms are generated on this device each week. No scores '
              'are uploaded and no other players are involved.',
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.place,
    required this.standing,
    required this.last,
  });

  final int place;
  final FirmStanding standing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final mine = standing.isPlayer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: mine ? Hue.cyan.withValues(alpha: 0.13) : Colors.transparent,
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Hue.cardEdge, width: 0.7)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('$place',
                style: Type.figure(
                    size: 13, color: mine ? Hue.cyan : Hue.chalkDim)),
          ),
          Expanded(
            child: Text(
              standing.firm,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Type.label(
                size: 13,
                color: mine ? Hue.chalk : Hue.chalkDim,
                tracking: 0.2,
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.apartment_rounded, size: 13, color: Hue.chalkDim),
              const SizedBox(width: 4),
              SizedBox(
                width: 26,
                child: Text('${standing.height}',
                    style: Type.figure(size: 12)),
              ),
            ],
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              Fmt.compact(standing.earnings),
              textAlign: TextAlign.right,
              style: Type.figure(size: 12, color: Hue.amber),
            ),
          ),
        ],
      ),
    );
  }
}
