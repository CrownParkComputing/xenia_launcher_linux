import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/dlc.dart';
import '../providers/live_games_provider.dart';
import '../services/dlc_service.dart';

class DLCDialog extends StatefulWidget {
  final Game game;

  const DLCDialog({
    super.key,
    required this.game,
  });

  @override
  State<DLCDialog> createState() => _DLCDialogState();
}

class _DLCDialogState extends State<DLCDialog> {
  late Game _currentGame;
  List<DLC> _dlcList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentGame = widget.game;
    _loadDLC();
  }

  Future<void> _loadDLC() async {
    setState(() => _isLoading = true);
    _dlcList = await DLCService.scanForDLC(_currentGame);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('DLC - ${_currentGame.title}'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Installed DLC (${_dlcList.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadDLC,
                      tooltip: 'Rescan DLC',
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _importDLC(context),
                      tooltip: 'Import DLC',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _dlcList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.extension_outlined, size: 48),
                              const SizedBox(height: 16),
                              const Text('No DLC installed'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _importDLC(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Import DLC'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _dlcList.length,
                          itemBuilder: (context, index) {
                            final dlc = _dlcList[index];
                            return ListTile(
                              title: Text(dlc.name),
                              subtitle: Text(
                                'Added ${_formatDate(dlc.dateAdded)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _removeDLC(context, dlc),
                                tooltip: 'Remove DLC',
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _importDLC(BuildContext context) async {
    final liveProvider = Provider.of<LiveGamesProvider>(context, listen: false);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Select DLC ZIP',
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Extracting DLC...'),
                ],
              ),
            ),
          ),
        ),
      );

      var successCount = 0;
      var failCount = 0;
      final successfulDlcs = <String>[];

      // Process each selected DLC file
      for (final file in result.files) {
        try {
          final dlc = await liveProvider.importDLC(file.path!, _currentGame);
          if (dlc != null) {
            successCount++;
            successfulDlcs.add(dlc.name);
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          print('Error importing DLC: $e');
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show result message
        String message = '';
        if (successCount > 0) {
          message += 'Successfully installed:\n${successfulDlcs.join('\n')}';
        }
        if (failCount > 0) {
          if (message.isNotEmpty) message += '\n\n';
          message += 'Failed to install $failCount DLC';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );

        // Refresh the DLC list
        await _loadDLC();
      }
    }
  }

  Future<void> _removeDLC(BuildContext context, DLC dlc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove DLC'),
        content: Text(
            'Are you sure you want to remove "${dlc.name}"?\n\nThis will delete the DLC files.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final liveProvider =
          Provider.of<LiveGamesProvider>(context, listen: false);

      try {
        await liveProvider.removeDLC(_currentGame, dlc);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DLC removed successfully')),
          );
          // Refresh the DLC list
          await _loadDLC();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error removing DLC: $e')),
          );
        }
      }
    }
  }
}
