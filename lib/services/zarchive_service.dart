import 'dart:io';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;
import '../models/zarchive_entry.dart';
import '../zarchive/ffi/zarchive_bindings.dart';
import '../zarchive/ffi/zarchive_types.dart';

typedef ProgressCallback = void Function(int current, int total);

class ZArchiveService {
  final ZArchiveBindings _bindings;
  static late RandomAccessFile _currentOutputFile;
  static late RandomAccessFile _currentInputFile;
  static late int _currentInputFileLength;
  
  ZArchiveService() : _bindings = ZArchiveBindings();

  Future<void> createArchive(
    String inputPath,
    String outputPath,
    ProgressCallback onProgress,
  ) async {
    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) {
      throw Exception('Input directory does not exist');
    }

    final files = await _collectFiles(inputDir);
    int totalBytes = 0;
    for (var file in files) {
      if (file is File) {
        totalBytes += await file.length() as int;
      }
    }

    int processedBytes = 0;
    Pointer<Void>? writer;

    try {
      _currentOutputFile = await File(outputPath).open(mode: FileMode.write);

      final newFileCb = Pointer.fromFunction<NewOutputFileCb>(_onNewFile);
      final writeDataCb = Pointer.fromFunction<WriteOutputDataCb>(_onWriteData);

      writer = _bindings.createWriter(newFileCb, writeDataCb, nullptr);

      for (var entity in files) {
        if (entity is! File) continue;

        final relativePath = path.relative(entity.path, from: inputDir.path);

        var parent = path.dirname(relativePath);
        if (parent != '.') {
          final parentPtr = parent.toNativeUtf8();
          final dirResult = _bindings.makeDir(writer, parentPtr, 1);
          calloc.free(parentPtr);
          if (dirResult == 0) {
            throw Exception('Failed to create directory: $parent');
          }
        }

        final pathPtr = relativePath.toNativeUtf8();
        final fileResult = _bindings.startFile(writer, pathPtr);
        calloc.free(pathPtr);
        if (fileResult == 0) {
          throw Exception('Failed to start file: $relativePath');
        }

        final fileBytes = await entity.readAsBytes();
        final data = calloc<Uint8>(fileBytes.length);
        final byteList = data.asTypedList(fileBytes.length);
        byteList.setAll(0, fileBytes);
        _bindings.appendData(writer, data.cast<Void>(), fileBytes.length);
        calloc.free(data);

        processedBytes += fileBytes.length;
        onProgress(processedBytes, totalBytes);
      }

      _bindings.finalize(writer);
    } finally {
      if (writer != null) {
        _bindings.destroyWriter(writer);
      }
      await _currentOutputFile.close();
    }
  }

  Future<List<ZArchiveEntry>> extractArchive(
    String archivePath,
    String outputPath,
    ProgressCallback onProgress,
  ) async {
    final entries = <ZArchiveEntry>[];
    Pointer<Void>? reader;
    
    try {
      _currentInputFile = await File(archivePath).open(mode: FileMode.read);
      _currentInputFileLength = await _currentInputFile.length();
      
      final readDataCb = Pointer.fromFunction<ReadInputDataCb>(_onReadData);
      reader = _bindings.createReader(readDataCb, nullptr);
      
      if (reader == nullptr) {
        throw Exception('Failed to create archive reader');
      }

      final initResult = _bindings.initializeReader(reader);
      if (initResult == 0) {
        throw Exception('Failed to initialize archive reader');
      }

      final outputDir = Directory(outputPath);
      if (!outputDir.existsSync()) {
        outputDir.createSync(recursive: true);
      }

      await _extractDirectory(reader, "", outputPath, entries, onProgress);
      
      entries.sort((a, b) {
        if (a.isFile == b.isFile) {
          return a.name.compareTo(b.name);
        }
        return a.isFile ? 1 : -1;
      });

    } finally {
      if (reader != null) {
        _bindings.destroyReader(reader);
      }
      await _currentInputFile.close();
    }

    return entries;
  }

  Future<void> _extractDirectory(
    Pointer<Void> reader,
    String sourcePath,
    String outputPath,
    List<ZArchiveEntry> entries,
    ProgressCallback onProgress,
  ) async {
    final fileList = _bindings.listFiles(reader);
    if (fileList == nullptr) {
      throw Exception('Failed to list files');
    }

    try {
      int totalBytes = 0;
      int processedBytes = 0;

      for (var i = 0; i < fileList.ref.count; i++) {
        final fileInfo = fileList.ref.files[i];
        totalBytes += fileInfo.size.toInt();
      }

      for (var i = 0; i < fileList.ref.count; i++) {
        final fileInfo = fileList.ref.files[i];
        final filePath = fileInfo.path.toDartString();

        entries.add(ZArchiveEntry(
          name: filePath,
          isFile: true,
          size: fileInfo.size.toInt(),
          offset: fileInfo.offset.toInt(),
        ));

        final fullOutputPath = path.join(outputPath, filePath);
        final parent = path.dirname(fullOutputPath);
        
        if (parent != '.') {
          Directory(parent).createSync(recursive: true);
          
          var currentPath = parent;
          while (currentPath != outputPath && currentPath != '.') {
            final relativePath = path.relative(currentPath, from: outputPath);
            
            final dirEntry = ZArchiveEntry(
              name: relativePath,
              isFile: false,
              size: 0,
              offset: 0,
            );
            
            if (!entries.any((e) => e.name == dirEntry.name && !e.isFile)) {
              entries.add(dirEntry);
            }
            currentPath = path.dirname(currentPath);
          }
        }

        final pathPtr = filePath.toNativeUtf8();
        final outputPathPtr = fullOutputPath.toNativeUtf8();
        
        try {
          final extractResult = _bindings.extractFile(reader, pathPtr, outputPathPtr);
          if (extractResult == 0) {
            throw Exception('Failed to extract file: $filePath');
          }
          
          processedBytes += fileInfo.size.toInt();
          onProgress(processedBytes, totalBytes);
        } finally {
          calloc.free(pathPtr);
          calloc.free(outputPathPtr);
        }
      }
    } finally {
      _bindings.freeFileList(fileList);
    }
  }

  Future<List<FileSystemEntity>> _collectFiles(Directory dir) async {
    final files = <FileSystemEntity>[];
    await for (var entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        files.add(entity);
      }
    }
    return files;
  }

  static void _onNewFile(int partIndex, Pointer<Void> ctx) {
    // No-op for now, we don't support multi-part archives
  }

  static void _onWriteData(Pointer<Void> data, int length, Pointer<Void> ctx) {
    final buffer = data.cast<Uint8>().asTypedList(length);
    _currentOutputFile.writeFromSync(buffer);
  }

  static void _onReadData(Pointer<Void> data, int offset, int length, Pointer<Void> ctx) {
    try {
      final actualOffset = offset < 0 ? _currentInputFileLength + offset : offset;
      _currentInputFile.setPositionSync(actualOffset);
      final buffer = data.cast<Uint8>().asTypedList(length);
      final bytesRead = _currentInputFile.readIntoSync(buffer);
      
      if (bytesRead != length) {
        throw Exception('Failed to read expected number of bytes');
      }
    } catch (e, stackTrace) {
      print('Error in read callback: $e\nStack trace: $stackTrace');
      rethrow;
    }
  }
}
