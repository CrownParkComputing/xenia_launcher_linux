import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/igdb_game.dart';
import '../models/config.dart';
import '../providers/settings_provider.dart';
import '../providers/iso_games_provider.dart';
import '../providers/live_games_provider.dart';
import '../services/igdb_service.dart';
import '../services/game_search_service.dart';
import '../screens/game_details_screen.dart';
import '../screens/achievements_screen.dart';
import '../widgets/dialogs/igdb_search_dialog.dart';
import 'game_card/game_cover.dart';
import 'game_card/game_title_section.dart';
import 'game_card/game_actions_section.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

class GameCard extends StatefulWidget {
  final Game game;
  final String? executableDisplayName;
  final VoidCallback onPlayTap;
  final VoidCallback onDLCTap;
  final VoidCallback onDeleteTap;
  final Function(String) onTitleEdit;
  final Function(String) onSearchTitleEdit;

  const GameCard({
    super.key,
    required this.game,
    required this.executableDisplayName,
    required this.onPlayTap,
    required this.onDLCTap,
    required this.onDeleteTap,
    required this.onTitleEdit,
    required this.onSearchTitleEdit,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _isHovering = false;
  late final IGDBService _igdbService;
  late final GameSearchService _gameSearchService;
  IGDBGame? _gameDetails;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      _igdbService = IGDBService(prefs);
      _gameSearchService = GameSearchService(_igdbService);
      _loadGameDetails();
    });
  }

  @override
  void didUpdateWidget(GameCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.igdbId != widget.game.igdbId) {
      _loadGameDetails();
    }
  }

  Future<void> _loadGameDetails() async {
    try {
      if (widget.game.igdbId != null) {
        developer.log('Loading game details using IGDB ID: ${widget.game.igdbId}');
        final details = await _igdbService.getGameById(widget.game.igdbId!);
        if (details != null && mounted) {
          setState(() {
            _gameDetails = details;
          });
          
          // Update the game with the new details
          final provider = widget.game.isIsoGame
              ? Provider.of<IsoGamesProvider>(context, listen: false)
              : Provider.of<LiveGamesProvider>(context, listen: false);

          final updatedGame = widget.game.copyWith(
            igdbId: details.id,
            summary: details.summary,
            rating: details.rating,
            releaseDate: details.releaseDate,
            genres: details.genres,
            gameModes: details.gameModes,
            screenshots: details.screenshots,
            coverUrl: details.coverUrl,
            localCoverPath: details.localCoverPath,
          );
          
          await provider.updateGame(updatedGame);
        }
      } else {
        developer.log('No IGDB ID found, searching by name');
        final details = await _gameSearchService.searchGame(context, widget.game);
        if (details != null && mounted) {
          setState(() {
            _gameDetails = details;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading game details: $e');
    }
  }

  Future<void> _showIgdbSearchDialog() async {
    try {
      final result = await showDialog<IGDBGame>(
        context: context,
        builder: (context) => IgdbSearchDialog(
          currentTitle: widget.game.title,
        ),
      );

      if (result != null && mounted) {
        final provider = widget.game.isIsoGame
            ? Provider.of<IsoGamesProvider>(context, listen: false)
            : Provider.of<LiveGamesProvider>(context, listen: false);

        // Create updated game with ALL details from the selected IGDB game
        final updatedGame = widget.game.copyWith(
          igdbId: result.id,
          searchTitle: result.name,  // Store IGDB name for future searches
          summary: result.summary,
          rating: result.rating,
          releaseDate: result.releaseDate,
          genres: result.genres,
          gameModes: result.gameModes,
          screenshots: result.screenshots,
          coverUrl: result.coverUrl,
          localCoverPath: result.localCoverPath,
        );
        
        // Update the game in the provider to persist changes
        await provider.updateGame(updatedGame);
        
        // Update local state to reflect changes immediately
        setState(() {
          _gameDetails = result;
        });
        
        developer.log('Stored IGDB game details permanently. Game ID: ${result.id}, Title: ${result.name}');
      }
    } catch (e) {
      debugPrint('Error storing IGDB game details: $e');
    }
  }

  Future<void> _handleTitleEdit(String newTitle) async {
    try {
      final provider = widget.game.isIsoGame
          ? Provider.of<IsoGamesProvider>(context, listen: false)
          : Provider.of<LiveGamesProvider>(context, listen: false);
      
      // Show search dialog with new title
      final result = await showDialog<IGDBGame>(
        context: context,
        builder: (context) => IgdbSearchDialog(
          currentTitle: newTitle,
        ),
      );

      if (result != null && mounted) {
        // Use the same update logic as _showIgdbSearchDialog
        final updatedGame = widget.game.copyWith(
          igdbId: result.id,
          title: newTitle,  // Keep the user's edited title
          searchTitle: result.name,  // Store IGDB name for future searches
          summary: result.summary,
          rating: result.rating,
          releaseDate: result.releaseDate,
          genres: result.genres,
          gameModes: result.gameModes,
          screenshots: result.screenshots,
          coverUrl: result.coverUrl,
          localCoverPath: result.localCoverPath,
        );
        
        await provider.updateGame(updatedGame);
        setState(() {
          _gameDetails = result;
        });
      }
    } catch (e) {
      debugPrint('Error updating game details: $e');
    }
  }

  double _getCardWidth(GameCardSize size) {
    switch (size) {
      case GameCardSize.small:
        return 180;
      case GameCardSize.medium:
        return 240;
      case GameCardSize.large:
        return 300;
    }
  }

  double _getCardHeight(GameCardSize size) {
    switch (size) {
      case GameCardSize.small:
        return 280;
      case GameCardSize.medium:
        return 360;
      case GameCardSize.large:
        return 440;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final cardSize = settingsProvider.config.cardSize;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameDetailsScreen(game: widget.game),
            ),
          );
        },
        child: SizedBox(
          width: _getCardWidth(cardSize),
          height: _getCardHeight(cardSize),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Game Cover - 3/4 of card height
                Expanded(
                  flex: 3,
                  child: GameCover(
                    localCoverPath: widget.game.localCoverPath ?? _gameDetails?.localCoverPath,
                    gameDetails: _gameDetails,
                    isHovering: _isHovering,
                    onPlayTap: widget.onPlayTap,
                  ),
                ),
                // Game Info - 1/4 of card height
                Container(
                  color: Theme.of(context).cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GameTitleSection(
                        title: widget.game.title,
                        executableDisplayName: widget.executableDisplayName,
                        onTitleEdit: _handleTitleEdit,
                        onSearchTap: _showIgdbSearchDialog,
                      ),
                      GameActionsSection(
                        onDeleteTap: widget.onDeleteTap,
                        onAchievementsTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AchievementsScreen(game: widget.game),
                            ),
                          );
                        },
                        onDLCTap: widget.onDLCTap,
                        achievementsCount: widget.game.achievements.length,
                        dlcCount: widget.game.dlc.length,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
