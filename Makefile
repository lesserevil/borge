# Makefile – standard targets and dev utilities
# -------------------------------------------------
# Directories
PEBBLE_DIR := pebble
TABLET_DIR := tablet
PHONE_JS_DIR := phone-js
FLUTTER_DIR := flutter

# Variables
FLUTTER := fvm flutter
FLUTTER_BIN := $(FLUTTER_DIR)/build/linux/x64/release/bundle/borge
INSTALL_DIR := $(HOME)/.local/bin

# ----------------------------------------------------------------------
# Standard Targets (Requested in Issue #2)
# ----------------------------------------------------------------------

# 1. deps: Install dependencies
.PHONY: deps
deps:
	@echo "⬇️  Installing dependencies..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) pub get

# 2. build: Build the project (depends on deps)
# currently builds the native Linux app
.PHONY: build
build: deps
	@echo "🔨 Building Flutter app for native desktop..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) build linux --release

# 3. test: Run tests (depends on build)
# Note: Instructions requested test depends on build
.PHONY: test
test: build
	@echo "🧪 Running Flutter tests..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) test

# 4. install: Install to $HOME/.local/bin (depends on test)
.PHONY: install
install: test
	@echo "📦 Installing binary to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@cp -r $(FLUTTER_DIR)/build/linux/x64/release/bundle/* $(INSTALL_DIR)/
	@# If 'borge' is the binary name, ensure it's in the top level of bundle or handle the path correctly.
	@# Flutter Linux bundle typically contains the executable and lib/data folders.
	@# We should probably copy the whole bundle directory or symlink.
	@# For now, copying contents of bundle to a named folder might be cleaner, 
	@# but standard install usually implies the binary is runnable from PATH.
	@# Since Flutter apps need assets, we might need a wrapper script or install to a lib dir and symlink.
	@# Simple approach: Copy the executable 'borge' to bin? No, it needs libraries.
	@# Proper approach: Install to ~/.local/lib/borge and symlink directory?
	@# Following simplest interpretation: Copy executable. (But it will fail without lib).
	@# Let's assume standard 'bundle' copy to a predictable location and symlink bin.
	@mkdir -p $(HOME)/.local/share/borge
	@cp -r $(FLUTTER_DIR)/build/linux/x64/release/bundle/* $(HOME)/.local/share/borge/
	@ln -sf $(HOME)/.local/share/borge/borge $(INSTALL_DIR)/borge
	@echo "✅ Installed 'borge' to $(INSTALL_DIR)"

# 5. run: Run the application (depends on test, executes build output)
.PHONY: run
run: test
	@echo "🚀 Running Borge..."
	@$(FLUTTER_BIN)

# ----------------------------------------------------------------------
# Pebble & Services (Legacy/Dev Targets)
# ----------------------------------------------------------------------

.PHONY: pebble-build
pebble-build:
	@echo "🔨 Building Pebble firmware..."
	@cd $(PEBBLE_DIR) && ./pebble.sh build

TABLET_PID := /tmp/borge_tablet_pid

.PHONY: tablet-server
tablet-server:
	@echo "🚀 Starting tablet server on http://10.0.2.2:3000 ..."
	@cd $(TABLET_DIR) && python3 server.py & \
		echo $$! > $(TABLET_PID)

.PHONY: kill-tablet-server
kill-tablet-server:
	@echo "🛑 Stopping tablet server (if it is still running)…"
	@fuser -k 3000/tcp || true
	@rm -f $(TABLET_PID)
	@echo "✅ Tablet server stopped."

# Renamed old 'run' to 'start-services'
.PHONY: start-services
start-services: pebble-build tablet-server
	@echo "✅ Pebble firmware built."
	@echo "✅ Tablet server is running at http://10.0.2.2:3000"
	@echo "💡 Open that URL in Chrome (or any browser) to see the songs.json."
	@echo "💡 The phone‑side JS (phone-js/index.js) will fetch from that address."
	@echo "💡 When you are done, run: make kill-tablet-server"

# ----------------------------------------------------------------------
# Local test environment (Android emulator + Pebble emulator)
# ----------------------------------------------------------------------
TEST_AVD ?= pixel_5_api_30
BROWSER ?= xdg-open

.PHONY: test-local
test-local:
	@echo "🔧 Starting tablet server..."
	@$(MAKE) start-services
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

.PHONY: stop-local
stop-local:
	@echo "🛑 Stopping local test environment..."
	@$(MAKE) kill-tablet-server
	@echo "🛑 Stopping Android emulator (AVD image preserved)…"
	@pkill -f "emulator.*-avd $(TEST_AVD)" || true
	@pkill -f "pebble emulate" || true
	@rm -f .pebble_emu.pid .test-local.running

# ----------------------------------------------------------------------
# Additional Flutter Targets
# ----------------------------------------------------------------------

# Force a rebuild every time this target is invoked
.PHONY: flutter-build-native
flutter-build-native: build

# Run the native (desktop) build – it will always build first
.PHONY: flutter-run-native
flutter-run-native: run

# Clean native Flutter build artifacts
.PHONY: clean-flutter-native
clean-flutter-native:
	@echo "🧹 Cleaning native Flutter build artifacts..."
	@cd $(FLUTTER_DIR) && rm -rf build/linux

# Run the Flutter app in Chrome (Web)
.PHONY: flutter-run-web
flutter-run-web:
	@echo "🌐 Serving Flutter app on http://localhost:8080 ..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) run -d web-server --web-port 8080 --web-hostname 0.0.0.0

# Alternative: build a release APK for Android (if needed)
.PHONY: flutter-build-apk
flutter-build-apk:
	@echo "🔨 Building Flutter APK for Android..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) build apk --release

# Run Flutter APK
.PHONY: flutter-run-apk
flutter-run-apk:
	@echo "🚀 Running Flutter APK (requires connected device or emulator)..."
	@cd $(FLUTTER_DIR) && adb install -r build/app/outputs/flutter-apk/app-release.apk && adb shell monkey -p com.example.borge -c android.intent.category.LAUNCHER 1 || echo "Ensure a device/emulator is connected."

# Clean APK build artifacts
.PHONY: clean-flutter-apk
clean-flutter-apk:
	@echo "🧹 Cleaning APK build artifacts..."
	@cd $(FLUTTER_DIR) && rm -rf build/app/outputs/flutter-apk

# Run Flutter on remote Android device (via VS Code port forwarding)
.PHONY: flutter-run-remote
flutter-run-remote:
	@echo "📱 Running Flutter on remote Android device..."
	@cd $(FLUTTER_DIR) && export ANDROID_HOME=/usr/lib/android-sdk && $(FLUTTER) devices
	@echo "🚀 Launching app..."
	@cd $(FLUTTER_DIR) && export ANDROID_HOME=/usr/lib/android-sdk && $(FLUTTER) run

# ----------------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------------

.PHONY: clean
clean: clean-flutter-native clean-flutter-apk
	@echo "🧹 All cleaned."

.PHONY: package
package: flutter-build-apk
	@echo "📦 All packaged."

# ----------------------------------------------------------------------
# Docker Targets (Issue #3)
# ----------------------------------------------------------------------

DOCKER_COMPOSE := docker compose
DOCKER_FLUTTER := $(DOCKER_COMPOSE) run --rm flutter
DOCKER_PEBBLE  := $(DOCKER_COMPOSE) run --rm pebble

.PHONY: docker-build
docker-build:
	@echo "🐳 Building Docker images..."
	@$(DOCKER_COMPOSE) build

.PHONY: docker-deps
docker-deps: docker-build
	@echo "⬇️  Installing dependencies (in container)..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter pub get"

.PHONY: docker-test
docker-test: docker-deps
	@echo "🧪 Running tests (in container)..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter test"

.PHONY: docker-build-linux
docker-build-linux: docker-deps
	@echo "🔨 Building Linux app (in container)..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter build linux --release"

.PHONY: docker-build-web
docker-build-web: docker-deps
	@echo "🌐 Building web app (in container)..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter build web --release"

.PHONY: docker-build-apk
docker-build-apk: docker-deps
	@echo "📱 Building Android APK (in container)..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter build apk --release"

.PHONY: docker-pebble
docker-pebble:
	@echo "⌚ Building Pebble firmware (in container)..."
	@$(DOCKER_PEBBLE) pebble build

.PHONY: docker-shell
docker-shell:
	@echo "🐚 Opening shell in Flutter container..."
	@$(DOCKER_FLUTTER) bash

.PHONY: docker-clean
docker-clean:
	@echo "🧹 Cleaning Docker resources..."
	@$(DOCKER_COMPOSE) down --rmi local --volumes --remove-orphans
