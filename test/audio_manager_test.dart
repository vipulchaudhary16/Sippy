import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/audio/audio_manager.dart';

void main() {
  test('does not play when muted', () async {
    final fake = FakeAudioSink();
    final mgr = AudioManager.withSink(fake);
    await mgr.play(['/a.mp3'], volume: 0.5, muted: true);
    expect(fake.playing, isFalse);
  });

  test('does not play when no paths', () async {
    final fake = FakeAudioSink();
    final mgr = AudioManager.withSink(fake);
    await mgr.play([], volume: 0.5, muted: false);
    expect(fake.playing, isFalse);
  });

  test('plays first path at given volume', () async {
    final fake = FakeAudioSink();
    final mgr = AudioManager.withSink(fake);
    await mgr.play(['/a.mp3', '/b.mp3'], volume: 0.3, muted: false);
    expect(fake.playing, isTrue);
    expect(fake.lastPath, equals('/a.mp3'));
    expect(fake.volume, equals(0.3));
  });
}
