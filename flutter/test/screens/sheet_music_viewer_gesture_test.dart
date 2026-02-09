import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borge/screens/sheet_music_viewer_screen.dart';
import 'package:borge/state/app_state.dart';
import 'package:borge/models/models.dart' as models;

void main() {
  group('SheetMusicViewerScreen Gesture Handling', () {
    late AppState appState;
    late models.Song testSong;

    setUp(() {
      appState = AppState();
      
      // Create a test song with a MusicXML page
      final testPage = models.Page(
        path: '/test/song.musicxml',
        pageNumber: 1,
        extension: '.musicxml',
      );
      testSong = models.Song(
        id: 'test-song',
        name: 'Test Song',
        pages: [testPage],
      );
      
      // Select the song in AppState
      appState.selectSong(testSong);
    });

    testWidgets('GestureDetector has active handlers in default mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Find the GestureDetector that wraps the Stack (the main one for navigation)
      final gestureDetectors = find.byType(GestureDetector);
      expect(gestureDetectors, findsWidgets);
      
      // Find the one with Stack as child
      final gestureDetector = tester.widgetList<GestureDetector>(gestureDetectors)
          .firstWhere((gd) => gd.child is Stack);

      // Verify handlers are not null in default mode
      expect(gestureDetector.onTapUp, isNotNull);
      expect(gestureDetector.onHorizontalDragEnd, isNotNull);
    });

    testWidgets('GestureDetector handlers become null in annotation mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Verify initial state - find the GestureDetector that wraps Stack
      var gestureDetectors = find.byType(GestureDetector);
      var gestureDetector = tester.widgetList<GestureDetector>(gestureDetectors)
          .firstWhere((gd) => gd.child is Stack);
      expect(gestureDetector.onTapUp, isNotNull);
      expect(gestureDetector.onHorizontalDragEnd, isNotNull);

      // Find and tap the draw button (Icons.draw_outlined when off)
      final drawButton = find.byIcon(Icons.draw_outlined);
      expect(drawButton, findsOneWidget);
      await tester.tap(drawButton);
      await tester.pump();

      // Find the GestureDetector again after state change
      gestureDetectors = find.byType(GestureDetector);
      gestureDetector = tester.widgetList<GestureDetector>(gestureDetectors)
          .firstWhere((gd) => gd.child is Stack);

      // Verify handlers are now null
      expect(gestureDetector.onTapUp, isNull);
      expect(gestureDetector.onHorizontalDragEnd, isNull);

      // Verify the icon changed to Icons.draw (on state)
      expect(find.byIcon(Icons.draw), findsOneWidget);
      expect(find.byIcon(Icons.draw_outlined), findsNothing);
    });

    testWidgets('GestureDetector handlers are restored when annotation mode is toggled off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Turn annotation mode ON
      await tester.tap(find.byIcon(Icons.draw_outlined));
      await tester.pump();

      // Verify handlers are null
      var gestureDetectors = find.byType(GestureDetector);
      var gestureDetector = tester.widgetList<GestureDetector>(gestureDetectors)
          .firstWhere((gd) => gd.child is Stack);
      expect(gestureDetector.onTapUp, isNull);
      expect(gestureDetector.onHorizontalDragEnd, isNull);

      // Turn annotation mode OFF
      await tester.tap(find.byIcon(Icons.draw));
      await tester.pump();

      // Find the GestureDetector again
      gestureDetectors = find.byType(GestureDetector);
      gestureDetector = tester.widgetList<GestureDetector>(gestureDetectors)
          .firstWhere((gd) => gd.child is Stack);

      // Verify handlers are restored
      expect(gestureDetector.onTapUp, isNotNull);
      expect(gestureDetector.onHorizontalDragEnd, isNotNull);

      // Verify icon is back to outlined
      expect(find.byIcon(Icons.draw_outlined), findsOneWidget);
      expect(find.byIcon(Icons.draw), findsNothing);
    });
  });
}
