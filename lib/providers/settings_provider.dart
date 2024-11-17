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

class SettingsProvider extends BaseProvider {
  final XeniaUpdateService _xeniaUpdateService = XeniaUpdateService();
  String? _latestVersion;
  bool _isCheckingUpdate = false;
  String _updateStatus = '';
  
  // Archive settings
  static const String _defaultCreatePathKey = 'default_create_path';
  static const String _defaultExtractPathKey = 'default_extract_path';

  SettingsProvider(SharedPreferences prefs) : super(prefs);

  // Archive getters and setters
  String get defaultCreatePath {
    final savedPath = prefs.getString(_defaultCreatePathKey);
    if (savedPath != null && savedPath.isNotEmpty && savedPath != '/') {
      return savedPath;
    }
    return path_util.join(
      Platform.environment['HOME'] ?? '/home/${Platform.environment['USER']}',
      'Xenia',
      'Archives'
    );
  }

  String get defaultExtractPath {
    final savedPath = prefs.getString(_defaultExtractPathKey);
    if (savedPath != null && savedPath.isNotEmpty && savedPath != '/') {
      return savedPath;
    }
    return path_util.join(
      Platform.environment['HOME'] ?? '/home/${Platform.environment['USER']}',
      'Xenia',
      'Extractions'
    );
  }

  Future<void> setDefaultCreatePath(String path) async {
    await prefs.setString(_defaultCreatePathKey, path);
    notifyListeners();
  }

  Future<void> setDefaultExtractPath(String path) async {
    await prefs.setString(_defaultExtractPathKey, path);
    notifyListeners();
  }

  // Existing getters
  String? get latestVersion => _latestVersion;
  bool get isCheckingUpdate => _isCheckingUpdate;
  String get updateStatus => _updateStatus;

  void _setUpdateStatus(String status) {
    _updateStatus = status;
    log(status);
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
    config.xeniaExecutables = paths;
    // Update the specific paths as well
    for (final path in paths) {
      final fileName = path.split(Platform.pathSeparator).last.toLowerCase();
      if (fileName.contains('canary') && !fileName.contains('netplay')) {
        await setXeniaCanaryPath(path);
      } else if (fileName.contains('netplay')) {
        await setXeniaNetplayPath(path);
      } else {
        await setXeniaStablePath(path);
      }
    }
    await saveConfig();
  }

  Future<void> setXeniaCanaryPath(String path) async {
    config.xeniaCanaryPath = path;
    if (!config.xeniaExecutables.contains(path)) {
      config.xeniaExecutables.add(path);
    }
    await saveConfig();
  }

  Future<void> setXeniaNetplayPath(String path) async {
    config.xeniaNetplayPath = path;
    if (!config.xeniaExecutables.contains(path)) {
      config.xeniaExecutables.add(path);
    }
    await saveConfig();
  }

  Future<void> setXeniaStablePath(String path) async {
    config.xeniaStablePath = path;
    if (!config.xeniaExecutables.contains(path)) {
      config.xeniaExecutables.add(path);
    }
    await saveConfig();
  }

  Future<void> setCardSize(GameCardSize size) async {
    config.cardSize = size;
    await saveConfig();
    notifyListeners();
  }

  Future<void> updateExecutableVersion(
      String executablePath, String version) async {
    config.xeniaVersions[executablePath] = version;
    await saveConfig();
    notifyListeners();
  }

  Future<bool> checkForUpdates() async {
    if (_isCheckingUpdate) return false;

    _isCheckingUpdate = true;
    _setUpdateStatus('Checking for updates...');
    notifyListeners();

    try {
      _latestVersion = await _xeniaUpdateService.getLatestCanaryVersion();

      if (_latestVersion != null && config.xeniaExecutables.isNotEmpty) {
        // Check version of first canary executable
        final canaryExe = config.xeniaExecutables.firstWhere(
          (exe) => exe.toLowerCase().contains('canary'),
          orElse: () => config.xeniaExecutables.first,
        );

        final currentVersion = config.xeniaVersions[canaryExe];
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
    if (config.xeniaExecutables.isEmpty) {
      _setUpdateStatus('No Xenia executables configured');
      return false;
    }

    try {
      _setUpdateStatus('Downloading update...');
      final success = await _xeniaUpdateService
          .downloadUpdate(config.xeniaExecutables.first);

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

        // Look for version in first line
        if (lines.isNotEmpty) {
          final firstLine = lines.first;
          if (firstLine.contains('Build:')) {
            final buildIndex = firstLine.indexOf('Build:');
            if (buildIndex != -1) {
              final version =
                  firstLine.substring(buildIndex + 'Build: '.length).trim();
              log('Found version: $version');
              await updateExecutableVersion(executable, version);
            }
          }
        }
      }

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

      process = await Process.start(
          'wine',
          [
            executable,
            gamePath,
          ],
          environment: {
            'WINEPREFIX': winePrefix,
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
}
