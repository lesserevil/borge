#!/bin/bash
# Wrapper script to run pebble commands via Docker
# Usage: ./pebble.sh <command> [args...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Allow X11 connections from Docker
xhost +local:docker 2>/dev/null || true

docker run --rm \
    -v "$SCRIPT_DIR:/pebble" \
    -w /pebble \
    -e DISPLAY="$DISPLAY" \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    --network host \
    rebble/pebble-sdk \
    pebble "$@"
