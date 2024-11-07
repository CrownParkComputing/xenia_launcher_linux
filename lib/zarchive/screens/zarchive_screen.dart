import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:developer' as developer;
import '../services/zarchive_service.dart';
import '../widgets/archive_explorer.dart';

class ZArchiveScreen extends StatefulWidget {
  const ZArchiveScreen({Key? key}) : super(key: key);

  @override
  _ZArchiveScreenState createState() => _ZArchiveScreenState();
}

class _ZArchiveScreenState extends State<ZArchiveScreen> {
  final ZArchiveService _archiveService = ZArchiveService();
  String? _currentArchivePath;
  String? _currentExtractPath;
  double _progressValue = 0.0;
  bool _isProcessing = false;

  void _updateProgress(int current, int total) {
    setState(() {
      _progressValue = current / total;
    });
  }

  Future<void> _createArchive() async {
    try {
      setState(() {
        _isProcessing = true;
        _progressValue = 0.0;
      });

      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) return;

      final saveResult = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Archive As',
        fileName: 'archive.zar',
      );
      if (saveResult == null) return;

      await _archiveService.createArchive(
        result, 
        saveResult, 
        _updateProgress
      );

      developer.log('Archive created successfully: $saveResult', 
        name: 'ZArchive', 
        error: 'Input directory: $result'
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archive created successfully')),
      );
    } catch (e) {
      developer.log('Error creating archive', 
        name: 'ZArchive', 
        error: e.toString()
      );
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

  Future<void> _extractArchive() async {
    try {
      setState(() {
        _isProcessing = true;
        _progressValue = 0.0;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zar'],
      );
      if (result == null) return;

      final extractPath = await FilePicker.platform.getDirectoryPath();
      if (extractPath == null) return;

      final entries = await _archiveService.extractArchive(
        result.files.single.path!, 
        extractPath,
        _updateProgress
      );
      
      setState(() {
        _currentArchivePath = result.files.single.path;
        _currentExtractPath = extractPath;
      });
      
      developer.log('Archive extracted successfully', 
        name: 'ZArchive', 
        error: 'Extracted ${entries.length} entries to $extractPath'
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archive extracted successfully (${entries.length} files)')),
      );
    } catch (e) {
      developer.log('Error extracting archive', 
        name: 'ZArchive', 
        error: e.toString()
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error extracting archive: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZArchive'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _isProcessing ? null : _createArchive,
            tooltip: 'Create Archive',
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _isProcessing ? null : _extractArchive,
            tooltip: 'Extract Archive',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isProcessing)
            LinearProgressIndicator(value: _progressValue),
          
          _currentArchivePath == null
              ? const Center(child: Text('Select an archive to explore'))
              : Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Extracted to: ${_currentExtractPath ?? "Unknown"}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Expanded(
                        child: ArchiveExplorer(archivePath: _currentArchivePath!),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
