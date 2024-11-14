import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path_util;
import 'zarchive_types.dart';

// Native function signatures
typedef _ZArchiveWriterCreate = Pointer<Void> Function(
    Pointer<NativeFunction<NewOutputFileCb>> newFileCb,
    Pointer<NativeFunction<WriteOutputDataCb>> writeDataCb,
    Pointer<Void> ctx
);

typedef _ZArchiveWriterDestroy = Void Function(
    Pointer<Void> writer
);

typedef _ZArchiveWriterStartFile = Int32 Function(
    Pointer<Void> writer,
    Pointer<Utf8> path
);

typedef _ZArchiveWriterAppendData = Void Function(
    Pointer<Void> writer,
    Pointer<Void> data,
    Size size
);

typedef _ZArchiveWriterMakeDir = Int32 Function(
    Pointer<Void> writer,
    Pointer<Utf8> path,
    Int32 recursive
);

typedef _ZArchiveWriterFinalize = Void Function(
    Pointer<Void> writer
);

typedef _ZArchiveReaderCreate = Pointer<Void> Function(
    Pointer<NativeFunction<ReadInputDataCb>> readDataCb,
    Pointer<Void> ctx
);

typedef _ZArchiveReaderDestroy = Void Function(
    Pointer<Void> reader
);

typedef _ZArchiveReaderInitialize = Int32 Function(
    Pointer<Void> reader
);

typedef _ZArchiveReaderListFiles = Pointer<ZArchiveFileList> Function(
    Pointer<Void> reader
);

typedef _ZArchiveFileListFree = Void Function(
    Pointer<ZArchiveFileList> list
);

typedef _ZArchiveReaderExtractFile = Int32 Function(
    Pointer<Void> reader,
    Pointer<Utf8> path,
    Pointer<Utf8> outputPath
);

// Dart function signatures
typedef ZArchiveWriterCreate = Pointer<Void> Function(
    Pointer<NativeFunction<NewOutputFileCb>> newFileCb,
    Pointer<NativeFunction<WriteOutputDataCb>> writeDataCb,
    Pointer<Void> ctx
);

typedef ZArchiveWriterDestroy = void Function(
    Pointer<Void> writer
);

typedef ZArchiveWriterStartFile = int Function(
    Pointer<Void> writer,
    Pointer<Utf8> path
);

typedef ZArchiveWriterAppendData = void Function(
    Pointer<Void> writer,
    Pointer<Void> data,
    int size
);

typedef ZArchiveWriterMakeDir = int Function(
    Pointer<Void> writer,
    Pointer<Utf8> path,
    int recursive
);

typedef ZArchiveWriterFinalize = void Function(
    Pointer<Void> writer
);

typedef ZArchiveReaderCreate = Pointer<Void> Function(
    Pointer<NativeFunction<ReadInputDataCb>> readDataCb,
    Pointer<Void> ctx
);

typedef ZArchiveReaderDestroy = void Function(
    Pointer<Void> reader
);

typedef ZArchiveReaderInitialize = int Function(
    Pointer<Void> reader
);

typedef ZArchiveReaderListFiles = Pointer<ZArchiveFileList> Function(
    Pointer<Void> reader
);

typedef ZArchiveFileListFree = void Function(
    Pointer<ZArchiveFileList> list
);

typedef ZArchiveReaderExtractFile = int Function(
    Pointer<Void> reader,
    Pointer<Utf8> path,
    Pointer<Utf8> outputPath
);

class ZArchiveBindings {
  late final DynamicLibrary _lib;
  
  // Writer functions
  late final ZArchiveWriterCreate createWriter;
  late final ZArchiveWriterDestroy destroyWriter;
  late final ZArchiveWriterStartFile startFile;
  late final ZArchiveWriterAppendData appendData;
  late final ZArchiveWriterMakeDir makeDir;
  late final ZArchiveWriterFinalize finalize;
  
  // Reader functions
  late final ZArchiveReaderCreate createReader;
  late final ZArchiveReaderDestroy destroyReader;
  late final ZArchiveReaderInitialize initializeReader;
  late final ZArchiveReaderListFiles listFiles;
  late final ZArchiveFileListFree freeFileList;
  late final ZArchiveReaderExtractFile extractFile;

  ZArchiveBindings() {
    // Load the dynamic library from the correct location
    final libraryPath = _getLibraryPath();
    print('Loading library from: $libraryPath');
    _lib = DynamicLibrary.open(libraryPath);

    // Look up writer functions
    createWriter = _lib
        .lookupFunction<_ZArchiveWriterCreate, ZArchiveWriterCreate>('zarchive_writer_create');
    destroyWriter = _lib
        .lookupFunction<_ZArchiveWriterDestroy, ZArchiveWriterDestroy>('zarchive_writer_destroy');
    startFile = _lib
        .lookupFunction<_ZArchiveWriterStartFile, ZArchiveWriterStartFile>('zarchive_writer_start_file');
    appendData = _lib
        .lookupFunction<_ZArchiveWriterAppendData, ZArchiveWriterAppendData>('zarchive_writer_append_data');
    makeDir = _lib
        .lookupFunction<_ZArchiveWriterMakeDir, ZArchiveWriterMakeDir>('zarchive_writer_make_dir');
    finalize = _lib
        .lookupFunction<_ZArchiveWriterFinalize, ZArchiveWriterFinalize>('zarchive_writer_finalize');

    // Look up reader functions
    createReader = _lib
        .lookupFunction<_ZArchiveReaderCreate, ZArchiveReaderCreate>('zarchive_reader_create');
    destroyReader = _lib
        .lookupFunction<_ZArchiveReaderDestroy, ZArchiveReaderDestroy>('zarchive_reader_destroy');
    initializeReader = _lib
        .lookupFunction<_ZArchiveReaderInitialize, ZArchiveReaderInitialize>('zarchive_reader_initialize');
    listFiles = _lib
        .lookupFunction<_ZArchiveReaderListFiles, ZArchiveReaderListFiles>('zarchive_reader_list_files');
    freeFileList = _lib
        .lookupFunction<_ZArchiveFileListFree, ZArchiveFileListFree>('zarchive_file_list_free');
    extractFile = _lib
        .lookupFunction<_ZArchiveReaderExtractFile, ZArchiveReaderExtractFile>('zarchive_reader_extract_file');
  }

  String _getLibraryPath() {
    final executableDir = File(Platform.resolvedExecutable).parent;
    final libName = Platform.isWindows ? 'zarchive.dll' : 'libzarchive.so';
    final libPath = Platform.isWindows
        ? path.join(Directory.current.path, libName)
        : path.join(Directory.current.path, 'lib', 'native', 'linux', libName);
    
    // Try to find the library in various locations
    final locations = [
      // Current directory
      libPath,
      // Executable directory
      path_util.join(executableDir.path, libName),
      // Project root (during development)
      path_util.join(Directory.current.path, '..', libName),
    ];

    for (final location in locations) {
      if (File(location).existsSync()) {
        return location;
      }
    }

    throw Exception('Could not find $libName. Please ensure it is in the same directory as the executable.');
  }
}