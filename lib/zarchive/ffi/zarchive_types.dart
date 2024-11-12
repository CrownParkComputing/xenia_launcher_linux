import 'dart:ffi';
import 'package:ffi/ffi.dart';

// FFI type definitions for callbacks
typedef NewOutputFileCb = Void Function(Int32 partIndex, Pointer<Void> ctx);
typedef WriteOutputDataCb = Void Function(Pointer<Void> data, Size length, Pointer<Void> ctx);
typedef ReadInputDataCb = Void Function(Pointer<Void> data, Size offset, Size length, Pointer<Void> ctx);

// Dart callback signatures
typedef DartNewOutputFileCb = void Function(int partIndex, Pointer<Void> ctx);
typedef DartWriteOutputDataCb = void Function(Pointer<Void> data, int length, Pointer<Void> ctx);
typedef DartReadInputDataCb = void Function(Pointer<Void> data, int offset, int length, Pointer<Void> ctx);

// Native structs
@Packed(8)
final class ZArchiveDirEntry extends Struct {
  @Int32()
  external int isDirectory;
  external Pointer<Utf8> name;
  @Int64()
  external int size;
  @Int64()
  external int offset;
}

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

// Type aliases for easier reference
typedef DirEntry = ZArchiveDirEntry;
typedef FileInfo = ZArchiveFileInfo;
typedef FileList = ZArchiveFileList;

// Error codes and constants
class ZArchiveConstants {
  static const int INVALID_NODE = -1;
  static const int SUCCESS = 1;
  static const int FAILURE = 0;
}