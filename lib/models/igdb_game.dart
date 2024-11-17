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
          final date = json['release_dates'][0]['date'];
          if (date is int) {
            return DateTime.fromMillisecondsSinceEpoch(date * 1000);
          }
        }
      } catch (e) {
        debugPrint('Error parsing release date: $e');
      }
      return null;
    }

    String? parseCoverUrl() {
      try {
        if (json['cover'] != null && json['cover']['url'] != null) {
          final url = json['cover']['url'] as String;
          return 'https://images.igdb.com/igdb/image/upload/t_cover_big/${url.split('/').last}';
        }
      } catch (e) {
        debugPrint('Error parsing cover URL: $e');
      }
      return null;
    }

    List<String> parseScreenshots() {
      try {
        return (json['screenshots'] as List<dynamic>?)
            ?.where((s) => s['url'] != null)
            .map((s) => 'https://images.igdb.com/igdb/image/upload/t_screenshot_big/${(s['url'] as String).split('/').last}')
            .toList() ?? [];
      } catch (e) {
        debugPrint('Error parsing screenshots: $e');
        return [];
      }
    }

    List<String> parseGenres() {
      try {
        return (json['genres'] as List<dynamic>?)
            ?.map((g) => g['name'] as String)
            .toList() ?? [];
      } catch (e) {
        debugPrint('Error parsing genres: $e');
        return [];
      }
    }

    List<String> parseGameModes() {
      try {
        return (json['game_modes'] as List<dynamic>?)
            ?.map((m) => m['name'] as String)
            .toList() ?? [];
      } catch (e) {
        debugPrint('Error parsing game modes: $e');
        return [];
      }
    }

    return IGDBGame(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Game',
      summary: json['summary'] as String?,
      coverUrl: parseCoverUrl(),
      screenshots: parseScreenshots(),
      genres: parseGenres(),
      gameModes: parseGameModes(),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      releaseDate: parseReleaseDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'summary': summary,
      'coverUrl': coverUrl,
      'screenshots': screenshots,
      'genres': genres,
      'gameModes': gameModes,
      'rating': rating,
      'releaseDate': releaseDate?.toIso8601String(),
    };
  }
}
