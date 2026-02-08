# Containerize Borge Project (Issue #3)

## TL;DR

> **Quick Summary**: Add Docker support so developers can build, test, and run the Borge project without installing Flutter, fvm, Java, Pebble SDK, or Linux GTK dependencies on their host machine. A single `docker compose up` should get a developer productive.
>
> **Deliverables**:
> - `Dockerfile` — Multi-stage image for Flutter dev/build (Linux desktop, Web, Android)
> - `Dockerfile.pebble` — Separate image for Pebble firmware builds
> - `docker-compose.yml` — Orchestrates dev environment
> - `.dockerignore` — Excludes build artifacts, .git, etc.
> - Updated `Makefile` — Docker-aware targets (`make docker-build`, `make docker-test`, etc.)
> - Updated `README.md` — Docker quickstart section
>
> **Estimated Effort**: Medium
> **Parallel Execution**: YES — 2 waves
> **Critical Path**: Dockerfile → docker-compose.yml → Makefile → README

---

## Context

### Original Request
GitHub Issue #3 by @jordanhubbard:
> "I don't want to install every project on github's goop on my machine. Docker is fine."

### Current Build Requirements (without Docker)
A developer currently needs ALL of these installed:

| Tool | Version | Purpose |
|------|---------|---------|
| fvm | latest | Flutter version manager |
| Flutter SDK | 3.38.5 | App framework |
| Dart SDK | ^3.10.4 | Language runtime |
| clang, cmake, ninja-build | system | C/C++ toolchain for Linux builds |
| pkg-config, libgtk-3-dev, liblzma-dev, libstdc++-12-dev | system | Linux desktop dependencies |
| Java (Temurin) | 17 | Android builds |
| Android SDK | latest | Android builds |
| Python | 3.12 | Pebble SDK |
| uv | latest | Python package manager for Pebble |
| pebble-tool + SDK | latest | Pebble watch firmware |
| libsdl1.2debian, libfdt1 | system | Pebble SDK deps |

### Existing CI (reference for what works)
`.github/workflows/flutter.yml` already builds all targets on Ubuntu — this is our proven recipe:
- **flutter-analyze**: `flutter pub get` → `flutter analyze` → `flutter test`
- **flutter-build-linux**: Install GTK deps → `flutter build linux --release`
- **flutter-build-web**: `flutter build web --release`
- **flutter-build-android**: Java 17 → `flutter build apk --release`
- **pebble-build**: Python 3.12 + uv + pebble-tool → `pebble build`

### Key Decisions Made
- **Skip fvm in Docker**: CI already uses Flutter directly (not fvm). Inside the container, install Flutter 3.38.5 directly. The `Makefile` can detect if inside Docker and use `flutter` instead of `fvm flutter`.
- **Separate Pebble image**: Pebble SDK has completely different deps (Python, SDL). Keep it in its own Dockerfile.
- **Dev-first approach**: The issue says "I don't want to install goop" — this is about developer experience, not just CI. The container should support interactive development (edit on host, build in container).
- **Volume mounts**: Source code mounted from host so the developer edits with their IDE and builds in the container.

---

## Work Objectives

### Core Objective
Allow a developer to clone the repo and run `docker compose up` to get a fully working build/test/dev environment without installing any project dependencies on their host.

### Concrete Deliverables
- `Dockerfile` — Flutter dev/build container
- `Dockerfile.pebble` — Pebble build container
- `docker-compose.yml` — Orchestration with volume mounts
- `.dockerignore` — Clean build context
- Updated `Makefile` — Docker-aware targets
- Updated `README.md` — Docker quickstart

### Definition of Done
- [ ] `docker compose run flutter make deps` succeeds
- [ ] `docker compose run flutter make test` succeeds (same pass/fail as bare metal)
- [ ] `docker compose run flutter make build` produces Linux binary
- [ ] `docker compose run flutter fvm flutter build web --release` produces web build
- [ ] `docker compose run pebble pebble build` builds Pebble firmware
- [ ] Source edits on host are immediately visible in container (volume mount)

