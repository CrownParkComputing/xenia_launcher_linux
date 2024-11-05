import 'package:flutter/material.dart';
import '../models/igdb_game.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../providers/iso_games_provider.dart';
import 'package:provider/provider.dart';

class GameSearchService {
  final IGDBService _igdbService;

  GameSearchService(this._igdbService);

  Future<IGDBGame?> searchGame(BuildContext context, Game game) async {
    try {
      // If we have an IGDB ID, use it directly
      if (game.igdbId != null) {
        return await _igdbService.getGameById(game.igdbId!);
      }
      
      // Search by name and store the ID if found
      final results = await _igdbService.searchGames(game.effectiveSearchTitle);
      if (results.isNotEmpty) {
        // Store the IGDB ID for future use
        final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
        final updatedGame = game.copyWith(igdbId: results.first.id);
        await isoProvider.updateGame(updatedGame);
        return results.first;
      }
      return null;
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
