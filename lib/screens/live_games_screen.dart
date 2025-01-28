import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/live_games_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/game_stats_provider.dart';
import '../models/game.dart';
import '../models/dlc.dart';
import '../screens/dlc_dialog.dart';
import '../widgets/game_grid.dart';
import '../screens/game_details_screen.dart';

class LiveGamesScreen extends StatefulWidget {
  const LiveGamesScreen({super.key});

  @override
  _LiveGamesScreenState createState() => _LiveGamesScreenState();
}

class _LiveGamesScreenState extends State<LiveGamesScreen> {
  String _getExecutableDisplayName(String? executablePath) {
    if (executablePath == null) return 'No executable set';
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final dummyGame = Game(
      title: '',
      path: '',
      lastUsedExecutable: executablePath,
      type: GameType.live,
    );
    return settingsProvider.getExecutableDisplayName(dummyGame) ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final liveProvider = Provider.of<LiveGamesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return _buildBody(context, liveProvider, settingsProvider);
  }

  Widget _buildBody(
    BuildContext context,
    LiveGamesProvider liveProvider,
    SettingsProvider settingsProvider,
  ) {
    if (liveProvider.config.baseFolder == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Please configure Xbox Live Games folder'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: const Text('Configure Xenia'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Xbox Live Games',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GameGrid(
              games: liveProvider.liveGames,
              getExecutableDisplayName: _getExecutableDisplayName,
              onGameTap: (game) => _launchGame(context, game),
              onGameMoreTap: (game) => _showDLCDialog(context, game),
              onGameDelete: (game) => _removeGame(context, game),
              onGameTitleEdit: (game, newTitle) => _updateGameTitle(context, game, newTitle),
              onGameSearchTitleEdit: (game, newSearchTitle) => _updateGameSearchTitle(context, game, newSearchTitle),
              onImportTap: () => _importGame(context),
              showAddGame: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGameTitle(BuildContext context, Game game, String newTitle) async {
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);
    final updatedGame = game.copyWith(title: newTitle);
    await liveProvider.updateGame(updatedGame);
  }

  Future<void> _updateGameSearchTitle(BuildContext context, Game game, String newSearchTitle) async {
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);
    final updatedGame = game.copyWith(searchTitle: newSearchTitle);
    await liveProvider.updateGame(updatedGame);
  }

  Future<void> _importGame(BuildContext context) async {
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);

    if (liveProvider.config.liveGamesFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please configure Xbox Live Games folder first')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Select Xbox Live Game',
      initialDirectory: liveProvider.config.liveGamesFolder,
    );

    if (result != null) {
      final game = await liveProvider.importGame(result.files.single.path!);
      if (game != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game imported successfully')),
        );

        // Prompt user to search IGDB for game details
        final shouldSearch = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Search Game Details'),
            content: const Text('Would you like to search IGDB to set the correct game details?'),
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
          // Show game details screen for searching
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameDetailsScreen(
                game: game,
                onGameUpdated: (updatedGame) async {
                  await liveProvider.updateGame(updatedGame);
                },
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _showDLCDialog(BuildContext context, Game game) async {
    await showDialog(
      context: context,
      builder: (context) => DLCDialog(game: game),
    );
  }

  Future<void> _removeGame(BuildContext context, Game game) async {
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);
    await liveProvider.removeGame(game);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game removed from library')),
      );
    }
  }

  Future<void> _launchGame(BuildContext context, Game game) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);

    // Check if game has IGDB ID
    if (game.igdbId == null) {
      final shouldSearch = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Game Details Missing'),
          content: const Text('This game does not have IGDB details. Would you like to search for it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Search'),
            ),
          ],
        ),
      );

      if (shouldSearch == true && context.mounted) {
        // Show game search dialog
        final updatedGame = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailsScreen(
              game: game,
              onGameUpdated: (updatedGame) async {
                await liveProvider.updateGame(updatedGame);
              },
            ),
          ),
        );

        if (updatedGame == null) {
          return; // User cancelled the search
        }
      }
    }

    // Use the specific Xenia paths
    final xeniaPath = settingsProvider.config.xeniaCanaryPath;
    if (xeniaPath == null) {
      throw Exception('Xenia executable not configured');
    }

    await _runGame(context, game, xeniaPath);
  }

  Future<void> _runGame(
      BuildContext context, Game game, String executable) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);
    final statsProvider =
        Provider.of<GameStatsProvider>(context, listen: false);
    final winePrefix = settingsProvider.config.winePrefix;

    if (winePrefix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wine prefix not set')),
      );
      return;
    }

    // Transform the path by replacing /run/media/jon/TVShows with F:
    String gamePath = game.executablePath ?? game.path;
    if (gamePath.startsWith('/run/media/jon/TVShows')) {
      gamePath = gamePath.replaceFirst('/run/media/jon/TVShows', 'F:');
    }

    final result = await settingsProvider.runExecutable(
      executable,
      winePrefix,
      [gamePath],
    );

    if (result.stderr != null && result.stderr!.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch game: ${result.stderr}')),
      );
      return;
    }

    if (result.process != null) {
      // Start tracking with the process
      await statsProvider.startTracking(game, executable, result.process!);
      await liveProvider.updateGameLastUsedExecutable(game, executable);

      // Wait for process to exit
      await result.process!.exitCode;

      // Stop tracking after game closes
      await statsProvider.stopTracking(game);
    }
  }
}
