import 'package:flutter_test/flutter_test.dart';

import 'package:borge/main.dart';

void main() {
  testWidgets('App launches and shows song list', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BorgeApp());

    // Verify that the app bar shows the title.
    expect(find.text('Sheet Music'), findsOneWidget);

    // Verify that we see the empty state message.
    expect(find.text('No sheet music found'), findsOneWidget);

    // Verify the demo button exists.
    expect(find.text('Load Demo Songs'), findsOneWidget);
  });
}
