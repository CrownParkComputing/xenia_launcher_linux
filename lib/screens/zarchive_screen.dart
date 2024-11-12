import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/settings_provider.dart';
import '../services/zarchive_service.dart';

class ZArchiveScreen extends StatefulWidget {
  const ZArchiveScreen({Key? key}) : super(key: key);

  @override
  _ZArchiveScreenState createState() => _ZArchiveScreenState();
}

class _ZArchiveScreenState extends State<ZArchiveScreen> {
  final ZArchiveService _archiveService = ZArchiveService();
  double _progressValue = 0.0;
  bool _isProcessing = false;
  List<Directory> _availableFolders = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableFolders();
  }

  Future<void> _loadAvailableFolders() async {
    final settings = context.read<SettingsProvider>();
    final extractPath = settings.defaultExtractPath;
    if (extractPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set Game Files Location in settings')),
      );
      return;
    }

    final dir = Directory(extractPath);
    if (!await dir.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game Files Location does not exist')),
      );
      return;
    }

    final List<Directory> folders = [];
    await for (var entity in dir.list()) {
      if (entity is Directory) {
        folders.add(entity);
      }
    }

    setState(() {
      _availableFolders = folders..sort((a, b) => 
        a.path.split(Platform.pathSeparator).last
          .compareTo(b.path.split(Platform.pathSeparator).last));
    });
  }

  void _updateProgress(int current, int total) {
    setState(() {
      _progressValue = current / total;
    });
  }

  Future<void> _createArchive(String sourcePath) async {
    try {
      setState(() {
        _isProcessing = true;
        _progressValue = 0.0;
      });

      final settings = context.read<SettingsProvider>();
      final defaultCreatePath = settings.defaultCreatePath;
      if (defaultCreatePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set Archive Save Location in settings')),
        );
        return;
      }

      final folderName = sourcePath.split(Platform.pathSeparator).last;
      final saveFile = File('$defaultCreatePath${Platform.pathSeparator}$folderName.zar');

      await _archiveService.createArchive(
        sourcePath, 
        saveFile.path, 
        _updateProgress
      );

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Archive Created'),
          content: Text('Archive saved to:\n${saveFile.path}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating archive: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
        _progressValue = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final extractPath = settings.defaultExtractPath;

    return Column(
      children: [
        if (_isProcessing)
          LinearProgressIndicator(value: _progressValue),
        
        if (extractPath == null)
          const Expanded(
            child: Center(
              child: Text('Configure Game Files Location in settings'),
            ),
          )
        else if (_availableFolders.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('No game folders found in:\n$extractPath'),
                  const SizedBox(height: 16),
                  const Text('Add game folders to this location'),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _availableFolders.length,
              itemBuilder: (context, index) {
                final folder = _availableFolders[index];
                final folderName = folder.path.split(Platform.pathSeparator).last;
                return ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folderName),
                  subtitle: const Text('Tap to create archive'),
                  onTap: _isProcessing ? null : () => _createArchive(folder.path),
                );
              },
            ),
          ),
      ],
    );
  }
}
