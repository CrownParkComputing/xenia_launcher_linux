import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../models/game.dart';

class LiveGameService {
  static Future<Game?> extractGame(
      String zipPath, String destinationDir) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Get game title from zip filename
      final zipName = path.basename(zipPath);
      final gameTitle = Game.cleanGameTitle(zipName);

      // Create game directory
      final gameDir = Directory(path.join(destinationDir, gameTitle));
      if (!gameDir.existsSync()) {
        gameDir.createSync(recursive: true);
      }

      // Extract files
      String? executablePath;
      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final filePath = path.join(gameDir.path, filename);

          // Create parent directory if it doesn't exist
          final parentDir = Directory(path.dirname(filePath));
          if (!parentDir.existsSync()) {
            parentDir.createSync(recursive: true);
          }

          // Write file
          File(filePath).writeAsBytesSync(data);

          // Check if this is the executable (file with no extension in deepest subfolder)
          if (path.extension(filename).isEmpty) {
            final currentDepth = filename.split('/').length;
            final currentExecDepth = executablePath?.split('/').length ?? 0;
            if (executablePath == null || currentDepth > currentExecDepth) {
              executablePath = filePath;
            }
          }
        }
      }

      if (executablePath == null) {
        throw Exception('No executable found in zip file');
      }

      return Game(
        title: gameTitle,
        path: gameDir.path,
        type: GameType.live,
        executablePath: executablePath,
      );
    } catch (e) {
      print('Error extracting game: $e');
      // Clean up if extraction failed
      final gameDir = Directory(path.join(
          destinationDir, Game.cleanGameTitle(path.basename(zipPath))));
      if (gameDir.existsSync()) {
        await gameDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  static Future<String?> findExecutable(String gameDir) async {
    String? executablePath;
    int maxDepth = 0;

    await for (final entity in Directory(gameDir).list(recursive: true)) {
      if (entity is File && path.extension(entity.path).isEmpty) {
        final depth =
            path.split(path.relative(entity.path, from: gameDir)).length;
        if (depth > maxDepth) {
          maxDepth = depth;
          executablePath = entity.path;
        }
      }
    }

    return executablePath;
  }

  static Future<bool> verifyGameStructure(String gameDir) async {
    try {
      final executablePath = await findExecutable(gameDir);
      return executablePath != null;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Game>> scanLiveGamesDirectory(String directory) async {
    final games = <Game>[];
    final dir = Directory(directory);

    if (!dir.existsSync()) return games;

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final executablePath = await findExecutable(entity.path);
        if (executablePath != null) {
          games.add(Game(
            title: path.basename(entity.path),
            path: entity.path,
            type: GameType.live,
            executablePath: executablePath,
          ));
        }
      }
    }

    return games;
  }
}
