class ZArchiveEntry {
  final String name;
  final bool isFile;
  final int size;
  final int offset;

  ZArchiveEntry({
    required this.name,
    required this.isFile,
    required this.size,
    required this.offset,
  });

  @override
  String toString() {
    return 'ZArchiveEntry{name: $name, isFile: $isFile, size: $size, offset: $offset}';
  }
}
