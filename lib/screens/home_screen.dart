import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../zarchive/screens/zarchive_screen.dart';
import 'settings_screen.dart';
import 'logs_screen.dart';
import 'xbox_iso_extractor_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showLogs(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LogsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xenia Launcher'),
        actions: [
          // Logs button
          IconButton(
            icon: const Icon(Icons.article_outlined),
            onPressed: () => _showLogs(context),
            tooltip: 'View Logs',
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Xenia Launcher',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.extension),
              title: const Text('Xbox ISO Extractor'),
              onTap: () {
                // Close the drawer
                Navigator.pop(context);
                // Navigate to ISO Extractor screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const XboxIsoExtractorScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('ZArchive'),
              onTap: () {
                // Close the drawer
                Navigator.pop(context);
                // Navigate to ZArchive screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ZArchiveScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Center(
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
      ),
    );
  }
}
