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

  test('setMuted(true) then setMuted(false) restores the prior volume',
      () async {
    final fake = FakeAudioSink();
    final mgr = AudioManager.withSink(fake);
    await mgr.play(['/a.mp3'], volume: 0.7, muted: false);
    expect(fake.volume, equals(0.7));
    await mgr.setMuted(true);
    expect(fake.volume, equals(0.0));
    await mgr.setMuted(false);
    expect(fake.volume, equals(0.7));
  });

  test('setVolume updates the restore point used by unmute', () async {
    final fake = FakeAudioSink();
    final mgr = AudioManager.withSink(fake);
    await mgr.setVolume(0.4);
    expect(fake.volume, equals(0.4));
    await mgr.setMuted(true);
    await mgr.setMuted(false);
    expect(fake.volume, equals(0.4));
  });
}
