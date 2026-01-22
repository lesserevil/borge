#!/bin/bash
# Android Local Setup Diagnostic Script
# Run this on your LOCAL machine (where Android device is physically connected)

set +e  # Don't exit on errors

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   Android Local Setup - Connection Diagnostic                  ║"
echo "║   (Run this on LOCAL machine with USB device)                  ║"
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
    ADB_VERSION=$(adb version 2>&1 | head -1)
    print_success "ADB is installed: $ADB_VERSION"
    ADB_PATH=$(which adb)
    echo "   Location: $ADB_PATH"
else
    print_error "ADB is not installed on this machine"
    echo ""
    echo "   Install Android Platform Tools:"
    echo "   ────────────────────────────────────────────────────────────"
    echo "   macOS:   brew install android-platform-tools"
    echo "   Linux:   sudo apt install adb android-tools-adb"
    echo "   Windows: Download from https://developer.android.com/studio/releases/platform-tools"
    echo ""
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Checking ADB Server Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if ADB server is running
ADB_STATUS=$(adb devices 2>&1 | head -1)

if echo "$ADB_STATUS" | grep -q "daemon"; then
    print_info "Starting ADB server..."
    adb start-server 2>&1 | head -3
    sleep 2
fi

if pgrep -x "adb" > /dev/null; then
    print_success "ADB server is running"
else
    print_warning "ADB server may not be running"
    echo "   Starting server..."
    adb start-server
    sleep 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Checking for Connected Android Devices"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DEVICE_OUTPUT=$(adb devices -l 2>&1)
echo "$DEVICE_OUTPUT"

DEVICE_COUNT=$(echo "$DEVICE_OUTPUT" | grep -w "device" | grep -v "devices attached" | wc -l)
UNAUTHORIZED_COUNT=$(echo "$DEVICE_OUTPUT" | grep "unauthorized" | wc -l)

echo ""

if [ "$DEVICE_COUNT" -gt 0 ]; then
    print_success "Found $DEVICE_COUNT authorized device(s)!"
    
    # Show device details
    echo ""
    echo "   Device Details:"
    adb devices -l | grep -v "List of devices"
    
elif [ "$UNAUTHORIZED_COUNT" -gt 0 ]; then
    print_error "Device found but UNAUTHORIZED"
    echo ""
    echo "   📱 Fix on your Android device:"
    echo "   ────────────────────────────────────────────────────────────"
    echo "   1. Look at your Android device screen"
    echo "   2. You should see a prompt: 'Allow USB debugging?'"
    echo "   3. Check the box: '☑ Always allow from this computer'"
    echo "   4. Tap 'OK' or 'Allow'"
    echo ""
    echo "   If you don't see the prompt:"
    echo "   - Unplug and re-plug the USB cable"
    echo "   - Run: adb kill-server && adb start-server"
    echo "   - Try again"
    echo ""
    
else
    print_error "No Android devices found!"
    echo ""
    echo "   📋 Troubleshooting Steps:"
    echo "   ────────────────────────────────────────────────────────────"
    echo "   1. Check Physical Connection:"
    echo "      □ USB cable is plugged into both device and computer"
    echo "      □ Try a different USB port"
    echo "      □ Try a different USB cable (some only charge, don't do data)"
    echo ""
    echo "   2. Enable Developer Options on Android:"
    echo "      □ Go to: Settings → About Phone"
    echo "      □ Tap 'Build Number' 7 times"
    echo "      □ You'll see: 'You are now a developer!'"
    echo ""
    echo "   3. Enable USB Debugging:"
    echo "      □ Go to: Settings → System → Developer Options"
    echo "      □ Enable: 'USB Debugging'"
    echo "      □ You may also need: 'Install via USB' (on some devices)"
    echo ""
    echo "   4. Check USB Connection Mode:"
    echo "      □ When you plug in USB, check notification"
    echo "      □ Select: 'File Transfer' or 'MTP' mode"
    echo "      □ NOT 'Charging only' or 'No data transfer'"
    echo ""
    echo "   5. Restart ADB:"
    echo "      □ Run: adb kill-server"
    echo "      □ Run: adb start-server"
    echo "      □ Run: adb devices"
    echo ""
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Checking USB Devices (Hardware Detection)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try lsusb if available (Linux/Mac)
if command -v lsusb &> /dev/null; then
    echo "USB devices detected:"
    lsusb 2>/dev/null | grep -i "android\|samsung\|google\|motorola\|oneplus\|xiaomi\|huawei\|lg\|sony" || echo "   No common Android manufacturers detected via lsusb"
elif command -v system_profiler &> /dev/null; then
    # macOS
    echo "USB devices detected (macOS):"
    system_profiler SPUSBDataType 2>/dev/null | grep -A 2 -i "android\|phone" || echo "   No Android devices in USB tree"
else
    print_info "lsusb not available - skipping hardware detection"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. VS Code SSH Port Forwarding Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$DEVICE_COUNT" -gt 0 ]; then
    print_success "Local setup looks good!"
    echo ""
    echo "   Next: Set up port forwarding in VS Code"
    echo "   ────────────────────────────────────────────────────────────"
    echo "   1. Connect to your remote server via VS Code Remote SSH"
    echo "   2. Press: Ctrl+Shift+P (or Cmd+Shift+P on Mac)"
    echo "   3. Type: 'Forward a Port'"
    echo "   4. Enter port: 5037"
    echo "   5. Direction: Remote → Local (this is critical!)"
    echo ""
    echo "   OR add to ~/.ssh/config:"
    echo "   ────────────────────────────────────────────────────────────"
    echo "   Host your-server"
    echo "       HostName your-server.com"
    echo "       User yourusername"
    echo "       RemoteForward 5037 localhost:5037"
    echo ""
    echo "   Then on REMOTE, run:"
    echo "       adb devices"
    echo ""
    echo "   You should see the SAME device appear!"
    echo ""
else
    print_warning "Fix local device connection first before setting up VS Code forwarding"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$DEVICE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Local Android setup is complete!${NC}"
    echo ""
    echo "   Device is connected and authorized."
    echo "   Next step: Configure VS Code port forwarding (see above)"
    echo ""
elif [ "$UNAUTHORIZED_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Device detected but unauthorized${NC}"
    echo ""
    echo "   Check your Android device screen and authorize USB debugging"
    echo ""
else
    echo -e "${RED}❌ No devices detected${NC}"
    echo -e "   Errors: $ERRORS, Warnings: $WARNINGS"
    echo ""
    echo "   Follow the troubleshooting steps above"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Quick Commands:"
echo "   adb devices           - List connected devices"
echo "   adb kill-server       - Kill ADB server"
echo "   adb start-server      - Start ADB server"
echo "   adb shell             - Open shell on device"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
