import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class VersionCheckCard extends StatelessWidget {
  const VersionCheckCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    if (settingsProvider.config.xeniaExecutables.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Xenia Version',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!settingsProvider.isCheckingUpdate)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _checkForUpdates(context),
                    tooltip: 'Check for updates',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (settingsProvider.isCheckingUpdate)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Status Text
              if (settingsProvider.updateStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    settingsProvider.updateStatus,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              // Version Info and Update Button
              if (settingsProvider.latestVersion != null)
                ListTile(
                  title: const Text('Latest Version'),
                  subtitle: Text(settingsProvider.latestVersion!),
                  trailing: ElevatedButton(
                    onPressed: () => _updateXenia(context),
                    child: const Text('Update'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final hasUpdate = await settingsProvider.checkForUpdates();

    if (context.mounted && hasUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update available!')),
      );
    }
  }

  Future<void> _updateXenia(BuildContext context) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final success = await settingsProvider.updateXenia();

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update completed successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update Xenia')),
        );
      }
    }
  }
}
