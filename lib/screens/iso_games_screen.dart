import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/iso_games_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/game_stats_provider.dart';
import '../models/game.dart';
import '../widgets/game_grid.dart';

class IsoGamesScreen extends StatelessWidget {
  const IsoGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isoProvider = Provider.of<IsoGamesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return _buildBody(context, isoProvider, settingsProvider);
  }

  Widget _buildBody(
    BuildContext context,
    IsoGamesProvider isoProvider,
    SettingsProvider settingsProvider,
  ) {
    if (isoProvider.config.baseFolder == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Please configure ISO Games folder'),
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
              games: isoProvider.isoGames,
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
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
    final updatedGame = game.copyWith(title: newTitle);
    await isoProvider.updateGame(updatedGame);
  }

  Future<void> _updateGameSearchTitle(BuildContext context, Game game, String newSearchTitle) async {
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
    final updatedGame = game.copyWith(searchTitle: newSearchTitle);
    await isoProvider.updateGame(updatedGame);
  }

  Future<void> _importGame(BuildContext context) async {
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);

    if (isoProvider.config.isoFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please configure ISO Games folder first')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['iso', 'zar'],
      dialogTitle: 'Select Xbox 360 Game File',
      initialDirectory: isoProvider.config.isoFolder,
    );

    if (result != null) {
      await isoProvider.importGame(result.files.single.path!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game imported successfully')),
        );
      }
    }
  }

  Future<void> _showDLCDialog(BuildContext context, Game game) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('DLC is not supported for ISO games')),
    );
  }

  Future<void> _removeGame(BuildContext context, Game game) async {
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
    await isoProvider.removeGame(game);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game removed from library')),
      );
    }
  }

  Future<void> _launchGame(BuildContext context, Game game) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);

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
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
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
    String gamePath = game.path;
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
      await isoProvider.updateGameLastUsedExecutable(game, executable);

      // Wait for process to exit
      await result.process!.exitCode;

      // Stop tracking after game closes
      await statsProvider.stopTracking(game);
    }
  }
}
