import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/achievement.dart';

class AchievementsScreen extends StatelessWidget {
  final Game game;

  const AchievementsScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${game.title} Achievements'),
      ),
      body: game.achievements.isEmpty
          ? const Center(
              child: Text('No achievements found'),
            )
          : ListView.builder(
              itemCount: game.achievements.length,
              itemBuilder: (context, index) {
                final achievement = game.achievements[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: ListTile(
                    title: Text(achievement.title),
                    subtitle: Text(achievement.description),
                    trailing: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Text(
                        'G ${achievement.gamerscore}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
