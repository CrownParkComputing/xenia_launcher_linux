import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import 'base_provider.dart';

class IsoGamesProvider extends BaseProvider {
  IsoGamesProvider(SharedPreferences prefs) : super(prefs);

  List<Game> get isoGames => games.where((g) => g.isIsoGame).toList();

  Future<({List<Game> newGames, List<Game> removedGames})> scanForChanges() async {
    final List<Game> newGames = [];
    final List<Game> removedGames = [];

    if (config.isoFolder == null) {
      return (newGames: newGames, removedGames: removedGames);
    }

    final existingFiles = <String>{};

    try {
      final dir = Directory(config.isoFolder!);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.iso')) {
          final path = entity.path;
          existingFiles.add(path);
          
          if (!games.any((g) => g.path == path)) {
            final title = path.split(Platform.pathSeparator).last.replaceAll('.iso', '');
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
      debugPrint('Error scanning for ISO games: $e');
    }

    return (newGames: newGames, removedGames: removedGames);
  }

  Future<void> setIsoFolder(String path) async {
    config.isoFolder = path;
    await saveConfig();
  }

  Future<void> updateGameLastUsedExecutable(Game game, String executable) async {
    if (!game.isIsoGame) return;
    final updatedGame = game.copyWith(lastUsedExecutable: executable);
    await updateGame(updatedGame);
  }

  Future<void> importGame(String isoPath) async {
    if (!isoPath.toLowerCase().endsWith('.iso')) return;

    final title = isoPath.split(Platform.pathSeparator).last.replaceAll('.iso', '');
    final game = Game(
      title: title,
      path: isoPath,
      type: GameType.iso,
    );
    
    await addGame(game);
  }
}
