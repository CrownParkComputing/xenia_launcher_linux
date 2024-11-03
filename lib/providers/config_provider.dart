import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config.dart';
import '../models/game.dart';
import '../services/live_game_service.dart';

class ConfigProvider with ChangeNotifier {
  Config _config = Config();
  List<Game> _games = [];
  final SharedPreferences _prefs;

  ConfigProvider(this._prefs) {
    _loadConfig();
    _loadGames();
  }

  Config get config => _config;
  List<Game> get games => _games;

  Future<void> _loadConfig() async {
    final configStr = _prefs.getString('config');
    if (configStr != null) {
      _config = Config.fromJson(jsonDecode(configStr));
      notifyListeners();
    }
  }

  Future<void> _loadGames() async {
    final gamesStr = _prefs.getString('games');
    if (gamesStr != null) {
      final List<dynamic> gamesList = jsonDecode(gamesStr);
      _games = gamesList.map((g) => Game.fromJson(g)).toList();
      // Sort games by most recently added
      _games.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      notifyListeners();
    }
  }

  Future<({List<Game> newGames, List<Game> removedGames})>
      scanForChanges() async {
    final List<Game> newGames = [];
    final List<Game> removedGames = [];

    if (_config.isoFolder == null) {
      return (newGames: newGames, removedGames: removedGames);
    }

    final existingFiles = <String>{};

    try {
      final dir = Directory(_config.isoFolder!);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.iso')) {
          final path = entity.path;
          existingFiles.add(path);

          // Check if game is already in library
          if (!_games.any((g) => g.path == path)) {
            final title =
                path.split(Platform.pathSeparator).last.replaceAll('.iso', '');
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
      for (final game in _games.where((g) => g.isIsoGame)) {
        if (!existingFiles.contains(game.path)) {
          removedGames.add(game);
        }
      }

      // Remove games that no longer exist
      if (removedGames.isNotEmpty) {
        _games.removeWhere(
            (game) => removedGames.any((g) => g.path == game.path));
        await _saveGames();
      }

      // Sort new games by title
      newGames.sort((a, b) => a.title.compareTo(b.title));
    } catch (e) {
      debugPrint('Error scanning for games: $e');
    }

    return (newGames: newGames, removedGames: removedGames);
  }

  Future<void> setBaseFolder(String path) async {
    _config.baseFolder = path;
    await _saveConfig();
  }

  Future<void> setWinePrefix(String path) async {
    _config.winePrefix = path;
    await _saveConfig();
  }

  Future<void> setIsoFolder(String path) async {
    _config.isoFolder = path;
    await _saveConfig();
  }

  Future<void> setLiveGamesFolder(String path) async {
    _config.liveGamesFolder = path;
    await _saveConfig();
  }

  Future<void> setXeniaExecutables(List<String> paths) async {
    _config.xeniaExecutables = paths;
    await _saveConfig();
  }

  Future<void> setCardSize(GameCardSize size) async {
    _config.cardSize = size;
    await _saveConfig();
  }

  Future<void> addGame(Game game) async {
    // Check if game already exists
    if (_games.any((g) => g.path == game.path)) {
      return;
    }

    _games.insert(0, game); // Add to beginning of list
    await _saveGames();
  }

  Future<void> addGames(List<Game> newGames) async {
    bool added = false;
    for (final game in newGames) {
      if (!_games.any((g) => g.path == game.path)) {
        _games.add(game);
        added = true;
      }
    }

    if (added) {
      _games.sort((a, b) => a.title.compareTo(b.title));
      await _saveGames();
    }
  }

  Future<void> updateGame(Game game) async {
    final index = _games.indexWhere((g) => g.path == game.path);
    if (index != -1) {
      _games[index] = game;
      await _saveGames();
    }
  }

  Future<void> updateGameLastUsedExecutable(
      Game game, String executable) async {
    final updatedGame = game.copyWith(lastUsedExecutable: executable);
    await updateGame(updatedGame);
  }

  Future<void> removeGame(Game game) async {
    _games.removeWhere((g) => g.path == game.path);
    await _saveGames();
  }

  Future<void> _saveConfig() async {
    await _prefs.setString('config', jsonEncode(_config.toJson()));
    notifyListeners();
  }

  Future<void> _saveGames() async {
    await _prefs.setString(
        'games', jsonEncode(_games.map((g) => g.toJson()).toList()));
    notifyListeners();
  }

  String? getExecutableDisplayName(String path) {
    final fileName = path.split(Platform.pathSeparator).last.toLowerCase();
    if (fileName == 'xenia_canary.exe') return 'Xenia Canary';
    if (fileName == 'xenia_canary_netplay.exe') return 'Xenia Netplay';
    if (fileName == 'xenia.exe') return 'Xenia Stable';
    return fileName;
  }
}
