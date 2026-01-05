import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'remote_command.dart';

/// Connection state for Nearby Connections
enum NearbyConnectionState {
  disconnected,
  advertising,
  discovering,
  connecting,
  connected,
}

/// Information about a discovered endpoint
class DiscoveredEndpoint {
  final String id;
  final String name;
  final String serviceId;

  const DiscoveredEndpoint({
    required this.id,
    required this.name,
    required this.serviceId,
  });

  @override
  String toString() => 'DiscoveredEndpoint(id: $id, name: $name)';
}

/// Information about a connected endpoint
class ConnectedEndpoint {
  final String id;
  final String name;

  const ConnectedEndpoint({required this.id, required this.name});

  @override
  String toString() => 'ConnectedEndpoint(id: $id, name: $name)';
}

/// Service for device-to-device communication via Google Nearby Connections.
///
/// This service enables:
/// - Advertising as a viewer (tablet mode)
/// - Discovering viewers (phone relay mode)
/// - Establishing encrypted, low-latency connections
/// - Sending and receiving [RemoteCommand] messages
///
/// Architecture:
/// ```
/// [Pebble Watch] <--BT--> [Phone Relay] <--Nearby--> [Tablet Viewer]
/// ```
class NearbyConnectionsService {
  /// Service ID for identifying our app's Nearby Connections
  static const String serviceId = 'com.borge.sheetmusic.nearby';

  /// Strategy for connection type (P2P_CLUSTER for multi-device support)
  static const Strategy strategy = Strategy.P2P_CLUSTER;

  final Nearby _nearby = Nearby();

  // State
  NearbyConnectionState _state = NearbyConnectionState.disconnected;
  final Map<String, DiscoveredEndpoint> _discoveredEndpoints = {};
  final Map<String, ConnectedEndpoint> _connectedEndpoints = {};
  String? _localEndpointName;

  // Stream controllers
  final _stateController = StreamController<NearbyConnectionState>.broadcast();
  final _discoveredController =
      StreamController<List<DiscoveredEndpoint>>.broadcast();
  final _connectedController =
      StreamController<List<ConnectedEndpoint>>.broadcast();
  final _commandController =
      StreamController<(String, RemoteCommand)>.broadcast();
  final _connectionRequestController =
      StreamController<(String, ConnectionInfo)>.broadcast();

  /// Current connection state
  NearbyConnectionState get state => _state;

  /// Stream of connection state changes
  Stream<NearbyConnectionState> get stateStream => _stateController.stream;

  /// Currently discovered endpoints
  List<DiscoveredEndpoint> get discoveredEndpoints =>
      _discoveredEndpoints.values.toList();

  /// Stream of discovered endpoints changes
  Stream<List<DiscoveredEndpoint>> get discoveredStream =>
      _discoveredController.stream;

  /// Currently connected endpoints
  List<ConnectedEndpoint> get connectedEndpoints =>
      _connectedEndpoints.values.toList();

  /// Stream of connected endpoints changes
  Stream<List<ConnectedEndpoint>> get connectedStream =>
      _connectedController.stream;

  /// Stream of incoming commands (endpointId, command)
  Stream<(String, RemoteCommand)> get commandStream =>
      _commandController.stream;

  /// Stream of incoming connection requests (endpointId, connectionInfo)
  Stream<(String, ConnectionInfo)> get connectionRequestStream =>
      _connectionRequestController.stream;

  /// Whether any endpoints are connected
  bool get isConnected => _connectedEndpoints.isNotEmpty;

