import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'run_director.dart';
import 'site_entities.dart';
import 'site_metrics.dart';
import 'sprite_bank.dart';

/// Draws the whole build site from [RunDirector] state. Works in site units
/// (Y down, tower up) projected through a vertical camera, and repaints off the
/// director's own [ChangeNotifier].
class SiteCanvas extends CustomPainter {
  SiteCanvas({
    required this.director,
    required this.zenith,
    required this.horizon,
  }) : super(repaint: director);

  final RunDirector director;
  final Color zenith;
  final Color horizon;

  final SpriteBank _bank = SpriteBank.shared;
  final math.Random _jitter = math.Random();

  late double _unit; // pixels per site unit
  late double _camera;
  late double _midY;
  late Size _canvas;
  Offset _joltOffset = Offset.zero;

  /// Site space -> canvas space.
  Offset _project(double sx, double sy) => Offset(
        _canvas.width / 2 + sx * _unit + _joltOffset.dx,
        _midY + (sy - _camera) * _unit + _joltOffset.dy,
      );

  @override
  void paint(Canvas canvas, Size size) {
    if (!_bank.isReady) return;
    _canvas = size;
    _unit = size.width / SiteMetrics.siteWidth;
    _camera = director.cameraY;
    _midY = size.height * 0.5;

    final jolt = director.jolt;
    _joltOffset = jolt > 0
        ? Offset(_jitter.nextDouble() - 0.5, _jitter.nextDouble() - 0.5) *
            jolt *
            _unit *
            0.5
        : Offset.zero;

    _sky(canvas, size);
    _clouds(canvas, size);
    _skyline(canvas);
    _ground(canvas);
    _pad(canvas);
    _stack(canvas);
    _cargo(canvas);
    _crane(canvas);
    _motes(canvas);
    _callouts(canvas);
  }

