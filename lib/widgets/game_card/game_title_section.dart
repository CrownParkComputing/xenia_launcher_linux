import 'package:flutter/material.dart';

class GameTitleSection extends StatefulWidget {
  final String title;
  final String? executableDisplayName;
  final Function(String) onTitleEdit;
  final VoidCallback onSearchTap;

  const GameTitleSection({
    super.key,
    required this.title,
    this.executableDisplayName,
    required this.onTitleEdit,
    required this.onSearchTap,
  });

  @override
  State<GameTitleSection> createState() => _GameTitleSectionState();
}

class _GameTitleSectionState extends State<GameTitleSection> {
  bool _isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveTitle() {
    if (_controller.text.isNotEmpty && _controller.text != widget.title) {
      widget.onTitleEdit(_controller.text);
    }
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: _isEditing
              ? TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: _saveTitle,
                    ),
                  ),
                  onSubmitted: (_) => _saveTitle(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.executableDisplayName != null)
                      Text(
                        widget.executableDisplayName!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(_isEditing ? Icons.close : Icons.edit),
                onPressed: () {
                  if (_isEditing) {
                    _controller.text = widget.title;
                  }
                  setState(() => _isEditing = !_isEditing);
                },
                tooltip: _isEditing ? 'Cancel' : 'Edit Title',
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: widget.onSearchTap,
                tooltip: 'Search IGDB',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
