import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/config.dart';
import '../providers/settings_provider.dart';
import 'game_card.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'game_details_dialog.dart';

class GameGrid extends StatelessWidget {
  final List<Game> games;
  final String Function(String?) getExecutableDisplayName;
  final Function(Game) onGameTap;
  final Function(Game) onGameMoreTap;
  final Function(Game) onGameDelete;
  final Function(Game, String) onGameTitleEdit;
  final Function(Game, String) onGameSearchTitleEdit;
  final VoidCallback? onImportTap;
  final bool showAddGame;

  const GameGrid({
    super.key,
    required this.games,
    required this.getExecutableDisplayName,
    required this.onGameTap,
    required this.onGameMoreTap,
    required this.onGameDelete,
    required this.onGameTitleEdit,
    required this.onGameSearchTitleEdit,
    this.onImportTap,
    this.showAddGame = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: showAddGame ? games.length + 1 : games.length,
      itemBuilder: (context, index) {
        if (showAddGame && index == games.length) {
          return _buildAddCard(context);
        }
        return _buildGameCard(context, games[index]);
      },
    );
  }

  Widget _buildGameCard(BuildContext context, Game game) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (game.coverUrl != null)
            Positioned.fill(
              child: Image.network(
                game.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.error));
                },
              ),
            )
          else
            const Positioned.fill(
              child: Center(child: Icon(Icons.games)),
            ),
          Positioned.fill(
            top: 56,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onGameTap?.call(game),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showGameDetails(context, game),
                tooltip: 'Game Details',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGameDetails(BuildContext context, Game game) {
    showDialog(
      context: context,
      builder: (context) => GameDetailsDialog(game: game),
    );
  }

  Widget _buildAddCard(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onImportTap,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 48),
              SizedBox(height: 8),
              Text('Add Game'),
            ],
          ),
        ),
      ),
    );
  }
}
