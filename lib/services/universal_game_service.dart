import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/game.dart';
import '../models/achievement.dart';
import 'achievement_service.dart';
import 'zarchive_service.dart';
import 'xiso_service.dart';
import 'log_service.dart';
import '../providers/settings_provider.dart';
import 'package:archive/archive.dart';

class UniversalGameService {
  final AchievementService _achievementService = AchievementService();
  final ZArchiveService _archiveService = ZArchiveService();
  final XisoService _xisoService = XisoService();
  final LogService _logService = LogService();

  Future<List<Game>> loadGames() async {
    try {
      final List<Game> games = [];
      // Load games from storage/cache
      return games;
    } catch (e) {
      _logService.log('Error loading games: $e');
      rethrow;
    }
  }

  Future<void> updateGame(Game game) async {
    try {
      // Update game in storage/cache
      _logService.log('Updating game: ${game.title}');
    } catch (e) {
      _logService.log('Error updating game: $e');
      rethrow;
    }
  }

  Future<Game?> importGame(String filePath, SettingsProvider settings) async {
    try {
      final extension = path.extension(filePath).toLowerCase();
      final fileName = path.basenameWithoutExtension(filePath);
      
      // Create initial game object
      final game = Game(
        title: Game.cleanGameTitle(fileName),
        path: filePath,
        type: extension == '.zar' || extension == '.iso' ? GameType.iso : GameType.live,
      );

      // Check if Xenia is configured
      final xeniaPath = settings.xeniaCanaryPath;
      if (xeniaPath == null) {
        throw Exception('Xenia Canary not configured');
      }

      // Make Xenia executable
      final executableFile = File(xeniaPath);
      if (await executableFile.exists()) {
        await Process.run('chmod', ['+x', xeniaPath]);
      } else {
        throw Exception('Xenia executable not found: $xeniaPath');
      }

      // Extract achievements using Xenia
      _logService.log('Extracting achievements for ${game.title}');
      _logService.log('Using Xenia at: $xeniaPath');
      _logService.log('Game path: ${game.path}');

      // Get achievements from the achievement service
      final achievements = await _achievementService.extractAchievements(
        game,
        settings,
      );

      // Create updated game with achievements
      final updatedGame = game.copyWith(
        achievements: achievements,
        lastUsedExecutable: xeniaPath,
      );
      _logService.log('Found ${achievements.length} achievements');

      return updatedGame;
    } catch (e) {
      _logService.log('Error importing game: $e');
      rethrow;
    }
  }

  Future<void> launchGame(Game game, SettingsProvider settings) async {
    try {
      // Get the appropriate executable
      String? executable = game.lastUsedExecutable;
      if (executable == null) {
        executable = settings.config.xeniaCanaryPath;
      }

      if (executable == null) {
        throw Exception('Xenia Canary not configured');
      }

      // Make the executable file executable
      final executableFile = File(executable);
      if (await executableFile.exists()) {
        // Set executable permission (chmod +x)
        await Process.run('chmod', ['+x', executable]);
      } else {
        throw Exception('Executable not found: $executable');
      }

      // Get the correct game path
      final gamePath = game.gameFilePath ?? game.path;
      if (gamePath.isEmpty) {
        throw Exception('Game path is empty');
      }

      final gameFile = File(gamePath);
      if (!await gameFile.exists()) {
        throw Exception('Game file not found: $gamePath');
      }

      _logService.log('Launching game: ${game.title}');
      _logService.log('Executable: $executable');
      _logService.log('Game path: $gamePath');

      // Launch Xenia directly
      final process = await Process.start(executable, [gamePath]);
      
      // Log process output for debugging
      process.stdout.transform(utf8.decoder).listen((data) {
        _logService.log('Xenia output: $data');
      });
      
      process.stderr.transform(utf8.decoder).listen((data) {
        _logService.log('Xenia error: $data');
      });

      _logService.log('Game process started');
    } catch (e) {
      _logService.log('Error launching game: $e');
      rethrow;
    }
  }

  Future<void> extractRar(String rarPath, String extractPath) async {
    try {
      final result = await Process.run('unrar', ['x', '-y', '-o+', rarPath, extractPath]);
      
      if (result.exitCode != 0) {
        throw Exception('Failed to extract RAR (exit code ${result.exitCode}): ${result.stderr}');
      }

      _logService.log('RAR extraction completed successfully');
    } catch (e) {
      if (e.toString().contains('No such file or directory')) {
        throw Exception('unrar is not installed. Please install it using: sudo pacman -S unrar');
      }
      rethrow;
    }
  }

  Future<void> createArchive(String sourcePath, String targetPath) async {
    try {
      await _archiveService.createArchive(
        sourcePath,
        targetPath,
        (current, total) {
          _logService.log('Creating archive: ${((current / total) * 100).toStringAsFixed(1)}%');
        },
      );
    } catch (e) {
      _logService.log('Error creating archive: $e');
      rethrow;
    }
  }

  Future<void> extractIso(String isoPath, String extractPath) async {
    try {
      final success = await _xisoService.extractXiso(isoPath, extractPath);
      if (!success) {
        throw Exception('Failed to extract ISO');
      }
    } catch (e) {
      _logService.log('Error extracting ISO: $e');
      rethrow;
    }
  }

  Future<void> extractRarToTemp(String rarPath, String tempDir) async {
    try {
      _logService.log('Extracting RAR file: $rarPath to $tempDir');
      
      final result = await Process.run('unrar', ['x', rarPath, tempDir]);
      
      if (result.exitCode != 0) {
        throw Exception('Failed to extract RAR file: ${result.stderr}');
      }
      
      _logService.log('RAR extraction completed successfully');
    } catch (e) {
      _logService.log('Error extracting RAR file: $e');
      throw Exception('Error extracting RAR file: $e');
    }
  }

  Future<void> createZarArchive(String sourcePath, String outputPath) async {
    try {
      _logService.log('Creating ZAR archive from $sourcePath to $outputPath');
      
      final archive = Archive();
      final sourceDir = Directory(sourcePath);
      
      await for (final file in sourceDir.list(recursive: true)) {
        if (file is File) {
          final relativePath = path.relative(file.path, from: sourcePath);
          final data = await file.readAsBytes();
          final archiveFile = ArchiveFile(relativePath, data.length, data);
          archive.addFile(archiveFile);
        }
      }
      
      final encoder = ZipEncoder();
      final output = File(outputPath);
      await output.writeAsBytes(encoder.encode(archive)!);
      
      _logService.log('ZAR archive created successfully');
    } catch (e) {
      _logService.log('Error creating ZAR archive: $e');
      throw Exception('Error creating ZAR archive: $e');
    }
  }
} 