### Must Have
- Flutter 3.38.5 installed in container
- All Linux desktop build dependencies pre-installed
- Java 17 for Android builds
- Web build support
- Pub cache persistence (don't re-download deps every run)
- Gradle cache persistence (don't re-download Android deps every run)
- Source code volume-mounted from host

### Must NOT Have (Guardrails)
- Do NOT create a massive monolithic Dockerfile — use multi-stage or separate files
- Do NOT bake source code into the image — use volume mounts
- Do NOT hardcode paths — use environment variables
- Do NOT require the developer to run more than 2-3 commands to get started
- Do NOT break the existing non-Docker workflow (bare metal fvm still works)
- Do NOT modify existing CI workflow — Docker is for local dev
- Do NOT include IDE-specific config (no .devcontainer — keep it simple)

---

## Verification Strategy

### Test Decision
- **Infrastructure exists**: YES (existing tests in flutter/test/)
- **Automated tests**: Tests-after (verify Docker runs existing tests)
- **Framework**: `fvm flutter test` (or `flutter test` inside container)

### Agent-Executed QA Scenarios

```
Scenario: Docker image builds successfully
  Tool: Bash
  Steps:
    1. docker compose build flutter
    2. Assert: exit code 0
    3. docker compose build pebble
    4. Assert: exit code 0
  Expected Result: Both images build without errors
  Evidence: Build output captured

Scenario: Flutter deps install in container
  Tool: Bash
  Steps:
    1. docker compose run --rm flutter flutter pub get
    2. Assert: exit code 0
    3. Assert: output contains "Got dependencies"
  Expected Result: All pub dependencies resolve
  Evidence: Command output captured

Scenario: Flutter tests run in container
  Tool: Bash
  Steps:
    1. docker compose run --rm flutter flutter test
    2. Assert: exit code matches bare-metal (some pre-existing failures OK)
    3. Assert: same number of passing tests as bare metal (~59 pass, ~18 fail)
  Expected Result: Test results match bare-metal environment
  Evidence: Test output captured

Scenario: Flutter Linux build succeeds in container
  Tool: Bash
  Steps:
    1. docker compose run --rm flutter flutter build linux --release
    2. Assert: exit code 0
    3. Assert: flutter/build/linux/x64/release/bundle/borge exists
  Expected Result: Linux binary produced
  Evidence: ls -la of build output

Scenario: Flutter Web build succeeds in container
  Tool: Bash
  Steps:
    1. docker compose run --rm flutter flutter build web --release
    2. Assert: exit code 0
    3. Assert: flutter/build/web/index.html exists
  Expected Result: Web build produced
  Evidence: ls -la of build output

Scenario: Source changes on host visible in container
  Tool: Bash
  Steps:
    1. On host: echo "// test" >> flutter/lib/main.dart
    2. In container: cat flutter/lib/main.dart | tail -1
    3. Assert: contains "// test"
    4. Cleanup: Remove test comment
  Expected Result: Volume mount works bidirectionally
  Evidence: Command output
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Create Dockerfile (Flutter)
├── Task 2: Create Dockerfile.pebble
└── Task 3: Create .dockerignore

Wave 2 (After Wave 1):
├── Task 4: Create docker-compose.yml
├── Task 5: Update Makefile with Docker targets
└── Task 6: Update README.md with Docker quickstart

Wave 3 (After Wave 2):
└── Task 7: Verify, commit, push
```

---

## TODOs

- [ ] 1. Create Dockerfile for Flutter development/builds

  **What to do**:
  - Create `Dockerfile` at the project root (`/home/shedwards/src/borge/Dockerfile`)
  - Base image: `ubuntu:24.04`
  - Multi-stage approach with a single dev/build stage (keep it simple — not a production deployment image)

  **Dockerfile contents**:
  ```dockerfile
  FROM ubuntu:24.04

  # Prevent interactive prompts during package installation
  ENV DEBIAN_FRONTEND=noninteractive
  ENV LANG=C.UTF-8
  ENV LC_ALL=C.UTF-8

  # Flutter version — pinned to match project
  ENV FLUTTER_VERSION=3.38.5
  ENV FLUTTER_HOME=/opt/flutter
  ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"

  # Android SDK
  ENV ANDROID_HOME=/opt/android-sdk
  ENV ANDROID_SDK_ROOT=${ANDROID_HOME}
  ENV PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

  # 1. Install system dependencies (Linux desktop + Android + general)
  RUN apt-get update && apt-get install -y --no-install-recommends \
      # General build tools
      curl git unzip xz-utils zip ca-certificates \
      # Flutter Linux desktop dependencies
      clang cmake ninja-build pkg-config \
      libgtk-3-dev liblzma-dev libstdc++-14-dev \
      # Java for Android builds
      openjdk-17-jdk-headless \
      # Cleanup
      && rm -rf /var/lib/apt/lists/*

  # 2. Install Flutter SDK
  RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
      https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
      && flutter precache --linux --web --android \
      && flutter config --no-analytics \
      && dart --disable-analytics

  # 3. Install Android SDK command-line tools
  RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
      && cd ${ANDROID_HOME}/cmdline-tools \
      && curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o cmdline-tools.zip \
      && unzip cmdline-tools.zip \
      && mv cmdline-tools latest \
      && rm cmdline-tools.zip \
      && yes | sdkmanager --licenses > /dev/null 2>&1 \
      && sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"

  # 4. Accept Android licenses
  RUN yes | flutter doctor --android-licenses > /dev/null 2>&1 || true

  # 5. Set up fvm symlink so Makefile works
  # The Makefile uses 'fvm flutter' — create a shim that just calls flutter
  RUN printf '#!/bin/sh\nif [ "$1" = "flutter" ]; then shift; exec flutter "$@"; else exec "$@"; fi\n' > /usr/local/bin/fvm \
      && chmod +x /usr/local/bin/fvm

  # Working directory
  WORKDIR /workspace

  # Verify Flutter installation
  RUN flutter doctor -v
  ```

  **Must NOT do**:
  - Do NOT copy source code into the image (it gets volume-mounted)
  - Do NOT install fvm (use the shim script instead)
  - Do NOT use Alpine (Flutter needs glibc)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5, 7
  - **Blocked By**: None

  **References**:
  - `.github/workflows/flutter.yml:109-112` — Linux desktop dependencies list (exact packages to install)
  - `.github/workflows/flutter.yml:19-24` — Flutter version and channel
  - `.github/workflows/flutter.yml:46-50` — Java version for Android
  - `Makefile:10` — `FLUTTER := fvm flutter` — why we need the fvm shim
  - `flutter/pubspec.yaml:22` — Dart SDK constraint `^3.10.4`

  **Acceptance Criteria**:
  - [ ] `Dockerfile` exists at project root
  - [ ] `docker build -t borge-flutter .` succeeds
  - [ ] `docker run --rm borge-flutter flutter --version` outputs `3.38.5`
  - [ ] `docker run --rm borge-flutter fvm flutter --version` outputs `3.38.5` (shim works)
  - [ ] `docker run --rm borge-flutter flutter doctor` shows Linux, Web, Android capabilities

  **Commit**: YES (groups with Tasks 2, 3)
  - Message: `Add Docker containerization for Flutter and Pebble development (closes #3)`
  - Files: `Dockerfile`, `Dockerfile.pebble`, `.dockerignore`

---

- [ ] 2. Create Dockerfile.pebble for Pebble firmware builds

  **What to do**:
  - Create `Dockerfile.pebble` at the project root
  - Separate from Flutter image because completely different toolchain

  **Dockerfile.pebble contents**:
  ```dockerfile
  FROM ubuntu:24.04

  ENV DEBIAN_FRONTEND=noninteractive
  ENV LANG=C.UTF-8
  ENV LC_ALL=C.UTF-8

  # Install system dependencies
  RUN apt-get update && apt-get install -y --no-install-recommends \
      curl git python3 python3-pip python3-venv python3.12-venv \
      nodejs npm \
      libsdl1.2debian libfdt1 \
      ca-certificates \
      && rm -rf /var/lib/apt/lists/*

  # Install uv (Python package manager)
  RUN curl -LsSf https://astral.sh/uv/install.sh | sh
  ENV PATH="/root/.local/bin:${PATH}"

  # Install pebble-tool
  RUN uv tool install pebble-tool --python 3.12

  # Install Pebble SDK
  RUN pebble sdk install latest

  WORKDIR /workspace
  ```

  **Must NOT do**:
  - Do NOT combine with Flutter Dockerfile
  - Do NOT include Flutter SDK

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 1, 3)
  - **Blocks**: Task 4
  - **Blocked By**: None

  **References**:
  - `.github/workflows/flutter.yml:134-170` — Pebble CI job (exact setup steps)
  - `README.md` — Pebble setup instructions in Quick Start section

  **Acceptance Criteria**:
  - [ ] `Dockerfile.pebble` exists at project root
  - [ ] `docker build -f Dockerfile.pebble -t borge-pebble .` succeeds
  - [ ] `docker run --rm borge-pebble pebble --version` succeeds

  **Commit**: YES (groups with Tasks 1, 3)

---

- [ ] 3. Create .dockerignore

  **What to do**:
  - Create `.dockerignore` at the project root

  **Contents**:
  ```
  # Build artifacts
  flutter/build/
  flutter/.dart_tool/
  flutter/.packages
  flutter/.flutter-plugins
  flutter/.flutter-plugins-dependencies

  # Platform builds
  flutter/android/.gradle/
  flutter/android/app/build/

  # fvm local
  flutter/.fvm/flutter_sdk

  # IDE
  .idea/
  .vscode/
  *.iml

  # Git
  .git/
  .gitignore

  # Pebble build
  pebble/build/

  # Docker (prevent recursive context)
  .dockerignore
  Dockerfile
  Dockerfile.pebble
  docker-compose.yml

  # Sisyphus working files
  .sisyphus/

  # OS files
  .DS_Store
  Thumbs.db
  ```

  **Must NOT do**:
  - Do NOT ignore `flutter/pubspec.yaml` or `flutter/pubspec.lock`
  - Do NOT ignore `flutter/web/` or `flutter/assets/`

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 1, 2)
  - **Blocks**: None
  - **Blocked By**: None

  **Acceptance Criteria**:
  - [ ] `.dockerignore` exists at project root
  - [ ] Contains all listed exclusions

  **Commit**: YES (groups with Tasks 1, 2)

