import 'package:flutter/material.dart';

import '../../app/palette.dart';

/// Shared background for every shell screen: a navy wash under a faint drafting
/// grid, with a soft glow behind the middle. Painted rather than sprited so it
/// costs nothing in the bundle and adapts to any screen size.
class BlueprintBackdrop extends StatelessWidget {
  const BlueprintBackdrop({super.key, required this.child, this.glow = true});

  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Hue.shellWash),
      child: CustomPaint(
        painter: _GridPainter(glow: glow),
        child: child,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.glow});

  final bool glow;

  static const _cell = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (glow) {
      final centre = Offset(size.width * 0.5, size.height * 0.34);
      final radius = size.longestSide * 0.55;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [Hue.cyan.withValues(alpha: 0.13), Hue.cyan.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    final thin = Paint()
      ..color = Hue.grid
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += _cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), thin);
    }
    for (var y = 0.0; y < size.height; y += _cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), thin);
    }

    // Every fifth line reads a touch stronger, like a drafting sheet.
    final bold = Paint()
      ..color = Hue.cyan.withValues(alpha: 0.09)
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += _cell * 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), bold);
    }
    for (var y = 0.0; y < size.height; y += _cell * 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), bold);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.glow != glow;
}
