import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Commands that can be sent between devices via Nearby Connections.
///
/// The protocol is designed for Pebble watch -> Phone -> Tablet communication,
/// allowing the watch to control sheet music on a tablet while staying
/// connected to the phone for notifications.
enum RemoteCommandType {
  // Navigation commands (phone -> tablet)
  nextPage('NEXT_PAGE'),
  prevPage('PREV_PAGE'),
  gotoPage('GOTO_PAGE'),

  // Playback commands (phone -> tablet)
  togglePlay('TOGGLE_PLAY'),

  // Status commands
  getStatus('GET_STATUS'),
  status('STATUS'),

  // Song selection (phone -> tablet)
  selectSong('SELECT_SONG'),
  getSongList('GET_SONG_LIST'),
  songList('SONG_LIST'),

  // Responses
  ack('ACK'),
  error('ERROR');

  final String value;
  const RemoteCommandType(this.value);

  static RemoteCommandType? fromValue(String value) {
    for (final cmd in RemoteCommandType.values) {
      if (cmd.value == value) return cmd;
    }
    return null;
  }
}

/// A command message sent between devices via Nearby Connections.
///
/// Each command has a unique ID for request/response correlation,
/// a type indicating the action, and optional payload data.
class RemoteCommand {
  /// Unique identifier for this command (for request/response correlation)
  final String id;

  /// The type of command
  final RemoteCommandType type;

  /// Optional payload data (varies by command type)
  final Map<String, dynamic>? payload;

  /// Timestamp when the command was created
  final DateTime timestamp;

  RemoteCommand({
    String? id,
    required this.type,
    this.payload,
    DateTime? timestamp,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  /// Create a NEXT_PAGE command
  factory RemoteCommand.nextPage() =>
      RemoteCommand(type: RemoteCommandType.nextPage);

  /// Create a PREV_PAGE command
  factory RemoteCommand.prevPage() =>
      RemoteCommand(type: RemoteCommandType.prevPage);

  /// Create a GOTO_PAGE command
  factory RemoteCommand.gotoPage(int page) =>
      RemoteCommand(type: RemoteCommandType.gotoPage, payload: {'page': page});

  /// Create a TOGGLE_PLAY command
  factory RemoteCommand.togglePlay() =>
      RemoteCommand(type: RemoteCommandType.togglePlay);

  /// Create a GET_STATUS command
  factory RemoteCommand.getStatus() =>
      RemoteCommand(type: RemoteCommandType.getStatus);

  /// Create a STATUS response
  factory RemoteCommand.status({
    required String requestId,
    required int currentPage,
    required int totalPages,
    required String songId,
    required String songName,
    bool isPlaying = false,
  }) => RemoteCommand(
    id: requestId,
    type: RemoteCommandType.status,
    payload: {
      'currentPage': currentPage,
      'totalPages': totalPages,
      'songId': songId,
      'songName': songName,
      'isPlaying': isPlaying,
    },
  );

  /// Create a SELECT_SONG command
  factory RemoteCommand.selectSong(String songId) => RemoteCommand(
    type: RemoteCommandType.selectSong,
    payload: {'songId': songId},
  );

  /// Create a GET_SONG_LIST command
  factory RemoteCommand.getSongList() =>
      RemoteCommand(type: RemoteCommandType.getSongList);

  /// Create a SONG_LIST response
  factory RemoteCommand.songList({
    required String requestId,
    required List<Map<String, dynamic>> songs,
  }) => RemoteCommand(
    id: requestId,
    type: RemoteCommandType.songList,
    payload: {'songs': songs},
  );

  /// Create an ACK response
  factory RemoteCommand.ack({
    required String requestId,
    bool success = true,
    String? message,
  }) => RemoteCommand(
    id: requestId,
    type: RemoteCommandType.ack,
    payload: {'success': success, if (message != null) 'message': message},
  );

  /// Create an ERROR response
  factory RemoteCommand.error({
    required String requestId,
    required String errorCode,
    String? message,
  }) => RemoteCommand(
    id: requestId,
    type: RemoteCommandType.error,
    payload: {'errorCode': errorCode, 'message': message},
  );

  /// Serialize to JSON string for transmission
  String toJson() {
    return jsonEncode({
      'id': id,
      'cmd': type.value,
      'ts': timestamp.toIso8601String(),
      if (payload != null) 'payload': payload,
    });
  }

  /// Serialize to bytes for Nearby Connections payload
  List<int> toBytes() => utf8.encode(toJson());

  /// Parse from JSON string
  static RemoteCommand? fromJson(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Parse from bytes received via Nearby Connections
  static RemoteCommand? fromBytes(List<int> bytes) {
    try {
      return fromJson(utf8.decode(bytes));
    } catch (_) {
      return null;
    }
  }

  /// Parse from a decoded map
  static RemoteCommand? fromMap(Map<String, dynamic> map) {
    try {
      final cmdValue = map['cmd'] as String?;
      if (cmdValue == null) return null;

      final type = RemoteCommandType.fromValue(cmdValue);
      if (type == null) return null;

      return RemoteCommand(
        id: map['id'] as String?,
        type: type,
        payload: map['payload'] as Map<String, dynamic>?,
        timestamp: map['ts'] != null
            ? DateTime.tryParse(map['ts'] as String)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  // Payload accessors for common fields

  /// Get page number from GOTO_PAGE or STATUS payload
  int? get page => payload?['page'] as int? ?? payload?['currentPage'] as int?;

  /// Get total pages from STATUS payload
  int? get totalPages => payload?['totalPages'] as int?;

  /// Get song ID from SELECT_SONG or STATUS payload
  String? get songId => payload?['songId'] as String?;

  /// Get song name from STATUS payload
  String? get songName => payload?['songName'] as String?;

  /// Get playing state from STATUS payload
  bool get isPlaying => payload?['isPlaying'] as bool? ?? false;

  /// Get success flag from ACK payload
  bool get isSuccess => payload?['success'] as bool? ?? false;

  /// Get error code from ERROR payload
  String? get errorCode => payload?['errorCode'] as String?;

  /// Get message from ACK or ERROR payload
  String? get message => payload?['message'] as String?;

  /// Get songs list from SONG_LIST payload
  List<Map<String, dynamic>>? get songs {
    final songsList = payload?['songs'];
    if (songsList is List) {
      return songsList.cast<Map<String, dynamic>>();
    }
    return null;
  }

  @override
  String toString() =>
      'RemoteCommand(id: $id, type: ${type.value}, payload: $payload)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteCommand &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ type.hashCode;
}

/// Common error codes for remote command errors
class RemoteErrorCode {
  static const String unknownCommand = 'UNKNOWN_COMMAND';
  static const String invalidPayload = 'INVALID_PAYLOAD';
  static const String songNotFound = 'SONG_NOT_FOUND';
  static const String pageOutOfRange = 'PAGE_OUT_OF_RANGE';
  static const String notConnected = 'NOT_CONNECTED';
  static const String timeout = 'TIMEOUT';
  static const String internalError = 'INTERNAL_ERROR';
}
