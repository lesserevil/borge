import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/app_state.dart';
import 'direct_ip_service.dart';
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

/// Connection type for remote control
enum ConnectionType {
  /// Google Nearby Connections (requires BT/WiFi hardware, doesn't work on emulators)
  nearby,

  /// Direct IP/TCP connection (works on emulators, requires manual IP entry)
  directIp,
}

/// Unified connection state (works for both Nearby and Direct IP)
enum RemoteConnectionState {
  disconnected,
  advertising, // Viewer: waiting for connections (Nearby)
  listening, // Viewer: waiting for connections (Direct IP)
  discovering, // Relay: looking for viewers (Nearby only)
  connecting,
  connected,
}

/// Service that integrates Nearby Connections and Direct IP with the app state.
///
/// In viewer mode: Advertises/listens and responds to remote commands (page turns, etc.)
/// In relay mode: Discovers/connects to viewers and forwards Pebble commands to them
class RemoteControlService extends ChangeNotifier {
  final AppState _appState;
  final NearbyConnectionsService _nearbyService;
  final DirectIpService _directIpService;

  RemoteControlMode _mode = RemoteControlMode.standalone;
  ConnectionType _connectionType = ConnectionType.directIp;
  bool _isEnabled = false;
  String _deviceName = 'Borge';
  String? _lastError;
  int? _listeningPort;
  List<String> _localIpAddresses = [];

  // Subscriptions
  StreamSubscription<(String, RemoteCommand)>? _commandSubscription;
  StreamSubscription<dynamic>? _stateSubscription;
  StreamSubscription<(String, dynamic)>? _connectionRequestSubscription;
  StreamSubscription<List<dynamic>>? _connectedSubscription;

  RemoteControlService({
    required AppState appState,
    NearbyConnectionsService? nearbyService,
    DirectIpService? directIpService,
  }) : _appState = appState,
       _nearbyService = nearbyService ?? NearbyConnectionsService(),
       _directIpService = directIpService ?? DirectIpService();

  /// Current operating mode
  RemoteControlMode get mode => _mode;

  /// Current connection type
  ConnectionType get connectionType => _connectionType;

  /// Whether remote control is enabled
  bool get isEnabled => _isEnabled;

  /// Current connection state (unified across connection types)
  RemoteConnectionState get connectionState {
    if (_connectionType == ConnectionType.nearby) {
      switch (_nearbyService.state) {
        case NearbyConnectionState.disconnected:
          return RemoteConnectionState.disconnected;
        case NearbyConnectionState.advertising:
          return RemoteConnectionState.advertising;
        case NearbyConnectionState.discovering:
          return RemoteConnectionState.discovering;
        case NearbyConnectionState.connecting:
          return RemoteConnectionState.connecting;
        case NearbyConnectionState.connected:
          return RemoteConnectionState.connected;
      }
    } else {
      switch (_directIpService.state) {
        case DirectIpConnectionState.disconnected:
          return RemoteConnectionState.disconnected;
        case DirectIpConnectionState.listening:
          return RemoteConnectionState.listening;
        case DirectIpConnectionState.connecting:
          return RemoteConnectionState.connecting;
        case DirectIpConnectionState.connected:
          return RemoteConnectionState.connected;
      }
    }
  }

  /// Whether connected to any endpoints
  bool get isConnected {
    if (_connectionType == ConnectionType.nearby) {
      return _nearbyService.isConnected;
    } else {
      return _directIpService.isConnected;
    }
  }

  /// List of discovered viewers (in relay mode, Nearby only)
  List<DiscoveredEndpoint> get discoveredViewers =>
      _nearbyService.discoveredEndpoints;

  /// List of connected endpoints (Nearby)
  List<ConnectedEndpoint> get connectedEndpoints =>
      _nearbyService.connectedEndpoints;

  /// List of connected endpoints (Direct IP)
  List<IpConnectedEndpoint> get ipConnectedEndpoints =>
      _directIpService.connectedEndpoints;

  /// Device name used for advertising/discovery
  String get deviceName => _deviceName;

  /// Last error message (if any)
  String? get lastError => _lastError;

  /// Port the viewer is listening on (Direct IP mode)
  int? get listeningPort => _listeningPort;

  /// Local IP addresses (for display to user in viewer mode)
  List<String> get localIpAddresses => _localIpAddresses;

  /// Stream of connection state changes (Nearby)
  Stream<NearbyConnectionState> get nearbyStateStream =>
      _nearbyService.stateStream;

