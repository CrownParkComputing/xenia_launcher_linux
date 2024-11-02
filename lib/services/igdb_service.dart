import 'dart:convert';
import '../screens/logs_screen.dart' show log;
import 'package:http/http.dart' as http;
import '../models/igdb_game.dart';

enum SearchType { exact, partial }

class IGDBService {
  static const String _baseUrl = 'https://api.igdb.com/v4';
  static const String _clientId = 'iwv8b7b2j538q7q956u8kpclmkwo3x';
  static const String _clientSecret = 'biypz8t9eyy4kj9cakkpqzyzj02yct';
  String? _accessToken;
  final Map<String, IGDBGame> _cache = {};

  // Common game name variants to remove
  static final List<RegExp> _variantPatterns = [
    RegExp(r"\bHD\b", caseSensitive: false),
    RegExp(r"\bRemastered\b", caseSensitive: false),
    RegExp(r"\bGOTY\b", caseSensitive: false),
    RegExp(r"\bGame of the Year\b", caseSensitive: false),
    RegExp(r"\bComplete Edition\b", caseSensitive: false),
    RegExp(r"\bCollector's Edition\b", caseSensitive: false),
    RegExp(r"\bDeluxe Edition\b", caseSensitive: false),
    RegExp(r"\bSpecial Edition\b", caseSensitive: false),
    RegExp(r"\bPlatinum Edition\b", caseSensitive: false),
    RegExp(r"\bPremium Edition\b", caseSensitive: false),
    RegExp(r"\bDefinitive Edition\b", caseSensitive: false),
    RegExp(r"\bEnhanced Edition\b", caseSensitive: false),
    RegExp(r"\bAnniversary Edition\b", caseSensitive: false),
  ];

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
        throw Exception('Failed to get access token: HTTP ${response.statusCode}');
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
        log('Returning cached data for: $gameName');
        return _cache[gameName];
      }

      log('Starting game details fetch for: $gameName');
      
      // Clean the game name to improve search results
      final cleanedName = _cleanGameName(gameName);
      log('Original name: $gameName');
      log('Cleaned name: $cleanedName');

      final token = await _getAccessToken();
      
      // Try different search strategies
      IGDBGame? game;
      
      // 1. Try exact match with cleaned name
      log('Attempting exact match search with cleaned name...');
      game = await _searchGame(token, cleanedName, searchType: SearchType.exact);
      
      // 2. Try partial match if no exact match found
      if (game == null) {
        log('No exact match found, trying partial match...');
        game = await _searchGame(token, cleanedName, searchType: SearchType.partial);
      }
      
      // 3. Try alternative names if still no match
      if (game == null) {
        final alternativeNames = _generateAlternativeNames(cleanedName);
        for (final altName in alternativeNames) {
          log('Trying alternative name: $altName');
          game = await _searchGame(token, altName, searchType: SearchType.partial);
          if (game != null) break;
        }
      }

      if (game != null) {
        _cache[gameName] = game;
        log('Successfully found game: ${game.name}');
      } else {
        log('No matches found for: $gameName');
      }

      return game;
    } catch (e) {
      log('Error in getGameDetails: $e');
      rethrow;
    }
  }

  Future<IGDBGame?> _searchGame(String token, String gameName, {required SearchType searchType}) async {
    final searchQuery = searchType == SearchType.exact
        ? '''
        fields name,summary,screenshots.*,genres.*,game_modes.*,cover.*,rating,release_dates.*;
        where name ~ "$gameName";
        limit 1;
        '''
        : '''
        fields name,summary,screenshots.*,genres.*,game_modes.*,cover.*,rating,release_dates.*;
        where name ~ "$gameName"* | name ~ "*$gameName*";
        limit 5;
        sort rating desc;
        ''';

    log('IGDB Query (${searchType.name}):\n$searchQuery');

    final response = await http.post(
      Uri.parse('$_baseUrl/games'),
      headers: {
        'Client-ID': _clientId,
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
      body: searchQuery,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Connection timeout while fetching game details');
      },
    );

    log('IGDB response status: ${response.statusCode}');
    log('IGDB response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final List<dynamic> games = json.decode(response.body);
      
      if (games.isNotEmpty) {
        log('Found game details for: $gameName');
        return IGDBGame.fromJson(games.first);
      }
      log('No games found for query: $gameName');
      return null;
    } else {
      throw Exception('Failed to fetch game details: HTTP ${response.statusCode}');
    }
  }

  List<String> _generateAlternativeNames(String name) {
    final alternatives = <String>[];
    
    // Split into words
    final words = name.split(' ');
    
    // Try first two words
    if (words.length > 1) {
      alternatives.add('${words[0]} ${words[1]}');
    }
    
    // Try without common prefixes
    if (name.startsWith('the ')) {
      alternatives.add(name.substring(4));
    }
    
    // Try removing numbers at the end
    if (RegExp(r'\s+\d+$').hasMatch(name)) {
      alternatives.add(name.replaceAll(RegExp(r'\s+\d+$'), ''));
    }
    
    log('Generated alternative names:');
    for (final alt in alternatives) {
      log('  - $alt');
    }
    
    return alternatives;
  }

  String _cleanGameName(String name) {
    var cleaned = name.toLowerCase();
    
    // Log each cleaning step
    log('Cleaning game name:');
    log('  Original: $cleaned');
    
    // Remove file extensions
    cleaned = cleaned.replaceAll(RegExp(r'\.(iso|xex|zip|gzip|rar)$'), '');
    log('  After extension removal: $cleaned');
    
    // Remove anything in brackets or parentheses and their contents
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]|\(.*?\)|\{.*?\}'), '');
    log('  After brackets/parentheses removal: $cleaned');
    
    // Remove version numbers
    cleaned = cleaned.replaceAll(RegExp(r'v\d+(\.\d+)*'), '');
    log('  After version numbers removal: $cleaned');
    
    // Remove release group names
    cleaned = cleaned.replaceAll(RegExp(r'-[a-zA-Z0-9]+$'), '');
    log('  After release group removal: $cleaned');

    // Remove common game variants (HD, Remastered, GOTY, etc.)
    for (final pattern in _variantPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }
    log('  After variant removal: $cleaned');
    
    // Remove all special characters except alphanumeric and spaces
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s]'), ' ');
    log('  After special characters removal: $cleaned');
    
    // Remove multiple spaces and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    log('  Final cleaned name: $cleaned');
    
    return cleaned;
  }
}
