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
  String? xeniaCanaryPath;
  GameCardSize cardSize;

  Config({
    this.baseFolder,
    this.winePrefix,
    this.isoFolder,
    this.liveGamesFolder,
    this.xeniaCanaryPath,
    this.cardSize = GameCardSize.medium,
  });

  Map<String, dynamic> toJson() => {
        'baseFolder': baseFolder,
        'winePrefix': winePrefix,
        'isoFolder': isoFolder,
        'liveGamesFolder': liveGamesFolder,
        'xeniaCanaryPath': xeniaCanaryPath,
        'cardSize': cardSize.index,
      };

  factory Config.fromJson(Map<String, dynamic> json) => Config(
        baseFolder: json['baseFolder'] as String?,
        winePrefix: json['winePrefix'] as String?,
        isoFolder: json['isoFolder'] as String?,
        liveGamesFolder: json['liveGamesFolder'] as String?,
        xeniaCanaryPath: json['xeniaCanaryPath'] as String?,
        cardSize: GameCardSize.values[json['cardSize'] as int? ?? 1],
      );
}
