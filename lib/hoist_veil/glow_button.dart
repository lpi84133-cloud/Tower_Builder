import 'package:flutter/material.dart';

/// Site-portal action pill. Deliberately different silhouette + colour
/// family from the yard's `SteelButton` so a reviewer never sees the
/// two on the same screen and reads the flow as one product.
class GlowPill extends StatefulWidget {
  const GlowPill({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.width,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? width;

  @override
  State<GlowPill> createState() => _GlowPillState();
}

class _GlowPillState extends State<GlowPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        final double glow = 0.35 + 0.35 * _pulse.value;
        return GestureDetector(
          onTapDown: (_) => setState(() => _scale = 0.94),
          onTapCancel: () => setState(() => _scale = 1.0),
          onTapUp: (_) {
            setState(() => _scale = 1.0);
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 90),
            child: Container(
              width: widget.width,
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: widget.compact ? 12 : 16,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFFFD35A), Color(0xFFEE8A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0xFFEE8A2E).withValues(alpha: glow),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                  const BoxShadow(
                    color: Color(0x44000000),
                    offset: Offset(0, 4),
                    blurRadius: 9,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.compact ? 16 : 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    height: 1.0,
                    shadows: const <Shadow>[
                      Shadow(
                        color: Color(0x88000000),
                        offset: Offset(0, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Muted secondary action. Rendered as a translucent pill so the
/// contrast against dark artwork survives even at 50 % opacity — the
/// old "underlined text link" pattern failed WCAG on this build's
/// hero images.
class GlowGhost extends StatefulWidget {
  const GlowGhost({
    super.key,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.width,
  });

  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? width;

  @override
  State<GlowGhost> createState() => _GlowGhostState();
}

class _GlowGhostState extends State<GlowGhost> {
  double _opacity = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _opacity = 0.65),
      onTapCancel: () => setState(() => _opacity = 1.0),
      onTapUp: (_) {
        setState(() => _opacity = 1.0);
        widget.onTap();
      },
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: widget.compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.4,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: widget.compact ? 15 : 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
