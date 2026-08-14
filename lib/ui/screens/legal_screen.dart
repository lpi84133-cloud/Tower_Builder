import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/brand.dart';
import '../../app/palette.dart';
import '../../app/type_scale.dart';
import '../widgets/blueprint_backdrop.dart';

/// Which text to show.
enum LegalDoc { privacy, terms, responsible }

/// Legal texts, rendered from strings compiled into the app.
///
/// They deliberately do not load a remote page: the app makes no network requests
/// at all, so the policy has to be readable offline, from the first launch. The
/// store listing hosts the same text for reviewers who need a URL.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  String get _title {
    switch (doc) {
      case LegalDoc.privacy:
        return 'Privacy policy';
      case LegalDoc.terms:
        return 'Terms of use';
      case LegalDoc.responsible:
        return 'Playing responsibly';
    }
  }

  List<_Block> get _blocks {
    switch (doc) {
      case LegalDoc.privacy:
        return _privacy;
      case LegalDoc.terms:
        return _terms;
      case LegalDoc.responsible:
        return _responsible;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Hue.navy,
      body: BlueprintBackdrop(
        glow: false,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: Hue.chalk, size: 28),
                    ),
                    Expanded(child: Text(_title, style: Type.label(size: 17))),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  children: [
                    Text('${Brand.title} \u00B7 ${Brand.studio}',
                        style: Type.eyebrow()),
                    const SizedBox(height: 16),
                    for (final block in _blocks) ...[
                      if (block.heading != null) ...[
                        Text(block.heading!, style: Type.label(size: 14)),
                        const SizedBox(height: 6),
                      ],
                      Text(block.body, style: Type.body(size: 13, height: 1.45)),
                      const SizedBox(height: 16),
                    ],
                    const Divider(color: Hue.cardEdge),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Questions: ${Brand.supportEmail}',
                              style: Type.body(size: 12)),
                        ),
                        IconButton(
                          tooltip: 'Copy address',
                          onPressed: () async {
                            await Clipboard.setData(
                                const ClipboardData(text: Brand.supportEmail));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: Hue.slate,
                              content: Text('Address copied',
                                  style: Type.body(size: 12)),
                            ));
                          },
                          icon: const Icon(Icons.copy_rounded,
                              size: 16, color: Hue.cyan),
                        ),
                      ],
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

class _Block {
  const _Block(this.heading, this.body);
  final String? heading;
  final String body;
}

const _privacy = <_Block>[
  _Block(
    'The short version',
    '${Brand.title} does not collect, transmit or sell any personal data. There '
        'are no accounts, no sign-in, no advertising, no analytics and no '
        'tracking of any kind. The game does not talk to a server.',
  ),
  _Block(
    'What is stored, and where',
    'Your balance, career rank, unlocked cosmetics, daily check-in streak, '
        'contracts, weekly standings and audio preferences are written to the '
        'app\u2019s private storage on this device only. Nothing is uploaded, '
        'backed up to us, or shared with a third party.',
  ),
  _Block(
    'Permissions',
    'The app requests no runtime permissions. It does not read your contacts, '
        'files, location, camera, microphone, advertising identifier or device '
        'identifiers.',
  ),
  _Block(
    'Third-party components',
    'The build includes open-source Flutter packages for local storage and '
        'audio playback only. Neither collects data, and the app declares no '
        'network permission at all.',
  ),
  _Block(
    'Children',
    '${Brand.title} is intended for players aged ${Brand.minimumAge} and over '
        'and is not directed at children. It contains no purchases and no data '
        'collection of any kind.',
  ),
  _Block(
    'Deleting your data',
    'Open Options and use "Erase progress" to wipe the save immediately. '
        'Uninstalling the app also removes everything it stored.',
  ),
  _Block(
    'Changes',
    'If this policy ever changes, the updated text ships inside the app update '
        'itself, so what you read here always matches the version you are running.',
  ),
];

const _terms = <_Block>[
  _Block(
    'What this game is',
    '${Brand.title} is a single-player construction simulation. A crane swings a '
        'prefabricated module, you release it, and a published per-storey chance '
        'decides whether that storey holds. Storeys that hold compound a bonus '
        'you can bank by signing the build off.',
  ),
  _Block(
    'The economy is virtual',
    Brand.simulationNotice,
  ),
  _Block(
    'No purchases, no wagering',
    '${Brand.noPurchaseNotice} ${Brand.currency} can only be earned by playing, '
        'by the daily site check-in, by completing contracts and through career '
        'promotions. If your balance ever runs dry, the yard grants a fresh '
        'starting stock at no cost, so the game can always be continued.',
  ),
  _Block(
    'Outcomes are chance-based',
    'Whether a storey holds is decided by the risk plan\u2019s hold chance, and '
        'each surviving storey rolls its own bonus within the range printed on '
        'that plan. Timing, skill or how long you hold the release do not change '
        'the odds. The stated percentages are the real ones used by the game.',
  ),
  _Block(
    'Your save',
    'Progress lives on this device. Reinstalling the app, clearing its storage '
        'or erasing progress from Options starts a new save, and previous '
        'progress cannot be recovered by us because we never receive it.',
  ),
  _Block(
    'Fair use',
    'Please do not modify, repackage or redistribute the app. The artwork, audio '
        'and code are owned by ${Brand.studio} except for the bundled open-source '
        'fonts, which are used under the SIL Open Font License and shipped with '
        'their licence texts.',
  ),
  _Block(
    'No warranty',
    'The game is provided as-is, for entertainment. To the extent permitted by '
        'law, ${Brand.studio} is not liable for any loss arising from its use.',
  ),
];

const _responsible = <_Block>[
  _Block(
    'It is a simulation',
    'Nothing in ${Brand.title} can be won or lost in the real world. '
        '${Brand.currency} are site credits inside the game; they have no cash '
        'value and no exchange path.',
  ),
  _Block(
    'Keep it a game',
    'Sessions are meant to be short. If a run stops being fun, or you notice '
        'yourself chasing a bad streak, close the app and come back another day. '
        'The daily check-in will still be there.',
  ),
  _Block(
    'The odds are printed',
    'Every risk plan shows its hold chance and bonus range before you commit a '
        'budget. Bolder plans fail more often \u2014 that is the whole trade, and '
        'no amount of practice changes it.',
  ),
  _Block(
    'If real gambling is a concern',
    'This game involves no money, but if simulated stakes make you think about '
        'real gambling habits, consider speaking to a support service in your '
        'country, such as BeGambleAware (begambleaware.org) or Gambling Therapy '
        '(gamblingtherapy.org).',
  ),
  _Block(
    'Controls in this app',
    'Options lets you mute sound and music, turn haptics off, and erase all '
        'progress at any time.',
  ),
];
