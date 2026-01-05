import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'remote_command.dart';

/// Connection state for direct IP connections
enum DirectIpConnectionState { disconnected, listening, connecting, connected }

/// Information about a connected endpoint over IP
class IpConnectedEndpoint {
  final String id;
  final String name;
  final String address;
  final int port;

  const IpConnectedEndpoint({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
  });

  @override
  String toString() => 'IpConnectedEndpoint(name: $name, $address:$port)';
}

/// Service for direct IP-based device-to-device communication.
///
/// This provides a fallback when Nearby Connections isn't available
/// (e.g., on emulators, or when Nearby fails).
///
/// Architecture:
/// - Viewer (tablet): Runs a TCP server, listens for connections
/// - Relay (phone): Connects to viewer's IP address as TCP client
///
/// Protocol:
/// - Each message is a newline-delimited JSON object
/// - Uses the same [RemoteCommand] format as Nearby Connections
class DirectIpService {
  /// Default port for the TCP server
  static const int defaultPort = 9876;

  // State
  DirectIpConnectionState _state = DirectIpConnectionState.disconnected;
  ServerSocket? _server;
  Socket? _clientSocket;
  final Map<String, _ClientConnection> _connectedClients = {};
  String _localName = 'Borge';

  // Stream controllers
  final _stateController =
      StreamController<DirectIpConnectionState>.broadcast();
  final _connectedController =
      StreamController<List<IpConnectedEndpoint>>.broadcast();
  final _commandController =
      StreamController<(String, RemoteCommand)>.broadcast();

  /// Current connection state
  DirectIpConnectionState get state => _state;

  /// Stream of connection state changes
  Stream<DirectIpConnectionState> get stateStream => _stateController.stream;

  /// Currently connected endpoints
  List<IpConnectedEndpoint> get connectedEndpoints => _connectedClients.values
      .map(
        (c) => IpConnectedEndpoint(
          id: c.id,
          name: c.name,
          address: c.address,
          port: c.port,
        ),
      )
      .toList();

  /// Stream of connected endpoints changes
  Stream<List<IpConnectedEndpoint>> get connectedStream =>
      _connectedController.stream;

  /// Stream of incoming commands (endpointId, command)
  Stream<(String, RemoteCommand)> get commandStream =>
      _commandController.stream;

  /// Whether any endpoints are connected
  bool get isConnected => _connectedClients.isNotEmpty || _clientSocket != null;

