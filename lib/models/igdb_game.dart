import 'package:flutter/foundation.dart';

class IGDBGame {
  final int id;
  final String name;
  final String? summary;
  final String? coverUrl;
  final List<String> screenshots;
  final List<String> genres;
  final List<String> gameModes;
  final double? rating;
  final DateTime? releaseDate;

  IGDBGame({
    required this.id,
    required this.name,
    this.summary,
    this.coverUrl,
    this.screenshots = const [],
    this.genres = const [],
    this.gameModes = const [],
    this.rating,
    this.releaseDate,
  });

  factory IGDBGame.fromJson(Map<String, dynamic> json) {
    DateTime? parseReleaseDate() {
      try {
        if (json['release_dates'] != null && 
            (json['release_dates'] as List).isNotEmpty &&
            json['release_dates'][0]['date'] != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            (json['release_dates'][0]['date'] as int) * 1000);
        }
      } catch (e) {
        debugPrint('Error parsing release date: $e');
      }
      return null;
    }

    return IGDBGame(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown Game',
      summary: json['summary'] as String?,
      coverUrl: json['cover'] != null && json['cover']['url'] != null
          ? 'https://images.igdb.com/igdb/image/upload/t_cover_big/${json['cover']['url'].split('/').last}'
          : null,
      screenshots: (json['screenshots'] as List<dynamic>?)
          ?.where((s) => s['url'] != null)
          .map((s) => 'https://images.igdb.com/igdb/image/upload/t_screenshot_big/${s['url'].split('/').last}')
          .toList() ??
          [],
      genres: (json['genres'] as List<dynamic>?)
          ?.map((g) => g['name'] as String)
          .toList() ??
          [],
      gameModes: (json['game_modes'] as List<dynamic>?)
          ?.map((m) => m['name'] as String)
          .toList() ??
          [],
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      releaseDate: parseReleaseDate(),
    );
  }
}
