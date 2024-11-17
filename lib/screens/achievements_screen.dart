import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/achievement.dart';
import 'package:provider/provider.dart';
import '../services/achievement_service.dart';
import '../providers/settings_provider.dart';
import '../providers/iso_games_provider.dart';
import '../providers/live_games_provider.dart';

class AchievementsScreen extends StatelessWidget {
  final Game game;

  const AchievementsScreen({super.key, required this.game});

  Future<void> _refreshAchievements(BuildContext context) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final achievementService = AchievementService();
    final winePrefix = settingsProvider.config.winePrefix;

    if (winePrefix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wine prefix not set')),
      );
      return;
    }

    // Get the executable path
    final xeniaPath = settingsProvider.config.xeniaCanaryPath ?? 
                     settingsProvider.config.xeniaNetplayPath ?? 
                     settingsProvider.config.xeniaStablePath;

    if (xeniaPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Xenia executable found')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final achievements = await achievementService.extractAchievements(
        game,
        xeniaPath,
        winePrefix,
        settingsProvider,
      );

      if (context.mounted) {
        // Update game with new achievements
        final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);
        final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);
        final updatedGame = game.copyWith(achievements: achievements);

        if (game.isLiveGame) {
          await liveProvider.updateGame(updatedGame);
        } else {
          await isoProvider.updateGame(updatedGame);
        }

        // Close loading indicator
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${achievements.length} achievements'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading indicator
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing achievements: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${game.title} Achievements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshAchievements(context),
            tooltip: 'Refresh Achievements',
          ),
        ],
      ),
      body: game.achievements.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No achievements found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refreshAchievements(context),
                    child: const Text('Refresh Achievements'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: game.achievements.length,
              itemBuilder: (context, index) {
                final achievement = game.achievements[index];
                return ListTile(
                  leading: const Icon(Icons.emoji_events),
                  title: Text(achievement.title),
                  subtitle: Text(achievement.description),
                  trailing: achievement.gamerscore != null
                      ? Chip(label: Text('${achievement.gamerscore}G'))
                      : null,
                );
              },
            ),
    );
  }
}
