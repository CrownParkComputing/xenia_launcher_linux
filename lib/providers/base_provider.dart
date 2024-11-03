import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config.dart';
import '../models/game.dart';

class BaseProvider with ChangeNotifier {
  Config _config = Config();
  List<Game> _games = [];
  final SharedPreferences _prefs;

  BaseProvider(this._prefs) {
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
      _games.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      notifyListeners();
    }
  }

  Future<void> addGame(Game game) async {
    if (_games.any((g) => g.path == game.path)) {
      return;
    }
    _games.insert(0, game);
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

  Future<void> removeGame(Game game) async {
    _games.removeWhere((g) => g.path == game.path);
    await _saveGames();
  }

  // Make this protected so child classes can access it
  @protected
  Future<void> saveConfig() async {
    await _prefs.setString('config', jsonEncode(_config.toJson()));
    notifyListeners();
  }

  Future<void> _saveGames() async {
    await _prefs.setString('games', jsonEncode(_games.map((g) => g.toJson()).toList()));
    notifyListeners();
  }

  String? getExecutableDisplayName(Game game) {
    if (game.lastUsedExecutable == null) return null;
    final fileName = game.lastUsedExecutable!.split('/').last.toLowerCase();
    if (fileName == 'xenia_canary.exe') return 'Xenia Canary';
    if (fileName == 'xenia_canary_netplay.exe') return 'Xenia Netplay';
    if (fileName == 'xenia.exe') return 'Xenia Stable';
    return fileName;
  }
}
