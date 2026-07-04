// Basic widget test for the Task 2 overlay POC.
//
// The old counter-app smoke test was tied to `MyApp`, which was replaced by
// the transparent overlay POC (`PocApp` + `SlidingBox`) as part of Task 2.
// This test just verifies the POC widget tree builds and renders the
// sliding box without needing a real native window (window configuration
// happens in `main()`, not in the widget tree).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sippy/main.dart';

void main() {
  testWidgets('PocApp renders the sliding teal box', (WidgetTester tester) async {
    await tester.pumpWidget(const PocApp());

    expect(find.byType(SlidingBox), findsOneWidget);

    final container = tester.widget<Container>(find.byType(Container));
    expect(container.color, Colors.teal);
  });
}
