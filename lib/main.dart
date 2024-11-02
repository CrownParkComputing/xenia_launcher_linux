import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/settings_provider.dart';
import 'providers/iso_games_provider.dart';
import 'providers/live_games_provider.dart';
import 'providers/game_stats_provider.dart';
import 'services/game_tracking_service.dart';
import 'screens/iso_games_screen.dart';
import 'screens/live_games_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(prefs),
        ),
        ChangeNotifierProxyProvider<SettingsProvider, IsoGamesProvider>(
          create: (context) => IsoGamesProvider(
            prefs,
            Provider.of<SettingsProvider>(context, listen: false),
          ),
          update: (context, settings, previous) => previous ?? IsoGamesProvider(prefs, settings),
        ),
        ChangeNotifierProxyProvider<SettingsProvider, LiveGamesProvider>(
          create: (context) => LiveGamesProvider(
            prefs,
            Provider.of<SettingsProvider>(context, listen: false),
          ),
          update: (context, settings, previous) => previous ?? LiveGamesProvider(prefs, settings),
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
}

class XeniaLauncher extends StatelessWidget {
  const XeniaLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xenia Launcher',
      theme: ThemeData.dark(useMaterial3: true),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    IsoGamesScreen(),
    LiveGamesScreen(),
    LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                icon: Icon(Icons.disc_full),
                label: Text('ISO Games'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.cloud_download),
                label: Text('Xbox Live Games'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                label: Text('Logs'),
              ),
            ],
            trailing: Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
    );
  }
}