  void _sky(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          [zenith, horizon],
        ),
    );
  }

  void _clouds(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Colors.white.withValues(alpha: 0.92);
    final deck = [_bank.cloudA, _bank.cloudB, _bank.cloudA];
    // Clouds sink slowly as the camera climbs, selling the height gain.
    final parallax = -_camera * _unit * 0.1;
    for (var layer = 0; layer < deck.length; layer++) {
      final image = deck[layer];
      final width = size.width * (0.42 + layer * 0.08);
      final height = width * image.height / image.width;
      final speed = 0.5 + layer * 0.25;
      final span = size.width + width + 80;
      final x = (director.driftPhase * speed * size.width + layer * span * 0.41) %
              span -
          width;
      final y =
          size.height * (0.1 + layer * 0.18) + parallax * (0.4 + layer * 0.2);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(x, y, width, height),
        paint,
      );
    }
  }

  void _skyline(Canvas canvas) {
    final image = _bank.skylineStrip;
    const width = SiteMetrics.siteWidth * 1.06; // bleed past both edges
    final height = width * image.height / image.width;
    const bottom = SiteMetrics.groundLine;
    final topLeft = _project(-width / 2, bottom - height);
    final bottomRight = _project(width / 2, bottom);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTRB(topLeft.dx, topLeft.dy, bottomRight.dx, bottomRight.dy),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _ground(Canvas canvas) {
    final line = _project(-SiteMetrics.siteWidth, SiteMetrics.groundLine);
    final rect = Rect.fromLTRB(
        0, line.dy, _canvas.width, line.dy + _canvas.height * 2);
    if (rect.bottom < 0 || rect.top > _canvas.height) return;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, rect.top),
          Offset(0, rect.top + _canvas.height * 0.5),
          [const Color(0xFF5A4632), const Color(0xFF2E2114)],
        ),
    );
    // Poured-slab highlight along the very top of the ground.
    canvas.drawRect(
      Rect.fromLTWH(0, line.dy, _canvas.width, 3),
      Paint()..color = const Color(0xFF6E573E),
    );
  }

  void _pad(Canvas canvas) {
    final image = _bank.foundationPad;
    final top = SiteMetrics.padTop;
    final topLeft = _project(-SiteMetrics.padWidth / 2, top);
    final bottomRight =
        _project(SiteMetrics.padWidth / 2, SiteMetrics.groundLine);

    // Warm wash behind the pad so the base reads as lit, not cut out.
    final glowAt = _project(0, top + SiteMetrics.padHeight * 0.4);
    final glowRadius = SiteMetrics.padWidth * _unit * 0.64;
    canvas.drawCircle(
      glowAt,
      glowRadius,
      Paint()
        ..shader = ui.Gradient.radial(glowAt, glowRadius, const [
          Color(0x66FFE9A8),
          Color(0x00FFE9A8),
        ]),
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTRB(topLeft.dx, topLeft.dy, bottomRight.dx, bottomRight.dy),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _stack(Canvas canvas) {
    for (final storey in director.stack) {
      _module(
        canvas,
        storey.facade,
        storey.centreX,
        storey.centreY,
        storey.width,
        storey.height,
        storey.seatTilt + storey.wobble,
      );
    }
  }

  void _cargo(Canvas canvas) {
    final cargo = director.cargo;
    if (cargo == null) return;
    _module(canvas, cargo.facade, cargo.x, cargo.y, cargo.width, cargo.height,
        cargo.spin);
  }

  void _crane(Canvas canvas) {
    // The rig stays visible during the fall too, so the empty hook can be seen
    // reeling up and away while the module drops.
    final loaded = director.isLoaded;
    final falling = director.phase == RunPhase.falling;
    if (!loaded && !falling) return;

    final hook = _bank.craneHook;
    final angle = director.swingAngle; // position uses +sin(angle)
    final tilt = -angle; // drawn lean, hanging back toward the pivot

    final pivot = _project(0, director.pivotY); // off the top of the screen
    final hookTip = _project(director.hookTipX, director.hookTipY);

    final imageW = hook.width.toDouble();
    final imageH = hook.height.toDouble();
    const hardwareFraction = SiteMetrics.hookHardwareFraction;
    final hardwareH = SiteMetrics.hookHardwareHeight * _unit;
    final hardwareW = hardwareH * (imageW / (hardwareFraction * imageH));
    final reachPx = director.hookReach * _unit;

    // Cable plus hook hardware, drawn in a frame rotated about the off-screen
    // pivot so "down" follows the cable. Because the cable is anchored at the
    // fixed pivot and only rotates and reels, the length showing below the top
    // edge grows through the bottom of the swing and shrinks at the extremes.
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(tilt);
    canvas.drawImageRect(
      hook,
      Rect.fromLTRB(0, 0, imageW, (1 - hardwareFraction) * imageH),
      Rect.fromLTRB(-hardwareW / 2, -_canvas.height, hardwareW / 2,
          reachPx - hardwareH),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.drawImageRect(
      hook,
      Rect.fromLTRB(0, (1 - hardwareFraction) * imageH, imageW, imageH),
      Rect.fromCenter(
        center: Offset(0, reachPx - hardwareH / 2),
        width: hardwareW,
        height: hardwareH,
      ),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    if (!loaded) return;

    // Slings from the hook tip to the module's top corners, then the module on
    // top so it covers the attachment points.
    final height = director.facadeHeight;
    final widthPx = SiteMetrics.moduleWidth * _unit;
    final heightPx = height * _unit;
    final hangAt = _project(director.cargoHangX, director.cargoHangY);
    final cos = math.cos(tilt);
    final sin = math.sin(tilt);

    Offset corner(double localX) {
      final localY = -heightPx / 2;
      return hangAt +
          Offset(localX * cos - localY * sin, localX * sin + localY * cos);
    }

    final sling = Paint()
      ..color = const Color(0xFF1B2330)
      ..strokeWidth = math.max(2, 0.05 * _unit)
      ..strokeCap = StrokeCap.round;
    // Set in far enough that the slings land on the facade itself, including the
    // hex module whose top edge is narrower than its footprint.
    final grip = widthPx / 2 - widthPx * 0.23;
    canvas.drawLine(hookTip, corner(-grip), sling);
    canvas.drawLine(hookTip, corner(grip), sling);

    _module(canvas, director.facade, director.cargoHangX, director.cargoHangY,
        SiteMetrics.moduleWidth, height, tilt);
  }

  void _motes(Canvas canvas) {
    for (final mote in director.motes) {
      final t = (mote.life / mote.fullLife).clamp(0.0, 1.0);
      final radius = mote.size * _unit * (mote.shrinks ? t : 1.0);
      if (radius <= 0) continue;
      final paint = Paint()
        ..color = mote.colour
            .withValues(alpha: (mote.soft ? t * 0.85 : t).clamp(0.0, 1.0));
      if (mote.soft) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.5);
      }
      canvas.drawCircle(_project(mote.x, mote.y), radius, paint);
    }
  }

  void _callouts(Canvas canvas) {
    for (final callout in director.callouts) {
      final t = callout.life.clamp(0.0, 1.0);
      final at = _project(callout.x, callout.y);
      final painter = TextPainter(
        text: TextSpan(
          text: callout.text,
          style: TextStyle(
            fontFamily: 'SiteDisplay',
            fontSize: math.max(13, 0.62 * _unit),
            color: callout.colour.withValues(alpha: t),
            shadows: const [
              Shadow(blurRadius: 5, color: Colors.black54, offset: Offset(1, 1)),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
          canvas, Offset(at.dx - painter.width / 2, at.dy - painter.height / 2));
    }
  }

  void _module(
    Canvas canvas,
    int facade,
    double centreX,
    double centreY,
    double widthUnits,
    double heightUnits,
    double tilt,
  ) {
    final image = _bank.facade(facade);
    final at = _project(centreX, centreY);
    final width = widthUnits * _unit;
    final height = heightUnits * _unit;

    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (tilt != 0) canvas.rotate(tilt);
    // Contact shadow under each module for a little depth on the seam.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, height * 0.42),
          width: width * 0.92,
          height: height * 0.18,
        ),
        Radius.circular(height * 0.09),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(
          center: Offset.zero, width: width, height: height),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SiteCanvas old) =>
      old.zenith != zenith || old.horizon != horizon;
}
