import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../models/dlc.dart';
import '../models/achievement.dart';
import '../services/live_game_service.dart';
import '../services/dlc_service.dart';
import '../services/achievement_service.dart';
import '../providers/settings_provider.dart';
import 'base_provider.dart';

class LiveGamesProvider extends BaseProvider {
  final AchievementService _achievementService = AchievementService();
  final SettingsProvider _settingsProvider;
  String _importStatus = '';
  
  LiveGamesProvider(SharedPreferences prefs, this._settingsProvider) : super(prefs);

  List<Game> get liveGames => games.where((g) => g.isLiveGame).toList();
  String get importStatus => _importStatus;

  void _updateStatus(String status) {
    _importStatus = status;
    notifyListeners();
  }

  void _clearStatus() {
    _importStatus = '';
    notifyListeners();
  }

  Future<void> setLiveGamesFolder(String path) async {
    config.liveGamesFolder = path;
    await saveConfig();
    await _scanLiveGames();
  }

  Future<void> _scanLiveGames() async {
    if (config.liveGamesFolder == null) return;

    try {
      final newGames = await LiveGameService.scanLiveGamesDirectory(config.liveGamesFolder!);
      
      // Remove games that no longer exist
      final existingPaths = newGames.map((g) => g.path).toSet();
      final gamesToRemove = games.where(
        (g) => g.isLiveGame && !existingPaths.contains(g.path)
      ).toList();
      
      for (final game in gamesToRemove) {
        await removeGame(game);
      }

      // Add new games and scan for DLC
      for (final game in newGames) {
        if (!games.any((g) => g.path == game.path)) {
          // Scan for existing DLC
          final dlcs = await DLCService.scanForDLC(game);
          
          // Extract achievements if Xenia is configured
          List<Achievement> achievements = [];
          if (config.baseFolder != null && config.winePrefix != null) {
            print('Extracting achievements for ${game.title}...');
            achievements = await _achievementService.extractAchievements(
              game,
              config.baseFolder!,
              config.winePrefix!,
              _settingsProvider
            );
            if (achievements.isNotEmpty) {
              print('Found ${achievements.length} achievements for ${game.title}');
            }
          }
          
          final gameWithExtras = game.copyWith(
            dlc: dlcs,
            achievements: achievements
          );
          await addGame(gameWithExtras);
        }
      }
    } catch (e) {
      debugPrint('Error scanning Live games: $e');
    }
  }

  Future<Game?> importGame(String zipPath) async {
    if (!zipPath.toLowerCase().endsWith('.zip')) return null;
    if (config.liveGamesFolder == null) return null;

    try {
      _updateStatus('Extracting game files...');
      final game = await LiveGameService.extractGame(
        zipPath,
        config.liveGamesFolder!,
      );

      if (game != null) {
        // Scan for existing DLC
        _updateStatus('Scanning for DLC...');
        final dlcs = await DLCService.scanForDLC(game);
        
        // Extract achievements if Xenia is configured
        List<Achievement> achievements = [];
        if (config.baseFolder != null && config.winePrefix != null) {
          _updateStatus('Extracting achievements...');
          print('Extracting achievements for ${game.title}...');
          achievements = await _achievementService.extractAchievements(
            game,
            config.baseFolder!,
            config.winePrefix!,
            _settingsProvider
          );
          if (achievements.isNotEmpty) {
            print('Found ${achievements.length} achievements for ${game.title}');
          }
        }
        
        _updateStatus('Finalizing import...');
        final gameWithExtras = game.copyWith(
          dlc: dlcs,
          achievements: achievements
        );
        await addGame(gameWithExtras);
        _clearStatus();
        return gameWithExtras;
      }
    } catch (e) {
      debugPrint('Error importing Live game: $e');
      _clearStatus();
    }
    return null;
  }

  Future<DLC?> importDLC(String zipPath, Game game) async {
    if (!game.isLiveGame) return null;

    try {
      final dlc = await DLCService.extractDLC(zipPath, game);
      if (dlc != null) {
        // Verify DLC structure
        if (await DLCService.verifyDLCStructure(dlc.path)) {
          final updatedGame = game.copyWith(
            dlc: [...game.dlc, dlc],
          );
          await updateGame(updatedGame);
          return dlc;
        } else {
          // Clean up if structure is invalid
          await DLCService.removeDLC(dlc);
        }
      }
    } catch (e) {
      debugPrint('Error importing DLC: $e');
    }
    return null;
  }

  Future<void> removeDLC(Game game, DLC dlc) async {
    try {
      await DLCService.removeDLC(dlc);
      final updatedGame = game.copyWith(
        dlc: game.dlc.where((d) => d.path != dlc.path).toList(),
      );
      await updateGame(updatedGame);
    } catch (e) {
      debugPrint('Error removing DLC: $e');
      rethrow;
    }
  }

  Future<void> updateGameLastUsedExecutable(Game game, String executable) async {
    if (!game.isLiveGame) return;
    final updatedGame = game.copyWith(lastUsedExecutable: executable);
    await updateGame(updatedGame);
  }

  Future<void> rescanGames() async {
    await _scanLiveGames();
  }

  Future<void> rescanDLC(Game game) async {
    if (!game.isLiveGame) return;

    try {
      final dlcs = await DLCService.scanForDLC(game);
      final updatedGame = game.copyWith(dlc: dlcs);
      await updateGame(updatedGame);
    } catch (e) {
      debugPrint('Error rescanning DLC: $e');
      rethrow;
    }
  }

  Future<void> rescanAchievements(Game game) async {
    if (!game.isLiveGame) return;
    if (config.baseFolder == null || config.winePrefix == null) return;

    try {
      print('Rescanning achievements for ${game.title}...');
      final achievements = await _achievementService.extractAchievements(
        game,
        config.baseFolder!,
        config.winePrefix!,
        _settingsProvider
      );
      
      if (achievements.isNotEmpty) {
        print('Found ${achievements.length} achievements for ${game.title}');
        final updatedGame = game.copyWith(achievements: achievements);
        await updateGame(updatedGame);
      }
    } catch (e) {
      debugPrint('Error rescanning achievements: $e');
      rethrow;
    }
  }
}
