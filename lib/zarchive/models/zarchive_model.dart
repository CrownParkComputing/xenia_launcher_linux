import 'dart:typed_data';

class ZArchiveEntry {
  final String name;
  final bool isFile;
  final int size;
  final int offset;
  final DateTime? modifiedTime;
  final String? comment;

  ZArchiveEntry({
    required this.name,
    required this.isFile,
    required this.size,
    this.offset = 0,
    this.modifiedTime,
    this.comment,
  });

  bool get isDirectory => !isFile;

  String get basename {
    final parts = name.split('/');
    return parts.isEmpty ? '' : parts.last;
  }

  String get dirname {
    final parts = name.split('/');
    parts.removeLast();
    return parts.join('/');
  }

  @override
  String toString() => 'ZArchiveEntry(name: $name, size: $size, offset: $offset)';
}

class ZArchiveDirectory {
  final String name;
  final List<ZArchiveEntry> entries;
  final Map<String, ZArchiveDirectory> subdirectories;

  ZArchiveDirectory({
    required this.name,
    List<ZArchiveEntry>? entries,
    Map<String, ZArchiveDirectory>? subdirectories,
  })  : entries = entries ?? [],
        subdirectories = subdirectories ?? {};

  void addEntry(ZArchiveEntry entry) {
    if (entry.isDirectory) {
      // Create subdirectories as needed
      final parts = entry.name.split('/')
        ..removeWhere((part) => part.isEmpty);
      
      var currentDir = this;
      var currentPath = '';
      
      for (final part in parts) {
        currentPath += '/$part';
        currentDir.subdirectories.putIfAbsent(
          currentPath,
          () => ZArchiveDirectory(name: part),
        );
        currentDir = currentDir.subdirectories[currentPath]!;
      }
    } else {
      entries.add(entry);
      
      // Add to appropriate subdirectory
      if (entry.dirname.isNotEmpty) {
        final dirParts = entry.dirname.split('/')
          ..removeWhere((part) => part.isEmpty);
        
        var currentDir = this;
        var currentPath = '';
        
        for (final part in dirParts) {
          currentPath += '/$part';
          currentDir.subdirectories.putIfAbsent(
            currentPath,
            () => ZArchiveDirectory(name: part),
          );
          currentDir = currentDir.subdirectories[currentPath]!;
        }
        
        currentDir.entries.add(entry);
      }
    }
  }

  List<ZArchiveEntry> getAllEntries() {
    final result = <ZArchiveEntry>[];
    result.addAll(entries);
    for (final subdir in subdirectories.values) {
      result.addAll(subdir.getAllEntries());
    }
    return result;
  }

  ZArchiveDirectory? findDirectory(String path) {
    if (path.isEmpty || path == '/') return this;
    
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return subdirectories[normalizedPath];
  }

  @override
  String toString() => 'ZArchiveDirectory(name: $name, entries: ${entries.length}, subdirs: ${subdirectories.length})';
}
