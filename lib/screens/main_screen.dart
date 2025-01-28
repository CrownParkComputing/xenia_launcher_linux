import 'dart:io';
import 'package:flutter/material.dart';
import 'package:game_app/models/game.dart';
import 'package:game_app/services/game_service.dart';
import 'package:game_app/screens/game_details_screen.dart';
import 'package:provider/provider.dart';
import '../providers/iso_games_provider.dart';
import '../providers/live_games_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/game_grid.dart';
import '../services/igdb_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GameService _gameService = GameService();
  String _filter = 'all'; // 'all', 'iso'
  String _searchQuery = '';
  bool _isLoading = true;
  List<Game> _games = [];

  @override
  void initState() {
    super.initState();
    debugPrint('MainScreen initialized');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGames();
    });
  }

  Future<void> _loadGames() async {
    debugPrint('Loading games...');
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);
    final igdbService = Provider.of<IGDBService>(context, listen: false);
    
    setState(() => _isLoading = true);

    try {
      await isoProvider.loadGames();
      await liveProvider.loadGames();
      
      final allGames = [...isoProvider.games, ...liveProvider.games];
      debugPrint('Loaded ${allGames.length} games');

      setState(() {
        _games = allGames;
        _isLoading = false;
      });

      // Give UI time to settle before showing dialogs
      await Future.delayed(const Duration(milliseconds: 500));

      // Check each game for missing IGDB ID or cover
      for (final game in allGames) {
        debugPrint('Checking game: ${game.title} (IGDB ID: ${game.igdbId}, Cover: ${igdbService.getLocalCoverPath(game.title)})');
        
        if (!mounted) return;

        // First priority: Check for missing IGDB ID
        if (game.igdbId == null) {
          debugPrint('Found game missing IGDB ID: ${game.title}');
          
          final shouldSearch = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Missing Game Details'),
              content: Text('${game.title} needs to be linked to IGDB. Would you like to search for it now?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Later'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Search Now'),
                ),
              ],
            ),
          );

          if (shouldSearch == true && mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GameDetailsScreen(
                  game: game,
                  onGameUpdated: (updatedGame) async {
                    final provider = game.isIsoGame
                        ? Provider.of<IsoGamesProvider>(context, listen: false)
                        : Provider.of<LiveGamesProvider>(context, listen: false);
                    await provider.updateGame(updatedGame);
                    setState(() {});
                    
                    // Continue checking other games after update
                    if (mounted) {
                      _loadGames();
                    }
                  },
                ),
              ),
            );
            return; // Exit after handling one game
          }
        }
        
        // Second priority: Check for missing cover if we have an IGDB ID
        if (game.igdbId != null) {
          final localCoverPath = igdbService.getLocalCoverPath(game.title);
          if (localCoverPath == null) {
            debugPrint('Found game missing cover: ${game.title}');
            
            final shouldSearch = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Missing Cover'),
                content: Text('${game.title} is missing its cover. Would you like to download it now?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Later'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Download Now'),
                  ),
                ],
              ),
            );

            if (shouldSearch == true && mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => GameDetailsScreen(
                    game: game,
                    onGameUpdated: (updatedGame) async {
                      final provider = game.isIsoGame
                          ? Provider.of<IsoGamesProvider>(context, listen: false)
                          : Provider.of<LiveGamesProvider>(context, listen: false);
                      await provider.updateGame(updatedGame);
                      setState(() {});
                      
                      // Continue checking other games after update
                      if (mounted) {
                        _loadGames();
                      }
                    },
                  ),
                ),
              );
              return; // Exit after handling one game
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading games: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Game> _getFilteredGames(BuildContext context) {
    final isoProvider = Provider.of<IsoGamesProvider>(context);
    final liveProvider = Provider.of<LiveGamesProvider>(context);
    
    List<Game> games = [];
    // Always show all games, but allow filtering ISO games
    if (_filter == 'all') {
      games.addAll(isoProvider.games);
      games.addAll(liveProvider.games);
    } else if (_filter == 'iso') {
      games.addAll(isoProvider.games);
    }

    if (_searchQuery.isNotEmpty) {
      games = games.where((game) => 
        game.title.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return games;
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final games = _getFilteredGames(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        actions: [
          // Filter dropdown
          DropdownButton<String>(
            value: _filter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Games')),
              DropdownMenuItem(value: 'iso', child: Text('ISO Games')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _filter = value;
                });
              }
            },
          ),
          const SizedBox(width: 16),
          // Search field
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search games...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
              ),
              onChanged: (value) => setState(() {
                _searchQuery = value;
              }),
            ),
          ),
        ],
      ),
      body: GameGrid(
        games: games,
        getExecutableDisplayName: settingsProvider.getExecutableDisplayName,
        onGameTap: (game) => _launchGame(context, game),
        onGameMoreTap: (game) => _showDLCDialog(context, game),
        onGameDelete: (game) => _removeGame(context, game),
        onGameTitleEdit: (game, newTitle) => _updateGameTitle(context, game, newTitle),
        onGameSearchTitleEdit: (game, newSearchTitle) => _updateGameSearchTitle(context, game, newSearchTitle),
        onImportTap: () => _importGame(context),
        showAddGame: false,  // Explicitly set to false for main screen
      ),
    );
  }

  Future<void> _launchGame(BuildContext context, Game game) async {
    final provider = game.isIsoGame
        ? Provider.of<IsoGamesProvider>(context, listen: false)
        : Provider.of<LiveGamesProvider>(context, listen: false);
    await provider.launchGame(game);
  }

  Future<void> _showDLCDialog(BuildContext context, Game game) async {
    // Implement DLC dialog
  }

  Future<void> _removeGame(BuildContext context, Game game) async {
    final provider = game.isIsoGame
        ? Provider.of<IsoGamesProvider>(context, listen: false)
        : Provider.of<LiveGamesProvider>(context, listen: false);
    await provider.removeGame(game);
  }

  Future<void> _updateGameTitle(BuildContext context, Game game, String newTitle) async {
    final provider = game.isIsoGame
        ? Provider.of<IsoGamesProvider>(context, listen: false)
        : Provider.of<LiveGamesProvider>(context, listen: false);
    final updatedGame = game.copyWith(title: newTitle);
    await provider.updateGame(updatedGame);
  }

  Future<void> _updateGameSearchTitle(BuildContext context, Game game, String newSearchTitle) async {
    final provider = game.isIsoGame
        ? Provider.of<IsoGamesProvider>(context, listen: false)
        : Provider.of<LiveGamesProvider>(context, listen: false);
    final updatedGame = game.copyWith(searchTitle: newSearchTitle);
    await provider.updateGame(updatedGame);
  }

  Future<void> _importGame(BuildContext context) async {
    final provider = Provider.of<IsoGamesProvider>(context, listen: false);
    final imported = await provider.importGame();
    
    if (imported && mounted) {
      // Get the most recently added game (it will be first in the list)
      final newGame = provider.games.first;
      
      // Always prompt to search IGDB for new games
      final shouldSearch = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Search Game Details'),
          content: Text('Would you like to search for details for ${newGame.title}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Search Now'),
            ),
          ],
        ),
      );

      if (shouldSearch == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameDetailsScreen(
              game: newGame,
              onGameUpdated: (updatedGame) async {
                await provider.updateGame(updatedGame);
                setState(() {});
                
                // After updating the new game, check for any other games needing details
                if (mounted) {
                  _loadGames();
                }
              },
            ),
          ),
        );
      }
    }
  }
} 