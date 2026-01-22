# Makefile – minimal version for local testing
# -------------------------------------------------
# Directories
PEBBLE_DIR := pebble
TABLET_DIR := tablet
PHONE_JS_DIR := phone-js
FLUTTER_DIR := flutter

# ----------------------------------------------------------------------
# Build Pebble firmware
# ----------------------------------------------------------------------
pebble-build:
	@echo "🔨 Building Pebble firmware..."
	@cd $(PEBBLE_DIR) && ./pebble.sh build

# ----------------------------------------------------------------------
# Start the tablet HTTP server (serves songs.json)
# ----------------------------------------------------------------------
TABLET_PID := /tmp/borge_tablet_pid

tablet-server:
	@echo "🚀 Starting tablet server on http://10.0.2.2:3000 ..."
	@cd $(TABLET_DIR) && python3 server.py & \
		echo $$! > $(TABLET_PID)

# ----------------------------------------------------------------------
# Kill tablet server
# ----------------------------------------------------------------------
kill-tablet-server:
	@echo "🛑 Stopping tablet server (if it is still running)…"
	@fuser -k 3000/tcp || true
	@rm -f $(TABLET_PID)
	@echo "✅ Tablet server stopped."

# ----------------------------------------------------------------------
# Native Flutter app build and run targets for local dev environment
# ----------------------------------------------------------------------
# Use fvm-managed Flutter version
FLUTTER := fvm flutter

# Build Flutter app for native (desktop) environment
FLUTTER      := fvm flutter
FLUTTER_DIR  := flutter
FLUTTER_BIN  := $(FLUTTER_DIR)/build/linux/x64/release/bundle/borge

# Force a rebuild every time this target is invoked
.PHONY: flutter-build-native
flutter-build-native:
	@echo "🔨 Building Flutter app for native desktop..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) build linux --release

# Run the native (desktop) build – it will always build first
.PHONY: flutter-run-native
flutter-run-native: flutter-build-native
	@echo "🚀 Running Flutter app natively..."
	@$(FLUTTER_BIN)

# Clean native Flutter build artifacts
clean-flutter-native:
	@echo "🧹 Cleaning native Flutter build artifacts..."
	@cd $(FLUTTER_DIR) && rm -rf build/linux

# Run the Flutter app in Chrome (Web)
.PHONY: flutter-run-web
flutter-run-web:
	@echo "🌐 Serving Flutter app on http://localhost:8080 ..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) run -d web-server --web-port 8080 --web-hostname 0.0.0.0

# Alternative: build a release APK for Android (if needed)
flutter-build-apk:
	@echo "🔨 Building Flutter APK for Android..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) build apk --release

flutter-run-apk:
	@echo "🚀 Running Flutter APK (requires connected device or emulator)..."
	@cd $(FLUTTER_DIR) && adb install -r build/app/outputs/flutter-apk/app-release.apk && adb shell monkey -p com.example.borge -c android.intent.category.LAUNCHER 1 || echo "Ensure a device/emulator is connected."

# Clean APK build artifacts
clean-flutter-apk:
	@echo "🧹 Cleaning APK build artifacts..."
	@cd $(FLUTTER_DIR) && rm -rf build/app/outputs/flutter-apk

# Run Flutter on remote Android device (via VS Code port forwarding)
.PHONY: flutter-run-remote
flutter-run-remote:
	@echo "📱 Running Flutter on remote Android device..."
	@echo "Make sure:"
	@echo "  1. Android device is connected to your local machine"
	@echo "  2. ADB is running locally: adb start-server"
	@echo "  3. Port 5037 is forwarded in VS Code"
	@echo ""
	@cd $(FLUTTER_DIR) && export ANDROID_HOME=/usr/lib/android-sdk && $(FLUTTER) devices
	@echo ""
	@echo "🚀 Launching app..."
	@cd $(FLUTTER_DIR) && export ANDROID_HOME=/usr/lib/android-sdk && $(FLUTTER) run

# ----------------------------------------------------------------------
# Convenience targets
# ------------------------------------------------------------------
run: pebble-build tablet-server
	@echo "✅ Pebble firmware built."
	@echo "✅ Tablet server is running at http://10.0.2.2:3000"
	@echo "💡 Open that URL in Chrome (or any browser) to see the songs.json."
	@echo "💡 The phone‑side JS (phone-js/index.js) will fetch from that address."
	@echo "💡 When you are done, run: make kill-tablet-server"

# ----------------------------------------------------------------------
# Local test environment (Android emulator + Pebble emulator)
# ----------------------------------------------------------------------
# Default AVD name - change to match the device you use for the phone
TEST_AVD ?= pixel_5_api_30
BROWSER ?= xdg-open

test-local:
	@echo "🔧 Starting tablet server..."
	@$(MAKE) run
	@echo "🚀 Launching Android emulator '$(TEST_AVD)'..."
	@emulator -avd $(TEST_AVD) > /dev/null 2>&1 &
	@echo "⏳ Waiting for emulator (adb wait-for-device)..."
	@adb wait-for-device
	@echo "⏳ Waiting for boot completion (max 30s)..."; \
		sleep 30
	@echo "✅ Emulator is ready"
	@echo "📦 Ensuring Pebble app is installed on the emulator..."
	@adb shell pm list packages | grep -q com.rebble || echo "Pebble app already installed"
	@echo "🕶️  Starting Pebble emulator..."
	@$(PEBBLE_DIR)/pebble.sh emulate basalt & echo $! > .pebble_emu.pid
	@echo "🌐 Opening tablet server URL in your default browser..."
	@$(BROWSER) http://10.0.2.2:3000 || true
	@echo "✅ All services are running. Close the browser tab when done, then run 'make stop-local'."

stop-local:
	@echo "🛑 Stopping local test environment..."
	@$(MAKE) kill-tablet-server
	@echo "🛑 Stopping Android emulator (AVD image preserved)…"
	@pkill -f "emulator.*-avd $(TEST_AVD)" || true
	@pkill -f "pebble emulate" || true
	@rm -f .pebble_emu.pid .test-local.running

# ----------------------------------------------------------------------
# Standard Agent Targets
# ----------------------------------------------------------------------

.PHONY: clean
clean: clean-flutter-native clean-flutter-apk
	@echo "🧹 All cleaned."

.PHONY: build
build: flutter-build-native pebble-build
	@echo "🔨 All built."

.PHONY: test
test:
	@echo "🧪 Running Flutter tests..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) test

.PHONY: package
package: flutter-build-apk
	@echo "📦 All packaged."

.PHONY: pebble-build tablet-server kill-tablet-server run test-local stop-local \
	flutter-build-native flutter-run-native flutter-run-web clean-flutter-native \
	flutter-build-apk flutter-run-apk flutter-run-remote clean-flutter-apk \
	clean build test package
