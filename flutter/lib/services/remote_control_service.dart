import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/app_state.dart';
import 'nearby_connections_service.dart';
import 'remote_command.dart';

/// Operating mode for remote control
enum RemoteControlMode {
  /// Standalone mode - no remote control
  standalone,

  /// Viewer mode - this device displays sheet music and accepts remote commands
  /// (typically tablet)
  viewer,

  /// Relay mode - this device relays commands from Pebble to a viewer
  /// (typically phone)
  relay,
}

/// Service that integrates Nearby Connections with the app state.
///
/// In viewer mode: Advertises and responds to remote commands (page turns, etc.)
/// In relay mode: Discovers viewers and forwards Pebble commands to them
class RemoteControlService extends ChangeNotifier {
  final AppState _appState;
  final NearbyConnectionsService _nearbyService;

  RemoteControlMode _mode = RemoteControlMode.standalone;
  bool _isEnabled = false;
  String _deviceName = 'Borge';
  String? _lastError;

  // Subscriptions
  StreamSubscription<(String, RemoteCommand)>? _commandSubscription;
  StreamSubscription<NearbyConnectionState>? _stateSubscription;
  StreamSubscription<(String, dynamic)>? _connectionRequestSubscription;

  RemoteControlService({
    required AppState appState,
    NearbyConnectionsService? nearbyService,
  }) : _appState = appState,
       _nearbyService = nearbyService ?? NearbyConnectionsService();

  /// Current operating mode
  RemoteControlMode get mode => _mode;

  /// Whether remote control is enabled
  bool get isEnabled => _isEnabled;

  /// Current connection state
  NearbyConnectionState get connectionState => _nearbyService.state;

  /// Whether connected to any endpoints
  bool get isConnected => _nearbyService.isConnected;

  /// List of discovered viewers (in relay mode)
  List<DiscoveredEndpoint> get discoveredViewers =>
      _nearbyService.discoveredEndpoints;

  /// List of connected endpoints
  List<ConnectedEndpoint> get connectedEndpoints =>
      _nearbyService.connectedEndpoints;

  /// Device name used for advertising/discovery
  String get deviceName => _deviceName;

  /// Last error message (if any)
  String? get lastError => _lastError;

  /// Stream of connection state changes
  Stream<NearbyConnectionState> get stateStream => _nearbyService.stateStream;

  /// Stream of discovered endpoints
  Stream<List<DiscoveredEndpoint>> get discoveredStream =>
      _nearbyService.discoveredStream;

  /// Stream of connected endpoints
  Stream<List<ConnectedEndpoint>> get connectedStream =>
      _nearbyService.connectedStream;

  /// Set the device name (before enabling)
  void setDeviceName(String name) {
    _deviceName = name;
    notifyListeners();
  }

  /// Enable viewer mode (tablet advertises, accepts commands)
  Future<bool> enableViewerMode() async {
    if (_isEnabled) {
      await disable();
    }

    _lastError = null;

    // Check permissions
    final hasPermissions = await _nearbyService.checkAndRequestPermissions();
    if (!hasPermissions) {
      _lastError = 'Permissions not granted';
      notifyListeners();
      return false;
    }

    // Start advertising
    final success = await _nearbyService.startAdvertising(_deviceName);
    if (!success) {
      _lastError = 'Failed to start advertising';
      notifyListeners();
      return false;
    }

    _mode = RemoteControlMode.viewer;
    _isEnabled = true;

    // Subscribe to incoming commands
    _commandSubscription = _nearbyService.commandStream.listen(_handleCommand);
    _stateSubscription = _nearbyService.stateStream.listen(_onStateChanged);
    _connectionRequestSubscription = _nearbyService.connectionRequestStream
        .listen(_onConnectionRequest);

    notifyListeners();
    return true;
  }

  /// Enable relay mode (phone discovers viewers, forwards commands)
  Future<bool> enableRelayMode() async {
    if (_isEnabled) {
      await disable();
    }

    _lastError = null;

    // Check permissions
    final hasPermissions = await _nearbyService.checkAndRequestPermissions();
    if (!hasPermissions) {
      _lastError = 'Permissions not granted';
      notifyListeners();
      return false;
    }

    // Start discovery
    final success = await _nearbyService.startDiscovery();
    if (!success) {
      _lastError = 'Failed to start discovery';
      notifyListeners();
      return false;
    }

    _mode = RemoteControlMode.relay;
    _isEnabled = true;

    // Subscribe to state changes
    _stateSubscription = _nearbyService.stateStream.listen(_onStateChanged);
    _connectionRequestSubscription = _nearbyService.connectionRequestStream
        .listen(_onConnectionRequest);

    notifyListeners();
    return true;
  }

  /// Disable remote control
  Future<void> disable() async {
    await _commandSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _connectionRequestSubscription?.cancel();
    _commandSubscription = null;
    _stateSubscription = null;
    _connectionRequestSubscription = null;

    if (_mode == RemoteControlMode.viewer) {
      await _nearbyService.stopAdvertising();
    } else if (_mode == RemoteControlMode.relay) {
      await _nearbyService.stopDiscovery();
    }

    await _nearbyService.stopAllEndpoints();

    _mode = RemoteControlMode.standalone;
    _isEnabled = false;
    _lastError = null;
    notifyListeners();
  }

