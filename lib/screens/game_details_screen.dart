import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import '../models/igdb_game.dart';
import '../models/game.dart';
import '../services/igdb_service.dart';
import '../services/game_search_service.dart';
import '../providers/game_stats_provider.dart';
import 'achievements_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../widgets/dialogs/igdb_search_dialog.dart';

class GameDetailsScreen extends StatefulWidget {
  final Game game;
  final Function(Game)? onGameUpdated;

  const GameDetailsScreen({super.key, required this.game, this.onGameUpdated});

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  late final IGDBService _igdbService;
  late final GameSearchService _gameSearchService;
  IGDBGame? _gameDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _igdbService = IGDBService(prefs);
        _gameSearchService = GameSearchService(_igdbService);
        _loadGameDetails();
      });
    });
  }

  Future<void> _loadGameDetails() async {
    try {
      developer.log('Fetching details for game: ${widget.game.title}');
      if (widget.game.igdbId != null) {
        developer.log('Using IGDB ID: ${widget.game.igdbId}');
        final details = await _igdbService.getGameById(widget.game.igdbId!);
        if (details != null) {
          if (mounted) {
            setState(() {
              _gameDetails = details;
              _isLoading = false;
            });
          }
          
          // Update the game with new details
          if (widget.onGameUpdated != null) {
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
            await widget.onGameUpdated!(updatedGame);
          }
          return;
        }
      }

      developer.log('No IGDB ID, searching by name');
      final details = await _gameSearchService.searchGame(context, widget.game);
      developer.log('Received game details: $details');

      if (mounted) {
        setState(() {
          _gameDetails = details;
          _isLoading = false;
        });
      }

      // Update the game with new details if found
      if (details != null && widget.onGameUpdated != null) {
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
        await widget.onGameUpdated!(updatedGame);
      }
    } catch (e, stackTrace) {
      developer.log('Error loading game details: $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  Widget _buildGameStats() {
    final stats =
        context.watch<GameStatsProvider>().getGame(widget.game.path) ??
            widget.game;

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last Played'),
                    Text(
                      stats.lastPlayed?.toString().split('.')[0] ?? 'Never',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total Play Time'),
                    Text(
                      _formatDuration(stats.totalPlayTime),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
            if (stats.achievements.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Achievements (${stats.achievements.length})'),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AchievementsScreen(game: stats),
                        ),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              debugPrint('Opening game search dialog');
              final result = await showDialog<IGDBGame>(
                context: context,
                builder: (context) => IgdbSearchDialog(
                  currentTitle: widget.game.title,
                ),
              );
              
              if (result != null) {
                debugPrint('Selected game: ${result.name}');
                setState(() {
                  _gameDetails = result;
                  _isLoading = false;
                });
                
                // Update the game in the database with new details
                final updatedGame = widget.game.copyWith(
                  igdbId: result.id,
                  title: widget.game.title, // Keep original title
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
                
                debugPrint('Updating game with new details');
                if (widget.onGameUpdated != null) {
                  await widget.onGameUpdated!(updatedGame);
                  debugPrint('Game updated successfully');
                } else {
                  debugPrint('No onGameUpdated callback provided');
                }
              } else {
                debugPrint('No game selected from search dialog');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadGameDetails();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildGameDetails(),
    );
  }

  Widget _buildGameDetails() {
    if (_gameDetails == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No details found for this game'),
            const SizedBox(height: 16),
            Text('Game title: ${widget.game.title}',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image
          if (_gameDetails!.coverUrl != null)
            Center(
              child: _gameDetails!.localCoverPath != null && File(_gameDetails!.localCoverPath!).existsSync()
                ? Image.file(
                    File(_gameDetails!.localCoverPath!),
                    height: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading local cover: $error');
                      return const Icon(Icons.error);
                    },
                  )
                : CachedNetworkImage(
                    imageUrl: _gameDetails!.coverUrl!,
                    height: 300,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) {
                      debugPrint('Error loading network cover: $error');
                      return const Icon(Icons.error);
                    },
                  ),
            ),

          // Game Stats
          _buildGameStats(),

          // Game Details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Basic Info
                Text(
                  _gameDetails!.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                // Version Title if available
                if (_gameDetails!.versionTitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _gameDetails!.versionTitle!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],

                // Ratings
                if (_gameDetails!.rating != null ||
                    _gameDetails!.aggregatedRating != null ||
                    _gameDetails!.totalRating != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Ratings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_gameDetails!.rating != null)
                    ListTile(
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: Text('User Rating'),
                      trailing: Text('${(_gameDetails!.rating! / 10).toStringAsFixed(1)}/10'),
                    ),
                  if (_gameDetails!.aggregatedRating != null)
                    ListTile(
                      leading: const Icon(Icons.reviews, color: Colors.blue),
                      title: Text('Critic Rating'),
                      trailing: Text('${(_gameDetails!.aggregatedRating! / 10).toStringAsFixed(1)}/10'),
                      subtitle: Text('Based on ${_gameDetails!.aggregatedRatingCount} reviews'),
                    ),
                  if (_gameDetails!.totalRating != null)
                    ListTile(
                      leading: const Icon(Icons.score, color: Colors.green),
                      title: Text('Total Rating'),
                      trailing: Text('${(_gameDetails!.totalRating! / 10).toStringAsFixed(1)}/10'),
                      subtitle: Text('Based on ${_gameDetails!.totalRatingCount} ratings'),
                    ),
                ],

                // Release Date and Status
                if (_gameDetails!.releaseDate != null || _gameDetails!.status != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Release Information',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_gameDetails!.releaseDate != null)
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text('Release Date'),
                      subtitle: Text(_gameDetails!.releaseDate!.toString().split(' ')[0]),
                    ),
                  if (_gameDetails!.status != null)
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: Text('Status'),
                      subtitle: Text(_gameDetails!.status!),
                    ),
                ],

                // Platforms
                if (_gameDetails!.platforms.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Platforms',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Wrap(
                    spacing: 8,
                    children: _gameDetails!.platforms
                        .map((platform) => Chip(label: Text(platform)))
                        .toList(),
                  ),
                ],

                // Genres
                if (_gameDetails!.genres.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Genres',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Wrap(
                    spacing: 8,
                    children: _gameDetails!.genres
                        .map((genre) => Chip(label: Text(genre)))
                        .toList(),
                  ),
                ],

                // Game Modes
                if (_gameDetails!.gameModes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Game Modes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Wrap(
                    spacing: 8,
                    children: _gameDetails!.gameModes
                        .map((mode) => Chip(label: Text(mode)))
                        .toList(),
                  ),
                ],

                // Themes
                if (_gameDetails!.themes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Themes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Wrap(
                    spacing: 8,
                    children: _gameDetails!.themes
                        .map((theme) => Chip(label: Text(theme)))
                        .toList(),
                  ),
                ],

                // Game Engines
                if (_gameDetails!.gameEngines.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Game Engines',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Wrap(
                    spacing: 8,
                    children: _gameDetails!.gameEngines
                        .map((engine) => Chip(label: Text(engine)))
                        .toList(),
                  ),
                ],

                // Companies
                if (_gameDetails!.companies.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Companies',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Wrap(
                    spacing: 8,
                    children: _gameDetails!.companies
                        .map((company) => Chip(label: Text(company)))
                        .toList(),
                  ),
                ],

                // Summary
                if (_gameDetails!.summary != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(_gameDetails!.summary!),
                ],

                // Storyline
                if (_gameDetails!.storyline != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Storyline',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(_gameDetails!.storyline!),
                ],

                // Screenshots
                if (_gameDetails!.screenshots.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Screenshots',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _gameDetails!.screenshots.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: CachedNetworkImage(
                            imageUrl: _gameDetails!.screenshots[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) {
                              debugPrint('Error loading screenshot: $error');
                              return const Icon(Icons.error);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
