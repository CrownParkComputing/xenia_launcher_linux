import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_provider.dart';

class SearchNamesProvider extends BaseProvider {
  static const String _searchNamesKey = 'custom_search_names';
  Map<String, String> _customSearchNames = {};
  final SharedPreferences prefs;

  Map<String, String> get customSearchNames => _customSearchNames;

  SearchNamesProvider(this.prefs) : super(prefs) {
    _initializeStorage();
  }

  void _initializeStorage() {
    if (!prefs.containsKey(_searchNamesKey)) {
      prefs.setStringList(_searchNamesKey, []);
    }
    _loadSearchNames();
  }

  @override
  Future<void> init() async {
    await _loadSearchNames();
  }

  Future<void> _loadSearchNames() async {
    final searchNamesJson = prefs.getStringList(_searchNamesKey) ?? [];
    
    _customSearchNames = Map.fromEntries(
      searchNamesJson.map((entry) {
        final parts = entry.split('::');
        if (parts.length == 2) {
          return MapEntry(parts[0], parts[1]);
        }
        return MapEntry(entry, entry); // Fallback for malformed entries
      }),
    );
    notifyListeners();
  }

  Future<void> setCustomSearchName(String originalName, String customName) async {
    _customSearchNames[originalName] = customName;
    await _saveToPrefs();
    notifyListeners();
  }

  String? getCustomSearchName(String originalName) {
    return _customSearchNames[originalName];
  }

  Future<void> _saveToPrefs() async {
    final searchNamesJson = _customSearchNames.entries
        .map((entry) => '${entry.key}::${entry.value}')
        .toList();
    await prefs.setStringList(_searchNamesKey, searchNamesJson);
  }
}
