import 'package:flutter/material.dart';
import '../models/igdb_game.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../providers/iso_games_provider.dart';
import 'package:provider/provider.dart';
import '../screens/game_search_dialog.dart';

class GameSearchService {
  final IGDBService _igdbService;

  GameSearchService(this._igdbService);

  Future<IGDBGame?> searchGame(BuildContext context, Game game) async {
    try {
      // First search by name to get basic game info
      debugPrint('Searching for game by name: ${game.effectiveSearchTitle}');
      final searchResults = await _igdbService.searchGames(game.effectiveSearchTitle);
      
      if (searchResults.isEmpty) {
        debugPrint('No results found for: ${game.effectiveSearchTitle}');
        return null;
      }

      // Let user select the correct game from results
      if (!context.mounted) return null;
      final selectedGame = await showDialog<IGDBGame>(
        context: context,
        builder: (context) => GameSearchDialog(
          initialQuery: game.effectiveSearchTitle,
          igdbService: _igdbService,
        ),
      );

      if (selectedGame == null) {
        debugPrint('No game selected by user');
        return null;
      }

      // Get full details using the selected game's ID
      debugPrint('Getting full details for game ID: ${selectedGame.id}');
      final fullDetails = await _igdbService.getGameById(selectedGame.id);
      
      if (fullDetails != null) {
        // Download cover if available
        if (fullDetails.coverUrl != null) {
          debugPrint('Downloading cover for ${fullDetails.name}');
          final downloadedPath = await _igdbService.downloadCover(
            fullDetails.coverUrl!,
            fullDetails.name,
          );
          if (downloadedPath != null) {
            fullDetails.localCoverPath = downloadedPath;
            debugPrint('Cover downloaded to: $downloadedPath');
          }
        }
        return fullDetails;
      }

      return selectedGame; // Fallback to basic details if full details fetch fails
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
