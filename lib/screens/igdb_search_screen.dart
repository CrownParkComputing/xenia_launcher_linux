import 'package:flutter/material.dart';
import '../services/igdb_service.dart';
import '../services/game_search_service.dart';
import '../models/igdb_game.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class IgdbSearchScreen extends StatefulWidget {
  const IgdbSearchScreen({super.key});

  @override
  State<IgdbSearchScreen> createState() => _IgdbSearchScreenState();
}

class _IgdbSearchScreenState extends State<IgdbSearchScreen> {
  final _searchController = TextEditingController();
  final _igdbService = IGDBService();
  late final _gameSearchService = GameSearchService(_igdbService);
  List<IGDBGame> _results = [];
  bool _isLoading = false;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      final results = await _igdbService.searchGames(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IGDB Search',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search IGDB',
                      border: OutlineInputBorder(),
                      hintText: 'Enter game title',
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_results.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final game = _results[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context, {
                            'coverUrl': game.coverUrl,
                            'igdbId': game.id,
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (game.coverUrl != null)
                                SizedBox(
                                  width: 100,
                                  height: 150,
                                  child: CachedNetworkImage(
                                    imageUrl: game.coverUrl!,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                  ),
                                )
                              else
                                Container(
                                  width: 100,
                                  height: 150,
                                  color: Colors.black26,
                                  child: const Icon(Icons.gamepad, size: 48),
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      game.name,
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    if (game.releaseDate != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat.yMMMd().format(game.releaseDate!),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                    if (game.rating != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, size: 16, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            (game.rating! / 20).toStringAsFixed(1),
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (game.summary != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        game.summary!,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (game.genres.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: game.genres
                                            .map((g) => Chip(
                                                  label: Text(g),
                                                  visualDensity: VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize.shrinkWrap,
                                                ))
                                            .toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              const Center(
                child: Text('No results found'),
              ),
          ],
        ),
      ),
    );
  }
}
