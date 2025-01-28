import 'package:flutter/foundation.dart';

class IGDBGame {
  final int id;
  final String name;
  final String? summary;
  final String? storyline;
  final String? coverUrl;
  String? localCoverPath;
  final List<String> screenshots;
  final List<String> genres;
  final List<String> gameModes;
  final List<String> themes;
  final List<String> platforms;
  final List<String> gameEngines;
  final List<String> playerPerspectives;
  final List<String> companies;
  final double? rating;
  final double? aggregatedRating;
  final int? aggregatedRatingCount;
  final double? totalRating;
  final int? totalRatingCount;
  final DateTime? releaseDate;
  final String? status;
  final int? category;
  final String? versionTitle;
  final Map<String, DateTime>? releaseDates;

  IGDBGame({
    required this.id,
    required this.name,
    this.summary,
    this.storyline,
    this.coverUrl,
    this.localCoverPath,
    this.screenshots = const [],
    this.genres = const [],
    this.gameModes = const [],
    this.themes = const [],
    this.platforms = const [],
    this.gameEngines = const [],
    this.playerPerspectives = const [],
    this.companies = const [],
    this.rating,
    this.aggregatedRating,
    this.aggregatedRatingCount,
    this.totalRating,
    this.totalRatingCount,
    this.releaseDate,
    this.status,
    this.category,
    this.versionTitle,
    this.releaseDates,
  });

