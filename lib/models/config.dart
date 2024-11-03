enum GameCardSize {
  small,
  medium,
  large,
}

class Config {
  String? baseFolder;
  String? winePrefix;
  String? isoFolder;
  String? liveGamesFolder;
  List<String> xeniaExecutables;
  Map<String, String> xeniaVersions; // Map executable path to its version
  GameCardSize cardSize;

  Config({
    this.baseFolder,
    this.winePrefix,
    this.isoFolder,
    this.liveGamesFolder,
    this.xeniaExecutables = const [],
    this.xeniaVersions = const {},
    this.cardSize = GameCardSize.medium,
  });

  Map<String, dynamic> toJson() => {
    'baseFolder': baseFolder,
    'winePrefix': winePrefix,
    'isoFolder': isoFolder,
    'liveGamesFolder': liveGamesFolder,
    'xeniaExecutables': xeniaExecutables,
    'xeniaVersions': xeniaVersions,
    'cardSize': cardSize.index,
  };

  factory Config.fromJson(Map<String, dynamic> json) => Config(
    baseFolder: json['baseFolder'] as String?,
    winePrefix: json['winePrefix'] as String?,
    isoFolder: json['isoFolder'] as String?,
    liveGamesFolder: json['liveGamesFolder'] as String?,
    xeniaExecutables: (json['xeniaExecutables'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? [],
    xeniaVersions: (json['xeniaVersions'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as String)) ?? {},
    cardSize: GameCardSize.values[json['cardSize'] as int? ?? 1],
  );
}
