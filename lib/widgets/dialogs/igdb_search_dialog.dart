import 'package:flutter/material.dart';
import '../../models/igdb_game.dart';
import '../../services/igdb_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class IgdbSearchDialog extends StatefulWidget {
  final String currentTitle;

  const IgdbSearchDialog({
    super.key,
    required this.currentTitle,
  });

  @override
  State<IgdbSearchDialog> createState() => _IgdbSearchDialogState();
}

class _IgdbSearchDialogState extends State<IgdbSearchDialog> {
  final _searchController = TextEditingController();
  final _igdbService = IGDBService();
  List<IGDBGame> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.currentTitle;
    _search();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      final results = await _igdbService.searchGames(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select IGDB Game'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search IGDB',
                      border: OutlineInputBorder(),
                      hintText: 'Enter game title',
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final game = _results[index];
                    return Card(
                      child: ListTile(
                        leading: game.coverUrl != null
                            ? SizedBox(
                                width: 50,
                                child: CachedNetworkImage(
                                  imageUrl: game.coverUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                ),
                              )
                            : const SizedBox(
                                width: 50,
                                child: Icon(Icons.gamepad),
                              ),
                        title: Text(game.name),
                        subtitle: game.releaseDate != null
                            ? Text(DateFormat.yMMMd().format(game.releaseDate!))
                            : null,
                        onTap: () => Navigator.pop(context, game),
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
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
