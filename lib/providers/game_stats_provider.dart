import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game.dart';
import '../services/game_tracking_service.dart';
import 'base_provider.dart';

class GameStatsProvider extends BaseProvider {
  final GameTrackingService _trackingService = GameTrackingService();
  final Map<String, Game> _gamesMap = {};

  GameStatsProvider(SharedPreferences prefs) : super(prefs) {
    _trackingService.setStatsProvider(this);
  }

  @override
  List<Game> get games => _gamesMap.values.toList();

  Game? getGame(String path) => _gamesMap[path];

  Future<void> startTracking(
      Game game, String xeniaPath, Process process) async {
    await _trackingService.startTracking(game, xeniaPath, process);
    _gamesMap[game.path] = game;
    notifyListeners();
  }

  Future<void> stopTracking(Game game) async {
    await _trackingService.stopTracking(game);
    notifyListeners();
  }

  Future<void> updateGameStats(Game game) async {
    _gamesMap[game.path] = game;
    notifyListeners();
  }
}