  /// Check and request all required permissions for Nearby Connections.
  ///
  /// Returns true if all permissions are granted.
  Future<bool> checkAndRequestPermissions() async {
    if (kIsWeb) {
      // Nearby Connections not available on web
      return false;
    }

    if (!Platform.isAndroid) {
      // Currently only supporting Android
      debugPrint('Nearby Connections only supported on Android');
      return false;
    }

    // Check location permission (required for BT/WiFi scanning)
    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        debugPrint('Location permission denied');
        if (locationStatus.isPermanentlyDenied) {
          await openAppSettings();
        }
        return false;
      }
    }

    // Check Bluetooth permissions (Android 12+)
    if (await _isAndroid12OrHigher()) {
      final bluetoothPermissions = [
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ];

      for (final permission in bluetoothPermissions) {
        var status = await permission.status;
        if (!status.isGranted) {
          status = await permission.request();
          if (!status.isGranted) {
            debugPrint('Bluetooth permission denied: $permission');
            return false;
          }
        }
      }
    }

    // Check WiFi permissions (Android 13+)
    if (await _isAndroid13OrHigher()) {
      var nearbyWifiStatus = await Permission.nearbyWifiDevices.status;
      if (!nearbyWifiStatus.isGranted) {
        nearbyWifiStatus = await Permission.nearbyWifiDevices.request();
        if (!nearbyWifiStatus.isGranted) {
          debugPrint('Nearby WiFi devices permission denied');
          return false;
        }
      }
    }

    debugPrint('All Nearby Connections permissions granted');
    return true;
  }

  Future<bool> _isAndroid12OrHigher() async {
    // Android 12 is API level 31
    // The nearby_connections plugin handles this internally, but we check for permission requests
    return Platform.isAndroid;
  }

  Future<bool> _isAndroid13OrHigher() async {
    // Android 13 is API level 33
    return Platform.isAndroid;
  }

  /// Start advertising as a viewer (tablet mode).
  ///
  /// Other devices running in discovery mode will be able to find this device.
  /// [deviceName] is the name shown to discoverers.
  Future<bool> startAdvertising(String deviceName) async {
    if (_state != NearbyConnectionState.disconnected) {
      debugPrint('Cannot start advertising: already in state $_state');
      return false;
    }

    try {
      _localEndpointName = deviceName;

      final result = await _nearby.startAdvertising(
        deviceName,
        strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId,
      );

      if (result) {
        _setState(NearbyConnectionState.advertising);
        debugPrint('Started advertising as: $deviceName');
      }
      return result;
    } catch (e) {
      debugPrint('Error starting advertising: $e');
      return false;
    }
  }

  /// Stop advertising.
  Future<void> stopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
      if (_state == NearbyConnectionState.advertising) {
        _setState(NearbyConnectionState.disconnected);
      }
      debugPrint('Stopped advertising');
    } catch (e) {
      debugPrint('Error stopping advertising: $e');
    }
  }

  /// Start discovering nearby advertisers (phone relay mode).
  ///
  /// Discovered devices will be emitted via [discoveredStream].
  Future<bool> startDiscovery() async {
    if (_state != NearbyConnectionState.disconnected) {
      debugPrint('Cannot start discovery: already in state $_state');
      return false;
    }

    try {
      final result = await _nearby.startDiscovery(
        _localEndpointName ?? 'BorgeRelay',
        strategy,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
        serviceId: serviceId,
      );

      if (result) {
        _setState(NearbyConnectionState.discovering);
        debugPrint('Started discovery');
      }
      return result;
    } catch (e) {
      debugPrint('Error starting discovery: $e');
      return false;
    }
  }

  /// Stop discovery.
  Future<void> stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
      _discoveredEndpoints.clear();
      _discoveredController.add([]);
      if (_state == NearbyConnectionState.discovering) {
        _setState(NearbyConnectionState.disconnected);
      }
      debugPrint('Stopped discovery');
    } catch (e) {
      debugPrint('Error stopping discovery: $e');
    }
  }

  /// Request a connection to a discovered endpoint.
  Future<bool> requestConnection(
    String endpointId, {
    String? displayName,
  }) async {
    try {
      _setState(NearbyConnectionState.connecting);

      final result = await _nearby.requestConnection(
        displayName ?? _localEndpointName ?? 'BorgeRelay',
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );

      if (!result) {
        _setState(NearbyConnectionState.discovering);
      }
      return result;
    } catch (e) {
      debugPrint('Error requesting connection: $e');
      _setState(NearbyConnectionState.discovering);
      return false;
    }
  }

  /// Accept an incoming connection request.
  Future<bool> acceptConnection(String endpointId) async {
    try {
      final result = await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (endpointId, payload) =>
            _onPayloadReceived(endpointId, payload),
        onPayloadTransferUpdate: _onPayloadTransferUpdate,
      );
      return result;
    } catch (e) {
      debugPrint('Error accepting connection: $e');
      return false;
    }
  }

  /// Reject an incoming connection request.
  Future<bool> rejectConnection(String endpointId) async {
    try {
      final result = await _nearby.rejectConnection(endpointId);
      return result;
    } catch (e) {
      debugPrint('Error rejecting connection: $e');
      return false;
    }
  }

  /// Disconnect from a specific endpoint.
  Future<void> disconnectFromEndpoint(String endpointId) async {
    try {
      await _nearby.disconnectFromEndpoint(endpointId);
      _connectedEndpoints.remove(endpointId);
      _connectedController.add(connectedEndpoints);

      if (_connectedEndpoints.isEmpty) {
        _setState(NearbyConnectionState.disconnected);
      }
    } catch (e) {
      debugPrint('Error disconnecting from endpoint: $e');
    }
  }

  /// Disconnect from all endpoints and stop all activity.
  Future<void> stopAllEndpoints() async {
    try {
      await _nearby.stopAllEndpoints();
      _connectedEndpoints.clear();
      _discoveredEndpoints.clear();
      _connectedController.add([]);
      _discoveredController.add([]);
      _setState(NearbyConnectionState.disconnected);
    } catch (e) {
      debugPrint('Error stopping all endpoints: $e');
    }
  }

  /// Send a command to a connected endpoint.
  Future<bool> sendCommand(String endpointId, RemoteCommand command) async {
    if (!_connectedEndpoints.containsKey(endpointId)) {
      debugPrint('Cannot send command: endpoint $endpointId not connected');
      return false;
    }

    try {
      await _nearby.sendBytesPayload(
        endpointId,
        Uint8List.fromList(command.toBytes()),
      );
      debugPrint('Sent command to $endpointId: ${command.type.value}');
      return true;
    } catch (e) {
      debugPrint('Error sending command: $e');
      return false;
    }
  }

  /// Send a command to all connected endpoints.
  Future<void> broadcastCommand(RemoteCommand command) async {
    for (final endpointId in _connectedEndpoints.keys) {
      await sendCommand(endpointId, command);
    }
  }

  // Callbacks

  void _onEndpointFound(
    String endpointId,
    String endpointName,
    String serviceId,
  ) {
    debugPrint('Endpoint found: $endpointName ($endpointId)');

    _discoveredEndpoints[endpointId] = DiscoveredEndpoint(
      id: endpointId,
      name: endpointName,
      serviceId: serviceId,
    );
    _discoveredController.add(discoveredEndpoints);
  }

  void _onEndpointLost(String? endpointId) {
    if (endpointId != null) {
      debugPrint('Endpoint lost: $endpointId');
      _discoveredEndpoints.remove(endpointId);
      _discoveredController.add(discoveredEndpoints);
    }
  }

  void _onConnectionInitiated(
    String endpointId,
    ConnectionInfo connectionInfo,
  ) {
    debugPrint(
      'Connection initiated from: ${connectionInfo.endpointName} ($endpointId)',
    );

    // Emit to stream so UI can show accept/reject dialog or auto-accept
    _connectionRequestController.add((endpointId, connectionInfo));
  }

  void _onConnectionResult(String endpointId, Status status) {
    debugPrint('Connection result for $endpointId: ${status.name}');

    if (status == Status.CONNECTED) {
      // Find the endpoint name from discovered endpoints or use a default
      final discovered = _discoveredEndpoints[endpointId];
      final name = discovered?.name ?? 'Unknown';

      _connectedEndpoints[endpointId] = ConnectedEndpoint(
        id: endpointId,
        name: name,
      );
      _connectedController.add(connectedEndpoints);
      _setState(NearbyConnectionState.connected);

      debugPrint('Connected to: $name ($endpointId)');
    } else {
      debugPrint('Connection failed: ${status.name}');

      if (_connectedEndpoints.isEmpty) {
        // If we were discovering, go back to discovering state
        if (_state == NearbyConnectionState.connecting) {
          _setState(NearbyConnectionState.discovering);
        }
      }
    }
  }

  void _onDisconnected(String endpointId) {
    debugPrint('Disconnected from: $endpointId');

    _connectedEndpoints.remove(endpointId);
    _connectedController.add(connectedEndpoints);

    if (_connectedEndpoints.isEmpty) {
      _setState(NearbyConnectionState.disconnected);
    }
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      final command = RemoteCommand.fromBytes(payload.bytes!);
      if (command != null) {
        debugPrint('Received command from $endpointId: ${command.type.value}');
        _commandController.add((endpointId, command));
      } else {
        debugPrint('Failed to parse command from $endpointId');
      }
    }
  }

  void _onPayloadTransferUpdate(
    String endpointId,
    PayloadTransferUpdate update,
  ) {
    // For byte payloads, this is called once with SUCCESS
    // Could be used for progress tracking with file transfers
    if (update.status == PayloadStatus.SUCCESS) {
      debugPrint('Payload transfer complete for $endpointId');
    } else if (update.status == PayloadStatus.FAILURE) {
      debugPrint('Payload transfer failed for $endpointId');
    }
  }

  void _setState(NearbyConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      debugPrint('Nearby state changed to: $newState');
    }
  }

  /// Dispose of resources.
  void dispose() {
    stopAllEndpoints();
    _stateController.close();
    _discoveredController.close();
    _connectedController.close();
    _commandController.close();
    _connectionRequestController.close();
  }
}
