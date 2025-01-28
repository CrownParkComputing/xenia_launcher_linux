import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../providers/iso_games_provider.dart';
import '../providers/live_games_provider.dart';
import '../providers/settings_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'game_details_screen.dart';
import 'package:path/path.dart' as path;
import '../services/xbox_live_game_service.dart';
import 'dart:io';

class GameLibraryScreen extends StatefulWidget {
  const GameLibraryScreen({super.key});

  @override
  State<GameLibraryScreen> createState() => _GameLibraryScreenState();
}

class _GameLibraryScreenState extends State<GameLibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final isoGames = Provider.of<IsoGamesProvider>(context).isoGames;
    final liveGames = Provider.of<LiveGamesProvider>(context).liveGames;
    final allGames = [...isoGames, ...liveGames];

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Game Library Management',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _importIsoGame(context),
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Import ISO Game'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _importXboxLiveGame(context),
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Import Xbox Live Game'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: allGames.length,
              itemBuilder: (context, index) {
                final game = allGames[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ExpansionTile(
                    title: Text(game.title),
                    subtitle: Text(game.path),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEditableField(
                              label: 'Title',
                              value: game.title,
                              onChanged: (value) => _updateGameField(context, game, 'title', value),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildEditableField(
                                    label: 'IGDB ID',
                                    value: game.igdbId?.toString() ?? '',
                                    onChanged: (value) => _updateGameField(context, game, 'igdbId', value),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                if (game.igdbId == null) ...[
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _searchIGDB(context, game),
                                    icon: const Icon(Icons.search),
                                    label: const Text('Search IGDB'),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildEditableField(
                              label: 'Search Title',
                              value: game.searchTitle ?? '',
                              onChanged: (value) => _updateGameField(context, game, 'searchTitle', value),
                            ),
                            const SizedBox(height: 8),
                            _buildEditableField(
                              label: 'Path',
                              value: game.path,
                              onChanged: (value) => _updateGameField(context, game, 'path', value),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _deleteGame(context, game),
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required String value,
    required Function(String) onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      onSubmitted: onChanged,
    );
  }

  Future<void> _updateGameField(BuildContext context, Game game, String field, String value) async {
    final provider = game.isIsoGame
        ? Provider.of<IsoGamesProvider>(context, listen: false)
        : Provider.of<LiveGamesProvider>(context, listen: false);

    Game updatedGame;
    switch (field) {
      case 'title':
        updatedGame = game.copyWith(title: value);
        break;
      case 'searchTitle':
        updatedGame = game.copyWith(searchTitle: value);
        break;
      case 'igdbId':
        updatedGame = game.copyWith(igdbId: int.tryParse(value));
        break;
      case 'path':
        updatedGame = game.copyWith(path: value);
        break;
      default:
        return;
    }

    await provider.updateGame(updatedGame);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game updated successfully')),
      );
    }
  }

  Future<void> _deleteGame(BuildContext context, Game game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: Text('Are you sure you want to delete "${game.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = game.isIsoGame
          ? Provider.of<IsoGamesProvider>(context, listen: false)
          : Provider.of<LiveGamesProvider>(context, listen: false);
      
      await provider.removeGame(game);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game deleted successfully')),
        );
      }
    }
  }

  Future<void> _searchIGDB(BuildContext context, Game game) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailsScreen(
          game: game,
          onGameUpdated: (updatedGame) async {
            final provider = game.isIsoGame
                ? Provider.of<IsoGamesProvider>(context, listen: false)
                : Provider.of<LiveGamesProvider>(context, listen: false);
            await provider.updateGame(updatedGame);
            setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> _importIsoGame(BuildContext context) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
    
    if (isoProvider.config.isoFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure ISO Games folder first')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['iso', 'zar'],
      dialogTitle: 'Select Xbox 360 Game File',
      initialDirectory: isoProvider.config.isoFolder,
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      final game = await isoProvider.importGame(result.files.single.path!);
      
      if (game != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game added successfully')),
        );

        // Immediately prompt to search IGDB
        final shouldSearch = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Search Game Details'),
            content: Text('Would you like to search for details for ${game.title}?'),
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

        if (shouldSearch == true && context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameDetailsScreen(
                game: game,
                onGameUpdated: (updatedGame) async {
                  await isoProvider.updateGame(updatedGame);
                  setState(() {});
                },
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _importXboxLiveGame(BuildContext context) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      if (settingsProvider.config.baseFolder == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please configure Xenia folder first')),
        );
        return;
      }

      final contentPath = path.join(settingsProvider.config.baseFolder!, 'content');
      if (!Directory(contentPath).existsSync()) {
        await Directory(contentPath).create(recursive: true);
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['rar'],
        dialogTitle: 'Select Xbox Live Game RAR File',
      );

      if (result != null && result.files.single.path != null && context.mounted) {
        try {
          final xboxLiveService = XboxLiveGameService(contentPath);
          final game = await xboxLiveService.importRarGame(result.files.single.path!, settingsProvider);
          
          if (game != null && context.mounted) {
            final provider = Provider.of<LiveGamesProvider>(context, listen: false);
            await provider.addGame(game);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Game added successfully')),
              );

              // Immediately prompt to search IGDB
              final shouldSearch = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Search Game Details'),
                  content: Text('Would you like to search for details for ${game.title}?'),
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

              if (shouldSearch == true && context.mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameDetailsScreen(
                      game: game,
                      onGameUpdated: (updatedGame) async {
                        await provider.updateGame(updatedGame);
                        setState(() {});
                      },
                    ),
                  ),
                );
              }
            }
          }
        } catch (e) {
          if (context.mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Import Failed'),
                content: Text('Failed to import game: ${e.toString()}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
} 