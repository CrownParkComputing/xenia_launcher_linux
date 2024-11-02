import 'dlc.dart';

enum GameType {
  iso,
  live
}

class Game {
  final int? id;
  final String title;
  final String path;
  final String? coverPath;
  final DateTime dateAdded;
  final String? lastUsedExecutable;
  final GameType type;
  final String? executablePath;
  final List<DLC> dlc;

  Game({
    this.id,
    required this.title,
    required this.path,
    this.coverPath,
    this.lastUsedExecutable,
    DateTime? dateAdded,
    this.type = GameType.iso,
    this.executablePath,
    List<DLC>? dlc,
  }) : dateAdded = dateAdded ?? DateTime.now(),
       dlc = dlc ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'path': path,
      'coverPath': coverPath,
      'lastUsedExecutable': lastUsedExecutable,
      'dateAdded': dateAdded.toIso8601String(),
      'type': type.name,
      'executablePath': executablePath,
      'dlc': dlc.map((d) => d.toJson()).toList(),
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'],
      title: json['title'] as String? ?? 'Unknown Game',
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
          .toList() ?? [],
    );
  }

  Game copyWith({
    int? id,
    String? title,
    String? path,
    String? coverPath,
    String? lastUsedExecutable,
    DateTime? dateAdded,
    GameType? type,
    String? executablePath,
    List<DLC>? dlc,
  }) {
    return Game(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      coverPath: coverPath ?? this.coverPath,
      lastUsedExecutable: lastUsedExecutable ?? this.lastUsedExecutable,
      dateAdded: dateAdded ?? this.dateAdded,
      type: type ?? this.type,
      executablePath: executablePath ?? this.executablePath,
      dlc: dlc ?? List.from(this.dlc),
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
}
