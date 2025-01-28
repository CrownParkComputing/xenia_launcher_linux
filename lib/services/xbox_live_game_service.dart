import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/game.dart';
import '../services/achievement_service.dart';
import '../providers/settings_provider.dart';
import 'dart:developer' as developer;

class XboxLiveGameService {
  final AchievementService _achievementService = AchievementService();
  final String xeniaContentPath;

  XboxLiveGameService(this.xeniaContentPath) {
    developer.log('XboxLiveGameService initialized with content path: $xeniaContentPath');
  }

  Future<Game?> importRarGame(String rarPath, SettingsProvider settingsProvider) async {
    Directory? tempDir;
    try {
      developer.log('Starting RAR import from: $rarPath');
      developer.log('File exists: ${File(rarPath).existsSync()}');
      developer.log('File size: ${await File(rarPath).length()} bytes');
      
      if (settingsProvider.config.baseFolder == null) {
        throw Exception('Xenia folder not configured');
      }

      // Get the correct Xenia executable from settings
      final xeniaPath = settingsProvider.config.xeniaCanaryPath;  // Using Canary by default
      if (xeniaPath == null) {
        throw Exception('Xenia Canary executable path not configured in settings');
      }
      if (!File(xeniaPath).existsSync()) {
        throw Exception('Xenia executable not found at: $xeniaPath');
      }
      developer.log('Using Xenia executable from settings: $xeniaPath');
      
      // Create temp directory for extraction
      tempDir = await Directory.systemTemp.createTemp('xenia_launcher_');
      developer.log('Created temp directory: ${tempDir.path}');

      // Extract RAR to temp directory
      developer.log('Attempting to extract RAR...');
      try {
        await _extractRar(rarPath, tempDir.path);
        developer.log('RAR extraction completed');
      } catch (e, stackTrace) {
        developer.log('Failed to extract RAR', error: e, stackTrace: stackTrace);
        throw Exception('RAR extraction failed: $e');
      }

      // List contents of temp directory
      developer.log('Listing contents of temp directory:');
      await for (final entity in tempDir.list(recursive: true)) {
        developer.log('Found: ${entity.path}');
      }

      // Find the content directory (should be a hex folder)
      developer.log('Searching for content directory...');
      final contentDir = await _findContentDirectory(tempDir);
      if (contentDir == null) {
        developer.log('No content directory found in RAR', error: 'No hex folder found');
        throw Exception('No content directory (hex folder) found in RAR');
      }
      developer.log('Found content directory: ${contentDir.path}');

      // Get game name from RAR file
      final gameName = path.basenameWithoutExtension(rarPath);
      developer.log('Game name extracted: $gameName');

      // Copy content to Xenia content folder
      final xeniaGameDir = Directory(path.join(xeniaContentPath, path.basename(contentDir.path)));
      developer.log('Creating Xenia game directory at: ${xeniaGameDir.path}');
      
      if (!xeniaGameDir.existsSync()) {
        await xeniaGameDir.create(recursive: true);
      }

      // Copy all files from content directory to Xenia content folder
      developer.log('Starting file copy...');
      try {
        await _copyDirectory(contentDir, xeniaGameDir);
        developer.log('Files copied successfully');
      } catch (e, stackTrace) {
        developer.log('Failed to copy files', error: e, stackTrace: stackTrace);
        throw Exception('Failed to copy game files: $e');
      }

      // Find the game executable
      developer.log('Searching for game executable...');
      final gameExe = await _findGameExecutable(xeniaGameDir);
      if (gameExe == null) {
        developer.log('No game executable found', error: 'Failed to find executable');
        throw Exception('No game executable found');
      }
      developer.log('Found game executable: ${gameExe.path}');

      // Create game object with correct Xenia path from settings
      final game = Game(
        title: gameName,
        path: xeniaPath,
        type: GameType.live,
        executablePath: xeniaPath,
        lastUsedExecutable: xeniaPath,
        gameFilePath: gameExe.path,  // Store the actual game file path separately
      );
      developer.log('Game object created with Xenia path: $xeniaPath');

      // Extract achievements if possible
      if (settingsProvider.config.baseFolder != null && settingsProvider.config.winePrefix != null) {
        developer.log('Attempting to extract achievements...');
        try {
          final achievements = await _achievementService.extractAchievements(
            game,
            settingsProvider.config.baseFolder!,
            settingsProvider.config.winePrefix!,
            settingsProvider,
          );

          if (achievements.isNotEmpty) {
            developer.log('Achievements extracted successfully');
            return game.copyWith(achievements: achievements);
          }
        } catch (e, stackTrace) {
          developer.log('Failed to extract achievements', error: e, stackTrace: stackTrace);
          // Don't throw here, just continue without achievements
        }
      }

      return game;
    } catch (e, stackTrace) {
      developer.log('Error importing RAR game', error: e, stackTrace: stackTrace);
      rethrow; // Rethrow to let the UI handle the error
    } finally {
      // Clean up temp directory
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
          developer.log('Temp directory cleaned up');
        } catch (e) {
          developer.log('Failed to clean up temp directory', error: e);
        }
      }
    }
  }

  Future<void> _extractRar(String rarPath, String destPath) async {
    try {
      developer.log('Reading RAR file...');
      
      // Create the destination directory if it doesn't exist
      await Directory(destPath).create(recursive: true);
      
      // Extract RAR using the system unrar command
      // x: extract with full paths
      // -y: assume yes on all queries
      // -o+: overwrite existing files
      final result = await Process.run('unrar', ['x', '-y', '-o+', rarPath, destPath]);
      
      developer.log('unrar stdout: ${result.stdout}');
      developer.log('unrar stderr: ${result.stderr}');
      
      if (result.exitCode != 0) {
        throw Exception('Failed to extract RAR (exit code ${result.exitCode}): ${result.stderr}');
      }
      
      developer.log('RAR extraction completed successfully');
    } catch (e, stackTrace) {
      developer.log('Error extracting RAR', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Directory?> _findContentDirectory(Directory baseDir) async {
    try {
      developer.log('Searching for hex folder in: ${baseDir.path}');
      // Look for a directory that matches a hex pattern (like 58410B1D)
      await for (final entity in baseDir.list(recursive: true)) {
        if (entity is Directory) {
          final dirName = path.basename(entity.path);
          developer.log('Checking directory: $dirName');
          if (_isHexString(dirName) && dirName.length == 8) {
            developer.log('Found hex folder: $dirName');
            return entity;
          }
        }
      }
      developer.log('No hex folder found');
    } catch (e, stackTrace) {
      developer.log('Error finding content directory', error: e, stackTrace: stackTrace);
    }
    return null;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    try {
      await for (final entity in source.list(recursive: false)) {
        final targetPath = path.join(destination.path, path.basename(entity.path));
        developer.log('Copying ${entity.path} to $targetPath');
        
        if (entity is Directory) {
          final newDirectory = Directory(targetPath);
          await newDirectory.create();
          await _copyDirectory(entity, newDirectory);
        } else if (entity is File) {
          await entity.copy(targetPath);
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error copying directory', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<File?> _findGameExecutable(Directory dir) async {
    try {
      developer.log('Searching for game executable in: ${dir.path}');
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          developer.log('Checking file: $fileName');
          // For Xbox Live games, we're looking for files without extensions
          // that are larger than 1MB (to avoid small metadata files)
          if (!fileName.contains('.')) {
            final size = await entity.length();
            if (size > 1024 * 1024) { // Larger than 1MB
              developer.log('Found likely game file: $fileName (${size ~/ 1024 / 1024}MB)');
              return entity;
            }
          }
        }
      }
      developer.log('No game file found');
    } catch (e, stackTrace) {
      developer.log('Error finding game file', error: e, stackTrace: stackTrace);
    }
    return null;
  }

  bool _isHexString(String str) {
    return RegExp(r'^[0-9A-Fa-f]+$').hasMatch(str);
  }
} 