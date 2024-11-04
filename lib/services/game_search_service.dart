import 'package:flutter/material.dart';
import '../models/igdb_game.dart';
import '../services/igdb_service.dart';

class GameSearchService {
  final IGDBService _igdbService;

  GameSearchService(this._igdbService);

  Future<IGDBGame?> searchGame(BuildContext context, String gameName) async {
    try {
      final results = await _igdbService.searchGames(gameName);
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      debugPrint('Error searching for game: $e');
      return null;
    }
  }

  Future<List<IGDBGame>> searchGames(String gameName) async {
    try {
      return await _igdbService.searchGames(gameName);
    } catch (e) {
      debugPrint('Error searching for games: $e');
      return [];
    }
  }
}
