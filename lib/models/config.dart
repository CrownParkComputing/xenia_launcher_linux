class XeniaConfig {
  String? baseFolder;
  String? winePrefix;
  String? isoFolder;
  String? liveGamesFolder;
  List<String> xeniaExecutables;
  
  XeniaConfig({
    this.baseFolder,
    this.winePrefix,
    this.isoFolder,
    this.liveGamesFolder,
    this.xeniaExecutables = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'baseFolder': baseFolder,
      'winePrefix': winePrefix,
      'isoFolder': isoFolder,
      'liveGamesFolder': liveGamesFolder,
      'xeniaExecutables': xeniaExecutables,
    };
  }

  factory XeniaConfig.fromJson(Map<String, dynamic> json) {
    return XeniaConfig(
      baseFolder: json['baseFolder'],
      winePrefix: json['winePrefix'],
      isoFolder: json['isoFolder'],
      liveGamesFolder: json['liveGamesFolder'],
      xeniaExecutables: List<String>.from(json['xeniaExecutables'] ?? []),
    );
  }
}
