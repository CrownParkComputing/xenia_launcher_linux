import 'dart:io';
import 'dart:typed_data';
import 'dart:math' show min;
import 'package:path/path.dart' as path;

class XisoService {
  static const _readWriteBuffer = 0x200000;
  static const _defaultEncoding = 'windows-1252';

  // Base offset values for different Xbox disc formats
  static const _baseOffsets = {
    'GamePartition': 0,
    'XGD3': 0x4100,
    'XGD2': 0x1fb20,
    'XGD1': 0x30600,
  };

  // Event callbacks
  Function(String)? onOperation;
  Function(String)? onStatus;
  Function(double)? onTotalProgress;
  Function(double)? onIsoProgress;
  Function(double, int)? onFileProgress;

  bool _abort = false;
  int? _baseOffset;

  Future<bool> verifyXiso(String filename) async {
    onOperation?.call('Verifying XISO: $filename');
    
    final file = await File(filename).open();
    int? validBaseOffset;

    try {
      for (var entry in _baseOffsets.entries) {
        if (await _checkMediaString(file, entry.value)) {
          validBaseOffset = entry.value;
          onStatus?.call('${entry.key} Image detected!');
          break;
        }
      }

      if (validBaseOffset == null) {
        onStatus?.call('Invalid XISO Image!');
        return false;
      }

      return true;
    } finally {
      await file.close();
    }
  }

  Future<bool> _checkMediaString(RandomAccessFile file, int baseOffset) async {
    try {
      final position = (baseOffset + 32) * 2048;
      onStatus?.call('Checking for Xbox media string at offset 0x${position.toRadixString(16)}');
      await file.setPosition(position);
      final data = await file.read(0x14);
      final mediaString = String.fromCharCodes(data);
      onStatus?.call('Found string: "$mediaString"');
      onStatus?.call('Raw bytes: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      return mediaString == 'MICROSOFT*XBOX*MEDIA';
    } catch (e) {
      onStatus?.call('Error checking media string: $e');
      return false;
    }
  }

  Future<void> _parseTOC(RandomAccessFile file, XisoListAndSize result, int offset, int level, int tocOffset, {String dirPrefix = '\\'}) async {
    if (_abort) return;

    // Read left/right pointers and sector
    await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset);
    final leftBytes = await file.read(2);
    final left = _bytesToUInt16(leftBytes, littleEndian: true);
    
    final rightBytes = await file.read(2);
    final right = _bytesToUInt16(rightBytes, littleEndian: true);

    // Read sector number (big endian)
    await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset + 4);
    final sectorBytes = await file.read(4);
    final sector = _bytesToUInt32(sectorBytes, littleEndian: false);
    
    if (sector == 0xFFFFFFFF) return; // End marker

    // Process left branch first
    if (left != 0) {
      await _parseTOC(file, result, left * 4, level, tocOffset, dirPrefix: dirPrefix);
    }

