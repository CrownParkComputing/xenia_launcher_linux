import 'package:flutter/material.dart';
import '../dialogs/igdb_search_dialog.dart';

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
                icon: const Icon(Icons.search, size: 16),
                onPressed: onEditTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Search IGDB',
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
