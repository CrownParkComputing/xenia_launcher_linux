import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../models/game.dart';
import '../services/achievement_service.dart';
import '../services/zarchive_service.dart';
import '../providers/settings_provider.dart';
import 'base_provider.dart';

class IsoGamesProvider extends BaseProvider {
  final AchievementService _achievementService = AchievementService();
  final ZArchiveService _archiveService = ZArchiveService();
  final SettingsProvider _settingsProvider;

  IsoGamesProvider(SharedPreferences prefs, this._settingsProvider)
      : super(prefs);

  List<Game> get isoGames => games.where((g) => g.isIsoGame).toList();

  Future<({List<Game> newGames, List<Game> removedGames})>
      scanForChanges() async {
    final List<Game> newGames = [];
    final List<Game> removedGames = [];

    if (config.isoFolder == null) {
      return (newGames: newGames, removedGames: removedGames);
    }

    final existingFiles = <String>{};

    try {
      final dir = Directory(config.isoFolder!);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && 
            (entity.path.toLowerCase().endsWith('.iso') || 
             entity.path.toLowerCase().endsWith('.zar'))) {
          final path = entity.path;
          existingFiles.add(path);

          if (!games.any((g) => g.path == path)) {
            final extension = path.toLowerCase().endsWith('.iso') ? '.iso' : '.zar';
            final title = path.split(Platform.pathSeparator).last.replaceAll(extension, '');
            final game = Game(
              title: title,
              path: path,
              type: GameType.iso,
            );
            newGames.add(game);
          }
        }
      }

      // Check for removed games
      for (final game in games.where((g) => g.isIsoGame)) {
        if (!existingFiles.contains(game.path)) {
          removedGames.add(game);
        }
      }

      // Remove games that no longer exist
      if (removedGames.isNotEmpty) {
        for (final game in removedGames) {
          await removeGame(game);
        }
      }

      // Sort new games by title
      newGames.sort((a, b) => a.title.compareTo(b.title));
    } catch (e) {
      debugPrint('Error scanning for ISO/ZAR games: $e');
    }

    return (newGames: newGames, removedGames: removedGames);
  }

  Future<void> setIsoFolder(String path) async {
    config.isoFolder = path;
    await saveConfig();
  }

  Future<void> updateGameLastUsedExecutable(
      Game game, String executable) async {
    if (!game.isIsoGame) return;
    final updatedGame = game.copyWith(lastUsedExecutable: executable);
    await updateGame(updatedGame);
  }

  Future<Game?> importGame(String gamePath) async {
    final isIso = gamePath.toLowerCase().endsWith('.iso');
    final isZar = gamePath.toLowerCase().endsWith('.zar');
    if (!isIso && !isZar) return null;

    final extension = isIso ? '.iso' : '.zar';
    final title = gamePath.split(Platform.pathSeparator).last.replaceAll(extension, '');
    print('Importing game: $title');
    print('Game path: $gamePath');

    try {
      // Create game with original path
      final game = Game(
        title: title,
        path: gamePath,
        type: GameType.iso,
      );

      // Add game first so it's in our library
      await addGame(game);

      // Extract achievements if Xenia is configured
      if (config.baseFolder != null && config.winePrefix != null) {
        print('Extracting achievements during game import...');

        String gamePath = game.path;
        if (isZar) {
          // Extract zar to temp directory for achievement extraction
          final tempDir = await Directory.systemTemp.createTemp('xenia_launcher_');
          await _archiveService.extractArchive(
            game.path,
            tempDir.path,
            (current, total) {},
          );

          // Find default.xex in extracted files
          File? xexFile;
          await for (var entity in tempDir.list(recursive: true)) {
            if (entity is File && path.basename(entity.path) == 'default.xex') {
              xexFile = entity;
              break;
            }
          }

          if (xexFile != null) {
            gamePath = xexFile.path;
          }
        }

        final achievements = await _achievementService.extractAchievements(
            game.copyWith(path: gamePath), // Use temp path for zar files
            config.baseFolder!,
            config.winePrefix!,
            _settingsProvider);

        // Update game with achievements
        if (achievements.isNotEmpty) {
          final updatedGame = game.copyWith(achievements: achievements);
          await updateGame(updatedGame);
          print('Game updated with ${achievements.length} achievements');
          return updatedGame;
        }

        // Clean up temp directory for zar files
        if (isZar) {
          final tempDir = path.dirname(gamePath);
          if (tempDir.contains('xenia_launcher_')) {
            await Directory(tempDir).delete(recursive: true);
          }
        }
      } else {
        print('Xenia not configured, skipping achievement extraction');
      }

      return game;
    } catch (e) {
      print('Error importing game: $e');
      rethrow;
    }
  }
}
