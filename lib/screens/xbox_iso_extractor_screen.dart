import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

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
  
  List<String> availableIsos = [];

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to ensure context is available
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
      
      // Check if directory exists
      if (!directory.existsSync()) {
        setState(() {
          outputText = 'ISO Folder does not exist: $selectedFolder';
          availableIsos = [];
        });
        return;
      }

      // Improved ISO file detection
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

  // Rest of the methods remain the same as in the previous implementation...
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
      final defaultExtractionPath = path.join(settingsProvider.config.baseFolder ?? '/home/jon', 'Extractions');

      // Create extraction subfolder based on ISO name
      final isoName = path.basenameWithoutExtension(selectedIso!);
      final extractionFolder = path.join(defaultExtractionPath, isoName);
      
      // Ensure extraction folder exists
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
                    child: const Text('Extract (Skip Updates)'),
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
                  controller: ScrollController(), // Ensures scrolling
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
