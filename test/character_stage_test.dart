import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sippy/overlay/character_stage.dart';

void main() {
  testWidgets('shows message and fires callbacks', (tester) async {
    var drank = 0, snoozed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CharacterStage(
          message: 'Have you drank water?',
          onDrank: () => drank++,
          onSnooze: () => snoozed++,
        ),
      ),
    ));

    // Let the walk/sip sequence complete. Advance in explicit pump() steps
    // rather than relying solely on pumpAndSettle(), since SpriteAnimator
    // keeps a Timer.periodic running (for frame cycling) which never
    // "settles" and would make pumpAndSettle() time out.
    //
    // We pump slightly *past* the 3s walk-animation duration (3050ms, not
    // exactly 3000ms). Pumping exactly the controller's duration can land
    // its internal elapsed-time computation a hair under the threshold
    // (double precision on the microseconds->seconds conversion), so
    // AnimationStatus never flips to `completed` and the sip/prompt sequence
    // never starts. A small overshoot avoids that boundary case reliably.
    //
    // The following pump(1300ms) then advances past the 1.2s sip-delay
    // Timer inside CharacterStage, which is enough for it to fire and flip
    // `_showPrompt` to true, revealing the bubble and buttons.
    await tester.pump(); // build, start walk animation
    await tester.pump(const Duration(
        seconds: 3, milliseconds: 50)); // finish walk -> sipping
    await tester
        .pump(const Duration(milliseconds: 1300)); // sip delay -> prompt

    expect(find.text('Have you drank water?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('drank-button')));
    await tester.tap(find.byKey(const Key('snooze-button')));
    expect(drank, equals(1));
    expect(snoozed, equals(1));
  });
}
