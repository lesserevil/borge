import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

/// Service for managing Google Drive authentication
class GoogleDriveAuthService {
  static const _driveScopes = [
    'https://www.googleapis.com/auth/drive.readonly',
    'email',
    'profile',
  ];

  GoogleSignIn? _googleSignIn;
  GoogleSignInAccount? _currentUser;

  /// Whether the user is currently signed in
  bool get isSignedIn => _currentUser != null;

  /// Current signed-in user
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Email of the current user
  String? get userEmail => _currentUser?.email;

  /// Display name of the current user
  String? get userDisplayName => _currentUser?.displayName;

  /// Initialize the Google Sign-In service
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('Google Drive not supported on web');
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('Google Drive only supported on Android and iOS');
      return;
    }

    _googleSignIn = GoogleSignIn(
      scopes: _driveScopes,
    );

    // Listen to sign-in state changes
    _googleSignIn!.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      debugPrint('Google Sign-In state changed: ${account?.email ?? "signed out"}');
    });

    // Try to sign in silently
    try {
      final account = await _googleSignIn!.signInSilently();
      _currentUser = account;
      if (account != null) {
        debugPrint('Silently signed in as: ${account.email}');
      }
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
    }
  }

  /// Sign in to Google Drive
  /// Returns true if sign-in was successful
  Future<bool> signIn() async {
    if (_googleSignIn == null) {
      debugPrint('Google Sign-In not initialized');
      return false;
    }

    try {
      final account = await _googleSignIn!.signIn();
      _currentUser = account;
      
      if (account != null) {
        debugPrint('Signed in as: ${account.email}');
        return true;
      }
      
      debugPrint('Sign-in cancelled by user');
      return false;
    } catch (e) {
      debugPrint('Sign-in error: $e');
      return false;
    }
  }

  /// Sign out from Google Drive
  Future<void> signOut() async {
    if (_googleSignIn == null) return;

    try {
      await _googleSignIn!.signOut();
      _currentUser = null;
      debugPrint('Signed out from Google Drive');
    } catch (e) {
      debugPrint('Sign-out error: $e');
    }
  }

  /// Get authenticated HTTP client for Drive API calls
  /// Returns null if not signed in
  Future<auth.AuthClient?> getAuthenticatedClient() async {
    if (_googleSignIn == null || _currentUser == null) {
      debugPrint('Not signed in to Google');
      return null;
    }

    try {
      final authHeaders = await _currentUser!.authHeaders;
      final accessToken = auth.AccessToken(
        'Bearer',
        authHeaders['Authorization']!.substring('Bearer '.length),
        DateTime.now().add(const Duration(hours: 1)).toUtc(),
      );

      // Alternative: Use the extension method
      return await _googleSignIn!.authenticatedClient();
    } catch (e) {
      debugPrint('Error getting authenticated client: $e');
      return null;
    }
  }

  /// Disconnect the account (revoke access)
  Future<void> disconnect() async {
    if (_googleSignIn == null) return;

    try {
      await _googleSignIn!.disconnect();
      _currentUser = null;
      debugPrint('Disconnected from Google Drive');
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  /// Check if the user has granted the required permissions
  Future<bool> hasRequiredScopes() async {
    if (_googleSignIn == null || _currentUser == null) {
      return false;
    }

    try {
      final scopes = await _googleSignIn!.requestScopes(_driveScopes);
      return scopes;
    } catch (e) {
      debugPrint('Error checking scopes: $e');
      return false;
    }
  }
}
