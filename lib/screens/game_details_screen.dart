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

class GameDetailsScreen extends StatefulWidget {
  final Game game;

  const GameDetailsScreen({super.key, required this.game});

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
      final details = await _gameSearchService.searchGame(context, widget.game);
      developer.log('Received game details: $details');

      if (mounted) {
        setState(() {
          _gameDetails = details;
          _isLoading = false;
        });
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
          if (_gameDetails!.coverUrl != null)
            Center(
              child: CachedNetworkImage(
                imageUrl: _gameDetails!.coverUrl!,
                height: 300,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const Icon(Icons.error),
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
              ),
            ),
          _buildGameStats(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _gameDetails!.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (_gameDetails!.rating != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      Text(
                          ' ${(_gameDetails!.rating! / 10).toStringAsFixed(1)}/10'),
                    ],
                  ),
                ],
                if (_gameDetails!.releaseDate != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Released: ${_gameDetails!.releaseDate!.year}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                if (_gameDetails!.genres.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: _gameDetails!.genres
                        .map((genre) => Chip(label: Text(genre)))
                        .toList(),
                  ),
                ],
                if (_gameDetails!.summary != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(_gameDetails!.summary!),
                ],
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
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (_gameDetails!.gameModes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Game Modes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _gameDetails!.gameModes
                        .map((mode) => Chip(label: Text(mode)))
                        .toList(),
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
