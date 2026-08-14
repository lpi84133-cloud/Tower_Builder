import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/asset_paths.dart';
import 'architect.dart';

/// Which looping bed should be playing.
enum Bed { shell, site }

/// Central mixer: one looping player for the bed plus disposable players for
/// overlapping one-shots. Volume and mute follow [Architect] live, and the bed
/// is parked whenever the app leaves the foreground.
///
/// Every call is failure-tolerant: if the platform has no working audio backend
/// the game keeps running silently rather than throwing mid-round.
class AudioDesk with WidgetsBindingObserver {
  AudioDesk(this._architect);

  final Architect _architect;
  final AudioPlayer _bedPlayer = AudioPlayer(playerId: 'tb.bed');

  Bed? _bed;
  bool _foreground = true;
  bool _ready = false;

  Future<void> boot() async {
    final context = AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
    );
    try {
      await AudioPlayer.global.setAudioContext(context);
      await _bedPlayer.setAudioContext(context);
      await _bedPlayer.setReleaseMode(ReleaseMode.loop);
      await _bedPlayer.setVolume(_architect.musicLevel);
      _ready = true;
    } catch (error) {
      debugPrint('AudioDesk: no audio backend ($error)');
    }
    _architect.addListener(_syncWithPreferences);
    WidgetsBinding.instance.addObserver(this);
  }

  void _syncWithPreferences() {
    if (!_ready) return;
    if (_architect.musicOn && _foreground) {
      _bedPlayer.setVolume(_architect.musicLevel);
      if (_bed != null && _bedPlayer.state != PlayerState.playing) {
        _bedPlayer.resume();
      }
    } else {
      _bedPlayer.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (!_ready) return;
    if (!foreground) {
      _bedPlayer.pause();
    } else if (_architect.musicOn && _bed != null) {
      _bedPlayer.resume();
    }
  }

  String _bedSource(Bed bed) => bed == Bed.shell ? Cue.bedShell : Cue.bedSite;

  /// Switch the looping bed. No-op when the requested bed is already running.
  Future<void> playBed(Bed bed) async {
    if (_bed == bed && _bedPlayer.state == PlayerState.playing) return;
    _bed = bed;
    if (!_ready || !_architect.musicOn || !_foreground) return;
    try {
      await _bedPlayer.stop();
      await _bedPlayer.setVolume(_architect.musicLevel);
      await _bedPlayer.play(AssetSource(_bedSource(bed)));
    } catch (error) {
      debugPrint('AudioDesk: bed failed ($error)');
    }
  }

  Future<void> stopBed() async {
    _bed = null;
    try {
      await _bedPlayer.stop();
    } catch (_) {}
  }

  /// Fire a one-shot from the [Cue] table.
  Future<void> shot(String source) async {
    if (!_ready || !_architect.soundOn) return;
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(_architect.soundLevel);
      await player.play(AssetSource(source));
      player.onPlayerComplete.first.then((_) => player.dispose());
    } catch (error) {
      debugPrint('AudioDesk: shot failed ($error)');
      player.dispose();
    }
  }

  Future<void> buzz({bool heavy = false}) async {
    if (!_architect.hapticsOn) return;
    if (heavy) {
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.selectionClick();
    }
  }

  void shutDown() {
    _architect.removeListener(_syncWithPreferences);
    WidgetsBinding.instance.removeObserver(this);
    _bedPlayer.dispose();
  }
}
