import 'package:audioplayers/audioplayers.dart';

/// Minimal audio interface so logic is testable without platform channels.
abstract class AudioSink {
  Future<void> loop(String path, double volume);
  Future<void> stop();
  Future<void> setVolume(double v);
}

class _RealSink implements AudioSink {
  final AudioPlayer _player;
  _RealSink(this._player);

  @override
  Future<void> loop(String path, double volume) async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(volume);
    await _player.play(DeviceFileSource(path));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double v) => _player.setVolume(v);
}

class FakeAudioSink implements AudioSink {
  bool playing = false;
  String? lastPath;
  double volume = 0;

  @override
  Future<void> loop(String path, double v) async {
    playing = true;
    lastPath = path;
    volume = v;
  }

  @override
  Future<void> stop() async => playing = false;

  @override
  Future<void> setVolume(double v) async => volume = v;
}

class AudioManager {
  final AudioSink _sink;
  double _currentVolume = 1.0;

  AudioManager({AudioPlayer? player})
      : _sink = _RealSink(player ?? AudioPlayer());
  AudioManager.withSink(this._sink);

  Future<void> play(List<String> paths,
      {required double volume, required bool muted}) async {
    if (muted || paths.isEmpty) return;
    _currentVolume = volume;
    await _sink.loop(paths.first, volume);
  }

  Future<void> stop() => _sink.stop();
  Future<void> setVolume(double v) {
    _currentVolume = v;
    return _sink.setVolume(v);
  }

  Future<void> setMuted(bool m) => _sink.setVolume(m ? 0 : _currentVolume);
}
