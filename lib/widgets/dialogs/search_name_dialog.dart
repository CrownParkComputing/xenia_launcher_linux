import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/search_names_provider.dart';

class SearchNameDialog extends StatefulWidget {
  final String originalName;

  const SearchNameDialog({
    Key? key,
    required this.originalName,
  }) : super(key: key);

  @override
  State<SearchNameDialog> createState() => _SearchNameDialogState();
}

class _SearchNameDialogState extends State<SearchNameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.originalName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom Search Name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No results found. Enter a custom search name for this game:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Search Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final customName = _controller.text.trim();
            if (customName.isNotEmpty) {
              context.read<SearchNamesProvider>().setCustomSearchName(
                    widget.originalName,
                    customName,
                  );
            }
            Navigator.of(context).pop(customName);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
