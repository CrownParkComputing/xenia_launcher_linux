import 'package:flutter/material.dart';

class GameTitleSection extends StatelessWidget {
  final String title;
  final String? executableDisplayName;
  final VoidCallback onEditTap;

  const GameTitleSection({
    super.key,
    required this.title,
    this.executableDisplayName,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 16),
                onPressed: onEditTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Edit Titles',
              ),
            ],
          ),
          if (executableDisplayName != null)
            Text(
              executableDisplayName!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class EditTitlesDialog extends StatefulWidget {
  final String title;
  final String? searchTitle;
  final Function(String) onTitleEdit;
  final Function(String) onSearchTitleEdit;

  const EditTitlesDialog({
    super.key,
    required this.title,
    required this.searchTitle,
    required this.onTitleEdit,
    required this.onSearchTitleEdit,
  });

  @override
  State<EditTitlesDialog> createState() => _EditTitlesDialogState();
}

class _EditTitlesDialogState extends State<EditTitlesDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _searchTitleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _searchTitleController = TextEditingController(text: widget.searchTitle ?? widget.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Game'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Display Title',
              helperText: 'The title shown in the launcher',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchTitleController,
            decoration: const InputDecoration(
              labelText: 'Search Title',
              helperText: 'The title used for IGDB search',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final newTitle = _titleController.text.trim();
            final newSearchTitle = _searchTitleController.text.trim();
            
            if (newTitle.isNotEmpty && newTitle != widget.title) {
              widget.onTitleEdit(newTitle);
            }
            
            if (newSearchTitle.isNotEmpty && newSearchTitle != widget.searchTitle) {
              widget.onSearchTitleEdit(newSearchTitle);
            }
            
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
