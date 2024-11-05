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

class LiveGamesScreen extends StatelessWidget {
  const LiveGamesScreen({super.key});

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
              getExecutableDisplayName:
                  settingsProvider.getExecutableDisplayName,
              onGameTap: (game) => _launchGame(context, game),
              onGameMoreTap: (game) => _showDLCDialog(context, game),
              onGameDelete: (game) => _removeGame(context, game),
              onGameTitleEdit: (game, newTitle) => _updateGameTitle(context, game, newTitle),
              onGameSearchTitleEdit: (game, newSearchTitle) => _updateGameSearchTitle(context, game, newSearchTitle),
              onImportTap: () => _importGame(context),
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
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);

    if (settingsProvider.config.xeniaExecutables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Xenia executables found')),
      );
      return;
    }

    // If there's a last used executable, use it directly
    final executable = game.lastUsedExecutable ??
        settingsProvider.config.xeniaExecutables.first;
    await _runGame(context, game, executable);
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
