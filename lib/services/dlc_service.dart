import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import '../models/dlc.dart';
import '../models/game.dart';

class DLCService {
  static const _dlcListFile = '.dlc_list';

  static String? _findGameSerial(String gamePath) {
    // Look for a folder that matches the Xbox 360 serial format (8 hex digits)
    final serialRegex = RegExp(r'^[0-9A-Fa-f]{8}$');
    
    try {
      final dir = Directory(gamePath);
      if (!dir.existsSync()) return null;

      // First check if the current folder is a serial
      final currentFolder = path.basename(gamePath);
      if (serialRegex.hasMatch(currentFolder)) {
        return currentFolder;
      }

      // Then check immediate subfolders
      for (final entity in dir.listSync()) {
        if (entity is Directory) {
          final folderName = path.basename(entity.path);
          if (serialRegex.hasMatch(folderName)) {
            return folderName;
          }
        }
      }
    } catch (e) {
      print('Error finding game serial: $e');
    }
    return null;
  }

  static Future<DLC?> extractDLC(String zipPath, Game game) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // Get DLC name from zip filename
      final zipName = path.basename(zipPath);
      final dlcName = DLC.cleanDLCName(zipName);

      // Get game serial
      final gameSerial = _findGameSerial(game.path);
      if (gameSerial == null) {
        throw Exception('Could not find serial number folder for ${game.title}');
      }

      // Validate DLC belongs to this game by checking top-level folder
      String? topLevelFolder;
      for (final file in archive) {
        final parts = file.name.split('/');
        if (parts.isNotEmpty) {
          topLevelFolder = parts[0];
          break;
        }
      }

      if (topLevelFolder == null) {
        throw Exception('Invalid DLC structure: no files found in zip');
      }

      if (topLevelFolder.toLowerCase() != gameSerial.toLowerCase()) {
        throw Exception('This DLC is not compatible with ${game.title}\n\nDLC is for game with serial $topLevelFolder\nSelected game has serial $gameSerial');
      }

      // Extract files directly to game folder, stripping the top-level folder
      var hasFiles = false;
      for (final file in archive) {
        if (file.isFile) {
          hasFiles = true;
          final data = file.content as List<int>;
          // Remove the top-level folder from the path since we're extracting directly to game folder
          final relativePath = file.name.split('/').sublist(1).join('/');
          if (relativePath.isEmpty) continue; // Skip if it's just the top-level folder
          
          final filePath = path.join(game.path, relativePath);
          
          // Create parent directory if it doesn't exist
          final parentDir = Directory(path.dirname(filePath));
          if (!parentDir.existsSync()) {
            parentDir.createSync(recursive: true);
          }
          
          // Write file
          File(filePath).writeAsBytesSync(data);
        }
      }

      if (!hasFiles) {
        throw Exception('No files found in DLC archive');
      }

      // Add DLC to the list file
      final dlcListFile = File(path.join(game.path, _dlcListFile));
      final dlcList = await _readDLCList(dlcListFile);
      
      // Check if DLC already exists
      if (!dlcList.any((d) => d.name == dlcName)) {
        final dlc = DLC(
          name: dlcName,
          path: game.path,
        );
        dlcList.add(dlc);
        await _writeDLCList(dlcListFile, dlcList);
        return dlc;
      }

      return null;
    } catch (e) {
      print('Error extracting DLC: $e');
      rethrow;
    }
  }

  static Future<List<DLC>> scanForDLC(Game game) async {
    final dlcListFile = File(path.join(game.path, _dlcListFile));
    if (!dlcListFile.existsSync()) {
      return [];
    }

    try {
      return await _readDLCList(dlcListFile);
    } catch (e) {
      print('Error scanning for DLC: $e');
      return [];
    }
  }

  static Future<List<DLC>> _readDLCList(File file) async {
    if (!file.existsSync()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      if (content.isEmpty) {
        return [];
      }

      // Try to parse as JSON first
      try {
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList.map((json) => DLC(
          name: json['name'] as String,
          path: json['path'] as String,
          dateAdded: json['dateAdded'] != null 
            ? DateTime.parse(json['dateAdded'] as String)
            : null,
        )).toList();
      } catch (e) {
        // If JSON parsing fails, try reading as plain text (for backward compatibility)
        final lines = content.split('\n').where((line) => line.isNotEmpty).toList();
        return lines.map((line) => DLC(
          name: line.trim(),
          path: file.parent.path,
        )).toList();
      }
    } catch (e) {
      print('Error reading DLC list: $e');
      return [];
    }
  }

  static Future<void> _writeDLCList(File file, List<DLC> dlcs) async {
    try {
      final jsonList = dlcs.map((dlc) => {
        'name': dlc.name,
        'path': dlc.path,
        'dateAdded': dlc.dateAdded.toIso8601String(),
      }).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error writing DLC list: $e');
      rethrow;
    }
  }

  static Future<bool> verifyDLCStructure(String dlcPath) async {
    try {
      final dir = Directory(dlcPath);
      if (!dir.existsSync()) return false;

      // Check if directory has any files
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && path.basename(entity.path) != _dlcListFile) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> removeDLC(DLC dlc) async {
    try {
      // Read the DLC list
      final dlcListFile = File(path.join(dlc.path, _dlcListFile));
      final dlcList = await _readDLCList(dlcListFile);
      
      // Remove the DLC from the list
      dlcList.removeWhere((d) => d.name == dlc.name);
      
      // Write the updated list
      await _writeDLCList(dlcListFile, dlcList);
    } catch (e) {
      print('Error removing DLC: $e');
      rethrow;
    }
  }

  static Future<int> countDLC(Game game) async {
    final dlcs = await scanForDLC(game);
    return dlcs.length;
  }
}
