import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path_util;
import '../screens/logs_screen.dart';
import '../services/xenia_update_service.dart';
import '../models/config.dart';
import '../models/game.dart';
import 'base_provider.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class SettingsProvider extends BaseProvider {
  final XeniaUpdateService _xeniaUpdateService = XeniaUpdateService();
  String? _latestVersion;
  bool _isCheckingUpdate = false;
  String _updateStatus = '';
  final List<String> _logs = [];
  
  // Archive settings keys
  static const String _defaultCreatePathKey = 'default_create_path';
  static const String _defaultExtractPathKey = 'default_extract_path';
  
  SettingsProvider(SharedPreferences prefs) : super(prefs) {
    _xeniaUpdateService.addLogListener(_handleServiceLog);
  }

  void _handleServiceLog(String message) {
    log(message);
  }

  @override
  void dispose() {
    _xeniaUpdateService.removeLogListener(_handleServiceLog);
    super.dispose();
  }

  // Getters
  String? get xeniaCanaryPath => config.xeniaCanaryPath;
  String? get latestVersion => _latestVersion;
  bool get isCheckingUpdate => _isCheckingUpdate;
  String get updateStatus => _updateStatus;
  List<String> get logs => List.unmodifiable(_logs);

  // Archive paths
  String? get defaultCreatePath => prefs.getString(_defaultCreatePathKey);
  String? get defaultExtractPath => prefs.getString(_defaultExtractPathKey);

  void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    debugPrint('[Xenia Launcher] $logMessage');
    _logs.add(logMessage);
    _updateStatus = message;
    notifyListeners();
  }

  void _setUpdateStatus(String status) {
    _updateStatus = status;
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> setBaseFolder(String path) async {
    if (path.isEmpty || path == '/') {
      return;
    }
    config.baseFolder = path;
    await saveConfig();
  }

  Future<void> setIsoFolder(String path) async {
    if (path.isEmpty || path == '/') {
      return;
    }
    config.isoFolder = path;
    await saveConfig();
  }

  Future<void> setWinePrefix(String path) async {
    if (path.isEmpty || path == '/') {
      return;
    }
    config.winePrefix = path;
    await saveConfig();
  }

  Future<void> setXeniaExecutables(List<String> paths) async {
    // Only keep the Canary path
    for (final path in paths) {
      final fileName = path.split(Platform.pathSeparator).last.toLowerCase();
      if (fileName.contains('canary') && !fileName.contains('netplay')) {
        await setXeniaCanaryPath(path);
        break;
      }
    }
    await saveConfig();
  }

  Future<void> setXeniaCanaryPath(String? path) async {
    if (path != null) {
      config.xeniaCanaryPath = path;
    } else {
      config.xeniaCanaryPath = null;
    }
    await saveConfig();
    notifyListeners();
  }

  Future<void> setCardSize(GameCardSize size) async {
    config.cardSize = size;
    await saveConfig();
    notifyListeners();
  }

  Future<String?> _getXeniaVersion(String executablePath) async {
    final execDir = path_util.dirname(executablePath);
    final logPath = path_util.join(execDir, 'xenia.log');

    // Clear existing log
    final logFile = File(logPath);
    if (await logFile.exists()) {
      await logFile.writeAsString('');
    }

    // Run Xenia briefly to generate version info
    final result = await runExecutable(executablePath, config.winePrefix ?? '', []);
    if (result.process != null) {
      // Wait briefly for log to be written
      await Future.delayed(const Duration(seconds: 1));
      result.process!.kill();
    }

    // Try to read version from log file
    if (await logFile.exists()) {
      final logContent = await logFile.readAsString();
      final lines = logContent.split('\n');
      if (lines.isNotEmpty) {
        final firstLine = lines.first;
        if (firstLine.contains('Build:')) {
          final buildIndex = firstLine.indexOf('Build:');
          if (buildIndex != -1) {
            return firstLine.substring(buildIndex + 'Build: '.length).trim();
          }
        }
      }
    }

    return null;
  }

  Future<bool> checkForUpdates() async {
    if (_isCheckingUpdate) return false;

    _isCheckingUpdate = true;
    _setUpdateStatus('Checking for updates...');
    notifyListeners();

    try {
      _latestVersion = await _xeniaUpdateService.getLatestCanaryVersion();

      if (_latestVersion != null && config.xeniaCanaryPath != null) {
        final currentVersion = await _getXeniaVersion(config.xeniaCanaryPath!);
        if (currentVersion == null) {
          _setUpdateStatus('Version information not available');
          return true; // Trigger update check if we don't have version info
        }

        _isCheckingUpdate = false;
        _setUpdateStatus(currentVersion == _latestVersion
            ? 'Already up to date'
            : 'Update available: $_latestVersion');

        return _latestVersion != currentVersion;
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      _setUpdateStatus('Error checking for updates: $e');
    }

    _isCheckingUpdate = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateXenia() async {
    if (config.xeniaCanaryPath == null) {
      _setUpdateStatus('No Xenia executable configured');
      return false;
    }

    try {
      _setUpdateStatus('Downloading update...');
      final success = await _xeniaUpdateService
          .downloadUpdate(config.xeniaCanaryPath!);

      if (success) {
        _setUpdateStatus('Update downloaded, rescanning executables...');

        // Rescan executables in the base folder
        if (config.baseFolder != null) {
          final executableNames = [
            'xenia_canary.exe',
            'xenia.exe',
            'xenia_canary_netplay.exe'
          ];
          final executables =
              await scanForExecutables(config.baseFolder!, executableNames);

          if (executables.isNotEmpty) {
            await setXeniaExecutables(executables);
            // Test each executable to get its version
            for (final exe in executables) {
              if (config.winePrefix != null) {
                await testExecutable(exe, config.winePrefix!);
              }
            }
            _setUpdateStatus('Update completed successfully');
          } else {
            _setUpdateStatus('Update completed but no executables found');
          }
        }

        // Trigger a new version check
        await checkForUpdates();
      } else {
        _setUpdateStatus('Update failed');
      }

      return success;
    } catch (e) {
      debugPrint('Error updating Xenia: $e');
      _setUpdateStatus('Error updating Xenia: $e');
      return false;
    }
  }

  Future<bool> testExecutable(String executable, String winePrefix) async {
    Process? process;
    try {
      log('Testing Xenia executable: $executable');
      log('Using WINEPREFIX: $winePrefix');
      log('Launch command: WINEPREFIX=$winePrefix wine $executable');

      process = await Process.start(
          'wine',
          [
            executable,
          ],
          environment: {
            'WINEPREFIX': winePrefix,
            'WINEDEBUG': '-all',
          },
          runInShell: true);

      // Get the directory containing the executable
      final execDir = path_util.dirname(executable);
      final logPath = path_util.join(execDir, 'xenia.log');

      // Wait a moment for the log file to be written
      await Future.delayed(const Duration(seconds: 1));

      // Try to read version from log file
      if (File(logPath).existsSync()) {
        final logContent = await File(logPath).readAsString();
        final lines = logContent.split('\n');
        if (lines.isNotEmpty) {
          final firstLine = lines.first;
          if (firstLine.contains('Build:')) {
            final buildIndex = firstLine.indexOf('Build:');
            if (buildIndex != -1) {
              final version = firstLine.substring(buildIndex + 'Build: '.length).trim();
              log('Found version: $version');
            }
          }
        }
      }

      // Start collecting output streams but don't wait for completion
      // This allows the process to continue running while we monitor output
      final stdoutFuture =
          process.stdout.transform(const SystemEncoding().decoder).join();
      final stderrFuture =
          process.stderr.transform(const SystemEncoding().decoder).join();

      // Wait briefly to catch immediate errors
      final stderr = await stderrFuture.timeout(
        const Duration(seconds: 2),
        onTimeout: () => '',
      );

      if (stderr.isNotEmpty) {
        log('Error output: $stderr');
      }

      return true;
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

      return false;
    }
  }

  Future<List<String>> scanForExecutables(
      String basePath, List<String> executableNames) async {
    final executables = <String>[];

    try {
      final dir = Directory(basePath);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final fileName =
              entity.path.split(Platform.pathSeparator).last.toLowerCase();
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

  Future<({String? stdout, String? stderr, Process? process})> runExecutable(
      String executable, String winePrefix, List<String> args) async {
    Process? process;
    try {
      log('Running executable: $executable');
      log('Using WINEPREFIX: $winePrefix');
      log('Arguments: $args');

      process = await Process.start(
          'wine',
          [executable, ...args],
          environment: {
            'WINEPREFIX': winePrefix,
            'WINEDEBUG': '-all',
          },
          runInShell: true);

      // Start collecting output streams but don't wait for completion
      // This allows the process to continue running while we monitor output
      final stdoutFuture =
          process.stdout.transform(const SystemEncoding().decoder).join();
      final stderrFuture =
          process.stderr.transform(const SystemEncoding().decoder).join();

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

  String? getExecutableDisplayName(Game game) {
    final path = game.executablePath;
    if (path == null) return null;
    final fileName = path.split(Platform.pathSeparator).last.toLowerCase();
    if (fileName == 'xenia_canary.exe') return 'Xenia Canary';
    return fileName;
  }

  Future<void> setDefaultCreatePath(String? path) async {
    if (path != null) {
      await prefs.setString(_defaultCreatePathKey, path);
    } else {
      await prefs.remove(_defaultCreatePathKey);
    }
    notifyListeners();
  }

  Future<void> setDefaultExtractPath(String? path) async {
    if (path != null) {
      await prefs.setString(_defaultExtractPathKey, path);
    } else {
      await prefs.remove(_defaultExtractPathKey);
    }
    notifyListeners();
  }
}
