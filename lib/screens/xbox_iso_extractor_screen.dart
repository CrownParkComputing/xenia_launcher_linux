import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/xbox_iso_extractor_service.dart';
import '../services/zarchive_service.dart';

class XboxIsoExtractorScreen extends StatefulWidget {
  const XboxIsoExtractorScreen({Key? key}) : super(key: key);

  @override
  _XboxIsoExtractorScreenState createState() => _XboxIsoExtractorScreenState();
}

class _XboxIsoExtractorScreenState extends State<XboxIsoExtractorScreen> {
  String? selectedFolder;
  String? selectedIso;
  List<String> availableIsos = [];
  String outputText = '';
  bool isProcessing = false;
  final _archiveService = ZArchiveService();

  @override
  void initState() {
    super.initState();
    _setDefaultIsoFolder(context);
  }

  void _loadAvailableIsos() {
    try {
      if (selectedFolder == null) {
        setState(() {
          outputText = 'No ISO Folder configured';
          availableIsos = [];
        });
        return;
      }

      final directory = Directory(selectedFolder!);
      
      if (!directory.existsSync()) {
        setState(() {
          outputText = 'ISO Folder does not exist: $selectedFolder';
          availableIsos = [];
        });
        return;
      }

      final isoFiles = directory
          .listSync(recursive: false)
          .where((file) => 
            file is File && 
            path.extension(file.path).toLowerCase() == '.iso')
          .map((file) => path.basename(file.path))
          .toList();

      setState(() {
        availableIsos = isoFiles;
        outputText = isoFiles.isEmpty 
          ? 'No ISO files found in ${directory.path}' 
          : '${isoFiles.length} ISO(s) found';
      });
    } catch (e) {
      setState(() {
        outputText = 'Error loading ISOs: ${e.toString()}';
        availableIsos = [];
      });
    }
  }

  void _selectIso(String isoName) {
    if (selectedFolder == null || !Directory(selectedFolder!).existsSync()) {
      setState(() {
        outputText = 'Invalid ISO folder selected';
      });
      return;
    }

    final fullPath = path.join(selectedFolder!, isoName);
    if (!File(fullPath).existsSync()) {
      setState(() {
        outputText = 'ISO file not found: $isoName';
      });
      return;
    }

    setState(() {
      selectedIso = fullPath;
      outputText = 'Selected ISO: $isoName';
    });
  }

