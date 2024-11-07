import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'zarchive_types.dart';

// Native structs
@Packed(8)
final class ZArchiveFileInfo extends Struct {
  external Pointer<Utf8> path;
  @Uint64()
  external int size;
  @Uint64()
  external int offset;
}

@Packed(8)
final class ZArchiveFileList extends Struct {
  external Pointer<ZArchiveFileInfo> files;
  @Size()
  external int count;
}

// Native function signatures
typedef _ZArchiveWriterCreate = Pointer Function(
    Pointer<NativeFunction<NewOutputFileCb>> newFileCb,
    Pointer<NativeFunction<WriteOutputDataCb>> writeDataCb,
    Pointer<Void> ctx
);

typedef _ZArchiveWriterDestroy = Void Function(Pointer writer);

typedef _ZArchiveWriterStartFile = Int32 Function(
    Pointer writer,
    Pointer<Utf8> path
);

typedef _ZArchiveWriterAppendData = Void Function(
    Pointer writer,
    Pointer<Void> data,
    Size size
);

typedef _ZArchiveWriterMakeDir = Int32 Function(
    Pointer writer,
    Pointer<Utf8> path,
    Int32 recursive
);

typedef _ZArchiveWriterFinalize = Void Function(Pointer writer);

typedef _ZArchiveReaderCreate = Pointer Function(
    Pointer<NativeFunction<ReadInputDataCb>> readDataCb,
    Pointer<Void> ctx
);

typedef _ZArchiveReaderDestroy = Void Function(Pointer reader);

typedef _ZArchiveReaderInitialize = Int32 Function(Pointer reader);

typedef _ZArchiveReaderListFiles = Pointer<ZArchiveFileList> Function(Pointer reader);

typedef _ZArchiveFileListFree = Void Function(Pointer<ZArchiveFileList> list);

typedef _ZArchiveReaderExtractFile = Int32 Function(
    Pointer reader,
    Pointer<Utf8> path,
    Pointer<Utf8> outputPath
);

// Dart function signatures
typedef ZArchiveWriterCreate = Pointer Function(
    Pointer<NativeFunction<NewOutputFileCb>> newFileCb,
    Pointer<NativeFunction<WriteOutputDataCb>> writeDataCb,
    Pointer<Void> ctx
);

typedef ZArchiveWriterDestroy = void Function(Pointer writer);

typedef ZArchiveWriterStartFile = int Function(
    Pointer writer,
    Pointer<Utf8> path
);

typedef ZArchiveWriterAppendData = void Function(
    Pointer writer,
    Pointer<Void> data,
    int size
);

typedef ZArchiveWriterMakeDir = int Function(
    Pointer writer,
    Pointer<Utf8> path,
    int recursive
);

typedef ZArchiveWriterFinalize = void Function(Pointer writer);

typedef ZArchiveReaderCreate = Pointer Function(
    Pointer<NativeFunction<ReadInputDataCb>> readDataCb,
    Pointer<Void> ctx
);

typedef ZArchiveReaderDestroy = void Function(Pointer reader);

typedef ZArchiveReaderInitialize = int Function(Pointer reader);

typedef ZArchiveReaderListFiles = Pointer<ZArchiveFileList> Function(Pointer reader);

typedef ZArchiveFileListFree = void Function(Pointer<ZArchiveFileList> list);

typedef ZArchiveReaderExtractFile = int Function(
    Pointer reader,
    Pointer<Utf8> path,
    Pointer<Utf8> outputPath
);

// Bindings class
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
    // Try multiple potential locations for the library
    final possiblePaths = [
      // Current build location
      '${Directory.current.path}/build/linux/x64/debug/bundle/lib/libzarchive.so',
      // Zarchive build directory
      '${Directory.current.path}/zarchive/build/libzarchive.so',
      // Absolute path to the current project
      '/home/jon/Desktop/xenia_launcher/build/linux/x64/debug/bundle/lib/libzarchive.so',
      '/home/jon/Desktop/xenia_launcher/zarchive/build/libzarchive.so',
      // Fallback system library path
      '/usr/local/lib/libzarchive.so',
      '/usr/lib/libzarchive.so',
    ];

    print('Searching for libzarchive.so in the following locations:');
    for (var path in possiblePaths) {
      print('Checking path: $path');
      final file = File(path);
      if (file.existsSync()) {
        print('Found libzarchive.so at: $path');
        return path;
      }
    }

    throw Exception('Could not find libzarchive.so in any of the expected locations');
  }
}
