import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'providers/settings_provider.dart';
import 'providers/folder_provider.dart';
import 'providers/iso_games_provider.dart';
import 'providers/live_games_provider.dart';
import 'providers/game_stats_provider.dart';
import 'services/game_tracking_service.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/igdb_search_screen.dart';
import 'screens/zarchive_screen.dart';
import 'screens/game_details_screen.dart';
import 'services/igdb_service.dart';
import 'services/universal_game_service.dart';
import 'models/game.dart';
import 'widgets/game_grid.dart';
import 'dart:developer';
import 'package:file_picker/file_picker.dart';
import 'screens/game_library_screen.dart';

void main() async {
  try {
    print('Starting Xenia Launcher...');
    WidgetsFlutterBinding.ensureInitialized();
    print('Flutter binding initialized');
    
    await windowManager.ensureInitialized();
    print('Window manager initialized');

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 720),
      center: true,
      title: 'Xenia Launcher',
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );

    print('Setting up window options');
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      print('Window ready to show');
      await windowManager.setIcon('assets/icon.png');
      await windowManager.show();
      await windowManager.focus();
    });

    print('Initializing SharedPreferences');
    final prefs = await SharedPreferences.getInstance();
    print('SharedPreferences initialized');

    print('Starting app with providers');
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(prefs),
          ),
          ChangeNotifierProvider(
            create: (_) => FolderProvider(prefs),
          ),
          ChangeNotifierProxyProvider<SettingsProvider, IsoGamesProvider>(
            create: (context) => IsoGamesProvider(
              prefs,
              Provider.of<SettingsProvider>(context, listen: false),
            ),
            update: (context, settings, previous) =>
                previous ?? IsoGamesProvider(prefs, settings),
          ),
          ChangeNotifierProxyProvider<SettingsProvider, LiveGamesProvider>(
            create: (context) => LiveGamesProvider(
              prefs,
              Provider.of<SettingsProvider>(context, listen: false),
            ),
            update: (context, settings, previous) =>
                previous ?? LiveGamesProvider(prefs, settings),
          ),
          ChangeNotifierProvider(
            create: (context) {
              final provider = GameStatsProvider(prefs);
              GameTrackingService().setStatsProvider(provider);
              return provider;
            },
          ),
        ],
        child: const XeniaLauncher(),
      ),
    );
  } catch (e) {
    print('Error starting Xenia Launcher: $e');
  }
}

