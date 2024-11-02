import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    try {
      final process = await Process.run('wine', [
        executable,
        '--help',
      ], environment: {
        'WINEPREFIX': winePrefix,
      });

      return process.exitCode == 0;
    } catch (e) {
      debugPrint('Error testing executable: $e');
      return false;
    }
  }

  Future<({String? stdout, String? stderr})> runExecutable(
    String executable,
    String winePrefix,
    List<String> args,
  ) async {
    try {
      final process = await Process.run('wine', [
        executable,
        ...args,
      ], environment: {
        'WINEPREFIX': winePrefix,
      });

      return (
        stdout: process.stdout.toString(),
        stderr: process.stderr.toString(),
      );
    } catch (e) {
      debugPrint('Error running executable: $e');
      return (stdout: null, stderr: e.toString());
    }
  }
}
