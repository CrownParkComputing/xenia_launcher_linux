import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../services/igdb_service.dart';
import '../models/igdb_game.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class GameSearchDialog extends StatefulWidget {
  final String initialQuery;
  final IGDBService igdbService;

  const GameSearchDialog({
    super.key,
    required this.initialQuery,
    required this.igdbService,
  });

  @override
  State<GameSearchDialog> createState() => _GameSearchDialogState();
}

class _GameSearchDialogState extends State<GameSearchDialog> {
  late final TextEditingController _searchController;
  List<IGDBGame> _results = [];
  bool _isLoading = false;
  String? _error;
  late final IGDBService _igdbService;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _igdbService = widget.igdbService;
    _search();
  }

  Future<void> _search() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      developer.log('Searching for: ${_searchController.text}');
      final results = await _igdbService.searchGames(_searchController.text);
      
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
        developer.log('Found ${results.length} results');
      }
    } catch (e) {
      developer.log('Error searching games: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
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
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _search,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Center(
                  child: Column(
                    children: [
                      Text('Error: $_error'),
                      TextButton(
                        onPressed: _search,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (_results.isEmpty)
                const Center(child: Text('No results found'))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final game = _results[index];
                      return Card(
                        child: ListTile(
                          leading: SizedBox(
                            width: 60,
                            height: 90,
                            child: game.coverUrl != null
                                ? (game.localCoverPath != null && File(game.localCoverPath!).existsSync()
                                    ? Image.file(
                                        File(game.localCoverPath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          debugPrint('Error loading local cover: $error');
                                          return const Icon(Icons.error);
                                        },
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: game.coverUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) {
                                          debugPrint('Error loading network cover: $error');
                                          return const Icon(Icons.error);
                                        },
                                      ))
                                : const Icon(Icons.gamepad),
                          ),
                          title: Text(game.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (game.releaseDate != null)
                                Text(DateFormat.yMMMd()
                                    .format(game.releaseDate!)),
                              if (game.rating != null)
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 16, color: Colors.amber),
                                    Text(
                                        ' ${(game.rating! / 10).toStringAsFixed(1)}/10'),
                                  ],
                                ),
                            ],
                          ),
                          onTap: () async {
                            developer.log('Selected game: ${game.name} with ID: ${game.id}');
                            
                            // Get full game details using the ID
                            final fullGameDetails = await _igdbService.getGameById(game.id);
                            if (fullGameDetails == null) {
                              developer.log('Failed to get full game details');
                              if (!context.mounted) return;
                              Navigator.of(context).pop(game);
                              return;
                            }

                            developer.log('Got full game details');
                            // Download cover if available
                            if (fullGameDetails.coverUrl != null) {
                              developer.log('Downloading cover for ${fullGameDetails.name}');
                              final downloadedPath = await _igdbService.downloadCover(
                                fullGameDetails.coverUrl!,
                                fullGameDetails.name,
                              );
                              if (downloadedPath != null) {
                                fullGameDetails.localCoverPath = downloadedPath;
                                developer.log('Cover downloaded to: $downloadedPath');
                              } else {
                                developer.log('Failed to download cover');
                              }
                            }
                            
                            if (!context.mounted) return;

                            // Show confirmation dialog with more details
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Game Selection'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Please confirm this is the correct game:'),
                                      const SizedBox(height: 16),
                                      if (fullGameDetails.localCoverPath != null)
                                        SizedBox(
                                          height: 200,
                                          child: Image.file(
                                            File(fullGameDetails.localCoverPath!),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      const SizedBox(height: 16),
                                      Text('Title: ${fullGameDetails.name}', style: Theme.of(context).textTheme.titleMedium),
                                      if (fullGameDetails.releaseDate != null)
                                        Text('Release Date: ${DateFormat.yMMMd().format(fullGameDetails.releaseDate!)}'),
                                      if (fullGameDetails.platforms.isNotEmpty)
                                        Text('Platforms: ${fullGameDetails.platforms.join(", ")}'),
                                      if (fullGameDetails.genres.isNotEmpty)
                                        Text('Genres: ${fullGameDetails.genres.join(", ")}'),
                                      if (fullGameDetails.summary != null) ...[
                                        const SizedBox(height: 8),
                                        Text('Summary:', style: Theme.of(context).textTheme.titleSmall),
                                        Text(fullGameDetails.summary!),
                                      ],
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('No, Search Again'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Yes, Update Game'),
                                  ),
                                ],
                              ),
                            );

                            if (!context.mounted) return;
                            if (confirmed == true) {
                              Navigator.of(context).pop(fullGameDetails);
                            }
                            // If not confirmed, stay on search screen
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 