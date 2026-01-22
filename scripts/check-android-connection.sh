#!/bin/bash
# Android Remote Development Diagnostic Script
# Run this on the REMOTE SSH machine to check Android device connection

set +e  # Don't exit on errors

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   Android Remote Development - Connection Diagnostic           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

ERRORS=0
WARNINGS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    ERRORS=$((ERRORS + 1))
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Checking ADB Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v adb &> /dev/null; then
    ADB_VERSION=$(adb version | head -1)
    print_success "ADB is installed: $ADB_VERSION"
else
    print_error "ADB is not installed"
    echo "   Fix: sudo apt install -y adb android-tools-adb"
    echo ""
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Checking Port 5037 (ADB Server Port)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if netstat -tuln 2>/dev/null | grep -q ':5037'; then
    print_success "Port 5037 is listening"
    PORT_INFO=$(netstat -tuln 2>/dev/null | grep ':5037')
    echo "   $PORT_INFO"
else
    print_error "Port 5037 is NOT listening"
    echo ""
    echo "   This means VS Code port forwarding is NOT set up."
    echo ""
    echo "   📋 Setup Instructions:"
    echo "   ────────────────────────────────────────────────────────────"
    echo "   On your LOCAL machine (where Android device is):"
    echo "     1. Open a terminal"
    echo "     2. Run: adb start-server"
    echo ""
    echo "   In VS Code (Remote SSH session):"
    echo "     1. Press Ctrl+Shift+P"
    echo "     2. Type 'Forward a Port'"
    echo "     3. Enter port: 5037"
    echo "     4. Make sure it's 'Remote → Local' direction"
    echo ""
    echo "   OR add to ~/.ssh/config on LOCAL machine:"
    echo "     Host your-server"
    echo "         RemoteForward 5037 localhost:5037"
    echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Testing ADB Connection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try to start ADB server if not running
adb start-server 2>&1 | head -2

sleep 1

# Check for devices
DEVICE_OUTPUT=$(adb devices -l 2>&1)
echo "$DEVICE_OUTPUT"

DEVICE_COUNT=$(echo "$DEVICE_OUTPUT" | grep -w "device" | grep -v "devices attached" | wc -l)

echo ""
if [ "$DEVICE_COUNT" -eq 0 ]; then
    print_error "No Android devices found!"
    echo ""
    echo "   🔍 Troubleshooting Checklist:"
    echo "   ────────────────────────────────────────────────────────────"
    echo "   On LOCAL machine:"
    echo "     □ Android device is connected via USB"
    echo "     □ USB cable supports data transfer (not just charging)"
    echo "     □ 'Developer Options' is enabled on Android device"
    echo "     □ 'USB Debugging' is enabled in Developer Options"
    echo "     □ Run: adb devices (should show your device)"
    echo "     □ Accept 'Allow USB debugging' prompt on device screen"
    echo ""
    echo "   On REMOTE machine (this machine):"
    echo "     □ Port 5037 is forwarded from remote to local"
    echo "     □ Run: adb devices (should show same device as local)"
    echo ""
elif echo "$DEVICE_OUTPUT" | grep -q "unauthorized"; then
    print_warning "Device found but UNAUTHORIZED"
    echo ""
    echo "   Fix:"
    echo "     1. Check your Android device screen"
    echo "     2. Accept the 'Allow USB debugging' prompt"
    echo "     3. Check 'Always allow from this computer'"
    echo "     4. Run: adb devices (device should show as 'device', not 'unauthorized')"
    echo ""
else
    print_success "Found $DEVICE_COUNT Android device(s)!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Checking Flutter"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v fvm &> /dev/null; then
    print_success "FVM is installed"
    
    if cd /home/shedwards/src/borge/flutter 2>/dev/null; then
        echo ""
        echo "Flutter devices:"
        export ANDROID_HOME=/usr/lib/android-sdk
        fvm flutter devices 2>&1
    fi
else
    print_warning "FVM not found (using system Flutter)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ] && [ "$DEVICE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ All checks passed! Ready to deploy.${NC}"
    echo ""
    echo "Run: make flutter-run-remote"
elif [ "$DEVICE_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Setup incomplete but device is visible.${NC}"
    echo -e "Errors: $ERRORS, Warnings: $WARNINGS"
    echo ""
    echo "You may be able to run: make flutter-run-remote"
else
    echo -e "${RED}❌ Setup incomplete. Fix the issues above.${NC}"
    echo -e "Errors: $ERRORS, Warnings: $WARNINGS"
    echo ""
    echo "Most common issue: Port 5037 forwarding not configured in VS Code"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📚 Full documentation: ~/src/borge/docs/ANDROID_REMOTE_SETUP.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
