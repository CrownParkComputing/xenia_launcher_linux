import 'package:flutter/material.dart';
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
          ],
        ),
      ),
    );
  }

  Future<void> _scanForExecutables(String basePath) async {
    // This method is now handled within XeniaVariantsCard
  }
}
