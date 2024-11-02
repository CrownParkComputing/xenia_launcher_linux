import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/settings_provider.dart';
import 'providers/iso_games_provider.dart';
import 'providers/live_games_provider.dart';
import 'screens/iso_games_screen.dart';
import 'screens/live_games_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => IsoGamesProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => LiveGamesProvider(prefs),
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
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.disc_full),
                label: Text('ISO Games'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.cloud_download),
                label: Text('Xbox Live Games'),
              ),
            ],
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
