FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Flutter version — pinned to match project
ENV FLUTTER_VERSION=3.38.5
ENV FLUTTER_HOME=/opt/flutter
ENV FLUTTER_ALLOW_ROOT=true
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
# TAR_OPTIONS needed for rootless container compatibility (podman/Docker)
ENV TAR_OPTIONS="--no-same-owner"
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

# 5. Set up fvm shim so Makefile works unchanged
# The Makefile uses 'fvm flutter' — this shim strips the 'flutter' arg and calls flutter directly
RUN printf '#!/bin/sh\nif [ "$1" = "flutter" ]; then shift; exec flutter "$@"; else exec "$@"; fi\n' > /usr/local/bin/fvm \
    && chmod +x /usr/local/bin/fvm

# Working directory (source code is volume-mounted here)
WORKDIR /workspace

# Verify Flutter installation
RUN flutter doctor -v
