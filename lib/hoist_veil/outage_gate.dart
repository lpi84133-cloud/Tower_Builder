import 'package:flutter/material.dart';

import 'brix_asset_kit.dart';
import 'glow_button.dart';

/// No-connection stage. Shows the project's no-wifi artwork with a
/// Retry pill overlaid at the bottom. Retry rebuilds whatever screen
/// the caller supplies — usually the site-portal router, so the whole
/// gate → attribution → dial pipeline restarts from scratch.
class OutageGate extends StatefulWidget {
  const OutageGate({super.key, required this.onRetryBuild});

  final WidgetBuilder onRetryBuild;

  @override
  State<OutageGate> createState() => _OutageGateState();
}

class _OutageGateState extends State<OutageGate> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final String bg = landscape
        ? BrixVeil.horizontalNoLink
        : BrixVeil.verticalNoLink;

    final double buttonWidth = landscape
        ? size.width * 0.35
        : (size.width * 0.72).clamp(220.0, 380.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1E3C),
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
                colors: <Color>[Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.10 : 0.07),
            child: Center(
              child: _busy
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFFD35A)),
                      ),
                    )
                  : GlowPill(
                      label: 'Retry',
                      width: buttonWidth,
                      onTap: _retry,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
