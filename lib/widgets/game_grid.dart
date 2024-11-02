import 'package:flutter/material.dart';
import '../models/game.dart';
import 'game_card.dart';

class GameGrid extends StatelessWidget {
  final List<Game> games;
  final String? Function(String) getExecutableDisplayName;
  final void Function(Game) onGameTap;
  final void Function(Game) onGameMoreTap;
  final void Function(Game) onGameDelete;
  final VoidCallback onImportTap;

  const GameGrid({
    super.key,
    required this.games,
    required this.getExecutableDisplayName,
    required this.onGameTap,
    required this.onGameMoreTap,
    required this.onGameDelete,
    required this.onImportTap,
  });

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gamepad_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'No games imported yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onImportTap,
              icon: const Icon(Icons.add),
              label: const Text('Import Game'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 3/4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        return GameCard(
          game: game,
          executableDisplayName: game.lastUsedExecutable != null
              ? getExecutableDisplayName(game.lastUsedExecutable!)
              : null,
          onPlayTap: () => onGameTap(game),
          onDLCTap: () => onGameMoreTap(game),
          onDeleteTap: () => onGameDelete(game),
        );
      },
    );
  }
}
