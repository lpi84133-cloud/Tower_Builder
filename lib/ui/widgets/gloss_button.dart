import 'package:flutter/material.dart';

import '../../app/palette.dart';
import '../../app/type_scale.dart';

enum GlossTone { glaze, sign, gold, graphite }

/// Moulded plastic button used across the site deck: the budget shortcuts and
/// the sign-off action. Painted rather than sprited, so it stretches cleanly and
/// stays crisp at any size.
class GlossButton extends StatefulWidget {
  const GlossButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.sublabel,
    this.icon,
    this.tone = GlossTone.glaze,
    this.width,
    this.height = 54,
    this.fontSize = 17,
  });

  final String label;
  final String? sublabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GlossTone tone;
  final double? width;
  final double height;
  final double fontSize;

  @override
  State<GlossButton> createState() => _GlossButtonState();
}

class _GlossButtonState extends State<GlossButton> {
  bool _held = false;

  void _hold(bool value) {
    if (widget.onPressed == null || _held == value) return;
    setState(() => _held = value);
  }

  ({Color crown, Color base, Color rim}) get _shell {
    switch (widget.tone) {
      case GlossTone.glaze:
        return (crown: Hue.glaze, base: Hue.glazeDeep, rim: Hue.glazeEdge);
      case GlossTone.sign:
        return (
          crown: const Color(0xFF6BD089),
          base: const Color(0xFF2E9A4F),
          rim: const Color(0xFF1C5E31)
        );
      case GlossTone.gold:
        return (crown: Hue.amber, base: Hue.amberDeep, rim: const Color(0xFF8A5A12));
      case GlossTone.graphite:
        return (
          crown: const Color(0xFF4A4D5C),
          base: const Color(0xFF2B2D38),
          rim: const Color(0xFF15161D)
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final idle = widget.onPressed == null;
    final shell = _shell;
    final radius = widget.height * 0.3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _hold(true),
      onTapUp: (_) => _hold(false),
      onTapCancel: () => _hold(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _held ? 0.965 : 1,
        duration: const Duration(milliseconds: 80),
        child: Opacity(
          opacity: idle ? 0.45 : 1,
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [shell.crown, shell.base],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: shell.rim, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _held ? 0.22 : 0.38),
                  blurRadius: _held ? 4 : 10,
                  offset: Offset(0, _held ? 2 : 5),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Sheen across the upper half, which is what sells the moulding.
                Positioned(
                  top: 3,
                  left: 8,
                  right: 8,
                  height: widget.height * 0.4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius * 0.8),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon,
                          size: widget.fontSize + 3, color: Colors.white),
                      const SizedBox(width: 7),
                    ],
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Type.label(
                              size: widget.fontSize,
                              color: Colors.white,
                              tracking: 0.8,
                            ).copyWith(
                              shadows: [
                                Shadow(color: shell.rim, offset: const Offset(0, 1.4)),
                              ],
                            ),
                          ),
                          if (widget.sublabel != null)
                            Text(
                              widget.sublabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Type.body(
                                size: widget.fontSize * 0.62,
                                color: Colors.white.withValues(alpha: 0.94),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
