import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/config.dart';
import '../providers/settings_provider.dart';
import 'game_card.dart';

class GameGrid extends StatelessWidget {
  final List<Game> games;
  final String? Function(Game) getExecutableDisplayName;
  final void Function(Game) onGameTap;
  final void Function(Game) onGameMoreTap;
  final void Function(Game) onGameDelete;
  final VoidCallback? onImportTap;

  const GameGrid({
    super.key,
    required this.games,
    required this.getExecutableDisplayName,
    required this.onGameTap,
    required this.onGameMoreTap,
    required this.onGameDelete,
    this.onImportTap,
  });

  double _getMaxCrossAxisExtent(GameCardSize size) {
    switch (size) {
      case GameCardSize.small:
        return 200;
      case GameCardSize.medium:
        return 260;
      case GameCardSize.large:
        return 320;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final cardSize = settingsProvider.config.cardSize;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _getMaxCrossAxisExtent(cardSize),
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: games.length + (onImportTap != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (onImportTap != null && index == games.length) {
          // Add Game Card
          return Card(
            child: InkWell(
              onTap: onImportTap,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, size: 48),
                    SizedBox(height: 8),
                    Text('Add Game'),
                  ],
                ),
              ),
            ),
          );
        }

        final game = games[index];
        return GameCard(
          game: game,
          executableDisplayName: getExecutableDisplayName(game),
          onPlayTap: () => onGameTap(game),
          onDLCTap: () => onGameMoreTap(game),
          onDeleteTap: () => onGameDelete(game),
        );
      },
    );
  }
}
