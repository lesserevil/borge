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
DOCKER_PEBBLE  := $(DOCKER_COMPOSE) run --rm pebble

# Bare-metal (for local dev without Docker)
FLUTTER := fvm flutter
FLUTTER_BIN := $(FLUTTER_DIR)/build/linux/x64/release/bundle/borge
INSTALL_DIR := $(HOME)/.local/bin

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

.PHONY: build-apk
build-apk: deps
	@echo "📱 Building Android APK..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter build apk --release"

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
# Bare-Metal Targets (local dev without Docker)
# ----------------------------------------------------------------------

.PHONY: bare-deps
bare-deps:
	@echo "⬇️  Installing dependencies (bare metal)..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) pub get

.PHONY: bare-build
bare-build: bare-deps
	@echo "🔨 Building Flutter app for native desktop (bare metal)..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) build linux --release

.PHONY: bare-test
bare-test: bare-build
	@echo "🧪 Running Flutter tests (bare metal)..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) test

.PHONY: bare-install
bare-install: bare-test
	@echo "📦 Installing binary to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@mkdir -p $(HOME)/.local/share/borge
	@cp -r $(FLUTTER_DIR)/build/linux/x64/release/bundle/* $(HOME)/.local/share/borge/
	@ln -sf $(HOME)/.local/share/borge/borge $(INSTALL_DIR)/borge
	@echo "✅ Installed 'borge' to $(INSTALL_DIR)"

.PHONY: bare-run
bare-run: bare-test
	@echo "🚀 Running Borge (bare metal)..."
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
# Additional Flutter Targets (bare metal)
# ----------------------------------------------------------------------

.PHONY: bare-run-web
bare-run-web:
	@echo "🌐 Serving Flutter app on http://localhost:8080 (bare metal)..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) run -d web-server --web-port 8080 --web-hostname 0.0.0.0

.PHONY: bare-build-apk
bare-build-apk:
	@echo "🔨 Building Flutter APK for Android (bare metal)..."
	@cd $(FLUTTER_DIR) && $(FLUTTER) build apk --release

.PHONY: bare-run-remote
bare-run-remote:
	@echo "📱 Running Flutter on remote Android device (bare metal)..."
	@cd $(FLUTTER_DIR) && export ANDROID_HOME=/usr/lib/android-sdk && $(FLUTTER) devices
	@echo "🚀 Launching app..."
	@cd $(FLUTTER_DIR) && export ANDROID_HOME=/usr/lib/android-sdk && $(FLUTTER) run

# ----------------------------------------------------------------------
# Cleanup (bare metal)
# ----------------------------------------------------------------------

.PHONY: bare-clean
bare-clean:
	@echo "🧹 Cleaning native build artifacts..."
	@cd $(FLUTTER_DIR) && rm -rf build/linux build/app/outputs/flutter-apk
	@echo "🧹 All cleaned."
