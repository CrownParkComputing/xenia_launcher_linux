import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings/version_check_card.dart';
import '../widgets/settings/card_size_settings.dart';
import '../widgets/settings/xenia_config_card.dart';
import '../widgets/settings/xenia_variants_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VersionCheckCard(),
            const SizedBox(height: 16),
            const CardSizeSettings(),
            const SizedBox(height: 16),
            XeniaConfigCard(
              onBaseFolderSelected: _scanForExecutables,
            ),
            const SizedBox(height: 16),
            const XeniaVariantsCard(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Archive Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Consumer<SettingsProvider>(
                      builder: (context, settings, _) => Column(
                        children: [
                          ListTile(
                            title: const Text('Archive Save Location'),
                            subtitle: Text(settings.defaultCreatePath ?? 'Not set'),
                            trailing: IconButton(
                              icon: const Icon(Icons.folder_open),
                              onPressed: () async {
                                final path = await FilePicker.platform.getDirectoryPath(
                                  dialogTitle: 'Select Archive Save Location',
                                );
                                if (path != null) {
                                  settings.setDefaultCreatePath(path);
                                }
                              },
                            ),
                          ),
                          ListTile(
                            title: const Text('Game Files Location'),
                            subtitle: Text(settings.defaultExtractPath ?? 'Not set'),
                            trailing: IconButton(
                              icon: const Icon(Icons.folder_open),
                              onPressed: () async {
                                final path = await FilePicker.platform.getDirectoryPath(
                                  dialogTitle: 'Select Game Files Location',
                                );
                                if (path != null) {
                                  settings.setDefaultExtractPath(path);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanForExecutables(String basePath) async {
    // This method is handled within XeniaVariantsCard
  }
}