  factory IGDBGame.fromJson(Map<String, dynamic> json) {
    Map<String, DateTime>? parseReleaseDates() {
      try {
        if (json['release_dates'] == null) return null;
        final dates = json['release_dates'] as List<dynamic>;
        final Map<String, DateTime> result = {};
        
        for (final date in dates) {
          if (date['platform'] != null && date['date'] != null) {
            final platformId = date['platform'] as int;
            final timestamp = date['date'] as int;
            result[platformId.toString()] = 
                DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          }
        }
        return result.isNotEmpty ? result : null;
      } catch (e) {
        debugPrint('Error parsing release dates: $e');
        return null;
      }
    }

    DateTime? parseReleaseDate() {
      try {
        // First try first_release_date
        if (json['first_release_date'] != null) {
          final timestamp = json['first_release_date'] as int;
          return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
        
        // Then try release_dates array
        if (json['release_dates'] != null && 
            (json['release_dates'] as List).isNotEmpty) {
          final dates = json['release_dates'] as List;
          for (final date in dates) {
            if (date['date'] != null) {
              final timestamp = date['date'] as int;
              return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            }
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
          var url = json['cover']['url'] as String;
          if (url.startsWith('//')) {
            url = 'https:$url';
          }
          // Add t_cover_big if not present
          if (!url.contains('t_cover_big')) {
            url = url.replaceAll(RegExp(r't_\w+'), 't_cover_big');
          }
          debugPrint('Parsed cover URL: $url');
          return url;
        }
      } catch (e) {
        debugPrint('Error parsing cover URL: $e');
      }
      return null;
    }

    List<String> parseScreenshots() {
      try {
        if (json['screenshots'] == null) return [];
        final screenshots = json['screenshots'] as List<dynamic>;
        return screenshots
            .map((s) {
              if (s is! Map) return null;
              if (!s.containsKey('url')) return null;
              final url = s['url'] as String?;
              if (url == null) return null;
              
              var processedUrl = url;
              if (processedUrl.startsWith('//')) {
                processedUrl = 'https:$processedUrl';
              }
              if (!processedUrl.contains('t_screenshot_big')) {
                processedUrl = processedUrl.replaceAll(RegExp(r't_\w+'), 't_screenshot_big');
              }
              debugPrint('Parsed screenshot URL: $processedUrl');
              return processedUrl;
            })
            .where((url) => url != null)
            .cast<String>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing screenshots: $e');
        return [];
      }
    }

    List<String> parseGenres() {
      try {
        if (json['genres'] == null) return [];
        final genres = json['genres'] as List<dynamic>;
        return genres
            .map((g) {
              if (g is! Map) return null;
              if (!g.containsKey('name')) return null;
              return g['name'] as String?;
            })
            .where((name) => name != null)
            .cast<String>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing genres: $e');
        return [];
      }
    }

    List<String> parseGameModes() {
      try {
        if (json['game_modes'] == null) return [];
        final modes = json['game_modes'] as List<dynamic>;
        return modes
            .map((m) {
              if (m is! Map) return null;
              if (!m.containsKey('name')) return null;
              return m['name'] as String?;
            })
            .where((name) => name != null)
            .cast<String>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing game modes: $e');
        return [];
      }
    }

    List<String> parsePlatforms() {
      try {
        if (json['platforms'] == null) return [];
        final platforms = json['platforms'] as List<dynamic>;
        return platforms
            .map((p) {
              if (p is! Map) return null;
              if (!p.containsKey('name')) return null;
              return p['name'] as String?;
            })
            .where((name) => name != null)
            .cast<String>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing platforms: $e');
        return [];
      }
    }

    List<String> parseThemes() {
      try {
        if (json['themes'] == null) return [];
        final themes = json['themes'] as List<dynamic>;
        return themes
            .map((t) {
              if (t is! Map) return null;
              if (!t.containsKey('name')) return null;
              return t['name'] as String?;
            })
            .where((name) => name != null)
            .cast<String>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing themes: $e');
        return [];
      }
    }

    List<String> parseGameEngines() {
      try {
        if (json['game_engines'] == null) return [];
        final engines = json['game_engines'] as List<dynamic>;
        return engines
            .map((e) {
              if (e is! Map) return null;
              if (!e.containsKey('name')) return null;
              return e['name'] as String?;
            })
            .where((name) => name != null)
            .cast<String>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing game engines: $e');
        return [];
      }
    }

    List<String> parsePlayerPerspectives() {
      try {
        if (json['player_perspectives'] == null) return [];
        final perspectives = json['player_perspectives'] as List<dynamic>;
        return perspectives
            .map((p) {
              if (p is! Map) return null;
              if (!p.containsKey('name')) return null;
              return p['name'] as String?;
            })
            .where((name) => name != null)
            .cast<String>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing player perspectives: $e');
        return [];
      }
    }

    List<String> parseCompanies() {
      try {
        if (json['involved_companies'] == null) return [];
        final companies = json['involved_companies'] as List<dynamic>;
        return companies
            .map((c) {
              if (c is! Map || !c.containsKey('company')) return null;
              final company = c['company'] as Map<String, dynamic>;
              if (!company.containsKey('name')) return null;
              return company['name'] as String?;
            })
            .where((name) => name != null)
            .cast<String>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing companies: $e');
        return [];
      }
    }

    final coverUrl = parseCoverUrl();
    debugPrint('Creating IGDBGame with coverUrl: $coverUrl');

    return IGDBGame(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown Game',
      summary: json['summary'] as String?,
      storyline: json['storyline'] as String?,
      coverUrl: coverUrl,
      localCoverPath: json['localCoverPath'] as String?,
      screenshots: parseScreenshots(),
      genres: parseGenres(),
      gameModes: parseGameModes(),
      themes: parseThemes(),
      platforms: parsePlatforms(),
      gameEngines: parseGameEngines(),
      playerPerspectives: parsePlayerPerspectives(),
      companies: parseCompanies(),
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      aggregatedRating: json['aggregated_rating'] != null ? (json['aggregated_rating'] as num).toDouble() : null,
      aggregatedRatingCount: json['aggregated_rating_count'] as int?,
      totalRating: json['total_rating'] != null ? (json['total_rating'] as num).toDouble() : null,
      totalRatingCount: json['total_rating_count'] as int?,
      releaseDate: parseReleaseDate(),
      status: json['status'] as String?,
      category: json['category'] as int?,
      versionTitle: json['version_title'] as String?,
      releaseDates: parseReleaseDates(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'summary': summary,
      'storyline': storyline,
      'coverUrl': coverUrl,
      'localCoverPath': localCoverPath,
      'screenshots': screenshots,
      'genres': genres,
      'gameModes': gameModes,
      'themes': themes,
      'platforms': platforms,
      'gameEngines': gameEngines,
      'playerPerspectives': playerPerspectives,
      'companies': companies,
      'rating': rating,
      'aggregatedRating': aggregatedRating,
      'aggregatedRatingCount': aggregatedRatingCount,
      'totalRating': totalRating,
      'totalRatingCount': totalRatingCount,
      'releaseDate': releaseDate?.toIso8601String(),
      'status': status,
      'category': category,
      'versionTitle': versionTitle,
      'releaseDates': releaseDates?.map((k, v) => MapEntry(k, v.toIso8601String())),
    };
  }

  String? getEffectiveCoverPath() {
    return localCoverPath ?? coverUrl;
  }
}
