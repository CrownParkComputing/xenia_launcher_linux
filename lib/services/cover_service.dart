import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/game.dart';

class CoverService {
  static final CoverService _instance = CoverService._internal();
  factory CoverService() => _instance;
  CoverService._internal();

  Future<String> getLocalCoverPath(Game game) async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(path.join(appDir.path, 'covers'));
    
    // Ensure covers directory exists
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    // Create a unique filename based on game title
    final filename = '${game.title.replaceAll(RegExp(r'[^\w\s-]'), '')}_${game.id ?? ''}.jpg';
    return path.join(coversDir.path, filename);
  }

  Future<String?> downloadAndStoreCover(String coverUrl, Game game) async {
    try {
      final response = await http.get(Uri.parse(coverUrl));
      if (response.statusCode == 200) {
        final localPath = await getLocalCoverPath(game);
        await File(localPath).writeAsBytes(response.bodyBytes);
        return localPath;
      }
    } catch (e) {
      print('Error downloading cover: $e');
    }
    return null;
  }

  Future<bool> coverExists(Game game) async {
    final localPath = await getLocalCoverPath(game);
    return File(localPath).exists();
  }
}
