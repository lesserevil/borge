#!/bin/bash
# Backup Google Drive settings from the device to local filesystem for development
# This allows restoring settings after app reinstalls during development

set -e

PACKAGE_NAME="com.lesserevil.borge"
BACKUP_DIR="$HOME/.borge-dev-backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== Borge Development Settings Backup ==="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Pull SharedPreferences
echo "📦 Backing up app preferences..."
if adb shell "run-as $PACKAGE_NAME ls shared_prefs/" 2>/dev/null | grep -q "FlutterSecureStorage"; then
    adb exec-out run-as $PACKAGE_NAME cat shared_prefs/FlutterSecureStorage.xml > "$BACKUP_DIR/FlutterSecureStorage_$TIMESTAMP.xml" 2>/dev/null || true
fi

if adb shell "run-as $PACKAGE_NAME ls shared_prefs/" 2>/dev/null | grep -q "FlutterSharedPreferences"; then
    adb exec-out run-as $PACKAGE_NAME cat shared_prefs/FlutterSharedPreferences.xml > "$BACKUP_DIR/FlutterSharedPreferences_$TIMESTAMP.xml" 2>/dev/null || true
fi

# List all preference files
echo "📋 Available preference files:"
adb shell "run-as $PACKAGE_NAME ls -la shared_prefs/" 2>/dev/null || echo "  (none found or unable to access)"

echo ""
echo "✅ Backup saved to: $BACKUP_DIR"
echo ""
echo "Note: Google Sign-In tokens are stored securely by the system"
echo "and cannot be easily backed up. You may still need to sign in again."
echo "However, your folder configuration should be preserved."
