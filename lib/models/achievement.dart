class Achievement {
  final String id;
  final String title;
  final String description;
  final int gamerscore;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.gamerscore,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'gamerscore': gamerscore,
    };
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      gamerscore: json['gamerscore'] as int,
    );
  }

  factory Achievement.fromLogLine(String id, String title, String description, String gamerscore) {
    // Handle empty or invalid gamerscore values
    int score = 0;
    try {
      final cleanScore = gamerscore.trim().replaceAll(RegExp(r'[^\d]'), '');
      if (cleanScore.isNotEmpty) {
        score = int.parse(cleanScore);
      }
    } catch (e) {
      print('Error parsing gamerscore: $e');
    }

    return Achievement(
      id: id.trim(),
      title: title.trim(),
      description: description.trim(),
      gamerscore: score,
    );
  }
}
