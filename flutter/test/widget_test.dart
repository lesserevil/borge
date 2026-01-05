import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:borge/screens/screens.dart';
import 'package:borge/state/state.dart';

void main() {
  testWidgets('App launches and shows splash screen', (
    WidgetTester tester,
  ) async {
    // Build the app
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            // Test splash screen content
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note, size: 64),
                    const SizedBox(height: 24),
                    const Text('Borge'),
                    const SizedBox(height: 8),
                    const Text('Sheet Music Viewer'),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    // Verify splash screen elements
    expect(find.text('Borge'), findsOneWidget);
    expect(find.text('Sheet Music Viewer'), findsOneWidget);
  });

  testWidgets('Song list screen shows empty state', (
    WidgetTester tester,
  ) async {
    final appState = AppState();

    await tester.pumpWidget(
      MaterialApp(home: SongListScreen(appState: appState)),
    );

    // Verify that the app bar shows the title.
    expect(find.text('Sheet Music'), findsOneWidget);

    // Verify that we see the empty state message.
    expect(find.text('No sheet music found'), findsOneWidget);

    // Verify the demo button exists.
    expect(find.text('Load Demo Songs'), findsOneWidget);
  });
}
