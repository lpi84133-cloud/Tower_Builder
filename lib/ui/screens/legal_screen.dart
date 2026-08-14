import 'package:flutter/material.dart';

import '../../app/brand.dart';

/// Which text to show.
enum LegalDoc { privacy, terms, responsible }

/// Legal texts embedded in the app — readable offline from the first launch.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  String get _title {
    switch (doc) {
      case LegalDoc.privacy:
        return 'Privacy Policy';
      case LegalDoc.terms:
        return 'Terms of Use';
      case LegalDoc.responsible:
        return 'Playing Responsibly';
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
    const bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: Colors.black87,
    );
    const headingStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    const dividerColor = Color(0xFFDDDDDD);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(_title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black, size: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          for (final block in _blocks) ...[
            if (block.heading != null) ...[
              const SizedBox(height: 20),
              Text(block.heading!, style: headingStyle),
              const SizedBox(height: 6),
            ],
            Text(block.body, style: bodyStyle),
          ],
          const SizedBox(height: 24),
          const Divider(color: dividerColor),
          const SizedBox(height: 8),
          Text(
            '${Brand.title} \u00B7 ${Brand.studio}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
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
    null,
    'Effective Date: August 2026\n\n'
        'Developer (\u201Cwe\u201D, \u201Cus\u201D, or \u201Cour\u201D) operates the ${Brand.title} mobile '
        'application (\u201CService\u201D). This Privacy Policy explains how information '
        'is collected, used, and protected when you use the Service.',
  ),
  _Block(
    'Information We Collect',
    'The Service may collect limited technical information necessary for '
        'operation and improvement of the application, including:\n\n'
        '\u2022 Device type and model\n'
        '\u2022 Operating system version\n'
        '\u2022 Anonymous usage statistics\n'
        '\u2022 Diagnostic and crash information\n'
        '\u2022 IP address (when required for security and analytics purposes)\n\n'
        'We do not intentionally collect sensitive personal information such as '
        'financial account details, government-issued identification numbers, or '
        'biometric data.',
  ),
  _Block(
    'How We Use Information',
    '\u2022 Provide and maintain the Service\n'
        '\u2022 Improve app functionality and user experience\n'
        '\u2022 Monitor application performance and stability\n'
        '\u2022 Detect, prevent, and resolve technical issues\n'
        '\u2022 Comply with legal obligations',
  ),
  _Block(
    'Data Storage and Security',
    'We take reasonable measures to protect information from unauthorized '
        'access, alteration, disclosure, or destruction. However, no method of '
        'electronic transmission or storage is completely secure.',
  ),
  _Block(
    'Third-Party Services',
    'The Service may use third-party providers for analytics, crash reporting, '
        'hosting, or other operational purposes. These providers may process '
        'information solely to provide services on our behalf.',
  ),
  _Block(
    'Data Retention',
    'We retain information only for as long as necessary to provide the '
        'Service, comply with legal obligations, resolve disputes, and enforce '
        'agreements.',
  ),
  _Block(
    'Data Deletion',
    'Users have the right to request deletion of their personal data.\n\n'
        'To request deletion of data associated with ${Brand.title}, please '
        'contact us at:\n\nEmail: support@towerbuilder.com\n\n'
        'When submitting a deletion request, please provide sufficient '
        'information to identify your account or device. Verified requests will '
        'be processed within a reasonable timeframe.\n\n'
        'If the application stores data only on the user\u2019s device, users may '
        'permanently delete all stored data by uninstalling the application and '
        'clearing the application\u2019s local storage.',
  ),
  _Block(
    'Your Rights',
    'Depending on your location, you may have rights regarding access, '
        'correction, deletion, restriction, or portability of your personal data '
        'under applicable privacy laws, including the GDPR.',
  ),
  _Block(
    'Children\u2019s Privacy',
    'The Service is not intended for children under the age of 18, and we do '
        'not knowingly collect personal information from children.',
  ),
  _Block(
    'Changes to This Privacy Policy',
    'We may update this Privacy Policy from time to time. Changes become '
        'effective when posted on this page. Users are encouraged to review this '
        'policy periodically.',
  ),
  _Block(
    'Contact Us',
    'If you have questions about this Privacy Policy or wish to exercise your '
        'privacy rights, please contact:\n\n'
        'Developer: ${Brand.title}\n'
        'Email: support@towerbuilder.com',
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