---

- [ ] 4. Create docker-compose.yml

  **What to do**:
  - Create `docker-compose.yml` at the project root
  - Define `flutter` and `pebble` services with volume mounts

  **docker-compose.yml contents**:
  ```yaml
  services:
    flutter:
      build:
        context: .
        dockerfile: Dockerfile
      volumes:
        - .:/workspace
        - flutter-pub-cache:/root/.pub-cache
        - flutter-gradle-cache:/root/.gradle
      working_dir: /workspace
      # Keep container running for interactive use
      stdin_open: true
      tty: true

    pebble:
      build:
        context: .
        dockerfile: Dockerfile.pebble
      volumes:
        - .:/workspace
      working_dir: /workspace/pebble
      stdin_open: true
      tty: true

  volumes:
    flutter-pub-cache:
      name: borge-pub-cache
    flutter-gradle-cache:
      name: borge-gradle-cache
  ```

  **Key design decisions**:
  - Source code is volume-mounted at `/workspace` — edits on host are instant in container
  - `flutter-pub-cache` and `flutter-gradle-cache` are named volumes — persist across container restarts
  - `stdin_open` + `tty` enable interactive shell sessions
  - No port mappings by default — use `docker compose run --service-ports` if needed for web dev

  **Must NOT do**:
  - Do NOT use bind mounts for caches (named volumes are faster on Mac/Windows)
  - Do NOT add port mappings by default (web server port is only needed during dev)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Blocks**: Tasks 5, 7
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `Makefile:153-154` — Web server runs on port 8080 (for future port mapping)

  **Acceptance Criteria**:
  - [ ] `docker-compose.yml` exists at project root
  - [ ] `docker compose config` validates without errors
  - [ ] `docker compose build` succeeds for both services
  - [ ] `docker compose run --rm flutter flutter --version` outputs 3.38.5
  - [ ] `docker compose run --rm flutter ls flutter/pubspec.yaml` shows the file (volume mount works)

  **Commit**: YES
  - Message: `Add docker-compose.yml with Flutter and Pebble services`
  - Files: `docker-compose.yml`