  Future<void> listContents() async {
    if (selectedIso == null) {
      setState(() {
        outputText = 'Please select an ISO file first';
      });
      return;
    }

    setState(() {
      isProcessing = true;
      outputText = 'Processing...';
    });

    try {
      final result = await XboxIsoExtractorService.getFileList(
        selectedIso!,
        onOperation: (op) => setState(() => outputText = '$outputText\n$op'),
        onStatus: (status) => setState(() => outputText = '$outputText\n$status'),
      );

      if (result.list.isEmpty) {
        setState(() {
          outputText = 'No files found in ISO. This may not be a valid Xbox ISO.';
        });
        return;
      }

      // Sort entries by path and name
      result.list.sort((a, b) {
        final pathCompare = a.path.compareTo(b.path);
        if (pathCompare != 0) return pathCompare;
        return a.name.compareTo(b.name);
      });

      // Build a formatted listing
      final buffer = StringBuffer();
      buffer.writeln('=== ISO Contents ===');
      buffer.writeln('Total Files: ${result.files}');
      buffer.writeln('Total Folders: ${result.folders}');
      buffer.writeln('Total Size: ${_getSizeReadable(result.size)}');
      buffer.writeln('\n=== File Listing ===');
      
      for (final entry in result.list) {
        final fullPath = '${entry.path}${entry.name}';
        final type = entry.isFile ? '[F]' : '[D]';
        final size = entry.isFile ? ' (${_getSizeReadable(entry.size)})' : '';
        buffer.writeln('$type $fullPath$size');
      }

      buffer.writeln('\n=== Raw Data for Debugging ===');
      for (final entry in result.list) {
        buffer.writeln('Type: ${entry.isFile ? "File" : "Dir"}');
        buffer.writeln('Name: ${entry.name}');
        buffer.writeln('Path: ${entry.path}');
        buffer.writeln('Offset: 0x${entry.offset.toRadixString(16)}');
        buffer.writeln('Size: ${entry.size}');
        buffer.writeln('---');
      }

      setState(() {
        outputText = buffer.toString();
      });
    } catch (e) {
      setState(() {
        outputText = 'Error listing contents: ${e.toString()}';
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> extractContents() async {
    if (selectedIso == null) {
      setState(() {
        outputText = 'Please select an ISO file first';
      });
      return;
    }

    setState(() {
      isProcessing = true;
      outputText = 'Extracting...';
    });

    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      // Get extraction path from settings
      final extractionBasePath = settingsProvider.defaultExtractPath;
      
      // Create extraction folder if it doesn't exist
      final extractionDir = Directory(extractionBasePath);
      if (!await extractionDir.exists()) {
        await extractionDir.create(recursive: true);
      }

      final isoName = path.basenameWithoutExtension(selectedIso!);
      final extractionFolder = path.join(extractionBasePath, isoName);

      // Create specific game extraction folder
      final gameDir = Directory(extractionFolder);
      if (!await gameDir.exists()) {
        await gameDir.create(recursive: true);
      }

      final success = await XboxIsoExtractorService.extractIso(
        selectedIso!,
        extractionFolder,
        onOperation: (op) => setState(() => outputText = op),
        onStatus: (status) => setState(() => outputText = status),
        onProgress: (progress) => setState(() => 
          outputText = '$outputText\nProgress: ${progress.toStringAsFixed(1)}%'),
      );

      if (success) {
        setState(() {
          outputText = '$outputText\nExtracted to: $extractionFolder';
        });

        // Show dialog asking if user wants to create archive
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
          await _createArchive(extractionFolder);
        }
      }
    } catch (e) {
      setState(() {
        outputText = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _createArchive(String sourcePath) async {
    setState(() {
      isProcessing = true;
      outputText = 'Creating archive...';
    });

    try {
      final settings = context.read<SettingsProvider>();
      final defaultCreatePath = settings.defaultCreatePath;
      if (defaultCreatePath == null) {
        setState(() {
          outputText = 'Please set Archive Save Location in settings';
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
            outputText = 'Creating archive: ${((current / total) * 100).toStringAsFixed(1)}%';
          });
        }
      );

      setState(() {
        outputText = 'Archive created: ${saveFile.path}';
      });

      // Ask if user wants to delete the source folder
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
          outputText += '\nSource folder deleted';
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
        outputText = 'Error creating archive: $e';
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  void _setDefaultIsoFolder(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final homeDir = Platform.environment['HOME'] ?? '/home/${Platform.environment['USER']}';
    
    String isoFolder;
    if (settingsProvider.config.isoFolder != null && 
        settingsProvider.config.isoFolder!.isNotEmpty && 
        settingsProvider.config.isoFolder != '/') {
      isoFolder = settingsProvider.config.isoFolder!;
    } else if (settingsProvider.config.baseFolder != null && 
               settingsProvider.config.baseFolder!.isNotEmpty && 
               settingsProvider.config.baseFolder != '/') {
      isoFolder = path.join(settingsProvider.config.baseFolder!, 'ISOs');
    } else {
      isoFolder = path.join(homeDir, 'Xenia', 'ISOs');
    }

    // Create the folder if it doesn't exist
    final directory = Directory(isoFolder);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    setState(() {
      selectedFolder = isoFolder;
      _loadAvailableIsos();
    });
  }

  String _getSizeReadable(int bytes) {
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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _setDefaultIsoFolder(context),
                    child: const Text('Reset to Default Folder'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadAvailableIsos,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Current Folder: ${selectedFolder ?? 'No folder selected'}'),
            const SizedBox(height: 8),
            if (availableIsos.isNotEmpty)
              SizedBox(
                height: 48,
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Select an ISO'),
                  value: selectedIso != null 
                    ? path.basename(selectedIso!) 
                    : null,
                  items: availableIsos.map((String isoName) {
                    return DropdownMenuItem<String>(
                      value: isoName,
                      child: Text(isoName),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _selectIso(newValue);
                    }
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (selectedIso != null && !isProcessing) ? listContents : null,
                    child: const Text('List Contents'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (selectedIso != null && !isProcessing) ? extractContents : null,
                    child: const Text('Extract & Archive'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: SelectableText(
                          outputText,
                          style: const TextStyle(
                            fontFamily: 'Monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    if (isProcessing)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
