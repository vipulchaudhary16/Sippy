import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/overlay/sprite_animator.dart';

void main() {
  test('every CharacterState has at least one frame', () {
    for (final state in CharacterState.values) {
      expect(SpriteFrames.frames[state], isNotNull);
      expect(SpriteFrames.frames[state]!.isNotEmpty, isTrue);
    }
  });

  test('walking has multiple frames for a cycle', () {
    expect(SpriteFrames.frames[CharacterState.walking]!.length,
        greaterThan(1));
  });
}
