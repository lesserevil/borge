#!/bin/bash
# Check Android device connection via VS Code port forwarding
# Run this script ON THE REMOTE SSH machine (in VS Code terminal)

echo "=== Android Device Connection Check ==="
echo ""

# Check if ADB is installed
if ! command -v adb &> /dev/null; then
    echo "❌ ADB not found. Installing..."
    sudo apt update && sudo apt install -y adb android-tools-adb
    echo ""
fi

echo "📱 Checking for connected devices..."
echo ""

# List devices
adb devices -l

DEVICE_COUNT=$(adb devices | grep -w "device" | wc -l)

echo ""

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "❌ No Android devices found!"
    echo ""
    echo "Make sure:"
    echo "  1. Android device is connected to your LOCAL machine via USB"
    echo "  2. ADB server is running on LOCAL machine: adb start-server"
    echo "  3. Port 5037 is forwarded in VS Code:"
    echo "     - Press Ctrl+Shift+P"
    echo "     - Type 'Forward a Port'"
    echo "     - Enter port: 5037"
    echo ""
else
    echo "✅ Found $DEVICE_COUNT device(s) connected!"
    echo ""
    echo "You can now run Flutter:"
    echo "  cd /home/shedwards/src/borge/flutter"
    echo "  flutter run"
    echo ""
fi

# Also check Flutter devices
if command -v flutter &> /dev/null; then
    echo "=== Flutter Devices ==="
    flutter devices
fi
