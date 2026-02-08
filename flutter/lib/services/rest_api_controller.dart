import 'dart:convert';
import 'dart:io';

import '../services/song_repository.dart';
import '../state/app_state.dart';

/// REST API controller for managing song navigation and control.
class RestApiController {
  final SongRepository _songRepository;
  final AppState _appState;
  HttpServer? _server;
  final int _port;
  final String _host;

  /// Whether the server is currently running.
  bool get isRunning => _server != null;

  /// The URL the server is listening on.
  String? get serverUrl => _server != null ? 'http://$_host:$_port' : null;

  RestApiController({
    required SongRepository songRepository,
    required AppState appState,
    int port = 8080,
    String host = '0.0.0.0',
  }) : _songRepository = songRepository,
       _appState = appState,
       _port = port,
       _host = host;

  /// Starts the HTTP server.
  Future<void> start() async {
    if (_server != null) {
      return; // Already running
    }

    _server = await HttpServer.bind(_host, _port);

    _server!.listen(_handleRequest);
  }

  /// Stops the HTTP server.
  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  /// Handles incoming HTTP requests.
  void _handleRequest(HttpRequest request) {
    // Add CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type',
    );

    // Handle preflight
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      request.response.close();
      return;
    }

    final path = request.uri.path;
    final segments = request.uri.pathSegments;

    try {
      if (request.method == 'GET') {
        if (path == '/songs' || path == '/songs/') {
          _handleGetSongs(request);
        } else if (segments.length == 2 && segments[0] == 'songs') {
          _handleGetSong(request, segments[1]);
        } else if (segments.length == 4 &&
            segments[0] == 'songs' &&
            segments[2] == 'pages') {
          _handleGetPage(request, segments[1], segments[3]);
        } else if (path == '/health' || path == '/health/') {
          _handleHealth(request);
        } else {
          _notFound(request);
        }
      } else if (request.method == 'POST') {
        if (path == '/control/next' || path == '/control/next/') {
          _handleNextPage(request);
        } else if (path == '/control/previous' ||
            path == '/control/previous/') {
          _handlePreviousPage(request);
        } else if (path == '/control/go-to-page' ||
            path == '/control/go-to-page/') {
          _handleGoToPage(request);
        } else {
          _notFound(request);
        }
      } else {
        _methodNotAllowed(request);
      }
    } catch (e) {
      _serverError(request, e.toString());
    }
  }

  /// GET /songs - Returns list of all songs.
  void _handleGetSongs(HttpRequest request) {
    _jsonResponse(request, _songRepository.toJson());
  }

  /// GET /songs/:id - Returns a specific song.
  void _handleGetSong(HttpRequest request, String songId) {
    final song = _songRepository.getSongById(songId);
    if (song == null) {
      _notFound(request, 'Song not found');
      return;
    }
    _jsonResponse(request, song.toJson());
  }

  /// GET /songs/:id/pages/:pageNumber - Returns a specific page.
  void _handleGetPage(
    HttpRequest request,
    String songId,
    String pageNumberStr,
  ) {
    final song = _songRepository.getSongById(songId);
    if (song == null) {
      _notFound(request, 'Song not found');
      return;
    }

    final pageNumber = int.tryParse(pageNumberStr);
    if (pageNumber == null) {
      _badRequest(request, 'Invalid page number');
      return;
    }

    final page = song.getPage(pageNumber);
    if (page == null) {
      _notFound(request, 'Page not found');
      return;
    }

    _jsonResponse(request, page.toJson());
  }

  /// GET /health - Health check endpoint.
  void _handleHealth(HttpRequest request) {
    _jsonResponse(request, {
      'status': 'ok',
      'songCount': _songRepository.songs.length,
    });
  }

  /// POST /control/next - Navigate to the next page.
  void _handleNextPage(HttpRequest request) {
    _appState.nextPage();
    _jsonResponse(request, {'status': 'ok', 'message': 'Moved to next page'});
  }

  /// POST /control/previous - Navigate to the previous page.
  void _handlePreviousPage(HttpRequest request) {
    _appState.previousPage();
    _jsonResponse(request, {
      'status': 'ok',
      'message': 'Moved to previous page',
    });
  }

  /// POST /control/go-to-page - Navigate to a specific page.
  void _handleGoToPage(HttpRequest request) {
    // Read the request body
    final StringBuffer body = StringBuffer();
    request.listen(
      (data) {
        body.write(utf8.decode(data));
      },
      onDone: () {
        try {
          final data = jsonDecode(body.toString());
          final page = data['page'] as int?;

          if (page == null) {
            _badRequest(request, 'Missing page number in request body');
            return;
          }

          _appState.goToPage(page - 1); // Convert to 0-based index
          _jsonResponse(request, {
            'status': 'ok',
            'message': 'Moved to page $page',
          });
        } catch (e) {
          _badRequest(request, 'Invalid JSON in request body');
        }
      },
    );
  }

  /// Sends a JSON response.
  void _jsonResponse(
    HttpRequest request,
    Map<String, dynamic> data, {
    int statusCode = HttpStatus.ok,
  }) {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    request.response.close();
  }

  /// Sends a 404 Not Found response.
  void _notFound(HttpRequest request, [String message = 'Not found']) {
    _jsonResponse(request, {'error': message}, statusCode: HttpStatus.notFound);
  }

  /// Sends a 400 Bad Request response.
  void _badRequest(HttpRequest request, String message) {
    _jsonResponse(request, {
      'error': message,
    }, statusCode: HttpStatus.badRequest);
  }

  /// Sends a 405 Method Not Allowed response.
  void _methodNotAllowed(HttpRequest request) {
    _jsonResponse(request, {
      'error': 'Method not allowed',
    }, statusCode: HttpStatus.methodNotAllowed);
  }

  /// Sends a 500 Internal Server Error response.
  void _serverError(HttpRequest request, String message) {
    _jsonResponse(request, {
      'error': 'Internal server error',
      'details': message,
    }, statusCode: HttpStatus.internalServerError);
  }
}