  /// Stream of connection state changes (Direct IP)
  Stream<DirectIpConnectionState> get directIpStateStream =>
      _directIpService.stateStream;

  /// Stream of discovered endpoints (Nearby only)
  Stream<List<DiscoveredEndpoint>> get discoveredStream =>
      _nearbyService.discoveredStream;

  /// Stream of connected endpoints (Nearby)
  Stream<List<ConnectedEndpoint>> get connectedStream =>
      _nearbyService.connectedStream;

  /// Stream of connected endpoints (Direct IP)
  Stream<List<IpConnectedEndpoint>> get ipConnectedStream =>
      _directIpService.connectedStream;

  /// Set the device name (before enabling)
  void setDeviceName(String name) {
    _deviceName = name;
    notifyListeners();
  }

  /// Set the connection type (before enabling)
  void setConnectionType(ConnectionType type) {
    if (_isEnabled) {
      debugPrint('Cannot change connection type while enabled');
      return;
    }
    _connectionType = type;
    notifyListeners();
  }

  /// Enable viewer mode (tablet advertises/listens, accepts commands)
  ///
  /// For Nearby: starts advertising
  /// For Direct IP: starts TCP server
  Future<bool> enableViewerMode({int? port}) async {
    if (_isEnabled) {
      await disable();
    }

    _lastError = null;

    if (_connectionType == ConnectionType.nearby) {
      return _enableViewerModeNearby();
    } else {
      return _enableViewerModeDirectIp(
        port: port ?? DirectIpService.defaultPort,
      );
    }
  }

  Future<bool> _enableViewerModeNearby() async {
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
    _stateSubscription = _nearbyService.stateStream.listen(
      (_) => _onStateChanged(),
    );
    _connectionRequestSubscription = _nearbyService.connectionRequestStream
        .listen(_onNearbyConnectionRequest);

    notifyListeners();
    return true;
  }

  Future<bool> _enableViewerModeDirectIp({required int port}) async {
    // Get local IP addresses for display
    _localIpAddresses = await _directIpService.getLocalIpAddresses();

    // Start listening
    final listeningPort = await _directIpService.startListening(
      port: port,
      deviceName: _deviceName,
    );

    if (listeningPort == null) {
      _lastError = 'Failed to start TCP server on port $port';
      notifyListeners();
      return false;
    }

    _listeningPort = listeningPort;
    _mode = RemoteControlMode.viewer;
    _isEnabled = true;

    // Subscribe to incoming commands
    _commandSubscription = _directIpService.commandStream.listen(
      _handleCommand,
    );
    _stateSubscription = _directIpService.stateStream.listen(
      (_) => _onStateChanged(),
    );
    _connectedSubscription = _directIpService.connectedStream.listen(
      (_) => notifyListeners(),
    );

    notifyListeners();
    return true;
  }

  /// Enable relay mode (phone discovers/connects to viewers, forwards commands)
  ///
  /// For Nearby: starts discovery
  /// For Direct IP: does nothing until connectToViewerIp is called
  Future<bool> enableRelayMode() async {
    if (_isEnabled) {
      await disable();
    }

    _lastError = null;

    if (_connectionType == ConnectionType.nearby) {
      return _enableRelayModeNearby();
    } else {
      return _enableRelayModeDirectIp();
    }
  }

  Future<bool> _enableRelayModeNearby() async {
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
    _stateSubscription = _nearbyService.stateStream.listen(
      (_) => _onStateChanged(),
    );
    _connectionRequestSubscription = _nearbyService.connectionRequestStream
        .listen(_onNearbyConnectionRequest);

    notifyListeners();
    return true;
  }

  Future<bool> _enableRelayModeDirectIp() async {
    // Direct IP relay mode just sets up state - connection happens via connectToViewerIp
    _mode = RemoteControlMode.relay;
    _isEnabled = true;

    // Subscribe to incoming commands (for responses from viewer)
    _commandSubscription = _directIpService.commandStream.listen(
      _handleCommand,
    );
    _stateSubscription = _directIpService.stateStream.listen(
      (_) => _onStateChanged(),
    );

    notifyListeners();
    return true;
  }

