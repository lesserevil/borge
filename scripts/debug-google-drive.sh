#!/bin/bash
# Debug script for Google Drive sign-in issues

echo "=== Borge Google Drive Debug ==="
echo ""

# Get the current package name from build.gradle
echo "1. Checking package configuration..."
ACTUAL_PACKAGE=$(grep -r "applicationId\|namespace" flutter/android/app/build.gradle.kts 2>/dev/null | grep -oP '"\K[^"]+' | head -1)
if [ -z "$ACTUAL_PACKAGE" ]; then
    ACTUAL_PACKAGE=$(grep -r "applicationId\|namespace" flutter/android/app/build.gradle 2>/dev/null | grep -oP '"\K[^"]+' | head -1)
fi

EXPECTED_PACKAGE="com.lesserevil.borge"
SETUP_SHA1=$(grep DEBUG_SHA1 ~/.config/borge/google-drive-config.sh 2>/dev/null | cut -d'"' -f2)

echo "  Expected package (OAuth): $EXPECTED_PACKAGE"
echo "  Actual package (app):     $ACTUAL_PACKAGE"
if [ "$ACTUAL_PACKAGE" != "$EXPECTED_PACKAGE" ]; then
    echo "  ⚠️  MISMATCH DETECTED!"
    echo ""
    echo "  This is likely why Google Sign-In is failing."
    echo "  You need to either:"
    echo "    1. Update OAuth credentials to use: $ACTUAL_PACKAGE"
    echo "    2. OR change app package to: $EXPECTED_PACKAGE"
fi
echo ""

# Get current SHA-1
echo "2. Checking SHA-1 fingerprint..."
CURRENT_SHA1=$(keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep "SHA1:" | awk '{print $2}')
echo "  Setup SHA-1:   $SETUP_SHA1"
echo "  Current SHA-1: $CURRENT_SHA1"
if [ "$CURRENT_SHA1" != "$SETUP_SHA1" ]; then
    echo "  ⚠️  SHA-1 MISMATCH!"
fi
echo ""

# Check if app is running
echo " 3. Checking if app is running..."
APP_PID=$(adb shell pidof $ACTUAL_PACKAGE 2>/dev/null)
if [ -n "$APP_PID" ]; then
    echo "  ✓ App is running (PID: $APP_PID)"
    echo ""
    echo "4. Watching live logs..."
    echo "   (Try signing in now, press Ctrl+C to stop)"
    echo ""
    sleep 2
    adb logcat -c
    adb logcat --pid=$APP_PID | grep -E "(flutter|I/|E/|W/)" --color=always
else
    echo "  ✗ App is not running"
    echo "  Please open the app first, then run this script again"
fi
