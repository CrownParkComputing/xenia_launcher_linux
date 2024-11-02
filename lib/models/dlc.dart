class DLC {
  final String name;
  final String path;
  final DateTime dateAdded;

  DLC({
    required this.name,
    required this.path,
    DateTime? dateAdded,
  }) : dateAdded = dateAdded ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory DLC.fromJson(Map<String, dynamic> json) {
    return DLC(
      name: json['name'] as String,
      path: json['path'] as String,
      dateAdded: json['dateAdded'] != null 
        ? DateTime.parse(json['dateAdded'] as String)
        : null,
    );
  }

  static String cleanDLCName(String zipName) {
    // Remove file extension
    var name = zipName.replaceAll(RegExp(r'\.zip$', caseSensitive: false), '');
    
    // Remove anything in parentheses
    name = name.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
    
    // Remove special characters and multiple spaces
    name = name.replaceAll(RegExp(r'[^\w\s-]'), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ');
    
    // Trim whitespace
    name = name.trim();
    
    return name;
  }
}
