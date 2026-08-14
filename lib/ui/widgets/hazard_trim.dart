import 'package:flutter/material.dart';

/// Warning-tape trim that closes off the site chrome, top and bottom.
class HazardTrim extends StatelessWidget {
  const HazardTrim({super.key, this.height = 6});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TapePainter()),
    );
  }
}

class _TapePainter extends CustomPainter {
  static const _bar = 14.0; // dark bar width; the gold gap matches it
  static const _gold = Color(0xFFF4B41A);
  static const _dark = Color(0xFF222226);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _gold);
    final bar = Paint()..color = _dark;
    for (var x = -size.height; x < size.width + size.height; x += _bar * 2) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + _bar, 0)
          ..lineTo(x + _bar - size.height, size.height)
          ..lineTo(x - size.height, size.height)
          ..close(),
        bar,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TapePainter oldDelegate) => false;
}
