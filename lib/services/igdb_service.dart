import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/logs_screen.dart' show log;
import 'package:http/http.dart' as http;
import '../models/igdb_game.dart';
import '../models/game.dart';

class IGDBService {
  final String _baseUrl = 'https://api.igdb.com/v4';
  static const String _clientId = 'iwv8b7b2j538q7q956u8kpclmkwo3x';
  static const String _clientSecret = 'biypz8t9eyy4kj9cakkpqzyzj02yct';
  String? _accessToken;
  final Map<String, IGDBGame> _cache = {};
  static const String _cacheKey = 'igdb_cache';
  final SharedPreferences _prefs;

  IGDBService(this._prefs) {
    _loadCache();
  }

  void _loadCache() {
    final cacheData = _prefs.getString(_cacheKey);
    if (cacheData != null) {
      final Map<String, dynamic> cacheMap = json.decode(cacheData);
      cacheMap.forEach((key, value) {
        _cache[key] = IGDBGame.fromJson(value);
      });
    }
  }

  Future<void> _saveCache() async {
    final cacheMap = Map<String, dynamic>.fromEntries(
      _cache.entries.map((e) => MapEntry(e.key, e.value.toJson())),
    );
    await _prefs.setString(_cacheKey, json.encode(cacheMap));
  }

  Future<void> initialize(String clientId, String clientSecret) async {
    // Removed initialization of _clientId and _clientSecret as they are now constants
  }

  Future<String> _getAccessToken() async {
    if (_accessToken != null) return _accessToken!;

    try {
      log('Requesting new access token from Twitch');
      final response = await http.post(
        Uri.parse('https://id.twitch.tv/oauth2/token'),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'grant_type': 'client_credentials'
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout while getting access token');
        },
      );

      log('Token response status: ${response.statusCode}');
      log('Token response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        return _accessToken!;
      } else {
        throw Exception(
            'Failed to get access token: HTTP ${response.statusCode}');
      }
    } catch (e) {
      log('Error getting access token: $e');
      rethrow;
    }
  }

  Future<IGDBGame?> getGameById(int id) async {
    final cacheKey = 'id_$id';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    try {
      log('Getting game details for ID: $id');
      final token = await _getAccessToken();

      final detailsQuery = '''
        fields id,name,summary,screenshots.url,genres.name,game_modes.name,cover.url,rating,release_dates.date;
        where id = $id;
      ''';

      log('IGDB Details Query:\n$detailsQuery');

      final detailsResponse = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: {
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: detailsQuery,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout while fetching game details');
        },
      );

      log('IGDB details response status: ${detailsResponse.statusCode}');
      log('IGDB details response body: ${detailsResponse.body}');

      if (detailsResponse.statusCode != 200) {
        throw Exception(
            'Failed to fetch game details: HTTP ${detailsResponse.statusCode}');
      }

      final List<dynamic> games = json.decode(detailsResponse.body);
      final game = games.isNotEmpty ? IGDBGame.fromJson(games.first) : null;
      if (game != null) {
        _cache[cacheKey] = game;
        await _saveCache();
      }
      return game;
    } catch (e) {
      log('Error in getGameById: $e');
      return null;
    }
  }

  Future<IGDBGame?> getGameDetails(String gameName) async {
    // Check cache first
    if (_cache.containsKey(gameName)) {
      return _cache[gameName];
    }

    final results = await searchGames(gameName);
    if (results.isNotEmpty) {
      _cache[gameName] = results.first;
      await _saveCache();
      return results.first;
    }
    return null;
  }

  Future<List<IGDBGame>> searchGames(String gameName) async {
    try {
      // Check cache first
      if (_cache.containsKey(gameName)) {
        return [_cache[gameName]!];
      }

      // Clean the game name using the Game model's cleanGameTitle method
      final cleanedGameName = Game.cleanGameTitle(gameName);
      log('Starting game search for: $cleanedGameName (original: $gameName)');
      final token = await _getAccessToken();

      // First get game IDs from search endpoint
      final searchQuery = '''
        fields name,game;
        search "${cleanedGameName.replaceAll('"', '\\"')}";
        where game != null;
        limit 10;
      ''';

      log('IGDB Search Query:\n$searchQuery');

      final searchResponse = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: {
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: searchQuery,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout while searching games');
        },
      );

      log('IGDB search response status: ${searchResponse.statusCode}');
      log('IGDB search response body: ${searchResponse.body}');

      if (searchResponse.statusCode != 200) {
        throw Exception(
            'Failed to search games: HTTP ${searchResponse.statusCode}');
      }

      final List<dynamic> searchResults = json.decode(searchResponse.body);
      if (searchResults.isEmpty) {
        return [];
      }

      // Extract game IDs
      final gameIds = searchResults
          .where((result) => result['game'] != null)
          .map((result) => result['game'].toString())
          .toList();

      if (gameIds.isEmpty) {
        return [];
      }

      // Get detailed game info
      final detailsQuery = '''
        fields id,name,summary,screenshots.url,genres.name,game_modes.name,cover.url,rating,release_dates.date;
        where id = (${gameIds.join(',')});
        limit ${gameIds.length};
      ''';

      log('IGDB Details Query:\n$detailsQuery');

      final detailsResponse = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: {
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: detailsQuery,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout while fetching game details');
        },
      );

      log('IGDB details response status: ${detailsResponse.statusCode}');
      log('IGDB details response body: ${detailsResponse.body}');

      if (detailsResponse.statusCode != 200) {
        throw Exception(
            'Failed to fetch game details: HTTP ${detailsResponse.statusCode}');
      }

      final List<dynamic> games = json.decode(detailsResponse.body);
      final results = games.map((g) => IGDBGame.fromJson(g)).toList()
        ..sort((a, b) {
          if (a.rating != null && b.rating != null) {
            return b.rating!.compareTo(a.rating!);
          }
          if (a.rating != null) return -1;
          if (b.rating != null) return 1;
          return 0;
        });

      if (results.isNotEmpty) {
        _cache[gameName] = results.first;
        await _saveCache();
        log('Successfully found ${results.length} games');
      } else {
        log('No matches found');
      }

      return results;
    } catch (e) {
      log('Error in searchGames: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchGameData(String gameName) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'igdb_$gameName';
    final cachedData = prefs.getString(cacheKey);

    if (cachedData != null) {
      return jsonDecode(cachedData);
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/games'),
      headers: {
        'Client-ID': _clientId,
        'Authorization': 'Bearer $_accessToken',
      },
      body: 'fields name,cover.url; search "$gameName";',
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await prefs.setString(cacheKey, response.body);
      return data;
    } else {
      throw Exception('Failed to fetch game data');
    }
  }

  Future<void> downloadCover(String url, String gameName) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final directory = Directory('covers');
      if (!directory.existsSync()) {
        directory.createSync();
      }
      final filePath = path.join(directory.path, '$gameName.jpg');
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('Failed to download cover');
    }
  }
}
