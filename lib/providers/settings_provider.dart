import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../screens/logs_screen.dart';
import 'base_provider.dart';

class SettingsProvider extends BaseProvider {
  SettingsProvider(SharedPreferences prefs) : super(prefs);

  Future<void> setBaseFolder(String path) async {
    config.baseFolder = path;
    await saveConfig();
  }

  Future<void> setWinePrefix(String path) async {
    config.winePrefix = path;
    await saveConfig();
  }

  Future<void> setXeniaExecutables(List<String> paths) async {
    config.xeniaExecutables = paths;
    await saveConfig();
  }

  Future<List<String>> scanForExecutables(String basePath, List<String> executableNames) async {
    final executables = <String>[];
    
    try {
      final dir = Directory(basePath);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last.toLowerCase();
          if (executableNames.contains(fileName.toLowerCase())) {
            executables.add(entity.path);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning for executables: $e');
    }
    
    return executables;
  }

  Future<bool> testExecutable(String executable, String winePrefix) async {
    Process? process;
    try {
      log('Testing Xenia executable: $executable');
      log('Using WINEPREFIX: $winePrefix');
      log('Launch command: WINEPREFIX=$winePrefix wine $executable');
      
      process = await Process.start('wine', [
        executable,
      ], environment: {
        'WINEPREFIX': winePrefix,
      }, runInShell: true);

      // Wait briefly to see if the process starts successfully
      await Future.delayed(const Duration(seconds: 2));

      log('Successfully launched Xenia test');
      return true;
    } catch (e) {
      log('Error testing executable: $e');
      return false;
    } finally {
      if (process != null) {
        try {
          // Try graceful termination first
          process.kill(ProcessSignal.sigterm);
          
          // Wait briefly for process to exit
          await Future.delayed(const Duration(seconds: 2));
          
          // Force kill if still running
          try {
            final running = process.kill(ProcessSignal.sigterm);
            if (running) {
              process.kill(ProcessSignal.sigkill);
            }
          } catch (e) {
            // Process already terminated
          }
          
          // Ensure streams are properly closed
          await process.stdout.drain();
          await process.stderr.drain();
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    }
  }

  Future<({String? stdout, String? stderr, Process? process})> runExecutable(
    String executable,
    String winePrefix,
    List<String> args,
  ) async {
    Process? process;
    try {
      final gamePath = args.first;
      final command = 'WINEPREFIX=$winePrefix wine $executable $gamePath';
      
      log('Launching game with Xenia');
      log('Launch command: $command');
      
      process = await Process.start('wine', [
        executable,
        gamePath,
      ], environment: {
        'WINEPREFIX': winePrefix,
      }, runInShell: true);

      // Start collecting output streams but don't wait for completion
      // This allows the process to continue running while we monitor output
      final stdoutFuture = process.stdout.transform(const SystemEncoding().decoder).join();
      final stderrFuture = process.stderr.transform(const SystemEncoding().decoder).join();

      // Wait briefly to catch immediate errors
      final stderr = await stderrFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () => '',
      );

      if (stderr.isNotEmpty) {
        log('Error output: $stderr');
      }

      return (
        stdout: await stdoutFuture.timeout(
          const Duration(seconds: 2),
          onTimeout: () => '',
        ),
        stderr: stderr,
        process: process,
      );
    } catch (e) {
      log('Error running executable: $e');
      
      // Ensure process cleanup on error
      if (process != null) {
        try {
          process.kill();
          await process.stdout.drain();
          await process.stderr.drain();
        } catch (e) {
          // Ignore cleanup errors
        }
      }
      
      return (stdout: null, stderr: e.toString(), process: null);
    }
  }
}
