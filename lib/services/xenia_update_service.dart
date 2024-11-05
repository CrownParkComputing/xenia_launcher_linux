import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import '../screens/logs_screen.dart' show log;

class XeniaUpdateService {
  static const String canaryReleaseUrl =
      'https://api.github.com/repos/xenia-canary/xenia-canary/releases/tags/experimental';

  Future<String?> getLatestCanaryVersion() async {
    try {
      log('Checking latest version from GitHub...');
      final response = await http.get(Uri.parse(canaryReleaseUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final version = data['tag_name'] ?? data['name'];
        log('Latest version from GitHub: $version');
        return version;
      } else {
        log('Failed to get latest version. Status code: ${response.statusCode}');
      }
    } catch (e) {
      log('Error checking Xenia version: $e');
    }
    return null;
  }

  Future<String?> getCurrentVersion(String xeniaPath) async {
    try {
      log('Getting current version from: $xeniaPath');

      // Get the directory containing the executable
      final execDir = path.dirname(xeniaPath);
      final logPath = path.join(execDir, 'xenia.log');
      log('Looking for log file at: $logPath');

      String? version;

      // First try to read existing log file
      if (File(logPath).existsSync()) {
        log('Found existing log file, reading contents...');
        version = await _extractVersionFromLog(logPath);
      }

      // If we couldn't get version from existing log, run executable to generate new log
      if (version == null) {
        log('No version found in existing log, running executable...');
        final process = await Process.run(
          'wine',
          [xeniaPath],
          environment: {'WINEDEBUG': '-all'},
          runInShell: true,
        );

        // Wait a moment for the log file to be written
        await Future.delayed(const Duration(seconds: 1));

        if (File(logPath).existsSync()) {
          log('Reading newly generated log file...');
          version = await _extractVersionFromLog(logPath);
        }
      }

      return version;
    } catch (e) {
      log('Error getting current version: $e');
      return null;
    }
  }

  Future<String?> _extractVersionFromLog(String logPath) async {
    try {
      final logContent = await File(logPath).readAsString();
      final lines = logContent.split('\n');

      // Get the first line
      if (lines.isNotEmpty) {
        final firstLine = lines.first;
        log('First line: $firstLine');

        // Look for "i> " prefix and "Build:" in the line
        if (firstLine.contains('i>') && firstLine.contains('Build:')) {
          // Extract everything after "Build: "
          final buildIndex = firstLine.indexOf('Build:');
          if (buildIndex != -1) {
            final versionInfo =
                firstLine.substring(buildIndex + 'Build: '.length).trim();
            log('Extracted version info: $versionInfo');
            return versionInfo;
          }
        }
      }

      log('Could not find version information in log file');
      return null;
    } catch (e) {
      log('Error reading log file: $e');
      return null;
    }
  }

  Future<bool> downloadUpdate(String xeniaPath) async {
    try {
      log('Starting update process...');
      log('Getting release info from GitHub...');
      final response = await http.get(Uri.parse(canaryReleaseUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final assets = data['assets'] as List;

        // Find the Windows ZIP asset
        log('Looking for Windows ZIP asset...');
        final zipAsset = assets.firstWhere(
          (asset) => asset['name'].toString().toLowerCase().endsWith('.zip'),
          orElse: () => null,
        );

        if (zipAsset != null) {
          final downloadUrl = zipAsset['browser_download_url'];
          log('Found download URL: $downloadUrl');
          log('Downloading ZIP file...');
          final downloadResponse = await http.get(Uri.parse(downloadUrl));

          if (downloadResponse.statusCode == 200) {
            // Get the base folder path (parent directory of xeniaPath)
            final baseFolder = path.dirname(xeniaPath);
            log('Base folder: $baseFolder');

            // Create backup of existing files
            final backupFolder = path.join(
                baseFolder, 'backup_${DateTime.now().millisecondsSinceEpoch}');
            if (Directory(baseFolder).existsSync()) {
              log('Creating backup at: $backupFolder');
              // Only backup the xenia files, not the entire directory
              for (final file in Directory(baseFolder).listSync()) {
                if (file is File && 
                    path.basename(file.path).toLowerCase().startsWith('xenia')) {
                  final backupPath = path.join(backupFolder, path.basename(file.path));
                  await Directory(path.dirname(backupPath)).create(recursive: true);
                  await file.copy(backupPath);
                }
              }
            }

            // Extract the ZIP contents directly to the base folder
            log('Extracting ZIP contents...');
            final bytes = downloadResponse.bodyBytes;
            final archive = ZipDecoder().decodeBytes(bytes);

            // Extract each file to the base folder
            for (final file in archive) {
              final filename = file.name;
              if (file.isFile) {
                log('Extracting: $filename');
                final data = file.content as List<int>;
                final filePath = path.join(baseFolder, filename);
                File(filePath)
                  ..createSync(recursive: true)
                  ..writeAsBytesSync(data);

                // Make executable files executable
                if (filename.toLowerCase().endsWith('.exe')) {
                  log('Making executable: $filePath');
                  await Process.run('chmod', ['+x', filePath]);
                }
              }
            }

            // Clean up old backup if everything succeeded
            if (Directory(backupFolder).existsSync()) {
              log('Cleaning up backup folder...');
              await Directory(backupFolder).delete(recursive: true);
            }

            log('Update completed successfully');
            return true;
          } else {
            log('Failed to download ZIP. Status code: ${downloadResponse.statusCode}');
          }
        } else {
          log('No ZIP asset found in release');
        }
      } else {
        log('Failed to get release info. Status code: ${response.statusCode}');
      }
    } catch (e) {
      log('Error downloading Xenia update: $e');
    }
    return false;
  }
}
