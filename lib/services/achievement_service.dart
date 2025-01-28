import 'dart:io';
import '../models/game.dart';
import '../models/achievement.dart';
import '../providers/settings_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  /// Extracts achievements from a game by launching it briefly and reading the log
  Future<List<Achievement>> extractAchievements(Game game, SettingsProvider settingsProvider) async {
    debugPrint('Extracting achievements for ${game.title}...');
    debugPrint('Game path: ${game.path}');

    // Get the executable from settings
    final executable = settingsProvider.xeniaCanaryPath;
                      
    if (executable == null) {
      debugPrint('No Xenia executable configured');
      return [];
    }

    final xeniaDir = path.dirname(executable);
    final logPath = path.join(xeniaDir, 'xenia.log');

    debugPrint('Looking for log at: $logPath');
    debugPrint('Using Xenia at: $executable');

    // Clear existing log
    final logFile = File(logPath);
    if (await logFile.exists()) {
      await logFile.writeAsString('');
      debugPrint('Cleared existing log file');
    }

    Process? xeniaProcess;
    try {
      // Get the correct path to launch based on game type
      final launchPath = game.gameFilePath ?? game.path;
      debugPrint('Launching game with path: $launchPath');

      // Launch Xenia
      xeniaProcess = await Process.start(
        executable,
        [launchPath],
        workingDirectory: xeniaDir,
      );

      debugPrint('Launched Xenia process with PID: ${xeniaProcess.pid}');

      // Set up stream listeners immediately
      xeniaProcess.stdout.listen((data) {
        // Handle stdout if needed
      }, onError: (error) {
        debugPrint('Stdout error: $error');
      });

      xeniaProcess.stderr.listen((data) {
        // Handle stderr if needed
      }, onError: (error) {
        debugPrint('Stderr error: $error');
      });

      // Wait for log file to contain achievements
      debugPrint('Waiting for achievements in log...');
      List<Achievement> achievements = [];
      int attempts = 0;
      const maxAttempts = 30; // 30 seconds max wait time
      bool foundAchievements = false;

      while (attempts < maxAttempts && !foundAchievements) {
        await Future.delayed(const Duration(seconds: 1));
        if (await logFile.exists()) {
          final content = await logFile.readAsString();
          debugPrint('Reading log content...');
          achievements = _parseAchievements(content);
          if (achievements.isNotEmpty) {
            foundAchievements = true;
            debugPrint('Successfully found ${achievements.length} achievements');
            break;
          }
        }
        attempts++;
        debugPrint('Checking for achievements (attempt $attempts)...');
      }

      // Gracefully terminate Xenia
      if (xeniaProcess != null) {
        debugPrint('Gracefully terminating Xenia...');
        xeniaProcess.kill(ProcessSignal.sigterm);

        // Wait for process to exit
        await Future.delayed(const Duration(seconds: 2));

        // Only force kill if still running
        try {
          final running = xeniaProcess.kill(ProcessSignal.sigterm);
          if (running) {
            debugPrint('Process still running, force terminating...');
            xeniaProcess.kill(ProcessSignal.sigkill);
          }
        } catch (e) {
          // Process already terminated
          debugPrint('Process already terminated');
        }
      }

      return achievements;
    } catch (e) {
      debugPrint('Error extracting achievements: $e');
      return [];
    } finally {
      // Ensure process is cleaned up in case of errors
      if (xeniaProcess != null) {
        try {
          // Try graceful termination first
          xeniaProcess.kill(ProcessSignal.sigterm);

          // Wait briefly for process to exit
          await Future.delayed(const Duration(seconds: 2));

          // Force kill if still running
          try {
            final running = xeniaProcess.kill(ProcessSignal.sigterm);
            if (running) {
              xeniaProcess.kill(ProcessSignal.sigkill);
            }
          } catch (e) {
            // Process already terminated
          }
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    }
  }

  List<Achievement> _parseAchievements(String logContent) {
    final achievements = <Achievement>[];
    final lines = logContent.split('\n');
    bool foundAchievementsSection = false;
    bool foundIdHeader = false;

    debugPrint('Starting achievement parse...');
    
    for (final line in lines) {
      // Check if we've hit the PROPERTIES section
      if (line.contains('PROPERTIES')) {
        debugPrint('Found PROPERTIES section, stopping parse');
        break;
      }

      // Look for achievements section
      if (!foundAchievementsSection && line.contains('ACHIEVEMENTS')) {
        debugPrint('Found ACHIEVEMENTS section');
        foundAchievementsSection = true;
        continue;
      }

      // Skip separator lines
      if (line.contains('+-----+')) {
        continue;
      }

      // Look for ID header after finding achievements section
      if (foundAchievementsSection && !foundIdHeader && line.contains('| ID')) {
        debugPrint('Found ID header row');
        foundIdHeader = true;
        continue;
      }

      // Process achievement lines - must start and end with | and contain achievement data
      if (foundIdHeader && line.trim().startsWith('|') && line.trim().endsWith('|')) {
        final cleanLine = line.trim();
        debugPrint('Found achievement line: $cleanLine');
        
        // Split by | and clean up each part
        final parts = cleanLine
            .split('|')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
            
        debugPrint('Split parts: $parts');

        if (parts.length >= 4) {
          try {
            final achievement = Achievement.fromLogLine(
              parts[0],  // ID
              parts[1],  // Title
              parts[2],  // Description
              parts[3]   // Gamerscore
            );
            achievements.add(achievement);
            debugPrint('Successfully added achievement: ${parts[1]}');
          } catch (e) {
            debugPrint('Error creating achievement: $e');
          }
        } else {
          debugPrint('Line did not have enough parts: ${parts.length} parts found');
        }
      }
    }

    debugPrint('Finished parsing. Found ${achievements.length} achievements');
    return achievements;
  }

  Future<void> saveAchievements(String gameName, List<String> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'achievements_$gameName';
    await prefs.setStringList(cacheKey, achievements);
  }

  Future<List<String>?> loadAchievements(String gameName) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'achievements_$gameName';
    return prefs.getStringList(cacheKey);
  }
}
