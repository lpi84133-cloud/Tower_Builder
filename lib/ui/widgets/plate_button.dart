import 'package:flutter/material.dart';

import '../../app/asset_paths.dart';
import '../../app/type_scale.dart';

/// The site's primary action, drawn on the warning-tape plate sprite.
///
/// The artwork carries no lettering, so it is stretched to whatever width the
/// deck gives it and the caption is drawn on top — that way the label never
/// skews with the plate.
class PlateButton extends StatefulWidget {
  const PlateButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 68,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  State<PlateButton> createState() => _PlateButtonState();
}

class _PlateButtonState extends State<PlateButton> {
  bool _held = false;

  void _hold(bool value) {
    if (widget.onPressed == null || _held == value) return;
    setState(() => _held = value);
  }

  @override
  Widget build(BuildContext context) {
    final idle = widget.onPressed == null;
    final fontSize = (widget.height * 0.4).clamp(17.0, 29.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _hold(true),
      onTapUp: (_) => _hold(false),
      onTapCancel: () => _hold(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _held ? 0.975 : 1,
        duration: const Duration(milliseconds: 80),
        child: Opacity(
          opacity: idle ? 0.5 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _held ? 0.24 : 0.42),
                  blurRadius: _held ? 4 : 11,
                  offset: Offset(0, _held ? 2 : 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(Art.plateBlank, fit: BoxFit.fill),
                    Center(
                      child: Text(
                        widget.label,
                        style: Type.slab(size: fontSize, color: Colors.white)
                            .copyWith(
                          letterSpacing: 2.4,
                          shadows: const [
                            Shadow(
                              color: Color(0xCC4A3300),
                              offset: Offset(0, 2),
                              blurRadius: 2,
                            ),
                            Shadow(color: Color(0x66000000), blurRadius: 5),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
