class IGDBGame {
  final int id;
  final String name;
  final String? summary;
  final List<String> screenshots;
  final List<String> genres;
  final List<String> gameModes;
  final String? coverUrl;
  final double? rating;
  final DateTime? releaseDate;

  IGDBGame({
    required this.id,
    required this.name,
    this.summary,
    required this.screenshots,
    required this.genres,
    required this.gameModes,
    this.coverUrl,
    this.rating,
    this.releaseDate,
  });

  factory IGDBGame.fromJson(Map<String, dynamic> json) {
    return IGDBGame(
      id: json['id'],
      name: json['name'],
      summary: json['summary'],
      screenshots: (json['screenshots'] as List?)
          ?.map((screenshot) => 'https:${screenshot['url'].toString().replaceAll('t_thumb', 't_screenshot_huge')}')
          .toList()
          .cast<String>() ??
          [],
      genres: (json['genres'] as List?)
          ?.map((genre) => genre['name'].toString())
          .toList()
          .cast<String>() ??
          [],
      gameModes: (json['game_modes'] as List?)
          ?.map((mode) => mode['name'].toString())
          .toList()
          .cast<String>() ??
          [],
      coverUrl: json['cover'] != null 
          ? 'https:${json['cover']['url'].toString().replaceAll('t_thumb', 't_cover_big')}'
          : null,
      rating: json['rating']?.toDouble(),
      releaseDate: json['release_dates'] != null && (json['release_dates'] as List).isNotEmpty
          ? DateTime.fromMillisecondsSinceEpoch(json['release_dates'][0]['date'] * 1000)
          : null,
    );
  }
}
