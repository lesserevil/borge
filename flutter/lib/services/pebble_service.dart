import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'song_repository.dart';

/// Command types for Pebble communication.
/// Supports both legacy numeric codes (C app) and string commands (Pebble.js).
enum PebbleCommand {
  getList(1, 'GET_LIST'),
  selectSong(2, 'SELECT_SONG'),
  nextPage(3, 'NEXT_PAGE'),
  prevPage(4, 'PREV_PAGE'),
  nextSong(5, 'NEXT_SONG'),
  prevSong(6, 'PREV_SONG'),
  ack(100, 'ACK'),
  listResp(101, 'LIST_RESP'),
  pageLoaded(102, 'PAGE_LOADED'),
  error(255, 'ERROR');

  final int numericValue;
  final String stringValue;
  const PebbleCommand(this.numericValue, this.stringValue);

  /// Parse command from numeric value (legacy C app)
  static PebbleCommand? fromNumeric(int value) {
    for (final cmd in PebbleCommand.values) {
      if (cmd.numericValue == value) return cmd;
    }
    return null;
  }

  /// Parse command from string value (Pebble.js app)
  static PebbleCommand? fromString(String value) {
    final upper = value.toUpperCase();
    for (final cmd in PebbleCommand.values) {
      if (cmd.stringValue == upper) return cmd;
    }
    return null;
  }
}

/// Message key mappings for Pebble communication.
/// Supports both numeric keys (legacy) and string keys (Pebble.js).
class PebbleMessageKey {
  // Numeric keys (legacy C app)
  static const int commandNum = 0;
  static const int songIdNum = 1;
  static const int songNameNum = 2;
  static const int pageNumNum = 3;
  static const int pageCountNum = 4;
  static const int songCountNum = 5;
  static const int songIndexNum = 6;

  // String keys (Pebble.js app)
  static const String command = 'cmd';
  static const String songId = 'songId';
  static const String songName = 'songName';
  static const String pageNum = 'pageNum';
  static const String pageCount = 'pageCount';
  static const String songCount = 'songCount';
  static const String songIndex = 'songIndex';
}

/// Callback type for when Pebble commands are received.
/// Used for relay mode to forward commands to tablet.
typedef PebbleCommandCallback =
    void Function(PebbleCommand command, Map<String, dynamic> data);

/// Service for communicating with Pebble watch apps.
///
/// Supports both:
/// - Legacy C app: Uses numeric command codes and keys
/// - Pebble.js app: Uses string command names and keys
///
/// The service can operate in two modes:
/// 1. Direct mode: Commands control local song repository
/// 2. Relay mode: Commands are forwarded via callback to RemoteControlService
class PebbleService {
  final SongRepository _songRepository;
  HttpServer? _server;

  int _currentSongIndex = 0;
  int _currentPage = 1;
  String? _currentSongId;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Callback for relay mode - when set, commands are forwarded here
  /// instead of being handled locally
  PebbleCommandCallback? onCommandReceived;

  bool get isRunning => _server != null;
  String? get serverUrl =>
      _server != null ? 'ws://${_server!.address.host}:${_server!.port}' : null;

  final Set<WebSocket> _clients = {};
  int get clientCount => _clients.length;

  PebbleService({required SongRepository songRepository})
    : _songRepository = songRepository;

  Future<void> start({int port = 9000, String host = '0.0.0.0'}) async {
    if (_server != null) return;

    _server = await HttpServer.bind(host, port);
    debugPrint('PebbleService started on ws://$host:$port');

    _server!.transform(WebSocketTransformer()).listen(_handleWebSocket);
  }

