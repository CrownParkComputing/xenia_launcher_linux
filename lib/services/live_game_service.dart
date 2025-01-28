import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/game.dart';
import '../providers/settings_provider.dart';
import 'base_service.dart';

class LiveGameService extends BaseService {
  final SettingsProvider _settings;

  LiveGameService(this._settings);

  Future<Game?> importGame(String rarPath) async {
    try {
      log('Importing Xbox Live game from RAR: $rarPath');
      
      // Create temp extraction directory
      final tempExtractPath = path.join(_settings.defaultExtractPath!, 'temp_extract');
      await Directory(tempExtractPath).create(recursive: true);
      
      try {
        // Extract RAR to temp directory
        log('Extracting RAR to temp directory for scanning...');
        final result = await Process.run('unrar', [
          'x',      // extract with full path
          '-y',     // assume yes on all queries
          rarPath,  // source file
          tempExtractPath, // destination directory
        ]);

        if (result.exitCode != 0) {
          throw Exception('Failed to extract RAR: ${result.stderr}');
        }

        // Look for default.xex to get game info
        log('Scanning for default.xex...');
        String? xexPath;
        await for (var entity in Directory(tempExtractPath).list(recursive: true)) {
          if (entity is File && path.basename(entity.path).toLowerCase() == 'default.xex') {
            xexPath = entity.path;
            break;
          }
        }

        if (xexPath == null) {
          throw Exception('No default.xex found in RAR archive');
        }

        // Get game title from folder name or xex
        final gameFolder = path.basename(path.dirname(xexPath));
        final gameTitle = gameFolder.replaceAll(RegExp(r'[_\-.]'), ' ');

        // Create game object
        final game = Game(
          id: DateTime.now().millisecondsSinceEpoch,
          title: gameTitle,
          path: rarPath,
          type: GameType.live,
          isIsoGame: false,
        );

        log('Game imported successfully: ${game.title}');
        return game;

      } finally {
        // Clean up temp directory
        log('Cleaning up temporary extraction directory...');
        if (await Directory(tempExtractPath).exists()) {
          await Directory(tempExtractPath).delete(recursive: true);
        }
      }
    } catch (e) {
      log('Error importing game: $e');
      rethrow;
    }
  }

  Future<void> launchGame(Game game) async {
    try {
      log('Preparing to launch Xbox Live game: ${game.title}');
      
      // Create extraction directory
      final extractPath = path.join(_settings.defaultExtractPath!, path.basenameWithoutExtension(game.path));
      await Directory(extractPath).create(recursive: true);

      // Extract RAR
      log('Extracting game files...');
      final result = await Process.run('unrar', [
        'x',      // extract with full path
        '-y',     // assume yes on all queries
        game.path,  // source file
        extractPath, // destination directory
      ]);

      if (result.exitCode != 0) {
        throw Exception('Failed to extract game files: ${result.stderr}');
      }

      // Find default.xex
      String? xexPath;
      await for (var entity in Directory(extractPath).list(recursive: true)) {
        if (entity is File && path.basename(entity.path).toLowerCase() == 'default.xex') {
          xexPath = entity.path;
          break;
        }
      }

      if (xexPath == null) {
        throw Exception('Could not find default.xex after extraction');
      }

      // Launch game with Xenia
      final xeniaPath = _settings.xeniaCanaryPath;
      if (xeniaPath == null) {
        throw Exception('Xenia path not configured');
      }

      log('Launching game with Xenia...');
      log('Xenia path: $xeniaPath');
      log('Game path: $xexPath');

      final process = await Process.start(
        xeniaPath,
        [xexPath],
        mode: ProcessStartMode.detached,
      );

      log('Game launched with PID: ${process.pid}');

      // Start monitoring process
      process.exitCode.then((_) async {
        log('Game process ended, cleaning up extracted files...');
        if (await Directory(extractPath).exists()) {
          await Directory(extractPath).delete(recursive: true);
        }
      });

    } catch (e) {
      log('Error launching game: $e');
      rethrow;
    }
  }
} 