import 'package:flutter/material.dart';

import '../../app/palette.dart';
import '../../app/type_scale.dart';

/// Visual weight of a [SteelButton].
enum SteelTone { primary, bank, caution, ghost }

/// The one button in the game. Drawn rather than sprited so it scales cleanly at
/// any density: a two-stop face, a lit top bevel, a darker skirt, and a pressed
/// state that sinks the whole plate by a pixel.
class SteelButton extends StatefulWidget {
  const SteelButton({
    super.key,
    required this.label,
    this.sublabel,
    this.icon,
    this.tone = SteelTone.primary,
    this.height = 58,
    this.fontSize = 17,
    this.expand = true,
    this.onPressed,
  });

  final String label;
  final String? sublabel;
  final IconData? icon;
  final SteelTone tone;
  final double height;
  final double fontSize;
  final bool expand;
  final VoidCallback? onPressed;

  bool get enabled => onPressed != null;

  @override
  State<SteelButton> createState() => _SteelButtonState();
}

class _SteelButtonState extends State<SteelButton> {
  bool _down = false;

  (Color, Color, Color) get _ramp {
    switch (widget.tone) {
      case SteelTone.primary:
        return (Hue.cyan, Hue.cyanDeep, Hue.chalk);
      case SteelTone.bank:
        return (Hue.amber, Hue.amberDeep, const Color(0xFF3A2402));
      case SteelTone.caution:
        return (Hue.rust, Hue.rustDeep, Hue.chalk);
      case SteelTone.ghost:
        return (Hue.slate, Hue.navy, Hue.chalkDim);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (face, skirt, text) = _ramp;
    final live = widget.enabled;
    final sunk = _down && live;

    return Semantics(
      button: true,
      enabled: live,
      label: widget.label,
      child: GestureDetector(
        onTapDown: live ? (_) => setState(() => _down = true) : null,
        onTapUp: live ? (_) => setState(() => _down = false) : null,
        onTapCancel: live ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: widget.expand ? double.infinity : null,
          height: widget.height,
          transform: Matrix4.translationValues(0, sunk ? 2 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: live
                  ? [Color.lerp(face, Colors.white, 0.16)!, skirt]
                  : [Hue.slate, Hue.navy],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: live
                  ? Color.lerp(face, Colors.white, 0.42)!
                  : Hue.cardEdge,
              width: 1.4,
            ),
            boxShadow: sunk || !live
                ? null
                : [
                    BoxShadow(
                      color: skirt.withValues(alpha: 0.55),
                      blurRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                    const BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    size: widget.fontSize + 3,
                    color: live ? text : Hue.chalkDim),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.label(
                        size: widget.fontSize,
                        color: live ? text : Hue.chalkDim,
                        tracking: 1.1,
                      ),
                    ),
                    if (widget.sublabel != null)
                      Text(
                        widget.sublabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.body(
                          size: widget.fontSize - 5,
                          color: (live ? text : Hue.chalkDim)
                              .withValues(alpha: 0.85),
                          weight: FontWeight.w600,
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
