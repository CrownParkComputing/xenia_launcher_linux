import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/iso_games_provider.dart';
import '../providers/live_games_provider.dart';

class XeniaVariant {
  final String name;
  final String executableName;

  XeniaVariant({
    required this.name,
    required this.executableName,
  });
}

class SettingsScreen extends StatelessWidget {
  static final List<XeniaVariant> xeniaVariants = [
    XeniaVariant(name: 'Xenia Canary', executableName: 'xenia_canary.exe'),
    XeniaVariant(name: 'Xenia Netplay', executableName: 'xenia_canary_netplay.exe'),
    XeniaVariant(name: 'Xenia Stable', executableName: 'xenia.exe'),
  ];

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isoProvider = Provider.of<IsoGamesProvider>(context);
    final liveProvider = Provider.of<LiveGamesProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
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
            ),
            const SizedBox(height: 16),
            if (settingsProvider.config.baseFolder != null) Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xenia Variants',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ...xeniaVariants.map((variant) {
                      final execPath = settingsProvider.config.xeniaExecutables
                          .firstWhere(
                            (exe) => exe.toLowerCase().endsWith(variant.executableName.toLowerCase()),
                            orElse: () => '',
                          );
                      
                      return ListTile(
                        leading: Icon(
                          execPath.isNotEmpty ? Icons.check_circle : Icons.error,
                          color: execPath.isNotEmpty ? Colors.green : Colors.red,
                        ),
                        title: Text(variant.name),
                        subtitle: Text(execPath.isNotEmpty 
                          ? execPath.split('/').last
                          : 'Not found'),
                        trailing: execPath.isNotEmpty ? ElevatedButton(
                          onPressed: () => _testExecutable(context, execPath),
                          child: const Text('Test'),
                        ) : null,
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBaseFolder(BuildContext context) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Xenia Base Folder',
    );
    
    if (result != null) {
      await settingsProvider.setBaseFolder(result);
      if (context.mounted) {
        await _scanForExecutables(context, result);
      }
    }
  }

  Future<void> _selectWinePrefix(BuildContext context) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
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

  Future<void> _scanForExecutables(BuildContext context, String basePath) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    final executables = await settingsProvider.scanForExecutables(
      basePath,
      xeniaVariants.map((v) => v.executableName.toLowerCase()).toList(),
    );
    
    if (executables.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Xenia executables found in the selected folder')),
        );
      }
      return;
    }
    
    await settingsProvider.setXeniaExecutables(executables);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found ${executables.length} Xenia variants')),
      );
    }
  }

  Future<void> _testExecutable(BuildContext context, String executable) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final winePrefix = settingsProvider.config.winePrefix;

    if (winePrefix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set Wine prefix first')),
      );
      return;
    }

    final success = await settingsProvider.testExecutable(executable, winePrefix);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully tested ${executable.split('/').last}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to run executable')),
        );
      }
    }
  }
}