class XeniaLauncher extends StatelessWidget {
  const XeniaLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    print('Building XeniaLauncher widget');
    return MaterialApp(
      title: 'Xenia Launcher',
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WindowListener {
  int _selectedIndex = 0;
  bool _isMaximized = false;
  late IGDBService _igdbService;
  late UniversalGameService _gameService;
  List<Game> _games = [];
  bool _isLoading = true;

  @override
  void initState() {
    print('Initializing MainScreen');
    super.initState();
    windowManager.addListener(this);
    SharedPreferences.getInstance().then((prefs) {
      setState(() {
        _igdbService = IGDBService(prefs);
        _gameService = UniversalGameService();
        _loadGames();
      });
    });
  }

  Future<void> _loadGames() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final games = await _gameService.loadGames();
      setState(() {
        _games = games;
      });
      
      // Check for missing covers
      await _igdbService.checkAndFetchMissingCovers(_games);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      log('Error loading games: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGameUpdate(Game updatedGame) async {
    await _gameService.updateGame(updatedGame);
    await _loadGames(); // Refresh the games list
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void _initOld() async {
    await windowManager.setPreventClose(true);
    setState(() {});
  }

  @override
  void onWindowMaximize() {
    setState(() {
      _isMaximized = true;
    });
  }

  @override
  void onWindowUnmaximize() {
    setState(() {
      _isMaximized = false;
    });
  }

  @override
  void onWindowClose() async {
    await windowManager.destroy();
  }

  String _getExecutableDisplayName(String? executablePath) {
    if (executablePath == null) return 'No executable set';
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final dummyGame = Game(
      title: '',
      path: '',
      lastUsedExecutable: executablePath,
      type: GameType.iso,
    );
    return settingsProvider.getExecutableDisplayName(dummyGame) ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isoProvider = Provider.of<IsoGamesProvider>(context);
    final liveProvider = Provider.of<LiveGamesProvider>(context);

    final isoGames = isoProvider.isoGames;
    final liveGames = liveProvider.liveGames;
    final allGames = [...isoGames, ...liveGames];

    final screens = [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: GameGrid(
          games: allGames,
          getExecutableDisplayName: _getExecutableDisplayName,
          onGameTap: (game) => _launchGame(context, game),
          onGameMoreTap: (game) => _showDLCDialog(context, game),
          onGameDelete: (game) => _removeGame(context, game),
          onGameTitleEdit: (game, newTitle) => _updateGameTitle(context, game, newTitle),
          onGameSearchTitleEdit: (game, newSearchTitle) => _updateGameSearchTitle(context, game, newSearchTitle),
          onImportTap: () => _importGame(context),
        ),
      ),
      const IgdbSearchScreen(),
      const GameLibraryScreen(),
      const LogsScreen(),
      const ZArchiveScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.minimize),
            onPressed: () async {
              await windowManager.minimize();
            },
            tooltip: 'Minimize',
          ),
          IconButton(
            icon: Icon(_isMaximized ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: () async {
              if (_isMaximized) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
            tooltip: _isMaximized ? 'Exit Fullscreen' : 'Fullscreen',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await windowManager.close();
            },
            tooltip: 'Close',
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.games),
                label: Text('Games'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search),
                label: Text('IGDB Search'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_books),
                label: Text('Library'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                label: Text('Logs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.archive),
                label: Text('Game Files'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: screens[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Future<void> _launchGame(BuildContext context, Game game) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await _gameService.launchGame(game, settingsProvider);
      
      // Update last used executable if needed
      if (game.lastUsedExecutable != settingsProvider.config.xeniaCanaryPath) {
        final provider = game.isIsoGame
            ? Provider.of<IsoGamesProvider>(context, listen: false)
            : Provider.of<LiveGamesProvider>(context, listen: false);
        final updatedGame = game.copyWith(lastUsedExecutable: settingsProvider.config.xeniaCanaryPath);
        await provider.updateGame(updatedGame);
      }
    } catch (e) {
      debugPrint('Error launching game: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to launch game: $e')),
        );
      }
    }
  }

  Future<void> _showDLCDialog(BuildContext context, Game game) async {
    // Implement DLC dialog
  }

  Future<void> _removeGame(BuildContext context, Game game) async {
    final provider = game.isIsoGame
        ? Provider.of<IsoGamesProvider>(context, listen: false)
        : Provider.of<LiveGamesProvider>(context, listen: false);
    await provider.removeGame(game);
  }

  Future<void> _updateGameTitle(BuildContext context, Game game, String newTitle) async {
    final provider = game.isIsoGame
        ? Provider.of<IsoGamesProvider>(context, listen: false)
        : Provider.of<LiveGamesProvider>(context, listen: false);
    final updatedGame = game.copyWith(title: newTitle);
    await provider.updateGame(updatedGame);
  }

  Future<void> _updateGameSearchTitle(BuildContext context, Game game, String newSearchTitle) async {
    final provider = game.isIsoGame
        ? Provider.of<IsoGamesProvider>(context, listen: false)
        : Provider.of<LiveGamesProvider>(context, listen: false);
    final updatedGame = game.copyWith(searchTitle: newSearchTitle);
    await provider.updateGame(updatedGame);
  }

  Future<void> _importGame(BuildContext context) async {
    try {
      final provider = Provider.of<IsoGamesProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Get the base folder from settings
      final baseFolder = settingsProvider.config.isoFolder;
      if (baseFolder == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please configure ISO Games folder first')),
        );
        return;
      }

      // Show file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['iso', 'zar'],
        dialogTitle: 'Select Xbox 360 Game File',
        initialDirectory: baseFolder,
      );

      if (result != null && result.files.single.path != null) {
        // Import the game using universal service
        final game = await _gameService.importGame(result.files.single.path!, settingsProvider);
        
        if (game != null && context.mounted) {
          await provider.addGame(game);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Game imported successfully')),
          );

          // Prompt to search IGDB
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
      debugPrint('Error importing game: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import game: $e')),
        );
      }
    }
  }
}
