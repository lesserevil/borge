import 'dart:async';

import 'package:flutter/foundation.dart';

import 'pebble_service.dart';
import 'remote_control_service.dart';
import 'song_repository.dart';

/// Bridge that connects the PebbleService to the RemoteControlService.
///
/// When the phone is in relay mode, this bridge:
/// 1. Receives Pebble commands via WebSocket (from Pebble companion app)
/// 2. Forwards them to the tablet via Nearby Connections
///
/// This allows the Pebble watch to control a tablet while remaining
/// connected to the phone for notifications.
class PebbleRelayBridge {
  final PebbleService _pebbleService;
  final RemoteControlService _remoteControlService;

  StreamSubscription<bool>? _pebbleConnectionSubscription;
  bool _isActive = false;

  PebbleRelayBridge({
    required PebbleService pebbleService,
    required RemoteControlService remoteControlService,
  }) : _pebbleService = pebbleService,
       _remoteControlService = remoteControlService;

  /// Whether the bridge is active (relay mode enabled)
  bool get isActive => _isActive;

  /// Whether the Pebble is connected
  bool get isPebbleConnected => _pebbleService.isRunning;

  /// Whether a tablet viewer is connected
  bool get isViewerConnected => _remoteControlService.isConnected;

  /// Activate the bridge - starts PebbleService and listens for commands
  Future<void> activate() async {
    if (_isActive) return;

    // Start the Pebble WebSocket server
    await _pebbleService.start();

    // Listen for Pebble connection changes
    _pebbleConnectionSubscription = _pebbleService.connectionStream.listen((
      connected,
    ) {
      debugPrint('Pebble connection changed: $connected');
    });

    _isActive = true;
    debugPrint('PebbleRelayBridge activated');
  }

  /// Deactivate the bridge
  Future<void> deactivate() async {
    if (!_isActive) return;

    await _pebbleConnectionSubscription?.cancel();
    _pebbleConnectionSubscription = null;

    await _pebbleService.stop();

    _isActive = false;
    debugPrint('PebbleRelayBridge deactivated');
  }

  /// Create a PebbleService that relays commands to the tablet
  /// instead of controlling local state.
  ///
  /// This creates a modified PebbleService that intercepts commands
  /// and forwards them via the RemoteControlService.
  static PebbleService createRelayingPebbleService({
    required RemoteControlService remoteControlService,
    required SongRepository songRepository,
  }) {
    return _RelayingPebbleService(
      songRepository: songRepository,
      remoteControlService: remoteControlService,
    );
  }

  void dispose() {
    deactivate();
  }
}

/// A PebbleService that relays commands to a remote viewer
/// instead of controlling local state.
class _RelayingPebbleService extends PebbleService {
  final RemoteControlService _remoteControlService;

  _RelayingPebbleService({
    required SongRepository songRepository,
    required RemoteControlService remoteControlService,
  }) : _remoteControlService = remoteControlService,
       super(songRepository: songRepository);

  // Override command handlers to relay to remote viewer

  // Note: The base PebbleService handles the WebSocket communication,
  // but we intercept the actual command execution to forward to the tablet.
  //
  // For a full implementation, we would need to either:
  // 1. Modify PebbleService to have overridable command handlers
  // 2. Or use a callback pattern
  //
  // For now, we'll add a relay mode to the RemoteControlService
  // that integrates directly with button-press events.
}

/// Extension on RemoteControlService to integrate with Pebble
extension PebbleRelayExtension on RemoteControlService {
  /// Handle a Pebble button press and relay it to the viewer.
  ///
  /// This is called when the Pebble companion app sends a button event.
  ///
  /// [button] can be 'up', 'down', 'select', or 'back'
  Future<void> handlePebbleButton(String button) async {
    if (mode != RemoteControlMode.relay || !isConnected) {
      debugPrint(
        'Cannot relay Pebble button: not in relay mode or not connected',
      );
      return;
    }

    switch (button.toLowerCase()) {
      case 'up':
        await sendPreviousPage();
        break;
      case 'down':
        await sendNextPage();
        break;
      case 'select':
        await sendTogglePlay();
        break;
      case 'back':
        // Could be used for going back to song list
        break;
      default:
        debugPrint('Unknown Pebble button: $button');
    }
  }
}
