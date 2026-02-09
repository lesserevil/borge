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

# Source file sets (used for change detection)
FLUTTER_SRCS := $(shell find $(FLUTTER_DIR)/lib -type f -name '*.dart' 2>/dev/null)
FLUTTER_DEPS := $(FLUTTER_DIR)/pubspec.yaml $(FLUTTER_DIR)/pubspec.lock
PEBBLE_SRCS  := $(shell find $(PEBBLE_DIR)/src -type f 2>/dev/null)

# Build artifacts
LINUX_BINARY := $(FLUTTER_DIR)/build/linux/x64/release/bundle/borge
WEB_OUTPUT   := $(FLUTTER_DIR)/build/web/main.dart.js
APK_OUTPUT   := $(FLUTTER_DIR)/build/app/outputs/flutter-apk/app-release.apk
PEBBLE_FW    := $(PEBBLE_DIR)/build/borge-companion.pbw

# Shared JS (canonical source -> web copy)
ANNOTATION_JS_SRC := $(FLUTTER_DIR)/assets/js/osmd_annotations.js
ANNOTATION_JS_WEB := $(FLUTTER_DIR)/web/osmd_annotations.js

# ----------------------------------------------------------------------
# Standard Targets (Docker — default)
# ----------------------------------------------------------------------

.PHONY: deps
deps:
	@echo "⬇️  Installing dependencies..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter pub get"

# Copy canonical annotation JS to web/ (single source of truth)
$(ANNOTATION_JS_WEB): $(ANNOTATION_JS_SRC)
	@cp $< $@

.PHONY: sync-annotation-js
sync-annotation-js: $(ANNOTATION_JS_WEB)

$(LINUX_BINARY): $(FLUTTER_DEPS) $(FLUTTER_SRCS)
	@echo "🔨 Building Flutter app for Linux desktop..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter pub get && flutter build linux --release"

.PHONY: build
build: $(LINUX_BINARY)

.PHONY: test
test:
	@echo "🧪 Running Flutter tests..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter pub get && flutter test"

$(WEB_OUTPUT): $(FLUTTER_DEPS) $(FLUTTER_SRCS) $(ANNOTATION_JS_WEB)
	@echo "🌐 Building web app..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter pub get && flutter build web --release"

.PHONY: build-web
build-web: $(WEB_OUTPUT)

.PHONY: run-web
run-web: $(ANNOTATION_JS_WEB)
	@echo "🌐 Serving Flutter app on http://localhost:8080..."
	@$(DOCKER_COMPOSE) run --rm -p 8080:8080 flutter bash -c "cd flutter && flutter pub get && flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0"

$(APK_OUTPUT): $(FLUTTER_DEPS) $(FLUTTER_SRCS)
	@echo "📱 Building Android APK..."
	@$(DOCKER_FLUTTER) bash -c "cd flutter && flutter pub get && flutter build apk --release"

.PHONY: build-apk
build-apk: $(APK_OUTPUT)

APK_PATH := $(APK_OUTPUT)

# ADB_HOST: set to <ip>:<port> to install over TCP via adb connect.
# Leave unset to install via USB on the host.
ADB_HOST ?=

.PHONY: install-apk
install-apk: build-apk
ifdef ADB_HOST
	@echo "📲 Installing APK on remote device $(ADB_HOST)..."
	@adb connect $(ADB_HOST) && adb -s $(ADB_HOST) wait-for-device && adb -s $(ADB_HOST) install -r $(APK_PATH)
else
	@echo "📲 Installing APK on USB-connected device..."
	@adb wait-for-device && adb install -r $(APK_PATH)
endif
	@echo "✅ APK installed."

$(PEBBLE_FW): $(PEBBLE_SRCS)
	@echo "⌚ Building Pebble firmware..."
	@$(DOCKER_PEBBLE) pebble build

.PHONY: pebble
pebble: $(PEBBLE_FW)

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
	@cd $(FLUTTER_DIR) && rm -rf build/linux build/app/outputs/flutter-apk build/web

.PHONY: package
package: $(APK_OUTPUT)
	@echo "📦 All packaged."

# ----------------------------------------------------------------------
# Signing & Secrets
# ----------------------------------------------------------------------

KEY_PROPERTIES := $(FLUTTER_DIR)/android/key.properties

# Generate key.properties from .env
$(KEY_PROPERTIES): .env
	@echo "🔑 Generating key.properties from .env..."
	@set -a && . ./.env && set +a && \
	 for var in KEYSTORE_FILE KEYSTORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do \
	   eval "val=\$$$$var"; \
	   if [ -z "$$val" ]; then echo "ERROR: $$var is not set in .env" >&2; exit 1; fi; \
	 done && \
	 cp "$$KEYSTORE_FILE" $(FLUTTER_DIR)/android/app/upload-keystore.jks && \
	 printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=%s\nstoreFile=app/upload-keystore.jks\n' \
	   "$$KEYSTORE_PASSWORD" "$$KEY_PASSWORD" "$$KEY_ALIAS" > $@
	@echo "✅ key.properties written."

.PHONY: key-properties
key-properties: $(KEY_PROPERTIES)

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
