# Borge Pebble Companion App

Pebble watch companion app for hands-free sheet music navigation.

## Prerequisites

### Ubuntu/Debian

```bash
# Install system dependencies
sudo apt install python3-pip python3-venv python3.12-venv nodejs npm libsdl1.2debian libfdt1

# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install pebble-tool
uv tool install pebble-tool --python 3.12

# Install latest Pebble SDK
pebble sdk install latest
```

### macOS

```bash
# Install dependencies
brew install python node

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install pebble-tool
uv tool install pebble-tool

# Install latest Pebble SDK
pebble sdk install latest
```

### Windows

Use WSL with Ubuntu, then follow the Ubuntu instructions above.

## Building

```bash
pebble build
```

## Installing

### On Emulator (Pebble Time)

```bash
pebble install --emulator basalt
```

### On Physical Watch

```bash
# Replace IP with your phone's IP shown in the Pebble app
pebble install --phone <IP>
```

## Features (Planned)

- **Button Navigation**: Up/Down for page turns, Select to confirm, Back to exit
- **BLE Communication**: Connects to Flutter app for song/page data
- **Haptic Feedback**: Vibration patterns for navigation confirmation
- **Song List Display**: Browse available songs on watch screen

## Communication Protocol

The companion app communicates with the Flutter app via BLE using the following commands:

| Command | Description |
|---------|-------------|
| `GET_LIST` | Request list of available songs |
| `LIST_RESP` | Response with song list data |
| `SELECT_SONG` | Select a song by ID |
| `NEXT_PAGE` | Navigate to next page |
| `PREV_PAGE` | Navigate to previous page |
| `ACK` | Acknowledge command receipt |

## Resources

- [Rebble Developer Portal](https://developer.rebble.io/)
- [Pebble SDK Documentation](https://developer.rebble.io/docs/)
- [Pebble C API Reference](https://developer.rebble.io/docs/c/)