    // Read attributes and determine if directory
    await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset + 0xC);
    final attributes = await file.read(1);
    final isDirectory = (attributes[0] & 0x10) == 0x10;

    if (isDirectory) {
      // Directory entry
      await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset + 0xD);
      final dirNameLenBytes = await file.read(1);
      final dirNameLen = dirNameLenBytes[0];
      
      await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset + 0xE);
      final dirNameBytes = await file.read(dirNameLen);
      final dirName = String.fromCharCodes(dirNameBytes);

      // Read directory sector
      await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset + 4);
      final dirSectorBytes = await file.read(4);
      final dirSector = _bytesToUInt32(dirSectorBytes, littleEndian: true);

      onStatus?.call('Found directory: $dirPrefix$dirName\\');
      
      result.list.add(XisoTableData(
        isFile: false,
        name: dirName,
        path: dirPrefix,
        offset: 0,
        size: 0
      ));
      result.folders++;

      // Parse subdirectory if it has contents
      if (dirSector != 0) {
        await _parseTOC(file, result, 0, level + 1, dirSector, dirPrefix: '$dirPrefix$dirName\\');
      }
    } else {
      // File entry
      await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset + 0xD);
      final fileNameLenBytes = await file.read(1);
      final fileNameLen = fileNameLenBytes[0];
      
      await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset + 0xE);
      final fileNameBytes = await file.read(fileNameLen);
      final fileName = String.fromCharCodes(fileNameBytes);

      // Read file sector and size
      await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset + 4);
      final fileSectorBytes = await file.read(4);
      final fileSector = _bytesToUInt32(fileSectorBytes, littleEndian: true);
      
      await file.setPosition(((_baseOffset! + tocOffset) * 2048) + offset + 8);
      final sizeBytes = await file.read(4);
      final size = _bytesToUInt32(sizeBytes, littleEndian: true);

      onStatus?.call('Found file: $dirPrefix$fileName (${_getSizeReadable(size)})');
      
      result.list.add(XisoTableData(
        isFile: true,
        name: fileName,
        path: dirPrefix,
        offset: (fileSector + _baseOffset!) * 0x800,
        size: size
      ));
      result.files++;
      result.size += size;
    }

    // Process right branch last
    if (right != 0) {
      await _parseTOC(file, result, right * 4, level, tocOffset, dirPrefix: dirPrefix);
    }
  }

  Future<XisoListAndSize> getFileListAndSize(String source, {bool excludeSysUpdate = true}) async {
    _abort = false;
    final result = XisoListAndSize();
    
    onStatus?.call('Opening ISO file: $source');
    final file = await File(source).open();
    
    try {
      // First find the correct base offset
      onStatus?.call('Checking ISO format...');
      _baseOffset = null;
      for (var entry in _baseOffsets.entries) {
        onStatus?.call('Trying offset ${entry.key}: 0x${entry.value.toRadixString(16)}');
        if (await _checkMediaString(file, entry.value)) {
          _baseOffset = entry.value;
          onStatus?.call('Found valid format: ${entry.key} at offset 0x${entry.value.toRadixString(16)}');
          break;
        }
      }

      if (_baseOffset == null) {
        onStatus?.call('Error: No valid Xbox ISO format detected');
        return result;
      }

      // Get root directory info
      final rootInfoPos = (_baseOffset! + 32) * 2048 + 0x14;
      onStatus?.call('Reading root info at offset 0x${rootInfoPos.toRadixString(16)}');
      
      await file.setPosition(rootInfoPos);
      final rootData = await file.read(8);
      onStatus?.call('Root data bytes: ${rootData.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      
      final rootSector = _bytesToUInt32(rootData.sublist(0, 4), littleEndian: true);
      final rootSize = _bytesToUInt32(rootData.sublist(4, 8), littleEndian: true);

      onStatus?.call('Root directory found:');
      onStatus?.call('- Sector: 0x${rootSector.toRadixString(16)}');
      onStatus?.call('- Size: 0x${rootSize.toRadixString(16)} bytes');

      // Parse the TOC starting from root
      await _parseTOC(file, result, 0, 0, rootSector);

      // Filter out system update files if requested
      if (excludeSysUpdate) {
        result.list = result.list.where((entry) {
          final isSystemUpdate = entry.name.toLowerCase() == 'update.xbe' ||
                               entry.path.toLowerCase().contains('\$systemupdate');
          if (isSystemUpdate) {
            if (entry.isFile) {
              result.files--;
              result.size -= entry.size;
            } else {
              result.folders--;
            }
          }
          return !isSystemUpdate;
        }).toList();
      }

      onStatus?.call('Parsing complete!');
      onStatus?.call('- Total files: ${result.files}');
      onStatus?.call('- Total folders: ${result.folders}');
      onStatus?.call('- Total size: ${_getSizeReadable(result.size)}');

      return result;
    } catch (e, stackTrace) {
      onStatus?.call('Error parsing ISO: $e');
      onStatus?.call('Stack trace: $stackTrace');
      return result;
    } finally {
      await file.close();
    }
  }

  Future<bool> extractXiso(String source, String target, {bool excludeSysUpdate = true}) async {
    try {
      onOperation?.call('Starting extraction...');
      final result = await getFileListAndSize(source, excludeSysUpdate: excludeSysUpdate);
      if (result.list.isEmpty) {
        onStatus?.call('No files found to extract');
        return false;
      }

      onStatus?.call('Extracting files to $target');
      onOperation?.call('Extracting files to $target');

      // Create base directory
      await Directory(target).create(recursive: true);

      // Open source file
      final sourceFile = await File(source).open();
      try {
        // First create all directories
        for (final entry in result.list.where((e) => !e.isFile)) {
          // Remove leading backslash and convert to forward slashes
          final relativePath = entry.path.replaceFirst(RegExp(r'^\\'), '')
                                       .replaceAll('\\', '/');
          final dirPath = path.join(target, relativePath, entry.name);
          onStatus?.call('Creating directory: $dirPath');
          await Directory(dirPath).create(recursive: true);
        }

        // Then extract all files
        var totalProcessed = 0;
        for (final entry in result.list.where((e) => e.isFile)) {
          if (_abort) {
            onStatus?.call('Extraction aborted by user');
            return false;
          }

          // Remove leading backslash and convert to forward slashes
          final relativePath = entry.path.replaceFirst(RegExp(r'^\\'), '')
                                       .replaceAll('\\', '/');
          final filePath = path.join(target, relativePath, entry.name);
          onStatus?.call('Extracting ${relativePath}${entry.name} (${_getSizeReadable(entry.size)})');

          // Create parent directory if it doesn't exist
          await Directory(path.dirname(filePath)).create(recursive: true);

          // Extract the file
          final targetFile = await File(filePath).open(mode: FileMode.writeOnly);
          try {
            await sourceFile.setPosition(entry.offset);
            var remaining = entry.size;
            var processed = 0;

            while (remaining > 0) {
              if (_abort) {
                onStatus?.call('Extraction aborted by user');
                return false;
              }

              final readSize = min(_readWriteBuffer, remaining);
              final buffer = await sourceFile.read(readSize);
              await targetFile.writeFrom(buffer);

              processed += readSize;
              totalProcessed += readSize;
              remaining -= readSize;

              // Update progress
              onFileProgress?.call((processed / entry.size) * 100, readSize);
              onIsoProgress?.call((totalProcessed / result.size) * 100);
            }
          } finally {
            await targetFile.close();
          }
        }

        onStatus?.call('Successfully extracted ${result.files} files in ${result.folders} folders');
        onStatus?.call('Total size: ${_getSizeReadable(result.size)}');
        return true;

      } finally {
        await sourceFile.close();
      }

    } catch (e, stackTrace) {
      onStatus?.call('Error during extraction: $e');
      onStatus?.call('Stack trace: $stackTrace');
      return false;
    }
  }

  void abort() {
    _abort = true;
  }

  // Endian conversion utilities
  int _swap16(int value) {
    return ((value & 0xFF00) >> 8) | ((value & 0x00FF) << 8);
  }

  int _swap32(int value) {
    return ((value & 0x000000FF) << 24) |
           ((value & 0x0000FF00) << 8) |
           ((value & 0x00FF0000) >> 8) |
           ((value & 0xFF000000) >> 24);
  }

  int _bytesToUInt16(List<int> bytes, {required bool littleEndian}) {
    if (bytes.length < 2) {
      throw Exception('Not enough bytes for uint16');
    }
    
    final data = Uint8List.fromList(bytes);
    final buffer = ByteData.view(data.buffer);
    final value = buffer.getUint16(0, littleEndian ? Endian.little : Endian.big);
    
    // Dart is always little-endian internally, so we need to swap if we want big-endian
    return littleEndian ? value : _swap16(value);
  }

  int _bytesToUInt32(List<int> bytes, {required bool littleEndian}) {
    if (bytes.length < 4) {
      throw Exception('Not enough bytes for uint32');
    }
    
    final data = Uint8List.fromList(bytes);
    final buffer = ByteData.view(data.buffer);
    final value = buffer.getUint32(0, littleEndian ? Endian.little : Endian.big);
    
    // Dart is always little-endian internally, so we need to swap if we want big-endian
    return littleEndian ? value : _swap32(value);
  }

  // Helper method to read a uint32 directly from a RandomAccessFile at current position
  Future<int> _readUInt32(RandomAccessFile file, {required bool littleEndian}) async {
    final bytes = await file.read(4);
    return _bytesToUInt32(bytes, littleEndian: littleEndian);
  }

  // Helper method to read a uint16 directly from a RandomAccessFile at current position
  Future<int> _readUInt16(RandomAccessFile file, {required bool littleEndian}) async {
    final bytes = await file.read(2);
    return _bytesToUInt16(bytes, littleEndian: littleEndian);
  }

  int _bytesToInt16(List<int> bytes, {required bool littleEndian}) {
    final data = Uint8List.fromList(bytes);
    final buffer = ByteData.view(data.buffer);
    return littleEndian ? buffer.getInt16(0, Endian.little) : buffer.getInt16(0, Endian.big);
  }

  int _bytesToInt32(List<int> bytes, {required bool littleEndian}) {
    final data = Uint8List.fromList(bytes);
    final buffer = ByteData.view(data.buffer);
    return littleEndian ? buffer.getInt32(0, Endian.little) : buffer.getInt32(0, Endian.big);
  }

  String _getSizeReadable(int bytes) {
    const kb = 1024;
    const mb = 1024 * kb;
    const gb = 1024 * mb;
    const tb = 1024 * gb;

    if (bytes >= tb) {
      return '${(bytes / tb).toStringAsFixed(2)} TB';
    }
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    }
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(2)} MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(2)} KB';
    }
    return '$bytes B';
  }
}

class XisoListAndSize {
  int files = 0;
  int folders = 0;
  int size = 0;
  List<XisoTableData> list = [];
}

class XisoTableData {
  final bool isFile;
  final String name;
  final String path;
  final int offset;
  final int size;

  XisoTableData({
    required this.isFile,
    required this.name,
    required this.path,
    required this.offset,
    required this.size,
  });
}
