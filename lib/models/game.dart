import 'dlc.dart';
import 'achievement.dart';

enum GameType { iso, live }

class Game {
  final int? id;
  final String title;
  final String? searchTitle;
  final String path;
  final String? coverPath;
  final DateTime dateAdded;
  final String? lastUsedExecutable;
  final GameType type;
  final String? executablePath;
  final List<DLC> dlc;
  final DateTime? lastPlayed;
  final Duration totalPlayTime;
  final List<Achievement> achievements;
  final int? igdbId;
  final String? summary;
  final double? rating;
  final DateTime? releaseDate;
  final List<String>? genres;
  final List<String>? gameModes;
  final List<String>? screenshots;
  final String? coverUrl;
  final String? localCoverPath;
  final String? gameFilePath;
  final bool isIsoGame;

  Game({
    this.id,
    required this.title,
    this.searchTitle,
    required this.path,
    this.coverPath,
    this.lastUsedExecutable,
    DateTime? dateAdded,
    this.type = GameType.iso,
    this.executablePath,
    List<DLC>? dlc,
    this.lastPlayed,
    Duration? totalPlayTime,
    List<Achievement>? achievements,
    this.igdbId,
    this.summary,
    this.rating,
    this.releaseDate,
    this.genres,
    this.gameModes,
    this.screenshots,
    this.coverUrl,
    this.localCoverPath,
    this.gameFilePath,
    bool? isIsoGame,
  })  : dateAdded = dateAdded ?? DateTime.now(),
        dlc = dlc ?? const [],
        totalPlayTime = totalPlayTime ?? Duration.zero,
        achievements = achievements ?? const [],
        isIsoGame = isIsoGame ?? (type == GameType.iso);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'searchTitle': searchTitle,
      'path': path,
      'coverPath': coverPath,
      'lastUsedExecutable': lastUsedExecutable,
      'dateAdded': dateAdded.toIso8601String(),
      'type': type.name,
      'executablePath': executablePath,
      'dlc': dlc.map((d) => d.toJson()).toList(),
      'lastPlayed': lastPlayed?.toIso8601String(),
      'totalPlayTime': totalPlayTime.inSeconds,
      'achievements': achievements.map((a) => a.toJson()).toList(),
      'igdbId': igdbId,
      'summary': summary,
      'rating': rating,
      'releaseDate': releaseDate?.toIso8601String(),
      'genres': genres,
      'gameModes': gameModes,
      'screenshots': screenshots,
      'coverUrl': coverUrl,
      'localCoverPath': localCoverPath,
      'gameFilePath': gameFilePath,
      'isIsoGame': isIsoGame,
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'],
      title: json['title'] as String? ?? 'Unknown Game',
      searchTitle: json['searchTitle'] as String?,
      path: json['path'] as String? ?? '',
      coverPath: json['coverPath'] as String?,
      lastUsedExecutable: json['lastUsedExecutable'] as String?,
      dateAdded: json['dateAdded'] != null
          ? DateTime.parse(json['dateAdded'] as String)
          : null,
      type: GameType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'iso'),
        orElse: () => GameType.iso,
      ),
      executablePath: json['executablePath'] as String?,
      dlc: (json['dlc'] as List<dynamic>?)
              ?.map((d) => DLC.fromJson(d as Map<String, dynamic>))
              .toList() ??
          const [],
      lastPlayed: json['lastPlayed'] != null
          ? DateTime.parse(json['lastPlayed'] as String)
          : null,
      totalPlayTime: json['totalPlayTime'] != null
          ? Duration(seconds: json['totalPlayTime'] as int)
          : Duration.zero,
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((a) => Achievement.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [],
      igdbId: json['igdbId'] as int?,
      summary: json['summary'] as String?,
      rating: json['rating'] as double?,
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : null,
      genres: (json['genres'] as List<dynamic>?)?.cast<String>(),
      gameModes: (json['gameModes'] as List<dynamic>?)?.cast<String>(),
      screenshots: (json['screenshots'] as List<dynamic>?)?.cast<String>(),
      coverUrl: json['coverUrl'] as String?,
      localCoverPath: json['localCoverPath'] as String?,
      gameFilePath: json['gameFilePath'] as String?,
      isIsoGame: json['isIsoGame'] as bool? ?? true,
    );
  }

  Game copyWith({
    int? id,
    String? title,
    String? searchTitle,
    String? path,
    String? coverPath,
    String? lastUsedExecutable,
    DateTime? dateAdded,
    GameType? type,
    String? executablePath,
    List<DLC>? dlc,
    DateTime? lastPlayed,
    Duration? totalPlayTime,
    List<Achievement>? achievements,
    int? igdbId,
    String? summary,
    double? rating,
    DateTime? releaseDate,
    List<String>? genres,
    List<String>? gameModes,
    List<String>? screenshots,
    String? coverUrl,
    String? localCoverPath,
    String? gameFilePath,
    bool? isIsoGame,
  }) {
    return Game(
      id: id ?? this.id,
      title: title ?? this.title,
      searchTitle: searchTitle ?? this.searchTitle,
      path: path ?? this.path,
      coverPath: coverPath ?? this.coverPath,
      lastUsedExecutable: lastUsedExecutable ?? this.lastUsedExecutable,
      dateAdded: dateAdded ?? this.dateAdded,
      type: type ?? this.type,
      executablePath: executablePath ?? this.executablePath,
      dlc: dlc ?? List.from(this.dlc),
      lastPlayed: lastPlayed ?? this.lastPlayed,
      totalPlayTime: totalPlayTime ?? this.totalPlayTime,
      achievements: achievements ?? List.from(this.achievements),
      igdbId: igdbId ?? this.igdbId,
      summary: summary ?? this.summary,
      rating: rating ?? this.rating,
      releaseDate: releaseDate ?? this.releaseDate,
      genres: genres ?? this.genres,
      gameModes: gameModes ?? this.gameModes,
      screenshots: screenshots ?? this.screenshots,
      coverUrl: coverUrl ?? this.coverUrl,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      gameFilePath: gameFilePath ?? this.gameFilePath,
      isIsoGame: isIsoGame ?? this.isIsoGame,
    );
  }

  static String cleanGameTitle(String zipName) {
    var title = zipName.replaceAll(RegExp(r'\.(iso|zar|zip)$', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    title = title.replaceAll(RegExp(r'[^\w\s-]'), '');
    title = title.replaceAll(RegExp(r'\s+'), ' ');
    return title.trim();
  }

  bool get isLiveGame => type == GameType.live;
  bool get hasDLC => dlc.isNotEmpty;
  String get displayPath => isLiveGame ? executablePath ?? path : path;
  String get effectiveSearchTitle => searchTitle ?? title;
}