  /// Connect to a discovered viewer (relay mode)
  Future<bool> connectToViewer(String endpointId) async {
    if (_mode != RemoteControlMode.relay) {
      debugPrint('Cannot connect to viewer: not in relay mode');
      return false;
    }

    final success = await _nearbyService.requestConnection(
      endpointId,
      displayName: _deviceName,
    );
    notifyListeners();
    return success;
  }

  /// Disconnect from a viewer
  Future<void> disconnectFromViewer(String endpointId) async {
    await _nearbyService.disconnectFromEndpoint(endpointId);
    notifyListeners();
  }

  // Relay mode: Send commands to connected viewers

  /// Send next page command (relay mode)
  Future<void> sendNextPage() async {
    if (_mode != RemoteControlMode.relay || !_nearbyService.isConnected) return;
    await _nearbyService.broadcastCommand(RemoteCommand.nextPage());
  }

  /// Send previous page command (relay mode)
  Future<void> sendPreviousPage() async {
    if (_mode != RemoteControlMode.relay || !_nearbyService.isConnected) return;
    await _nearbyService.broadcastCommand(RemoteCommand.prevPage());
  }

  /// Send go to page command (relay mode)
  Future<void> sendGoToPage(int page) async {
    if (_mode != RemoteControlMode.relay || !_nearbyService.isConnected) return;
    await _nearbyService.broadcastCommand(RemoteCommand.gotoPage(page));
  }

  /// Send toggle play command (relay mode)
  Future<void> sendTogglePlay() async {
    if (_mode != RemoteControlMode.relay || !_nearbyService.isConnected) return;
    await _nearbyService.broadcastCommand(RemoteCommand.togglePlay());
  }

  /// Request status from viewer (relay mode)
  Future<void> requestStatus() async {
    if (_mode != RemoteControlMode.relay || !_nearbyService.isConnected) return;
    await _nearbyService.broadcastCommand(RemoteCommand.getStatus());
  }

  // Viewer mode: Handle incoming commands

  void _handleCommand((String endpointId, RemoteCommand command) data) {
    final (endpointId, command) = data;
    debugPrint('Handling command from $endpointId: ${command.type.value}');

    switch (command.type) {
      case RemoteCommandType.nextPage:
        _appState.nextPage();
        _sendAck(endpointId, command.id);
        break;

      case RemoteCommandType.prevPage:
        _appState.previousPage();
        _sendAck(endpointId, command.id);
        break;

      case RemoteCommandType.gotoPage:
        final page = command.page;
        if (page != null && page > 0) {
          _appState.goToPage(page - 1); // Convert to 0-indexed
          _sendAck(endpointId, command.id);
        } else {
          _sendError(endpointId, command.id, RemoteErrorCode.invalidPayload);
        }
        break;

      case RemoteCommandType.togglePlay:
        // TODO: Implement auto-scroll/playback toggle
        _sendAck(endpointId, command.id);
        break;

      case RemoteCommandType.getStatus:
        _sendStatus(endpointId, command.id);
        break;

      case RemoteCommandType.selectSong:
        final songId = command.songId;
        if (songId != null) {
          final song = _appState.songs.firstWhere(
            (s) => s.id == songId,
            orElse: () => _appState.songs.first,
          );
          _appState.selectSong(song);
          _sendAck(endpointId, command.id);
        } else {
          _sendError(endpointId, command.id, RemoteErrorCode.invalidPayload);
        }
        break;

      case RemoteCommandType.getSongList:
        _sendSongList(endpointId, command.id);
        break;

      // Response types - these are handled by the relay, not the viewer
      case RemoteCommandType.status:
      case RemoteCommandType.songList:
      case RemoteCommandType.ack:
      case RemoteCommandType.error:
        // Ignore responses in viewer mode
        break;
    }
  }

  void _sendAck(String endpointId, String requestId) {
    _nearbyService.sendCommand(
      endpointId,
      RemoteCommand.ack(requestId: requestId, success: true),
    );
  }

  void _sendError(String endpointId, String requestId, String errorCode) {
    _nearbyService.sendCommand(
      endpointId,
      RemoteCommand.error(requestId: requestId, errorCode: errorCode),
    );
  }

  void _sendStatus(String endpointId, String requestId) {
    final song = _appState.currentSong;
    if (song == null) {
      _sendError(endpointId, requestId, RemoteErrorCode.songNotFound);
      return;
    }

    _nearbyService.sendCommand(
      endpointId,
      RemoteCommand.status(
        requestId: requestId,
        currentPage: _appState.currentPageNumber,
        totalPages: _appState.totalPages,
        songId: song.id,
        songName: song.name,
        isPlaying: false, // TODO: track playback state
      ),
    );
  }

  void _sendSongList(String endpointId, String requestId) {
    final songs = _appState.songs
        .map((s) => {'id': s.id, 'name': s.name, 'pageCount': s.pageCount})
        .toList();

    _nearbyService.sendCommand(
      endpointId,
      RemoteCommand.songList(requestId: requestId, songs: songs),
    );
  }

  void _onStateChanged(NearbyConnectionState state) {
    debugPrint('Remote control state changed: $state');
    notifyListeners();
  }

  void _onConnectionRequest((String, dynamic) data) {
    final (endpointId, connectionInfo) = data;
    debugPrint('Connection request from: $endpointId');

    // Auto-accept connections in viewer mode
    if (_mode == RemoteControlMode.viewer) {
      _nearbyService.acceptConnection(endpointId);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    disable();
    _nearbyService.dispose();
    super.dispose();
  }
}
