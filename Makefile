# Makefile – standard targets and dev utilities
# -------------------------------------------------
# Directories
PEBBLE_DIR := pebble
TABLET_DIR := tablet
PHONE_JS_DIR := phone-js
FLUTTER_DIR := flutter

# Docker (default development method)
DOCKER_COMPOSE := docker compose
DOCKER_FLUTTER := $(DOCKER_COMPOSE) run --rm flutter
DOCKER_FLUTTER_USB := $(DOCKER_COMPOSE) run --rm flutter-usb
DOCKER_PEBBLE  := $(DOCKER_COMPOSE) run --rm pebble

# ----------------------------------------------------------------------
# Standard Targets (Docker — default)
# ----------------------------------------------------------------------

.PHONY: deps
deps:
	@echo "⬇️  Installing dependencies..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter pub get"

.PHONY: build
build: deps
	@echo "🔨 Building Flutter app for Linux desktop..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter build linux --release"

.PHONY: test
test: deps
	@echo "🧪 Running Flutter tests..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter test"

.PHONY: build-web
build-web: deps
	@echo "🌐 Building web app..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter build web --release"

.PHONY: run-web
run-web: deps
	@echo "🌐 Serving Flutter app on http://localhost:8080..."
	@$(DOCKER_COMPOSE) run --rm -p 8080:8080 flutter bash -c "cd flutter && flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0"

.PHONY: build-apk
build-apk: deps
	@echo "📱 Building Android APK..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter build apk --release"

APK_PATH := flutter/build/app/outputs/flutter-apk/app-release.apk

# ADB_HOST: set to <ip>:<port> to install over TCP (direct device or adb bridge).
# Leave unset to install via USB.
ADB_HOST ?=

.PHONY: install-apk
install-apk: build-apk
ifdef ADB_HOST
	@echo "📲 Installing APK on remote device $(ADB_HOST)..."
	@$(DOCKER_FLUTTER) bash -c "adb connect $(ADB_HOST) && adb -s $(ADB_HOST) wait-for-device && adb -s $(ADB_HOST) install -r $(APK_PATH)"
else
	@echo "📲 Installing APK on USB-connected device..."
	@$(DOCKER_FLUTTER_USB) bash -c "adb wait-for-device && adb install -r $(APK_PATH)"
endif
	@echo "✅ APK installed."

.PHONY: pebble
pebble:
	@echo "⌚ Building Pebble firmware..."
	@$(DOCKER_PEBBLE) pebble build

.PHONY: shell
shell:
	@echo "🐚 Opening shell in Flutter container..."
	@$(DOCKER_FLUTTER) bash

.PHONY: images
images:
	@echo "🐳 Building Docker images..."
	@$(DOCKER_COMPOSE) build

.PHONY: clean
clean:
	@echo "🧹 Cleaning Docker resources and build artifacts..."
	@$(DOCKER_COMPOSE) down --rmi local --volumes --remove-orphans
	@cd $(FLUTTER_DIR) && rm -rf build/linux build/app/outputs/flutter-apk

.PHONY: package
package: build-apk
	@echo "📦 All packaged."

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
