import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/logs_screen.dart' show log;
import 'package:http/http.dart' as http;
import '../models/igdb_game.dart';
import '../models/game.dart';
import 'dart:developer' as developer;

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

  Future<IGDBGame?> getGameDetails(String gameName) async {
    try {
      // Check cache first
      if (_cache.containsKey(gameName)) {
        return _cache[gameName];
      }

      // First get basic game info to get the ID
      final token = await _getAccessToken();
      final searchQuery = '''
        fields id,name,cover.url;
        search "${gameName.replaceAll('"', '\\"')}";
        limit 1;
      ''';

      final searchResponse = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: {
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: searchQuery,
      );

      if (searchResponse.statusCode != 200) {
        throw Exception('Failed to search game: ${searchResponse.statusCode}');
      }

      final List<dynamic> searchResults = json.decode(searchResponse.body);
      if (searchResults.isEmpty) return null;

      // Get the ID and fetch full details
      final gameId = searchResults.first['id'] as int;
      final fullGame = await getGameById(gameId);

      if (fullGame != null) {
        // Download cover if available
        if (fullGame.coverUrl != null) {
          await downloadCover(fullGame.coverUrl!, gameName);
        }
        _cache[gameName] = fullGame;
        await _saveCache();
      }

      return fullGame;
    } catch (e) {
      log('Error in getGameDetails: $e');
      return null;
    }
  }

  Future<IGDBGame?> getGameById(int id) async {
    try {
      log('Getting full game details for ID: $id');
      final token = await _getAccessToken();

      final detailsQuery = '''
        fields name,summary,storyline,cover.*,screenshots.*,genres.*,
               rating,release_dates.*,platforms.*,involved_companies.company.*,
               game_modes.*,themes.*,similar_games.*,dlcs.*,expansions.*,
               remakes.*,remasters.*,aggregated_rating,aggregated_rating_count,
               total_rating,total_rating_count,first_release_date,status,category,
               version_title,game_engines.*,player_perspectives.*;
        where id = $id;
      ''';

      final detailsResponse = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: {
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: detailsQuery,
      );

      if (detailsResponse.statusCode != 200) {
        log('Failed to get game details: HTTP ${detailsResponse.statusCode}');
        log('Response body: ${detailsResponse.body}');
        throw Exception('Failed to get game details: ${detailsResponse.statusCode}');
      }

      final List<dynamic> games = json.decode(detailsResponse.body);
      if (games.isEmpty) {
        log('No game found with ID: $id');
        return null;
      }

      final gameData = games.first;
      log('Got game details: ${json.encode(gameData)}');
      
      final game = IGDBGame.fromJson(gameData);
      return game;
    } catch (e) {
      log('Error in getGameById: $e');
      return null;
    }
  }

  Future<List<IGDBGame>> searchGames(String gameName) async {
    try {
      // Clean the game name using the Game model's cleanGameTitle method
      final cleanedGameName = Game.cleanGameTitle(gameName);
      log('Starting game search for: $cleanedGameName (original: $gameName)');
      final token = await _getAccessToken();

      // Get more information in the search results
      final searchQuery = '''
        fields id,name,cover.url,rating,release_dates.date,summary,genres.name,
              screenshots.url,game_modes.name,platforms.name,
              aggregated_rating,aggregated_rating_count,
              total_rating,total_rating_count,first_release_date;
        search "${cleanedGameName.replaceAll('"', '\\"')}";
        limit 10;
      ''';

      final searchResponse = await http.post(
        Uri.parse('$_baseUrl/games'),
        headers: {
          'Client-ID': _clientId,
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
        body: searchQuery,
      );

      if (searchResponse.statusCode != 200) {
        log('Failed to search games: HTTP ${searchResponse.statusCode}');
        log('Response body: ${searchResponse.body}');
        throw Exception('Failed to search games: ${searchResponse.statusCode}');
      }

      final List<dynamic> searchResults = json.decode(searchResponse.body);
      log('Found ${searchResults.length} results');
      
      final results = searchResults.map((g) => IGDBGame.fromJson(g)).toList();
      
      // Sort by rating if available
      results.sort((a, b) {
        if (a.rating != null && b.rating != null) {
          return b.rating!.compareTo(a.rating!);
        }
        if (a.rating != null) return -1;
        if (b.rating != null) return 1;
        return 0;
      });

      return results;
    } catch (e) {
      log('Error in searchGames: $e');
      return [];
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

  Future<String?> downloadCover(String url, String gameName) async {
    try {
      // Create covers directory in the app's directory
      final directory = Directory('covers');
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      // Clean the filename
      final cleanName = gameName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = '$cleanName.jpg';
      final filePath = path.join(directory.path, fileName);
      final file = File(filePath);

      // Check if file already exists
      if (file.existsSync()) {
        log('Cover already exists for: $gameName');
        return filePath;
      }

      // Ensure URL is properly formatted
      var downloadUrl = url;
      if (downloadUrl.startsWith('//')) {
        downloadUrl = 'https:$downloadUrl';
      }
      if (!downloadUrl.contains('t_cover_big')) {
        downloadUrl = downloadUrl.replaceAll(RegExp(r't_\w+'), 't_cover_big');
      }

      // Download the image
      log('Downloading cover from: $downloadUrl');
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        log('Successfully downloaded cover for: $gameName');
        return filePath;
      } else {
        log('Failed to download cover: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error downloading cover: $e');
      return null;
    }
  }

  String? getLocalCoverPath(String gameName) {
    final cleanName = gameName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final fileName = '$cleanName.jpg';
    final filePath = path.join('covers', fileName);
    final file = File(filePath);
    return file.existsSync() ? filePath : null;
  }

  Future<Game?> checkAndFetchMissingCovers(List<Game> games) async {
    // First check for any games missing IGDB IDs - this is highest priority
    final missingIdGame = games.firstWhere(
      (game) => game.igdbId == null,
      orElse: () => games.firstWhere(
        (game) => getLocalCoverPath(game.title) == null,
        orElse: () => games[0], // This won't be used since we return null below
      ),
    );

    if (missingIdGame.igdbId == null) {
      log('Found game missing IGDB ID: ${missingIdGame.title}');
      return missingIdGame;
    }

    // Then check for missing covers
    for (final game in games) {
      final localPath = getLocalCoverPath(game.title);
      if (localPath == null) {
        log('Found game missing cover: ${game.title}');
        return game;
      }
    }

    return null;
  }
}
