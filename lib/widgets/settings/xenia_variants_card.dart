import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class XeniaVariant {
  final String name;
  final String executableName;

  XeniaVariant({
    required this.name,
    required this.executableName,
  });
}

class XeniaVariantsCard extends StatelessWidget {
  static final List<XeniaVariant> xeniaVariants = [
    XeniaVariant(name: 'Xenia Canary', executableName: 'xenia_canary.exe'),
    XeniaVariant(
        name: 'Xenia Netplay', executableName: 'xenia_canary_netplay.exe'),
    XeniaVariant(name: 'Xenia Stable', executableName: 'xenia.exe'),
  ];

  const XeniaVariantsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    if (settingsProvider.config.baseFolder == null) {
      return const SizedBox.shrink();
    }

    return Card(
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
              final execPath =
                  settingsProvider.config.xeniaExecutables.firstWhere(
                (exe) => exe
                    .toLowerCase()
                    .endsWith(variant.executableName.toLowerCase()),
                orElse: () => '',
              );

              final version = execPath.isNotEmpty
                  ? settingsProvider.config.xeniaVersions[execPath] ?? 'Unknown'
                  : '';

              return ListTile(
                leading: Icon(
                  execPath.isNotEmpty ? Icons.check_circle : Icons.error,
                  color: execPath.isNotEmpty ? Colors.green : Colors.red,
                ),
                title: Text(variant.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(execPath.isNotEmpty
                        ? execPath.split('/').last
                        : 'Not found'),
                    if (version.isNotEmpty && version != 'Unknown')
                      Text(
                        version,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                  ],
                ),
                trailing: execPath.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () => _testExecutable(context, execPath),
                            child: const Text('Test'),
                          ),
                        ],
                      )
                    : null,
                isThreeLine: version.isNotEmpty && version != 'Unknown',
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _testExecutable(BuildContext context, String executable) async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final winePrefix = settingsProvider.config.winePrefix;

    if (winePrefix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set Wine prefix first')),
      );
      return;
    }

    final success =
        await settingsProvider.testExecutable(executable, winePrefix);

    if (context.mounted) {
      if (success) {
        final version = settingsProvider.config.xeniaVersions[executable];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Successfully tested ${executable.split('/').last}${version != null ? '\n$version' : ''}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to run executable')),
        );
      }
    }
  }
}
