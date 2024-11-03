import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/igdb_game.dart';
import '../models/config.dart';
import '../providers/settings_provider.dart';
import '../services/dlc_service.dart';
import '../services/igdb_service.dart';
import '../screens/logs_screen.dart' show log;
import '../screens/game_details_screen.dart';
import '../screens/achievements_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GameCard extends StatefulWidget {
  final Game game;
  final String? executableDisplayName;
  final VoidCallback onPlayTap;
  final VoidCallback onDLCTap;
  final VoidCallback onDeleteTap;

  const GameCard({
    super.key,
    required this.game,
    required this.executableDisplayName,
    required this.onPlayTap,
    required this.onDLCTap,
    required this.onDeleteTap,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _isHovering = false;
  final IGDBService _igdbService = IGDBService();
  IGDBGame? _gameDetails;

  @override
  void initState() {
    super.initState();
    _loadGameDetails();
  }

  @override
  void didUpdateWidget(GameCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.title != widget.game.title) {
      _loadGameDetails();
    }
  }

  Future<void> _loadGameDetails() async {
    try {
      final details = await _igdbService.getGameDetails(widget.game.title);
      if (mounted) {
        setState(() {
          _gameDetails = details;
        });
      }
    } catch (e) {
      log('Error loading game details: $e');
    }
  }

  void _showAchievements() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AchievementsScreen(game: widget.game),
      ),
    );
  }

  double _getCardWidth(GameCardSize size) {
    switch (size) {
      case GameCardSize.small:
        return 180;
      case GameCardSize.medium:
        return 240;
      case GameCardSize.large:
        return 300;
    }
  }

  double _getCardHeight(GameCardSize size) {
    switch (size) {
      case GameCardSize.small:
        return 280;
      case GameCardSize.medium:
        return 360;
      case GameCardSize.large:
        return 440;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final cardSize = settingsProvider.config.cardSize;

    return FutureBuilder<int>(
      future: DLCService.countDLC(widget.game),
      builder: (context, snapshot) {
        final dlcCount = snapshot.data ?? 0;
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GameDetailsScreen(game: widget.game),
                ),
              );
            },
            child: SizedBox(
              width: _getCardWidth(cardSize),
              height: _getCardHeight(cardSize),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Game Cover - 3/4 of card height
                    Expanded(
                      flex: 3,
                      child: Stack(
                        children: [
                          _buildCover(),
                          // Dark overlay when hovering
                          if (_isHovering)
                            Container(
                              color: Colors.black.withOpacity(0.3),
                            ),
                          // Play button
                          AnimatedOpacity(
                            opacity: _isHovering ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Center(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  iconSize: 64,
                                  icon: const Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white,
                                  ),
                                  onPressed: widget.onPlayTap,
                                  tooltip: 'Launch Game',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Game Info - 1/4 of card height
                    Container(
                      color: Theme.of(context).cardColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Game Title
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.game.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.executableDisplayName != null)
                                  Text(
                                    widget.executableDisplayName!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          // Action Buttons
                          SizedBox(
                            height: 48,
                            child: Stack(
                              children: [
                                // Delete button - bottom left
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed: widget.onDeleteTap,
                                      tooltip: 'Remove from Library',
                                    ),
                                  ),
                                ),
                                // Achievements button - bottom center
                                Positioned(
                                  bottom: 4,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: widget.game.achievements.isNotEmpty
                                            ? Colors.amber.withOpacity(0.8)
                                            : Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: InkWell(
                                        onTap: _showAchievements,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.emoji_events,
                                                color: Colors.white,
                                                size: widget.game.achievements.isNotEmpty ? 16 : 20,
                                              ),
                                              if (widget.game.achievements.isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${widget.game.achievements.length}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // DLC button/badge - bottom right
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: dlcCount > 0
                                      ? InkWell(
                                          onTap: widget.onDLCTap,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.8),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.extension,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$dlcCount DLC',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.extension,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: widget.onDLCTap,
                                            tooltip: 'Add DLC',
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCover() {
    // First try to use local cover
    if (widget.game.coverPath != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Image.file(
            File(widget.game.coverPath!),
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
          ),
        ),
      );
    }
    // If no local cover, try IGDB cover
    if (_gameDetails?.coverUrl != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: _gameDetails!.coverUrl!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            placeholder: (context, url) => _buildDefaultCover(),
            errorWidget: (context, url, error) => _buildDefaultCover(),
          ),
        ),
      );
    }
    // Fall back to default cover
    return _buildDefaultCover();
  }

  Widget _buildDefaultCover() {
    return Container(
      color: Colors.black26,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: const Icon(Icons.gamepad, size: 64),
    );
  }
}
