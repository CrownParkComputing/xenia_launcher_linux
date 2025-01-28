import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/settings/version_check_card.dart';
import '../widgets/settings/card_size_settings.dart';
import '../widgets/settings/xenia_config_card.dart';
import 'dart:io';

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
            const XeniaConfigCard(),
          ],
        ),
      ),
    );
  }

  Future<void> _scanForExecutables(String basePath) async {
    // This method is handled within XeniaVariantsCard
  }

  Future<void> _selectExecutable(BuildContext context, Function(String?) onSelect) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [''],
      dialogTitle: 'Select Xenia Canary Executable',
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      if (await file.exists()) {
        // Make the file executable
        await Process.run('chmod', ['+x', file.path]);
        onSelect(file.path);
      }
    }
  }
}
