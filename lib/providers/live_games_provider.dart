import 'dart:io';
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
import 'package:path/path.dart' as path;

class LiveGamesProvider extends BaseProvider {
  final AchievementService _achievementService = AchievementService();
  final SettingsProvider _settingsProvider;
  String _importStatus = '';
  late final LiveGameService _liveGameService;
  final List<Game> _liveGames = [];

  LiveGamesProvider(SharedPreferences prefs, this._settingsProvider)
      : super(prefs) {
    _liveGameService = LiveGameService(_settingsProvider);
  }

  List<Game> get liveGames => List.unmodifiable(_liveGames);
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
    if (_settingsProvider.defaultExtractPath == null) return;

    try {
      final newGames = await loadGames();

      // Remove games that no longer exist
      final existingPaths = newGames.map((g) => g.path).toSet();
      final gamesToRemove = _liveGames
          .where((g) => !existingPaths.contains(g.path))
          .toList();

      for (final game in gamesToRemove) {
        await removeGame(game);
      }

      // Add new games and scan for DLC
      for (final game in newGames) {
        if (!_liveGames.any((g) => g.path == game.path)) {
          // Scan for existing DLC
          final dlcs = await DLCService.scanForDLC(game);

          // Extract achievements if Xenia is configured
          List<Achievement> achievements = [];
          if (_settingsProvider.xeniaCanaryPath != null) {
            debugPrint('Extracting achievements for ${game.title}...');
            achievements = await _achievementService.extractAchievements(
                game, _settingsProvider);
            if (achievements.isNotEmpty) {
              debugPrint('Found ${achievements.length} achievements for ${game.title}');
            }
          }

          final gameWithExtras =
              game.copyWith(dlc: dlcs, achievements: achievements);
          await addGame(gameWithExtras);
        }
      }
    } catch (e) {
      debugPrint('Error scanning Live games: $e');
    }
  }

  Future<List<Game>> loadGames() async {
    try {
      final liveGamesFolder = _settingsProvider.defaultExtractPath;
      if (liveGamesFolder == null) return [];

      final games = <Game>[];

      // Scan for RAR files in the live games folder
      final dir = Directory(liveGamesFolder);
      if (!await dir.exists()) return [];

      await for (final entity in dir.list(recursive: false)) {
        if (entity is File && path.extension(entity.path).toLowerCase() == '.rar') {
          final game = await _liveGameService.importGame(entity.path);
          if (game != null) {
            games.add(game);
          }
        }
      }

      return games;
    } catch (e) {
      debugPrint('Error loading live games: $e');
      return [];
    }
  }

  Future<Game?> importGame(String zipPath) async {
    if (!zipPath.toLowerCase().endsWith('.zip')) return null;
    if (_settingsProvider.defaultExtractPath == null) return null;

    try {
      _updateStatus('Extracting game files...');
      final game = await _liveGameService.importGame(zipPath);

      if (game != null) {
        // Scan for existing DLC
        _updateStatus('Scanning for DLC...');
        final dlcs = await DLCService.scanForDLC(game);

        // Extract achievements if Xenia is configured
        List<Achievement> achievements = [];
        if (_settingsProvider.xeniaCanaryPath != null) {
          _updateStatus('Extracting achievements...');
          debugPrint('Extracting achievements for ${game.title}...');
          achievements = await _achievementService.extractAchievements(
              game, _settingsProvider);
          if (achievements.isNotEmpty) {
            debugPrint('Found ${achievements.length} achievements for ${game.title}');
          }
        }

        _updateStatus('Finalizing import...');
        final gameWithExtras =
            game.copyWith(dlc: dlcs, achievements: achievements);
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

  Future<void> updateGameLastUsedExecutable(
      Game game, String executable) async {
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
    if (_settingsProvider.xeniaCanaryPath == null) return;

    try {
      debugPrint('Rescanning achievements for ${game.title}...');
      final achievements = await _achievementService.extractAchievements(
          game, _settingsProvider);

      if (achievements.isNotEmpty) {
        debugPrint('Found ${achievements.length} achievements for ${game.title}');
        final updatedGame = game.copyWith(achievements: achievements);
        await updateGame(updatedGame);
      }
    } catch (e) {
      debugPrint('Error rescanning achievements: $e');
      rethrow;
    }
  }

  Future<void> addGame(Game game) async {
    try {
      _liveGames.add(game);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding live game: $e');
      rethrow;
    }
  }

  Future<void> removeGame(Game game) async {
    try {
      // Remove the RAR file
      final file = File(game.path);
      if (await file.exists()) {
        await file.delete();
      }

      _liveGames.removeWhere((g) => g.id == game.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing live game: $e');
      rethrow;
    }
  }

  Future<void> updateGame(Game game) async {
    final index = _liveGames.indexWhere((g) => g.id == game.id);
    if (index != -1) {
      _liveGames[index] = game;
      notifyListeners();
    }
  }

  Future<void> launchGame(Game game) async {
    await _liveGameService.launchGame(game);
  }
}
