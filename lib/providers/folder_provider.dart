import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../models/config.dart';
import 'base_provider.dart';

class FolderProvider extends BaseProvider {
  FolderProvider(SharedPreferences prefs) : super(prefs);

  String getDefaultIsoFolder() {
    return path.join(config.baseFolder ?? '/home/jon', 'ISOs');
  }

  String getDefaultExtractionFolder() {
    return path.join(config.baseFolder ?? '/home/jon', 'Extractions');
  }

  Future<void> setBaseFolder(String newPath) async {
    config.baseFolder = newPath;
    await saveConfig();
    notifyListeners();
  }
}
