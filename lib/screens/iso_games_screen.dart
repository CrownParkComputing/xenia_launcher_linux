import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/iso_games_provider.dart';
import '../providers/settings_provider.dart';
import '../models/game.dart';
import '../widgets/game_grid.dart';
import 'settings_screen.dart';

class IsoGamesScreen extends StatelessWidget {
  const IsoGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isoProvider = Provider.of<IsoGamesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ISO Games'),
        actions: _buildActions(context, isoProvider),
      ),
      body: _buildBody(context, isoProvider, settingsProvider),
    );
  }

  List<Widget> _buildActions(BuildContext context, IsoGamesProvider isoProvider) {
    return [
      if (isoProvider.config.isoFolder != null)
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
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () => _showSettings(context),
      ),
    ];
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
            const Text('Welcome to Xenia Launcher'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showSettings(context),
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
              getExecutableDisplayName: settingsProvider.getExecutableDisplayName,
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

  void _showSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _importGame(BuildContext context) async {
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
    
    if (isoProvider.config.isoFolder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure ISO Games folder first')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['iso'],
      dialogTitle: 'Select Xbox 360 ISO',
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

  Future<void> _rescanGames(BuildContext context) async {
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await isoProvider.scanForChanges();

    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog
      
      String message = '';
      if (result.newGames.isNotEmpty) {
        message += 'Found ${result.newGames.length} new games\n';
      }
      if (result.removedGames.isNotEmpty) {
        message += 'Removed ${result.removedGames.length} missing games';
      }
      if (message.isEmpty) {
        message = 'No changes found';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
    
    if (settingsProvider.config.xeniaExecutables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Xenia executables found')),
      );
      return;
    }

    // If there's a last used executable, use it directly
    final executable = game.lastUsedExecutable ?? settingsProvider.config.xeniaExecutables.first;
    await _runGame(context, game, executable);
  }

  Future<void> _runGame(BuildContext context, Game game, String executable) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
    final winePrefix = settingsProvider.config.winePrefix;

    if (winePrefix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wine prefix not set')),
      );
      return;
    }

    final result = await settingsProvider.runExecutable(
      executable,
      winePrefix,
      [game.path],
    );

    if (result.stderr != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch game: ${result.stderr}')),
      );
    } else {
      await isoProvider.updateGameLastUsedExecutable(game, executable);
    }
  }
}
