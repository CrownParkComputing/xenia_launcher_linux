import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/zarchive_service.dart';

class XboxIsoExtractorScreen extends StatefulWidget {
  const XboxIsoExtractorScreen({super.key});

  @override
  _XboxIsoExtractorScreenState createState() => _XboxIsoExtractorScreenState();
}

class _XboxIsoExtractorScreenState extends State<XboxIsoExtractorScreen> {
  String? selectedFolder;
  String? selectedIso;
  String outputText = '';
  bool isProcessing = false;
  final ZArchiveService _archiveService = ZArchiveService();
  
  List<String> availableIsos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setDefaultIsoFolder(context);
    });
  }

  void _setDefaultIsoFolder(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final isoFolder = settingsProvider.config.isoFolder ?? 
      path.join(settingsProvider.config.baseFolder ?? '/home/jon', 'ISOs');

    setState(() {
      selectedFolder = isoFolder;
      _loadAvailableIsos();
    });
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
    setState(() {
      selectedIso = path.join(selectedFolder!, isoName);
      outputText = 'Selected ISO: $selectedIso';
    });
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
      final executable = path.join(Directory.current.path, 'tools', 'extract-xiso');
      final result = await Process.run(
        'bash',
        ['-c', '"$executable" -s -l "$selectedIso"'],
        runInShell: true,
      );

      setState(() {
        outputText = result.stdout.toString();
        if (result.stderr.isNotEmpty) {
          outputText += '\nError: ${result.stderr}';
        }
      });
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
      final defaultExtractionPath = settingsProvider.defaultExtractPath ?? 
        path.join(settingsProvider.config.baseFolder ?? '/home/jon', 'Extractions');

      final isoName = path.basenameWithoutExtension(selectedIso!);
      final extractionFolder = path.join(defaultExtractionPath, isoName);
      
      await Directory(extractionFolder).create(recursive: true);

      final executable = path.join(Directory.current.path, 'tools', 'extract-xiso');
      final result = await Process.run(
        'bash',
        ['-c', '"$executable" -s -x "$selectedIso" -d "$extractionFolder"'],
        runInShell: true,
      );

      setState(() {
        outputText = result.stdout.toString();
        if (result.stderr.isNotEmpty) {
          outputText += '\nError: ${result.stderr}';
        }
        outputText += '\nExtracted to: $extractionFolder';
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

  Future<void> rewriteIso() async {
    if (selectedIso == null) {
      setState(() {
        outputText = 'Please select an ISO file first';
      });
      return;
    }

    setState(() {
      isProcessing = true;
      outputText = 'Rewriting/Optimizing ISO...';
    });

    try {
      final executable = path.join(Directory.current.path, 'tools', 'extract-xiso');
      final result = await Process.run(
        'bash',
        ['-c', '"$executable" -s -r "$selectedIso"'],
        runInShell: true,
      );

      setState(() {
        outputText = result.stdout.toString();
        if (result.stderr.isNotEmpty) {
          outputText += '\nError: ${result.stderr}';
        }
        outputText += '\nISO Rewritten/Optimized';
      });
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
            Text(outputText, 
              style: TextStyle(
                color: outputText.contains('Error') ? Colors.red : Colors.green
              )
            ),
            const SizedBox(height: 8),
            if (availableIsos.isNotEmpty)
              DropdownButton<String>(
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
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (selectedIso != null && !isProcessing) ? rewriteIso : null,
                    child: const Text('Rewrite/Optimize'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  controller: ScrollController(),
                  child: Text(outputText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
