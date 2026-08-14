import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import '../app/asset_paths.dart';
import 'site_metrics.dart';

/// Decodes the playfield sprites once, up front, so the renderer can draw
/// synchronously on every frame. Also caches each facade's clamped aspect ratio,
/// which is what determines a module's drawn height.
class SpriteBank {
  SpriteBank._();

  static final SpriteBank shared = SpriteBank._();

  final Map<String, ui.Image> _decoded = {};
  final Map<int, double> _facadeAspect = {};
  bool _ready = false;
  Future<void>? _inFlight;

  bool get isReady => _ready;

  ui.Image get skylineStrip => _decoded[Art.skylineStrip]!;
  ui.Image get foundationPad => _decoded[Art.foundationPad]!;
  ui.Image get craneHook => _decoded[Art.craneHook]!;
  ui.Image get cloudA => _decoded[Art.cloudA]!;
  ui.Image get cloudB => _decoded[Art.cloudB]!;

  ui.Image facade(int index) => _decoded[Art.module(index)]!;

  /// Drawn height, in site units, of facade [index].
  double moduleHeight(int index) =>
      SiteMetrics.moduleWidth * (_facadeAspect[index] ?? 1.0);

  /// Idempotent and safe to await from several call sites at once.
  Future<void> warmUp() {
    if (_ready) return Future.value();
    return _inFlight ??= _load();
  }

  Future<void> _load() async {
    const manifest = <String>[
      Art.skylineStrip,
      Art.foundationPad,
      Art.craneHook,
      Art.cloudA,
      Art.cloudB,
    ];
    for (final path in [...manifest, ...Art.allModules]) {
      _decoded[path] = await _decode(path);
    }
    for (var index = 1; index <= Art.moduleCount; index++) {
      final image = _decoded[Art.module(index)]!;
      _facadeAspect[index] = (image.height / image.width).clamp(
        SiteMetrics.minModuleAspect,
        SiteMetrics.maxModuleAspect,
      );
    }
    _ready = true;
    _inFlight = null;
  }

  static Future<ui.Image> _decode(String path) async {
    final bytes = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
