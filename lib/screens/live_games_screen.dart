import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/live_games_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/game_stats_provider.dart';
import '../models/game.dart';
import '../widgets/game_grid.dart';
import 'dlc_dialog.dart';

class LiveGamesScreen extends StatelessWidget {
  const LiveGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final liveProvider = Provider.of<LiveGamesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xbox Live Games'),
        actions: [
          if (liveProvider.config.liveGamesFolder != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _rescanGames(context),
              tooltip: 'Scan for changes',
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _importGame(context),
            tooltip: 'Import Game',
          ),
        ],
      ),
      body: _buildBody(context, liveProvider, settingsProvider),
    );
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
            const Text('Welcome to Xenia Launcher'),
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
            'Games',
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
              onImportTap: () => _importGame(context),
            ),
          ),
        ],
      ),
    );
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
      dialogTitle: 'Select Xbox Live Game ZIP',
      initialDirectory: liveProvider.config.liveGamesFolder,
    );

    if (result != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Consumer<LiveGamesProvider>(
          builder: (context, provider, child) {
            return Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        provider.importStatus.isNotEmpty
                            ? provider.importStatus
                            : 'Importing game...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );

      final game = await liveProvider.importGame(result.files.single.path!);

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        if (game != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully imported ${game.title}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to import game')),
          );
        }
      }
    }
  }

  Future<void> _rescanGames(BuildContext context) async {
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await liveProvider.rescanGames();

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Found ${liveProvider.liveGames.length} Xbox Live games')),
      );
    }
  }

  Future<void> _showDLCDialog(BuildContext context, Game game) {
    return showDialog(
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

    if (game.executablePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game executable not found')),
      );
      return;
    }

    final result = await settingsProvider.runExecutable(
      executable,
      winePrefix,
      [game.executablePath!],
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
