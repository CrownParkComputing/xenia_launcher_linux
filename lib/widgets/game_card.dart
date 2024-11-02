import 'package:flutter/material.dart';
import 'dart:io';
import '../models/game.dart';
import '../services/dlc_service.dart';

class GameCard extends StatefulWidget {
  final Game game;
  final String? executableDisplayName;
  final VoidCallback onPlayTap;
  final VoidCallback onDLCTap;
  final VoidCallback onDeleteTap;

  const GameCard({
    super.key,
    required this.game,
    required this.executableDisplayName,
    required this.onPlayTap,
    required this.onDLCTap,
    required this.onDeleteTap,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: DLCService.countDLC(widget.game),
      builder: (context, snapshot) {
        final dlcCount = snapshot.data ?? 0;
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Game Cover - 3/4 of card height
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      _buildCover(),
                      // Dark overlay when hovering
                      if (_isHovering)
                        Container(
                          color: Colors.black.withOpacity(0.3),
                        ),
                      // Play button
                      AnimatedOpacity(
                        opacity: _isHovering ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 64,
                              icon: const Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                              ),
                              onPressed: widget.onPlayTap,
                              tooltip: 'Launch Game',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Game Info - 1/4 of card height
                Container(
                  color: Theme.of(context).cardColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Game Title
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.game.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.executableDisplayName != null)
                              Text(
                                widget.executableDisplayName!,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Action Buttons
                      SizedBox(
                        height: 48,
                        child: Stack(
                          children: [
                            // Delete button - bottom left
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: widget.onDeleteTap,
                                  tooltip: 'Remove from Library',
                                ),
                              ),
                            ),
                            // DLC button/badge - bottom right
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: dlcCount > 0
                                  ? InkWell(
                                      onTap: widget.onDLCTap,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.extension,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$dlcCount DLC',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.extension,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        onPressed: widget.onDLCTap,
                                        tooltip: 'Add DLC',
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCover() {
    if (widget.game.coverPath != null) {
      return Image.file(
        File(widget.game.coverPath!),
        fit: BoxFit.cover,
      );
    }
    return Container(
      color: Colors.black26,
      child: const Icon(Icons.gamepad, size: 64),
    );
  }
}