  /// Disable remote control
  Future<void> disable() async {
    await _commandSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _connectionRequestSubscription?.cancel();
    await _connectedSubscription?.cancel();
    _commandSubscription = null;
    _stateSubscription = null;
    _connectionRequestSubscription = null;
    _connectedSubscription = null;

    if (_connectionType == ConnectionType.nearby) {
      if (_mode == RemoteControlMode.viewer) {
        await _nearbyService.stopAdvertising();
      } else if (_mode == RemoteControlMode.relay) {
        await _nearbyService.stopDiscovery();
      }
      await _nearbyService.stopAllEndpoints();
    } else {
      await _directIpService.stopAll();
    }

    _mode = RemoteControlMode.standalone;
    _isEnabled = false;
    _lastError = null;
    _listeningPort = null;
    _localIpAddresses = [];
    notifyListeners();
  }

  /// Connect to a discovered viewer via Nearby (relay mode)
  Future<bool> connectToViewer(String endpointId) async {
    if (_mode != RemoteControlMode.relay ||
        _connectionType != ConnectionType.nearby) {
      debugPrint('Cannot connect to viewer: not in Nearby relay mode');
      return false;
    }

    final success = await _nearbyService.requestConnection(
      endpointId,
      displayName: _deviceName,
    );
    notifyListeners();
    return success;
  }

  /// Connect to a viewer at a specific IP address (Direct IP relay mode)
  Future<bool> connectToViewerIp({
    required String host,
    int port = DirectIpService.defaultPort,
  }) async {
    if (_mode != RemoteControlMode.relay ||
        _connectionType != ConnectionType.directIp) {
      debugPrint('Cannot connect to viewer IP: not in Direct IP relay mode');
      return false;
    }

    final success = await _directIpService.connect(
      host: host,
      port: port,
      deviceName: _deviceName,
    );

    if (!success) {
      _lastError = 'Failed to connect to $host:$port';
    }

    notifyListeners();
    return success;
  }

  /// Disconnect from a viewer (Nearby)
  Future<void> disconnectFromViewer(String endpointId) async {
    if (_connectionType == ConnectionType.nearby) {
      await _nearbyService.disconnectFromEndpoint(endpointId);
    } else {
      await _directIpService.disconnectClient(endpointId);
    }
    notifyListeners();
  }

  /// Disconnect from viewer (Direct IP client mode)
  Future<void> disconnectFromViewerIp() async {
    await _directIpService.disconnect();
    notifyListeners();
  }

  // Relay mode: Send commands to connected viewers

  /// Send next page command (relay mode)
  Future<void> sendNextPage() async {
    if (_mode != RemoteControlMode.relay || !isConnected) return;
    await _broadcastCommand(RemoteCommand.nextPage());
  }

  /// Send previous page command (relay mode)
  Future<void> sendPreviousPage() async {
    if (_mode != RemoteControlMode.relay || !isConnected) return;
    await _broadcastCommand(RemoteCommand.prevPage());
  }

  /// Send go to page command (relay mode)
  Future<void> sendGoToPage(int page) async {
    if (_mode != RemoteControlMode.relay || !isConnected) return;
    await _broadcastCommand(RemoteCommand.gotoPage(page));
  }

  /// Send toggle play command (relay mode)
  Future<void> sendTogglePlay() async {
    if (_mode != RemoteControlMode.relay || !isConnected) return;
    await _broadcastCommand(RemoteCommand.togglePlay());
  }

  /// Request status from viewer (relay mode)
  Future<void> requestStatus() async {
    if (_mode != RemoteControlMode.relay || !isConnected) return;
    await _broadcastCommand(RemoteCommand.getStatus());
  }

  Future<void> _broadcastCommand(RemoteCommand command) async {
    if (_connectionType == ConnectionType.nearby) {
      await _nearbyService.broadcastCommand(command);
    } else {
      await _directIpService.broadcastCommand(command);
    }
  }

  Future<void> _sendCommand(String endpointId, RemoteCommand command) async {
    if (_connectionType == ConnectionType.nearby) {
      await _nearbyService.sendCommand(endpointId, command);
    } else {
      await _directIpService.sendCommand(endpointId, command);
    }
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
    _sendCommand(
      endpointId,
      RemoteCommand.ack(requestId: requestId, success: true),
    );
  }

  void _sendError(String endpointId, String requestId, String errorCode) {
    _sendCommand(
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

    _sendCommand(
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

    _sendCommand(
      endpointId,
      RemoteCommand.songList(requestId: requestId, songs: songs),
    );
  }

  void _onStateChanged() {
    debugPrint('Remote control state changed: $connectionState');
    notifyListeners();
  }

  void _onNearbyConnectionRequest((String, dynamic) data) {
    final (endpointId, _) = data;
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
    _directIpService.dispose();
    super.dispose();
  }
}