  /// Get the local IP addresses of this device
  Future<List<String>> getLocalIpAddresses() async {
    final addresses = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            addresses.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting local IPs: $e');
    }
    return addresses;
  }

  /// Start listening as a viewer (tablet mode).
  ///
  /// Returns the port number if successful, null otherwise.
  Future<int?> startListening({
    int port = defaultPort,
    String? deviceName,
  }) async {
    if (_state != DirectIpConnectionState.disconnected) {
      debugPrint('Cannot start listening: already in state $_state');
      return null;
    }

    _localName = deviceName ?? 'Borge';

    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );

      _setState(DirectIpConnectionState.listening);
      debugPrint('Direct IP server listening on port ${_server!.port}');

      _server!.listen(
        _onClientConnected,
        onError: (e) {
          debugPrint('Server error: $e');
        },
        onDone: () {
          debugPrint('Server closed');
          _setState(DirectIpConnectionState.disconnected);
        },
      );

      return _server!.port;
    } catch (e) {
      debugPrint('Error starting server: $e');
      return null;
    }
  }

  /// Stop listening for connections.
  Future<void> stopListening() async {
    try {
      // Disconnect all clients
      for (final client in _connectedClients.values.toList()) {
        await _disconnectClient(client.id);
      }

      await _server?.close();
      _server = null;

      if (_state == DirectIpConnectionState.listening) {
        _setState(DirectIpConnectionState.disconnected);
      }
      debugPrint('Stopped listening');
    } catch (e) {
      debugPrint('Error stopping server: $e');
    }
  }

  /// Connect to a viewer at the specified IP address (relay mode).
  Future<bool> connect({
    required String host,
    int port = defaultPort,
    String? deviceName,
  }) async {
    if (_clientSocket != null) {
      debugPrint('Already connected');
      return true;
    }

    _localName = deviceName ?? 'BorgeRelay';
    _setState(DirectIpConnectionState.connecting);

    try {
      _clientSocket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );

      final endpointId =
          '${_clientSocket!.remoteAddress.address}:${_clientSocket!.remotePort}';
      debugPrint('Connected to $host:$port (id: $endpointId)');

      // Send handshake
      _sendRaw(_clientSocket!, {'type': 'handshake', 'name': _localName});

      // Listen for messages
      _clientSocket!
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) => _handleMessage(endpointId, line),
            onError: (e) {
              debugPrint('Socket error: $e');
              disconnect();
            },
            onDone: () {
              debugPrint('Socket closed');
              disconnect();
            },
          );

      _setState(DirectIpConnectionState.connected);
      return true;
    } catch (e) {
      debugPrint('Error connecting: $e');
      _clientSocket = null;
      _setState(DirectIpConnectionState.disconnected);
      return false;
    }
  }

  /// Disconnect from the viewer (relay mode).
  Future<void> disconnect() async {
    try {
      await _clientSocket?.close();
      _clientSocket = null;
      _setState(DirectIpConnectionState.disconnected);
      debugPrint('Disconnected from viewer');
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  /// Disconnect a specific client (viewer mode).
  Future<void> disconnectClient(String endpointId) async {
    await _disconnectClient(endpointId);
  }

  /// Stop all connections.
  Future<void> stopAll() async {
    await disconnect();
    await stopListening();
  }

  /// Send a command to a connected endpoint.
  Future<bool> sendCommand(String endpointId, RemoteCommand command) async {
    // If we're a client (relay mode), send to server
    if (_clientSocket != null) {
      _sendRaw(_clientSocket!, {
        'type': 'command',
        'command': jsonDecode(command.toJson()),
      });
      debugPrint('Sent command to viewer: ${command.type.value}');
      return true;
    }

    // If we're a server (viewer mode), send to specific client
    final client = _connectedClients[endpointId];
    if (client == null) {
      debugPrint('Cannot send command: endpoint $endpointId not connected');
      return false;
    }

    _sendRaw(client.socket, {
      'type': 'command',
      'command': jsonDecode(command.toJson()),
    });
    debugPrint('Sent command to $endpointId: ${command.type.value}');
    return true;
  }

  /// Send a command to all connected endpoints.
  Future<void> broadcastCommand(RemoteCommand command) async {
    // If we're a client (relay mode), send to server
    if (_clientSocket != null) {
      _sendRaw(_clientSocket!, {
        'type': 'command',
        'command': jsonDecode(command.toJson()),
      });
      return;
    }

    // If we're a server (viewer mode), send to all clients
    for (final client in _connectedClients.values) {
      _sendRaw(client.socket, {
        'type': 'command',
        'command': jsonDecode(command.toJson()),
      });
    }
  }

  // Private methods

  void _onClientConnected(Socket socket) {
    final address = socket.remoteAddress.address;
    final port = socket.remotePort;
    final endpointId = '$address:$port';

    debugPrint('Client connected: $endpointId');

    final client = _ClientConnection(
      id: endpointId,
      name: 'Unknown',
      address: address,
      port: port,
      socket: socket,
    );

    _connectedClients[endpointId] = client;

    // Send handshake response
    _sendRaw(socket, {'type': 'handshake', 'name': _localName});

    // Listen for messages
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _handleMessage(endpointId, line),
          onError: (e) {
            debugPrint('Client error ($endpointId): $e');
            _disconnectClient(endpointId);
          },
          onDone: () {
            debugPrint('Client disconnected: $endpointId');
            _disconnectClient(endpointId);
          },
        );

    _setState(DirectIpConnectionState.connected);
    _connectedController.add(connectedEndpoints);
  }

  void _handleMessage(String endpointId, String line) {
    try {
      final data = jsonDecode(line) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'handshake':
          final name = data['name'] as String? ?? 'Unknown';
          // Update client name
          final client = _connectedClients[endpointId];
          if (client != null) {
            _connectedClients[endpointId] = _ClientConnection(
              id: client.id,
              name: name,
              address: client.address,
              port: client.port,
              socket: client.socket,
            );
            _connectedController.add(connectedEndpoints);
          }
          debugPrint('Handshake from $endpointId: $name');
          break;

        case 'command':
          final commandData = data['command'] as Map<String, dynamic>?;
          if (commandData != null) {
            final command = RemoteCommand.fromMap(commandData);
            if (command != null) {
              debugPrint(
                'Received command from $endpointId: ${command.type.value}',
              );
              _commandController.add((endpointId, command));
            }
          }
          break;

        default:
          debugPrint('Unknown message type from $endpointId: $type');
      }
    } catch (e) {
      debugPrint('Error parsing message from $endpointId: $e');
    }
  }

  void _sendRaw(Socket socket, Map<String, dynamic> data) {
    try {
      final json = jsonEncode(data);
      socket.writeln(json);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> _disconnectClient(String endpointId) async {
    final client = _connectedClients.remove(endpointId);
    if (client != null) {
      try {
        await client.socket.close();
      } catch (_) {}
      _connectedController.add(connectedEndpoints);

      if (_connectedClients.isEmpty &&
          _state == DirectIpConnectionState.connected) {
        _setState(
          _server != null
              ? DirectIpConnectionState.listening
              : DirectIpConnectionState.disconnected,
        );
      }
    }
  }

  void _setState(DirectIpConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      debugPrint('Direct IP state changed to: $newState');
    }
  }

  /// Dispose of resources.
  void dispose() {
    stopAll();
    _stateController.close();
    _connectedController.close();
    _commandController.close();
  }
}

/// Internal class to track connected clients
class _ClientConnection {
  final String id;
  final String name;
  final String address;
  final int port;
  final Socket socket;

  const _ClientConnection({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.socket,
  });
}
