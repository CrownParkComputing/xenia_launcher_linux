import 'dlc.dart';
import 'achievement.dart';

enum GameType { iso, live }

class Game {
  final int? id;
  final String title;
  final String? searchTitle;  // New field for IGDB search
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
  final int? igdbId;  // Added IGDB ID field

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
    this.igdbId,  // Added to constructor
  })  : dateAdded = dateAdded ?? DateTime.now(),
        dlc = dlc ?? [],
        totalPlayTime = totalPlayTime ?? Duration.zero,
        achievements = achievements ?? [];

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
      'igdbId': igdbId,  // Added to JSON serialization
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
          [],
      lastPlayed: json['lastPlayed'] != null
          ? DateTime.parse(json['lastPlayed'] as String)
          : null,
      totalPlayTime: json['totalPlayTime'] != null
          ? Duration(seconds: json['totalPlayTime'] as int)
          : null,
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((a) => Achievement.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      igdbId: json['igdbId'] as int?,  // Added to JSON deserialization
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
    int? igdbId,  // Added to copyWith
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
      igdbId: igdbId ?? this.igdbId,  // Added to copyWith
    );
  }

  static String cleanGameTitle(String zipName) {
    // Remove file extension
    var title = zipName.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');

    // Remove anything in parentheses
    title = title.replaceAll(RegExp(r'\s*\([^)]*\)'), '');

    // Remove special characters and multiple spaces
    title = title.replaceAll(RegExp(r'[^\w\s-]'), '');
    title = title.replaceAll(RegExp(r'\s+'), ' ');

    // Trim whitespace
    title = title.trim();

    return title;
  }

  bool get isLiveGame => type == GameType.live;
  bool get isIsoGame => type == GameType.iso;
  bool get hasDLC => dlc.isNotEmpty;

  String get displayPath => isLiveGame ? executablePath ?? path : path;
  
  // Use searchTitle if available, otherwise use title
  String get effectiveSearchTitle => searchTitle ?? title;
}
