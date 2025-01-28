import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';

class GameService {
  Future<List<Game>> loadGames() async {
    final prefs = await SharedPreferences.getInstance();
    final gamesJson = prefs.getString('games');
    if (gamesJson == null) {
      return [];
    }

    final List<dynamic> gamesData = json.decode(gamesJson);
    return gamesData.map((data) => Game.fromJson(data)).toList();
  }

  Future<void> updateGame(Game game) async {
    final prefs = await SharedPreferences.getInstance();
    final games = await loadGames();
    
    final index = games.indexWhere((g) => g.path == game.path);
    if (index != -1) {
      games[index] = game;
      final gamesJson = games.map((g) => g.toJson()).toList();
      await prefs.setString('games', json.encode(gamesJson));
    }
  }
} 