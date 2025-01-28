import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../providers/settings_provider.dart';
import '../services/zarchive_service.dart';
import '../services/xbox_iso_extractor_service.dart';
import 'package:path/path.dart' as path;

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
  String _outputText = '';

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
      await dir.create(recursive: true);
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

  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['iso', 'rar'],
        dialogTitle: 'Select ISO or RAR File',
      );

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      final extension = path.extension(filePath).toLowerCase();

      final settings = context.read<SettingsProvider>();
      final extractPath = settings.defaultExtractPath;
      if (extractPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set Game Files Location in settings')),
        );
        return;
      }

      setState(() {
        _isProcessing = true;
        _outputText = 'Processing ${path.basename(filePath)}...';
      });

      // For ISO files, we still want a subfolder since extract-xiso doesn't create one
      if (extension == '.iso') {
        final fileName = path.basenameWithoutExtension(filePath);
        final extractDir = path.join(extractPath, fileName);
        await Directory(extractDir).create(recursive: true);
        await _extractIso(filePath, extractDir);
      } else if (extension == '.rar') {
        // For RAR files, extract directly to the base folder since the RAR usually contains its own folder structure
        await _extractRar(filePath, extractPath);
      }

      await _loadAvailableFolders();

      if (!mounted) return;
      final shouldCreateArchive = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create Archive?'),
          content: const Text('Would you like to create a ZAR archive from the extracted files?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (shouldCreateArchive == true) {
        // For RAR files, we need to find the game folder that was just extracted
        if (extension == '.rar') {
          // Look for a folder containing default.xex
          Directory? gameDir;
          await for (var entity in Directory(extractPath).list()) {
            if (entity is Directory) {
              bool hasXex = false;
              await for (var file in entity.list(recursive: true)) {
                if (file is File && path.basename(file.path).toLowerCase() == 'default.xex') {
                  hasXex = true;
                  gameDir = entity;
                  break;
                }
              }
              if (hasXex) break;
            }
          }

          if (gameDir != null) {
            await _createArchive(gameDir.path);
          } else {
            setState(() {
              _outputText = 'Could not find extracted game folder with default.xex';
            });
          }
        } else {
          // For ISO files, we know the exact folder path
          final extractDir = path.join(extractPath, path.basenameWithoutExtension(filePath));
          await _createArchive(extractDir);
        }
      }

    } catch (e) {
      setState(() {
        _outputText = 'Error: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _extractIso(String isoPath, String extractDir) async {
    final success = await XboxIsoExtractorService.extractIso(
      isoPath,
      extractDir,
      onOperation: (op) => setState(() => _outputText = op),
      onStatus: (status) => setState(() => _outputText = status),
      onProgress: (progress) => setState(() => 
        _outputText = '$_outputText\nProgress: ${progress.toStringAsFixed(1)}%'),
    );

    if (!success) {
      throw Exception('Failed to extract ISO');
    }
  }

  Future<void> _extractRar(String rarPath, String extractDir) async {
    try {
      // Check if unrar is installed
      final checkResult = await Process.run('which', ['unrar']);
      if (checkResult.exitCode != 0) {
        throw Exception('unrar is not installed. Please install it using: sudo pacman -S unrar');
      }

      setState(() {
        _outputText = 'Extracting RAR file: ${path.basename(rarPath)}';
      });

      // Extract with full path preservation and overwrite
      final result = await Process.run('unrar', [
        'x',      // extract with full path
        '-y',     // assume yes on all queries
        '-o+',    // overwrite existing files
        rarPath,  // source file
        extractDir, // destination directory
      ]);
      
      if (result.exitCode != 0) {
        throw Exception('Failed to extract RAR:\n${result.stderr}');
      }

      // Look for default.xex in extracted files
      bool foundXex = false;
      String? xexPath;
      await for (var entity in Directory(extractDir).list(recursive: true)) {
        if (entity is File && path.basename(entity.path).toLowerCase() == 'default.xex') {
          foundXex = true;
          xexPath = entity.path;
          break;
        }
      }

      setState(() {
        if (foundXex) {
          _outputText = 'RAR extracted successfully - Found default.xex at:\n$xexPath';
        } else {
          _outputText = 'RAR extracted successfully - No default.xex found';
        }
      });
    } catch (e) {
      setState(() {
        _outputText = 'Error extracting RAR: $e';
      });
      rethrow;
    }
  }

  Future<void> _createArchive(String sourcePath) async {
    try {
      final settings = context.read<SettingsProvider>();
      final defaultCreatePath = settings.defaultCreatePath;
      if (defaultCreatePath == null) {
        setState(() {
          _outputText = 'Please set Archive Save Location in settings';
        });
        return;
      }

      final folderName = path.basename(sourcePath);
      final saveFile = File('$defaultCreatePath${Platform.pathSeparator}$folderName.zar');

      await _archiveService.createArchive(
        sourcePath, 
        saveFile.path, 
        (current, total) {
          setState(() {
            _outputText = 'Creating archive: ${((current / total) * 100).toStringAsFixed(1)}%';
          });
        }
      );

      if (!mounted) return;
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Source Folder?'),
          content: Text('Would you like to delete the extracted folder?\n\n$sourcePath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (shouldDelete == true) {
        await Directory(sourcePath).delete(recursive: true);
        setState(() {
          _outputText += '\nSource folder deleted';
        });
      }

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
      setState(() {
        _outputText = 'Error creating archive: $e';
      });
    }
  }

  Future<void> _deleteFolder(String folderPath) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Folder'),
          content: Text('Are you sure you want to delete:\n\n${path.basename(folderPath)}?\n\nThis cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() {
          _outputText = 'Deleting folder: ${path.basename(folderPath)}';
        });

        await Directory(folderPath).delete(recursive: true);
        await _loadAvailableFolders(); // Refresh the list

        setState(() {
          _outputText = 'Folder deleted successfully';
        });
      }
    } catch (e) {
      setState(() {
        _outputText = 'Error deleting folder: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _importFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import ISO/RAR'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _loadAvailableFolders,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            LinearProgressIndicator(value: _progressValue),
          
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available folders list
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Available Game Folders',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _availableFolders.isEmpty
                            ? const Center(
                                child: Text('No game folders available'),
                              )
                            : ListView.builder(
                                itemCount: _availableFolders.length,
                                itemBuilder: (context, index) {
                                  final folder = _availableFolders[index];
                                  final folderName = folder.path.split(Platform.pathSeparator).last;
                                  return ListTile(
                                    leading: const Icon(Icons.folder),
                                    title: Text(folderName),
                                    subtitle: const Text('Tap to create archive'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: _isProcessing ? null : () => _deleteFolder(folder.path),
                                      tooltip: 'Delete folder',
                                    ),
                                    onTap: _isProcessing ? null : () => _createArchive(folder.path),
                                  );
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Output log
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Operation Log',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16.0),
                              child: SelectableText(
                                _outputText,
                                style: const TextStyle(
                                  fontFamily: 'Monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
