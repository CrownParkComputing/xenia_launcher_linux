import 'dart:io';
import 'package:flutter/material.dart';
import '../models/zarchive_model.dart';
import '../services/zarchive_service.dart';
import 'package:path/path.dart' as path;

class ArchiveExplorer extends StatefulWidget {
  final String archivePath;

  const ArchiveExplorer({
    super.key,
    required this.archivePath,
  });

  @override
  State<ArchiveExplorer> createState() => _ArchiveExplorerState();
}

class _ArchiveExplorerState extends State<ArchiveExplorer> {
  final ZArchiveService _archiveService = ZArchiveService();
  List<ZArchiveEntry>? _entries;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Create a temporary directory for listing
      final tempDir = await Directory.systemTemp.createTemp('zarchive_list');
      
      // Extract and list entries
      final entries = await _archiveService.extractArchive(
        widget.archivePath,
        tempDir.path,
        (current, total) {}, // Progress callback not needed for explorer
      );

      // Sort entries by path
      entries.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _entries = entries;
        _isLoading = false;
      });

      // Clean up temp directory
      await tempDir.delete(recursive: true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildEntryIcon(ZArchiveEntry entry) {
    final extension = path.extension(entry.name).toLowerCase();
    
    // Define icon based on file type
    IconData icon;
    if (entry.name.endsWith('/')) {
      icon = Icons.folder;
    } else if (['.png', '.jpg', '.jpeg', '.gif'].contains(extension)) {
      icon = Icons.image;
    } else if (['.mp3', '.wav', '.ogg'].contains(extension)) {
      icon = Icons.audio_file;
    } else if (['.mp4', '.avi', '.mov'].contains(extension)) {
      icon = Icons.video_file;
    } else if (['.txt', '.md', '.json', '.xml'].contains(extension)) {
      icon = Icons.description;
    } else if (['.zip', '.rar', '.7z', '.tar', '.gz'].contains(extension)) {
      icon = Icons.archive;
    } else {
      icon = Icons.insert_drive_file;
    }

    return Icon(icon);
  }

  String _formatSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading archive: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEntries,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_entries == null || _entries!.isEmpty) {
      return const Center(
        child: Text('No files found in archive'),
      );
    }

    return ListView.builder(
      itemCount: _entries!.length,
      itemBuilder: (context, index) {
        final entry = _entries![index];
        return ListTile(
          leading: _buildEntryIcon(entry),
          title: Text(entry.name),
          subtitle: Text(_formatSize(entry.size)),
          dense: true,
          visualDensity: VisualDensity.compact,
          onTap: () {
            // Could add preview functionality here
          },
        );
      },
    );
  }
}
