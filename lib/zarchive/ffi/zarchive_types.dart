import 'dart:ffi';

// FFI type definitions for callbacks
typedef NewOutputFileCb = Void Function(Int32 partIndex, Pointer<Void> ctx);
typedef WriteOutputDataCb = Void Function(Pointer<Void> data, Size length, Pointer<Void> ctx);
typedef ReadInputDataCb = Void Function(Pointer<Void> data, Size offset, Size length, Pointer<Void> ctx);

// Dart callback signatures
typedef DartNewOutputFileCb = void Function(int partIndex, Pointer<Void> ctx);
typedef DartWriteOutputDataCb = void Function(Pointer<Void> data, int length, Pointer<Void> ctx);
typedef DartReadInputDataCb = void Function(Pointer<Void> data, int offset, int length, Pointer<Void> ctx);
