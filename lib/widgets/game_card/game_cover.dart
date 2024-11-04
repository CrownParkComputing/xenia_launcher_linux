import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/igdb_game.dart';

class GameCover extends StatelessWidget {
  final String? localCoverPath;
  final IGDBGame? gameDetails;
  final bool isHovering;
  final VoidCallback onPlayTap;

  const GameCover({
    super.key,
    this.localCoverPath,
    this.gameDetails,
    required this.isHovering,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildCoverImage(),
        if (isHovering) ...[
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          AnimatedOpacity(
            opacity: isHovering ? 1.0 : 0.0,
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
                  onPressed: onPlayTap,
                  tooltip: 'Launch Game',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCoverImage() {
    // First try to use local cover
    if (localCoverPath != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Image.file(
            File(localCoverPath!),
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
          ),
        ),
      );
    }
    // If no local cover, try IGDB cover
    if (gameDetails?.coverUrl != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: gameDetails!.coverUrl!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            placeholder: (context, url) => _buildDefaultCover(),
            errorWidget: (context, url, error) => _buildDefaultCover(),
          ),
        ),
      );
    }
    // Fall back to default cover
    return _buildDefaultCover();
  }

  Widget _buildDefaultCover() {
    return Container(
      color: Colors.black26,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: const Icon(Icons.gamepad, size: 64),
    );
  }
}