  Future<void> stop() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    debugPrint('PebbleService stopped');
  }

  void _handleWebSocket(WebSocket socket) {
    _clients.add(socket);
    _connectionController.add(true);
    debugPrint('Pebble client connected. Total clients: ${_clients.length}');

    socket.listen(
      (data) => _handleMessage(socket, data),
      onDone: () {
        _clients.remove(socket);
        _connectionController.add(_clients.isNotEmpty);
        debugPrint(
          'Pebble client disconnected. Total clients: ${_clients.length}',
        );
      },
      onError: (error) {
        _clients.remove(socket);
        debugPrint('Pebble client error: $error');
      },
    );
  }

  void _handleMessage(WebSocket socket, dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      debugPrint('Received Pebble message: $message');

      final command = _parseCommand(message);
      if (command == null) {
        debugPrint('Unknown command in message');
        return;
      }

      // If in relay mode, forward the command
      if (onCommandReceived != null) {
        onCommandReceived!(command, message);
        return;
      }

      // Otherwise, handle locally
      _handleCommand(socket, command, message);
    } catch (e) {
      debugPrint('Error handling Pebble message: $e');
      _sendError(socket);
    }
  }

  /// Parse command from message, supporting both numeric and string formats
  PebbleCommand? _parseCommand(Map<String, dynamic> message) {
    // Try Pebble.js string format first (more common going forward)
    final stringCmd = message[PebbleMessageKey.command] as String?;
    if (stringCmd != null) {
      return PebbleCommand.fromString(stringCmd);
    }

    // Try legacy numeric format
    final numericCmd = message[PebbleMessageKey.commandNum.toString()] as int?;
    if (numericCmd != null) {
      return PebbleCommand.fromNumeric(numericCmd);
    }

    // Try alternate numeric key format
    final altNumericCmd = message['KEY_COMMAND'] as int?;
    if (altNumericCmd != null) {
      return PebbleCommand.fromNumeric(altNumericCmd);
    }

    return null;
  }

  /// Extract song ID from message
  String? _extractSongId(Map<String, dynamic> message) {
    return message[PebbleMessageKey.songId] as String? ??
        message[PebbleMessageKey.songIdNum.toString()] as String? ??
        message['KEY_SONG_ID'] as String?;
  }

  void _handleCommand(
    WebSocket socket,
    PebbleCommand command,
    Map<String, dynamic> message,
  ) {
    switch (command) {
      case PebbleCommand.getList:
        _handleGetList(socket);
        break;
      case PebbleCommand.selectSong:
        final songId = _extractSongId(message);
        _handleSelectSong(socket, songId);
        break;
      case PebbleCommand.nextPage:
        _handleNextPage(socket);
        break;
      case PebbleCommand.prevPage:
        _handlePrevPage(socket);
        break;
      case PebbleCommand.nextSong:
        _handleNextSong(socket);
        break;
      case PebbleCommand.prevSong:
        _handlePrevSong(socket);
        break;
      default:
        break;
    }
  }

  void _handleGetList(WebSocket socket) {
    final songs = _songRepository.songs;
    if (songs.isEmpty) {
      _sendError(socket);
      return;
    }

    _currentSongIndex = 0;
    final song = songs[_currentSongIndex];
    _currentSongId = song.id;

    _sendListResponse(socket, song, _currentSongIndex, songs.length);
  }

  void _handleSelectSong(WebSocket socket, String? songId) {
    final id = songId ?? _currentSongId;
    if (id == null) {
      _sendError(socket);
      return;
    }

    final song = _songRepository.getSongById(id);
    if (song == null || !song.hasPages) {
      _sendError(socket);
      return;
    }

    _currentSongId = id;
    _currentPage = 1;

    _sendPageLoaded(socket, _currentPage, song.pageCount);
  }

  void _handleNextPage(WebSocket socket) {
    if (_currentSongId == null) {
      _sendError(socket);
      return;
    }

    final song = _songRepository.getSongById(_currentSongId!);
    if (song == null) {
      _sendError(socket);
      return;
    }

    if (_currentPage < song.pageCount) {
      _currentPage++;
      _sendPageLoaded(socket, _currentPage, song.pageCount);
    } else {
      _sendAck(socket);
    }
  }

  void _handlePrevPage(WebSocket socket) {
    if (_currentSongId == null) {
      _sendError(socket);
      return;
    }

    final song = _songRepository.getSongById(_currentSongId!);
    if (song == null) {
      _sendError(socket);
      return;
    }

    if (_currentPage > 1) {
      _currentPage--;
      _sendPageLoaded(socket, _currentPage, song.pageCount);
    } else {
      _sendAck(socket);
    }
  }

  void _handleNextSong(WebSocket socket) {
    final songs = _songRepository.songs;
    if (songs.isEmpty) {
      _sendError(socket);
      return;
    }

    if (_currentSongIndex < songs.length - 1) {
      _currentSongIndex++;
    } else {
      _currentSongIndex = 0;
    }

    final song = songs[_currentSongIndex];
    _currentSongId = song.id;

    _sendListResponse(socket, song, _currentSongIndex, songs.length);
  }

  void _handlePrevSong(WebSocket socket) {
    final songs = _songRepository.songs;
    if (songs.isEmpty) {
      _sendError(socket);
      return;
    }

    if (_currentSongIndex > 0) {
      _currentSongIndex--;
    } else {
      _currentSongIndex = songs.length - 1;
    }

    final song = songs[_currentSongIndex];
    _currentSongId = song.id;

    _sendListResponse(socket, song, _currentSongIndex, songs.length);
  }

  /// Send a response in both legacy and Pebble.js formats
  void _sendMessage(WebSocket socket, Map<String, dynamic> message) {
    socket.add(jsonEncode(message));
  }

  void _sendListResponse(WebSocket socket, dynamic song, int index, int total) {
    // Send in Pebble.js format (also compatible with legacy via dual keys)
    _sendMessage(socket, {
      // Pebble.js format
      PebbleMessageKey.command: PebbleCommand.listResp.stringValue,
      PebbleMessageKey.songId: song.id,
      PebbleMessageKey.songName: _truncate(song.name, 60),
      PebbleMessageKey.songCount: total,
      PebbleMessageKey.songIndex: index,
      PebbleMessageKey.pageCount: song.pageCount,
      // Legacy format (for backwards compatibility)
      PebbleMessageKey.commandNum.toString():
          PebbleCommand.listResp.numericValue,
      PebbleMessageKey.songIdNum.toString(): song.id,
      PebbleMessageKey.songNameNum.toString(): _truncate(song.name, 60),
      PebbleMessageKey.songCountNum.toString(): total,
      PebbleMessageKey.songIndexNum.toString(): index,
      PebbleMessageKey.pageCountNum.toString(): song.pageCount,
    });
  }

  void _sendPageLoaded(WebSocket socket, int page, int total) {
    _sendMessage(socket, {
      // Pebble.js format
      PebbleMessageKey.command: PebbleCommand.pageLoaded.stringValue,
      PebbleMessageKey.pageNum: page,
      PebbleMessageKey.pageCount: total,
      // Legacy format
      PebbleMessageKey.commandNum.toString():
          PebbleCommand.pageLoaded.numericValue,
      PebbleMessageKey.pageNumNum.toString(): page,
      PebbleMessageKey.pageCountNum.toString(): total,
    });
  }

  void _sendAck(WebSocket socket) {
    _sendMessage(socket, {
      PebbleMessageKey.command: PebbleCommand.ack.stringValue,
      PebbleMessageKey.commandNum.toString(): PebbleCommand.ack.numericValue,
    });
  }

  void _sendError(WebSocket socket) {
    _sendMessage(socket, {
      PebbleMessageKey.command: PebbleCommand.error.stringValue,
      PebbleMessageKey.commandNum.toString(): PebbleCommand.error.numericValue,
    });
  }

  String _truncate(String s, int maxLength) {
    if (s.length <= maxLength) return s;
    return '${s.substring(0, maxLength - 3)}...';
  }

  /// Broadcast page change to all connected Pebble clients
  void broadcastPageChange(int pageNumber) {
    if (_currentSongId == null) return;
    final song = _songRepository.getSongById(_currentSongId!);
    if (song == null) return;

    _currentPage = pageNumber;

    for (final client in _clients) {
      _sendPageLoaded(client, _currentPage, song.pageCount);
    }
  }

  /// Broadcast song change to all connected Pebble clients
  void broadcastSongChange(String songId, String songName, int pageCount) {
    _currentSongId = songId;
    _currentPage = 1;

    for (final client in _clients) {
      _sendMessage(client, {
        PebbleMessageKey.command: PebbleCommand.pageLoaded.stringValue,
        PebbleMessageKey.pageNum: 1,
        PebbleMessageKey.pageCount: pageCount,
        PebbleMessageKey.commandNum.toString():
            PebbleCommand.pageLoaded.numericValue,
        PebbleMessageKey.pageNumNum.toString(): 1,
        PebbleMessageKey.pageCountNum.toString(): pageCount,
      });
    }
  }

  void dispose() {
    _connectionController.close();
    stop();
  }
}
