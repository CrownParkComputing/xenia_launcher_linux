import 'package:flutter/material.dart';
import '../models/game.dart';
import '../screens/achievements_screen.dart';
import '../screens/game_details_screen.dart';

class GameDetailsDialog extends StatelessWidget {
  final Game game;

  const GameDetailsDialog({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (game.coverUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      game.coverUrl!,
                      width: 120,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.games, size: 48),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      if (game.searchTitle != null && game.searchTitle != game.title)
                        Text(
                          'Search Title: ${game.searchTitle}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Type: ${game.isLiveGame ? 'Xbox Live Game' : 'ISO Game'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Achievements: ${game.achievements.length}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (game.igdbId != null) ...[
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GameDetailsScreen(
                                  game: game,
                                  onGameUpdated: null,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info),
                          label: const Text('View Full Game Details'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AchievementsScreen(game: game),
                      ),
                    );
                  },
                  child: const Text('View Achievements'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 