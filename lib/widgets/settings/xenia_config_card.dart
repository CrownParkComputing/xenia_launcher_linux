import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/settings_provider.dart';
import '../../providers/iso_games_provider.dart';
import '../../providers/live_games_provider.dart';

class XeniaConfigCard extends StatelessWidget {
  final void Function(String) onBaseFolderSelected;

  const XeniaConfigCard({
    super.key,
    required this.onBaseFolderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isoProvider = Provider.of<IsoGamesProvider>(context);
    final liveProvider = Provider.of<LiveGamesProvider>(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xenia Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Base Folder'),
              subtitle: Text(settingsProvider.config.baseFolder ?? 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.folder),
                onPressed: () => _selectBaseFolder(context),
              ),
            ),
            ListTile(
              title: const Text('Wine Prefix'),
              subtitle: Text(settingsProvider.config.winePrefix ?? 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.folder),
                onPressed: () => _selectWinePrefix(context),
              ),
            ),
            ListTile(
              title: const Text('ISO Games Folder'),
              subtitle: Text(isoProvider.config.isoFolder ?? 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.folder),
                onPressed: () => _selectIsoFolder(context),
              ),
            ),
            ListTile(
              title: const Text('Xbox Live Games Folder'),
              subtitle: Text(liveProvider.config.liveGamesFolder ?? 'Not set'),
              trailing: IconButton(
                icon: const Icon(Icons.folder),
                onPressed: () => _selectLiveGamesFolder(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBaseFolder(BuildContext context) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Xenia Base Folder',
    );

    if (result != null) {
      await settingsProvider.setBaseFolder(result);
      onBaseFolderSelected(result);
    }
  }

  Future<void> _selectWinePrefix(BuildContext context) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Wine Prefix Folder',
    );

    if (result != null) {
      await settingsProvider.setWinePrefix(result);
    }
  }

  Future<void> _selectIsoFolder(BuildContext context) async {
    final isoProvider = Provider.of<IsoGamesProvider>(context, listen: false);

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Xbox 360 ISO Games Folder',
    );

    if (result != null) {
      await isoProvider.setIsoFolder(result);
    }
  }

  Future<void> _selectLiveGamesFolder(BuildContext context) async {
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Xbox Live Games Folder',
    );

    if (result != null) {
      await liveProvider.setLiveGamesFolder(result);
    }
  }
}
