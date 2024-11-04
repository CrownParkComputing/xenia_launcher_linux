import 'package:flutter/material.dart';

class GameActionsSection extends StatelessWidget {
  final VoidCallback onDeleteTap;
  final VoidCallback onAchievementsTap;
  final VoidCallback onDLCTap;
  final int achievementsCount;
  final int dlcCount;

  const GameActionsSection({
    super.key,
    required this.onDeleteTap,
    required this.onAchievementsTap,
    required this.onDLCTap,
    required this.achievementsCount,
    required this.dlcCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                onPressed: onDeleteTap,
                tooltip: 'Remove from Library',
              ),
            ),
          ),
          // Achievements button - bottom center
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: achievementsCount > 0
                      ? Colors.amber.withOpacity(0.8)
                      : Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: onAchievementsTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: achievementsCount > 0 ? 16 : 20,
                        ),
                        if (achievementsCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$achievementsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // DLC button - bottom right
          Positioned(
            bottom: 4,
            right: 4,
            child: dlcCount > 0
                ? InkWell(
                    onTap: onDLCTap,
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
                      onPressed: onDLCTap,
                      tooltip: 'Add DLC',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
