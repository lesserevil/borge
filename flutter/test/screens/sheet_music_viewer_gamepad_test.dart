import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:borge/screens/sheet_music_viewer_screen.dart';
import 'package:borge/state/app_state.dart';
import 'package:borge/models/models.dart' as models;

void main() {
  group('SheetMusicViewerScreen Gamepad Input', () {
    late AppState appState;
    late models.Song testSong;

    setUp(() {
      appState = AppState();
      
      // Create a test song with 3 MusicXML pages for navigation boundary tests
      final testPages = [
        models.Page(
          path: '/test/song.musicxml',
          pageNumber: 1,
          extension: '.musicxml',
        ),
        models.Page(
          path: '/test/song.musicxml',
          pageNumber: 2,
          extension: '.musicxml',
        ),
        models.Page(
          path: '/test/song.musicxml',
          pageNumber: 3,
          extension: '.musicxml',
        ),
      ];
      testSong = models.Song(
        id: 'test-song',
        name: 'Test Song',
        pages: testPages,
      );
      
      // Select the song in AppState
      appState.selectSong(testSong);
    });

    testWidgets('R1 (gameButtonRight1) navigates to next page', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Verify starting at page 0
      expect(appState.currentPageIndex, 0);

      // Simulate R1 button press
      await simulateKeyDownEvent(LogicalKeyboardKey.gameButtonRight1);
      await tester.pump();

      // Verify navigation to next page
      expect(appState.currentPageIndex, 1);
    });

    testWidgets('L1 (gameButtonLeft1) navigates to previous page', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Navigate to page 1 first
      appState.nextPage();
      expect(appState.currentPageIndex, 1);

      // Simulate L1 button press
      await simulateKeyDownEvent(LogicalKeyboardKey.gameButtonLeft1);
      await tester.pump();

      // Verify navigation to previous page
      expect(appState.currentPageIndex, 0);
    });

    testWidgets('R1 at last page does not go beyond', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Navigate to last page (page 2 for 3-page song)
      appState.goToPage(2);
      expect(appState.currentPageIndex, 2);

      // Simulate R1 button press
      await simulateKeyDownEvent(LogicalKeyboardKey.gameButtonRight1);
      await tester.pump();

      // Verify page index unchanged
      expect(appState.currentPageIndex, 2);
    });

    testWidgets('L1 at first page does not go below zero', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Verify starting at page 0
      expect(appState.currentPageIndex, 0);

      // Simulate L1 button press
      await simulateKeyDownEvent(LogicalKeyboardKey.gameButtonLeft1);
      await tester.pump();

      // Verify page index unchanged
      expect(appState.currentPageIndex, 0);
    });

    testWidgets('R2 (gameButtonRight2) zooms in by 0.1', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Record initial zoom (default is 0.4)
      expect(appState.zoom, 0.4);

      // Simulate R2 button press
      await simulateKeyDownEvent(LogicalKeyboardKey.gameButtonRight2);
      await tester.pump();

      // Verify zoom increased by 0.1
      expect(appState.zoom, closeTo(0.5, 0.01));
    });

    testWidgets('L2 (gameButtonLeft2) zooms out by 0.1', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Set zoom to 1.0 first
      appState.zoom = 1.0;

      // Simulate L2 button press
      await simulateKeyDownEvent(LogicalKeyboardKey.gameButtonLeft2);
      await tester.pump();

      // Verify zoom decreased by 0.1
      expect(appState.zoom, closeTo(0.9, 0.01));
    });

    testWidgets('R2 at max zoom (3.0) does not exceed max', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Set zoom to max (3.0)
      appState.zoom = 3.0;

      // Simulate R2 button press
      await simulateKeyDownEvent(LogicalKeyboardKey.gameButtonRight2);
      await tester.pump();

      // Verify zoom unchanged
      expect(appState.zoom, 3.0);
    });

    testWidgets('L2 at min zoom (0.4) does not go below min', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SheetMusicViewerScreen(appState: appState),
        ),
      );

      // Verify starting at min zoom (0.4)
      expect(appState.zoom, 0.4);

      // Simulate L2 button press
      await simulateKeyDownEvent(LogicalKeyboardKey.gameButtonLeft2);
      await tester.pump();

      // Verify zoom unchanged
      expect(appState.zoom, 0.4);
    });
  });
}
