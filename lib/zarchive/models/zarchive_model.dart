import 'dart:typed_data';

// lib/zarchive/models/zarchive_model.dart

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
}
