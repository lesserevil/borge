import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'song_repository.dart';

enum PebbleCommand {
  getList(1),
  selectSong(2),
  nextPage(3),
  prevPage(4),
  nextSong(5),
  prevSong(6),
  ack(100),
  listResp(101),
  pageLoaded(102),
  error(255);

  final int value;
  const PebbleCommand(this.value);

  static PebbleCommand? fromValue(int value) {
    for (final cmd in PebbleCommand.values) {
      if (cmd.value == value) return cmd;
    }
    return null;
  }
}

enum PebbleMessageKey {
  command(0),
  songId(1),
  songName(2),
  pageNum(3),
  pageCount(4),
  songCount(5),
  songIndex(6);

  final int value;
  const PebbleMessageKey(this.value);
}

class PebbleService {
  final SongRepository _songRepository;
  HttpServer? _server;

  int _currentSongIndex = 0;
  int _currentPage = 1;
  String? _currentSongId;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isRunning => _server != null;
  String? get serverUrl => _server != null ? 'ws://${_server!.address.host}:${_server!.port}' : null;

  final Set<WebSocket> _clients = {};

  PebbleService({required SongRepository songRepository})
      : _songRepository = songRepository;

  Future<void> start({int port = 9000, String host = '0.0.0.0'}) async {
    if (_server != null) return;

    _server = await HttpServer.bind(host, port);

    _server!.transform(WebSocketTransformer()).listen(_handleWebSocket);
  }

  Future<void> stop() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
  }

  void _handleWebSocket(WebSocket socket) {
    _clients.add(socket);
    _connectionController.add(true);

    socket.listen(
      (data) => _handleMessage(socket, data),
      onDone: () {
        _clients.remove(socket);
        _connectionController.add(_clients.isNotEmpty);
      },
      onError: (error) {
        _clients.remove(socket);
      },
    );
  }

  void _handleMessage(WebSocket socket, dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final cmdValue = message[PebbleMessageKey.command.value.toString()] as int?;
      
      if (cmdValue == null) return;
      
      final command = PebbleCommand.fromValue(cmdValue);
      if (command == null) return;

      switch (command) {
        case PebbleCommand.getList:
          _handleGetList(socket);
          break;
        case PebbleCommand.selectSong:
          final songId = message[PebbleMessageKey.songId.value.toString()] as String?;
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
    } catch (_) {
      _sendError(socket);
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

    _sendMessage(socket, {
      PebbleMessageKey.command.value.toString(): PebbleCommand.listResp.value,
      PebbleMessageKey.songId.value.toString(): song.id,
      PebbleMessageKey.songName.value.toString(): _truncate(song.name, 60),
      PebbleMessageKey.songCount.value.toString(): songs.length,
      PebbleMessageKey.songIndex.value.toString(): _currentSongIndex,
      PebbleMessageKey.pageCount.value.toString(): song.pageCount,
    });
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

    _sendMessage(socket, {
      PebbleMessageKey.command.value.toString(): PebbleCommand.pageLoaded.value,
      PebbleMessageKey.pageNum.value.toString(): _currentPage,
      PebbleMessageKey.pageCount.value.toString(): song.pageCount,
    });
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
      _sendMessage(socket, {
        PebbleMessageKey.command.value.toString(): PebbleCommand.pageLoaded.value,
        PebbleMessageKey.pageNum.value.toString(): _currentPage,
        PebbleMessageKey.pageCount.value.toString(): song.pageCount,
      });
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
      _sendMessage(socket, {
        PebbleMessageKey.command.value.toString(): PebbleCommand.pageLoaded.value,
        PebbleMessageKey.pageNum.value.toString(): _currentPage,
        PebbleMessageKey.pageCount.value.toString(): song.pageCount,
      });
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

    _sendMessage(socket, {
      PebbleMessageKey.command.value.toString(): PebbleCommand.listResp.value,
      PebbleMessageKey.songId.value.toString(): song.id,
      PebbleMessageKey.songName.value.toString(): _truncate(song.name, 60),
      PebbleMessageKey.songCount.value.toString(): songs.length,
      PebbleMessageKey.songIndex.value.toString(): _currentSongIndex,
      PebbleMessageKey.pageCount.value.toString(): song.pageCount,
    });
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

    _sendMessage(socket, {
      PebbleMessageKey.command.value.toString(): PebbleCommand.listResp.value,
      PebbleMessageKey.songId.value.toString(): song.id,
      PebbleMessageKey.songName.value.toString(): _truncate(song.name, 60),
      PebbleMessageKey.songCount.value.toString(): songs.length,
      PebbleMessageKey.songIndex.value.toString(): _currentSongIndex,
      PebbleMessageKey.pageCount.value.toString(): song.pageCount,
    });
  }

  void _sendMessage(WebSocket socket, Map<String, dynamic> message) {
    socket.add(jsonEncode(message));
  }

  void _sendAck(WebSocket socket) {
    _sendMessage(socket, {
      PebbleMessageKey.command.value.toString(): PebbleCommand.ack.value,
    });
  }

  void _sendError(WebSocket socket) {
    _sendMessage(socket, {
      PebbleMessageKey.command.value.toString(): PebbleCommand.error.value,
    });
  }

  String _truncate(String s, int maxLength) {
    if (s.length <= maxLength) return s;
    return '${s.substring(0, maxLength - 3)}...';
  }

  void broadcastPageChange(int pageNumber) {
    if (_currentSongId == null) return;
    final song = _songRepository.getSongById(_currentSongId!);
    if (song == null) return;

    _currentPage = pageNumber;
    final message = {
      PebbleMessageKey.command.value.toString(): PebbleCommand.pageLoaded.value,
      PebbleMessageKey.pageNum.value.toString(): _currentPage,
      PebbleMessageKey.pageCount.value.toString(): song.pageCount,
    };

    for (final client in _clients) {
      _sendMessage(client, message);
    }
  }

  void dispose() {
    _connectionController.close();
    stop();
  }
}
