# Google Drive Integration for Android

## Overview

This document outlines the implementation of Google Drive folder integration for the Borge music app on Android.

## Requirements

### Dependencies
- `googleapis` - Google APIs client library for Dart
- `googleapis_auth` - Authentication for Google APIs
- `google_sign_in` - Google Sign-In for Flutter
- `extension_google_sign_in_as_googleapis_auth` - Bridge between Google Sign-In and googleapis_auth

### Permissions
- Internet permission (for API calls)
- Google Drive OAuth2 scopes:
  - `https://www.googleapis.com/auth/drive.readonly` - Read-only access to Drive files
  - `https://www.googleapis.com/auth/drive.file` - Access to files created by this app

## Architecture

### 1. Google Drive Service (`google_drive_service.dart`)
This service handles:
- Authentication with Google Drive API
- Listing folders in Google Drive
- Downloading MusicXML files from Drive
- Caching Drive files locally
- Syncing changes when online

### 2. Storage Model
We'll store Google Drive folders alongside local folders with metadata:
```json
{
  "type": "local" | "google_drive",
  "path": "/local/path" or "drive://folder_id",
  "displayName": "Folder Name",
  "driveMetadata": {
    "folderId": "...",
    "folderName": "...",
    "lastSync": "ISO timestamp"
  }
}
```

### 3. User Flow

#### Adding a Google Drive Folder
1. User taps "Add Music Folder" in settings
2. New option appears: "Add from Google Drive"
3. User authenticates with Google (if not already)
4. Browse Drive folders in a dialog
5. Select folder(s) to add
6. App downloads/caches MusicXML files from selected folder
7. Folder appears in music folders list with a cloud icon

#### Syncing
- On app startup (if online)
- Manual refresh button in settings
- Background sync when folder is accessed

## Implementation Steps

### Phase 1: Dependencies & Authentication
1. Add required packages to `pubspec.yaml`
2. Configure Google OAuth credentials
3. Create `GoogleDriveAuthService` for sign-in/sign-out
4. Update settings screen with "Sign in to Google Drive" option

### Phase 2: Drive API Integration
1. Create `GoogleDriveService` with file listing/downloading
2. Implement local caching of Drive files
3. Add sync logic to detect changes

### Phase 3: UI Integration
1. Update `MusicLibraryService` to support multiple source types
2. Create Drive folder picker dialog
3. Add cloud icon/indicator for Drive folders
4. Add sync status indicators

### Phase 4: Offline Support
1. Implement local cache for Drive files
2. Handle offline access gracefully
3. Show sync status (synced, pending, offline)

## Technical Considerations

### Caching Strategy
- Download all MusicXML files from Drive folders to local cache
- Use Drive file IDs as cache keys
- Check modifiedTime to detect changes
- Prune cache on storage limits

### Performance
- Lazy loading of large Drive folders
- Background sync using isolates
- Paginated file listing

### Error Handling
- Network errors (retry logic)
- Auth token expiration (auto-refresh)
- Drive API quota limits
- Storage limits (cache cleanup)

## File Structure
```
lib/
  services/
    google_drive/
      google_drive_auth_service.dart      # Authentication
      google_drive_service.dart           # Drive API operations
      google_drive_cache_service.dart     # Local caching
  models/
    music_folder.dart                     # Updated model for folder types
  screens/
    google_drive_folder_picker.dart       # Drive folder selection UI
```

## Configuration

### Android Setup (google-services.json)
1. Create project in Google Cloud Console
2. Enable Google Drive API
3. Create OAuth 2.0 credentials for Android
4. Download `google-services.json`
5. Add SHA-1 fingerprint for debug/release

### OAuth Scopes
```dart
const driveScopes = [
  'https://www.googleapis.com/auth/drive.readonly',
  'email',
  'profile',
];
```

## Testing Plan
1. Unit tests for Drive API operations (mocked)
2. Integration tests for auth flow
3. Manual testing with various Drive folder structures
4. Offline mode testing
5. Large file handling (performance)
