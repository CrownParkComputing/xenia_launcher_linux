import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/iso_games_provider.dart';
import '../providers/live_games_provider.dart';
import '../providers/settings_provider.dart';
import 'iso_games_screen.dart';
import 'live_games_screen.dart';

class XboxGamesScreen extends StatelessWidget {
  const XboxGamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isoProvider = Provider.of<IsoGamesProvider>(context);
    final liveProvider = Provider.of<LiveGamesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    // Show welcome screen if neither folder is configured
    if (isoProvider.config.baseFolder == null && liveProvider.config.baseFolder == null) {
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TabBar(
              tabs: const [
                Tab(text: 'ISO Games'),
                Tab(text: 'Xbox Live Games'),
              ],
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            IsoGamesScreen(),
            LiveGamesScreen(),
          ],
        ),
      ),
    );
  }
}
