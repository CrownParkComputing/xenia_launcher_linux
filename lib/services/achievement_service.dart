import 'dart:io';
import '../models/game.dart';
import '../models/achievement.dart';
import '../providers/settings_provider.dart';
import 'package:path/path.dart' as path;

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  /// Extracts achievements from a game by launching it briefly and reading the log
  Future<List<Achievement>> extractAchievements(
    Game game,
    String xeniaPath,
    String winePrefix,
    SettingsProvider settingsProvider
  ) async {
    print('Extracting achievements for ${game.title}...');
    print('Game path: ${game.path}');
    
    // Get the executable from settings
    if (settingsProvider.config.xeniaExecutables.isEmpty) {
      print('No Xenia executables configured');
      return [];
    }

    final executable = settingsProvider.config.xeniaExecutables.first;
    final xeniaDir = path.dirname(executable);
    final logPath = path.join(xeniaDir, 'xenia.log');
    
    print('Looking for log at: $logPath');
    print('Using Xenia at: $executable');
    
    // Clear existing log
    final logFile = File(logPath);
    if (await logFile.exists()) {
      await logFile.writeAsString('');
      print('Cleared existing log file');
    }

    Process? xeniaProcess;
    try {
      // Get the correct path to launch based on game type
      final launchPath = game.isLiveGame ? game.executablePath! : game.path;
      print('Launching game with path: $launchPath');

      // Launch Xenia directly as a Process to maintain control
      xeniaProcess = await Process.start(
        executable,
        [launchPath],
        workingDirectory: xeniaDir,
      );

      print('Launched Xenia process with PID: ${xeniaProcess.pid}');

      // Set up stream listeners immediately
      xeniaProcess.stdout.listen((data) {
        // Handle stdout if needed
      }, onError: (error) {
        print('Stdout error: $error');
      });

      xeniaProcess.stderr.listen((data) {
        // Handle stderr if needed
      }, onError: (error) {
        print('Stderr error: $error');
      });

      // Wait for log file to contain achievements
      print('Waiting for achievements in log...');
      List<Achievement> achievements = [];
      int attempts = 0;
      const maxAttempts = 30; // 30 seconds max wait time
      
      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        if (await logFile.exists()) {
          final content = await logFile.readAsString();
          achievements = _parseAchievements(content);
          if (achievements.isNotEmpty) {
            print('Successfully parsed ${achievements.length} achievements');
            break;
          }
        }
        attempts++;
      }

      // Gracefully terminate Xenia
      if (xeniaProcess != null) {
        print('Gracefully terminating Xenia...');
        xeniaProcess.kill(ProcessSignal.sigterm);
        
        // Wait for process to exit
        await Future.delayed(const Duration(seconds: 2));
        
        // Only force kill if still running
        try {
          final running = xeniaProcess.kill(ProcessSignal.sigterm);
          if (running) {
            print('Process still running, force terminating...');
            xeniaProcess.kill(ProcessSignal.sigkill);
          }
        } catch (e) {
          // Process already terminated
          print('Process already terminated');
        }
      }

      return achievements;
    } catch (e) {
      print('Error extracting achievements: $e');
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
    bool inAchievementSection = false;
    bool headerPassed = false;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      // Stop parsing if we hit the PROPERTIES section
      if (trimmedLine.contains('PROPERTIES')) {
        break;
      }

      // Start parsing after we find the ACHIEVEMENTS section
      if (trimmedLine.contains('ACHIEVEMENTS')) {
        inAchievementSection = true;
        continue;
      }

      // Skip until we find the header row
      if (inAchievementSection && trimmedLine.contains('ID | Title')) {
        headerPassed = true;
        continue;
      }

      // Skip separator rows
      if (trimmedLine.contains('----+')) {
        continue;
      }

      // Only process achievement lines after header and if they match our format
      if (inAchievementSection && headerPassed && trimmedLine.startsWith('| ') && trimmedLine.endsWith(' |')) {
        final parts = trimmedLine.split('|')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();

        if (parts.length >= 4) {
          final id = parts[0];
          final title = parts[1];
          final description = parts[2];
          final gamerscore = parts[3].replaceAll(RegExp(r'[^\d]'), '');

          try {
            final achievement = Achievement.fromLogLine(
              id,
              title,
              description,
              gamerscore
            );
            achievements.add(achievement);
            print('Added achievement: $title');
          } catch (e) {
            print('Error creating achievement: $e');
          }
        }
      }
    }

    print('Found ${achievements.length} achievements');
    return achievements;
  }
}
