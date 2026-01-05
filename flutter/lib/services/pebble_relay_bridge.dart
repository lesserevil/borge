import 'dart:async';

import 'package:flutter/foundation.dart';

import 'pebble_service.dart';
import 'remote_control_service.dart';

/// Bridge that connects the PebbleService to the RemoteControlService.
///
/// When the phone is in relay mode, this bridge:
/// 1. Receives Pebble commands via WebSocket (from Pebble watch app)
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
  bool get isPebbleConnected => _pebbleService.clientCount > 0;

  /// Whether a tablet viewer is connected
  bool get isViewerConnected => _remoteControlService.isConnected;

  /// Activate the bridge - starts PebbleService and listens for commands
  Future<void> activate() async {
    if (_isActive) return;

    // Set up the command callback to relay commands to tablet
    _pebbleService.onCommandReceived = _onPebbleCommand;

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

    // Remove the command callback
    _pebbleService.onCommandReceived = null;

    await _pebbleService.stop();

    _isActive = false;
    debugPrint('PebbleRelayBridge deactivated');
  }

  /// Handle Pebble commands and relay them to the tablet
  void _onPebbleCommand(PebbleCommand command, Map<String, dynamic> data) {
    debugPrint('Relaying Pebble command: ${command.stringValue}');

    if (!_remoteControlService.isConnected) {
      debugPrint('Cannot relay: not connected to viewer');
      return;
    }

    switch (command) {
      case PebbleCommand.nextPage:
        _remoteControlService.sendNextPage();
        break;
      case PebbleCommand.prevPage:
        _remoteControlService.sendPreviousPage();
        break;
      case PebbleCommand.nextSong:
        // TODO: Implement song navigation via remote control
        debugPrint('NEXT_SONG not yet implemented for relay');
        break;
      case PebbleCommand.prevSong:
        // TODO: Implement song navigation via remote control
        debugPrint('PREV_SONG not yet implemented for relay');
        break;
      case PebbleCommand.selectSong:
        final songId = data['songId'] as String?;
        if (songId != null) {
          // TODO: Implement song selection via remote control
          debugPrint('SELECT_SONG not yet implemented for relay');
        }
        break;
      case PebbleCommand.getList:
        // TODO: Request song list from tablet and relay back to watch
        debugPrint('GET_LIST not yet implemented for relay');
        break;
      default:
        debugPrint('Unhandled command for relay: ${command.stringValue}');
    }
  }

  void dispose() {
    deactivate();
  }
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
