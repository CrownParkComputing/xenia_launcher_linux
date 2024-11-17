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
import 'screens/xbox_games_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/igdb_search_screen.dart';
import 'screens/xbox_iso_extractor_screen.dart';
import 'screens/zarchive_screen.dart';

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

  static const List<Widget> _screens = [
    XboxGamesScreen(),
    IgdbSearchScreen(),
    LogsScreen(),
    XboxIsoExtractorScreen(),
    ZArchiveScreen(),
  ];

  @override
  void initState() {
    print('Initializing MainScreen');
    super.initState();
    windowManager.addListener(this);
    _init();
  }

  Future<void> _init() async {
    try {
      print('Running MainScreen init');
      await Future.wait([
        windowManager.setPreventClose(false),
        windowManager.setMinimumSize(const Size(800, 600)),
      ]);
      print('MainScreen init complete');
    } catch (e) {
      print('Error in MainScreen init: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: 8),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.gamepad),
                  label: Text('Xbox Games'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search),
                  label: Text('IGDB Search'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.article_outlined),
                  label: Text('Logs'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.iso),
                  label: Text('ISO Extractor'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_zip),
                  label: Text('Game Files'),
                ),
              ],
              trailing: Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings),
                      SizedBox(height: 4),
                      Text('Settings'),
                    ],
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: _screens[_selectedIndex],
            ),
          ],
        ),
      ),
    );
  }
}
