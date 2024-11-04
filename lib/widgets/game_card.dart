import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/igdb_game.dart';
import '../models/config.dart';
import '../providers/settings_provider.dart';
import '../services/igdb_service.dart';
import '../services/game_search_service.dart';
import '../screens/game_details_screen.dart';
import '../screens/achievements_screen.dart';
import 'game_card/game_cover.dart';
import 'game_card/game_title_section.dart';
import 'game_card/game_actions_section.dart';

class GameCard extends StatefulWidget {
  final Game game;
  final String? executableDisplayName;
  final VoidCallback onPlayTap;
  final VoidCallback onDLCTap;
  final VoidCallback onDeleteTap;
  final Function(String) onTitleEdit;
  final Function(String) onSearchTitleEdit;

  const GameCard({
    super.key,
    required this.game,
    required this.executableDisplayName,
    required this.onPlayTap,
    required this.onDLCTap,
    required this.onDeleteTap,
    required this.onTitleEdit,
    required this.onSearchTitleEdit,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _isHovering = false;
  late final IGDBService _igdbService;
  late final GameSearchService _gameSearchService;
  IGDBGame? _gameDetails;

  @override
  void initState() {
    super.initState();
    _igdbService = IGDBService();
    _gameSearchService = GameSearchService(_igdbService);
    _loadGameDetails();
  }

  @override
  void didUpdateWidget(GameCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.effectiveSearchTitle != widget.game.effectiveSearchTitle) {
      _loadGameDetails();
    }
  }

  Future<void> _loadGameDetails() async {
    try {
      final details = await _gameSearchService.searchGame(context, widget.game.effectiveSearchTitle);
      if (mounted) {
        setState(() {
          _gameDetails = details;
        });
      }
    } catch (e) {
      debugPrint('Error loading game details: $e');
    }
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => EditTitlesDialog(
        title: widget.game.title,
        searchTitle: widget.game.searchTitle,
        onTitleEdit: widget.onTitleEdit,
        onSearchTitleEdit: widget.onSearchTitleEdit,
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
                  child: GameCover(
                    localCoverPath: widget.game.coverPath,
                    gameDetails: _gameDetails,
                    isHovering: _isHovering,
                    onPlayTap: widget.onPlayTap,
                  ),
                ),
                // Game Info - 1/4 of card height
                Container(
                  color: Theme.of(context).cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GameTitleSection(
                        title: widget.game.title,
                        executableDisplayName: widget.executableDisplayName,
                        onEditTap: _showEditDialog,
                      ),
                      GameActionsSection(
                        onDeleteTap: widget.onDeleteTap,
                        onAchievementsTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AchievementsScreen(game: widget.game),
                            ),
                          );
                        },
                        onDLCTap: widget.onDLCTap,
                        achievementsCount: widget.game.achievements.length,
                        dlcCount: widget.game.dlc.length,
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
  }
}