---

- [ ] 5. Update Makefile with Docker targets

  **What to do**:
  - Add new Docker-specific targets to the existing `Makefile`
  - Keep all existing targets working (backward compatible)

  **Add these targets after the existing `# Cleanup` section**:
  ```makefile
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
  	@$(DOCKER_FLUTTER) flutter pub get

  .PHONY: docker-test
  docker-test: docker-deps
  	@echo "🧪 Running tests (in container)..."
  	@$(DOCKER_FLUTTER) flutter test

  .PHONY: docker-build-linux
  docker-build-linux: docker-deps
  	@echo "🔨 Building Linux app (in container)..."
  	@$(DOCKER_FLUTTER) flutter build linux --release

  .PHONY: docker-build-web
  docker-build-web: docker-deps
  	@echo "🌐 Building web app (in container)..."
  	@$(DOCKER_FLUTTER) flutter build web --release

  .PHONY: docker-build-apk
  docker-build-apk: docker-deps
  	@echo "📱 Building Android APK (in container)..."
  	@$(DOCKER_FLUTTER) flutter build apk --release

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
  ```

  **Must NOT do**:
  - Do NOT modify existing targets
  - Do NOT make existing targets depend on Docker
  - Do NOT change `FLUTTER := fvm flutter` (bare metal still uses fvm)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 6)
  - **Blocks**: Task 7
  - **Blocked By**: Task 4

  **References**:
  - `Makefile` — Full existing Makefile (append new section, don't modify existing)

  **Acceptance Criteria**:
  - [ ] New Docker targets added to Makefile
  - [ ] Existing targets unchanged
  - [ ] `make docker-build` builds Docker images
  - [ ] `make docker-test` runs tests in container
  - [ ] `make docker-shell` opens interactive bash

  **Commit**: YES (groups with Task 6)
  - Message: `Add Docker-aware Makefile targets and update README with Docker quickstart`
  - Files: `Makefile`, `README.md`

---

- [ ] 6. Update README.md with Docker quickstart

  **What to do**:
  - Add a "Docker Development" section to `README.md`
  - Place it right after the existing "Flutter App Setup" section

  **Content to add**:
  ```markdown
  ### Docker Development (Recommended)

  No need to install Flutter, Java, or any other dependencies. Just Docker.

  ```bash
  # Build the development container
  make docker-build

  # Run tests
  make docker-test

  # Build Linux desktop app
  make docker-build-linux

  # Build web app
  make docker-build-web

  # Build Android APK
  make docker-build-apk

  # Build Pebble firmware
  make docker-pebble

  # Open interactive shell in container
  make docker-shell
  ```

  Your source code is volume-mounted — edit files with your IDE on the host,
  build and test inside the container.
  ```

  **Must NOT do**:
  - Do NOT remove existing setup instructions (some devs prefer bare metal)
  - Do NOT restructure the entire README

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 5)
  - **Blocks**: Task 7
  - **Blocked By**: Task 4

  **References**:
  - `README.md` — Existing README structure

  **Acceptance Criteria**:
  - [ ] README.md has Docker Development section
  - [ ] Commands listed match actual Makefile targets

  **Commit**: YES (groups with Task 5)

