import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/base_provider.dart';
import '../providers/config_provider.dart';
import '../providers/game_stats_provider.dart';
import '../providers/iso_games_provider.dart';
import '../providers/live_games_provider.dart';
import '../providers/search_names_provider.dart';
import '../providers/settings_provider.dart';

class ProviderConfig {
  static Future<List<ChangeNotifierProvider<BaseProvider>>> getProviders() async {
    final prefs = await SharedPreferences.getInstance();
    
    return [
      ChangeNotifierProvider<ConfigProvider>(
        create: (_) => ConfigProvider(prefs),
      ),
      ChangeNotifierProvider<SettingsProvider>(
        create: (_) => SettingsProvider(prefs),
      ),
      ChangeNotifierProvider<GameStatsProvider>(
        create: (_) => GameStatsProvider(prefs),
      ),
      ChangeNotifierProvider<IsoGamesProvider>(
        create: (_) => IsoGamesProvider(prefs),
      ),
      ChangeNotifierProvider<LiveGamesProvider>(
        create: (_) => LiveGamesProvider(prefs),
      ),
      ChangeNotifierProvider<SearchNamesProvider>(
        create: (_) => SearchNamesProvider(prefs),
      ),
    ];
  }

  static Future<void> initializeProviders(BuildContext context) async {
    final providers = Provider.of<List<BaseProvider>>(context, listen: false);
    for (final provider in providers) {
      await provider.init();
    }
  }
}
