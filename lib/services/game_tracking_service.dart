import 'dart:async';
import 'dart:io';
import '../models/game.dart';
import '../providers/game_stats_provider.dart';

class GameTrackingService {
  static final GameTrackingService _instance = GameTrackingService._internal();
  factory GameTrackingService() => _instance;
  GameTrackingService._internal();

  DateTime? _gameStartTime;
  Timer? _playTimeTimer;
  GameStatsProvider? _statsProvider;
  Process? _gameProcess;
  StreamSubscription? _processExitSubscription;

  void setStatsProvider(GameStatsProvider provider) {
    _statsProvider = provider;
  }

  Future<void> startTracking(
      Game game, String xeniaPath, Process process) async {
    print('Starting game tracking for ${game.title}');
    _gameStartTime = DateTime.now();
    _gameProcess = process;

    // Start playtime timer
    _playTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // This will be used to update total playtime when game ends
    });

    // Listen for process exit
    _processExitSubscription = process.exitCode.asStream().listen((_) {
      stopTracking(game);
    });
  }

  Future<void> stopTracking(Game game) async {
    print('Stopping game tracking for ${game.title}');
    _playTimeTimer?.cancel();
    _processExitSubscription?.cancel();

    // Gracefully terminate the process if it's still running
    if (_gameProcess != null) {
      try {
        // Try graceful termination first
        _gameProcess!.kill(ProcessSignal.sigterm);

        // Wait briefly for process to exit
        await Future.delayed(const Duration(seconds: 2));

        // Force kill if still running
        try {
          final running = _gameProcess!.kill(ProcessSignal.sigterm);
          if (running) {
            _gameProcess!.kill(ProcessSignal.sigkill);
          }
        } catch (e) {
          // Process already terminated
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    }

    if (_gameStartTime != null) {
      final playSession = DateTime.now().difference(_gameStartTime!);

      // Update game with new statistics
      final updatedGame = game.copyWith(
        lastPlayed: DateTime.now(),
        totalPlayTime: game.totalPlayTime + playSession,
      );

      await _statsProvider?.updateGameStats(updatedGame);
      print(
          'Updated play time: ${updatedGame.totalPlayTime.inMinutes} minutes');
    }

    _gameStartTime = null;
    _gameProcess = null;
  }
}