---

- [ ] 7. Create branch from main, verify everything, commit, and push

  **What to do**:
  - Create a new branch from `main`: `git checkout main && git checkout -b feature/docker-containerization`
  - Stage and commit all new/modified files
  - Run `docker compose build` to verify images build
  - Run `docker compose run --rm flutter flutter --version` to verify Flutter
  - Run `docker compose run --rm flutter flutter pub get` in the flutter directory
  - Run `docker compose run --rm flutter flutter test` and compare results
  - Push branch to remote

  **IMPORTANT**: The issue says to create a new branch from main. Make sure to start from main, NOT from the current feature/music-drawing-annotation branch.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: `["git-master"]`

  **Parallelization**:
  - **Blocked By**: All previous tasks

  **Acceptance Criteria**:
  - [ ] Branch `feature/docker-containerization` created from `main`
  - [ ] `docker compose build` succeeds
  - [ ] `docker compose run --rm flutter flutter --version` shows 3.38.5
  - [ ] `docker compose run --rm flutter flutter test` in flutter dir — same pass/fail count as bare metal
  - [ ] All commits pushed to remote
  - [ ] `git status` shows "up to date with origin"

  **Commit**: YES
  - Message: varies per task grouping (see individual tasks)

---

## Commit Strategy

| After Tasks | Message | Files |
|-------------|---------|-------|
| 1, 2, 3 | `Add Docker containerization for Flutter and Pebble development (closes #3)` | `Dockerfile`, `Dockerfile.pebble`, `.dockerignore` |
| 4 | `Add docker-compose.yml with Flutter and Pebble services` | `docker-compose.yml` |
| 5, 6 | `Add Docker-aware Makefile targets and update README with Docker quickstart` | `Makefile`, `README.md` |

---

## Success Criteria

### Verification Commands
```bash
# Build images
docker compose build  # Expected: both images build successfully

# Verify Flutter
docker compose run --rm flutter flutter --version  # Expected: Flutter 3.38.5
docker compose run --rm flutter flutter doctor  # Expected: Linux, Web, Android capabilities

# Run tests
docker compose run --rm flutter bash -c "cd flutter && flutter test"  # Expected: ~59 pass / ~18 fail

# Build Linux
docker compose run --rm flutter bash -c "cd flutter && flutter build linux --release"  # Expected: binary at flutter/build/linux/x64/release/bundle/borge

# Build Web
docker compose run --rm flutter bash -c "cd flutter && flutter build web --release"  # Expected: flutter/build/web/index.html exists
```

### Final Checklist
- [ ] `docker compose build` succeeds
- [ ] Flutter tests run in container with same results as bare metal
- [ ] Linux desktop build works in container
- [ ] Web build works in container
- [ ] Volume mount allows host edits visible in container
- [ ] Pub cache persists across container restarts
- [ ] Existing non-Docker workflow still works
- [ ] README documents Docker quickstart
- [ ] Issue #3 can be closed
