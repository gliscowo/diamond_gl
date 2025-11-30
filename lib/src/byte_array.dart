import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

abstract class ByteArray {
  ByteArray({required int size});

  ByteData get data;

  @mustBeOverridden
  @mustCallSuper
  void view(int size, void Function(Pointer<Uint8> pointer) withView) {
    assert(size <= data.lengthInBytes);
  }

  void resize(int newSize);
  void free();
}

final class ManagedByteArray extends ByteArray {
  ByteData _array;

  ManagedByteArray({required super.size}) : _array = ByteData(size);

  @override
  ByteData get data => _array;

  @override
  void view(int size, void Function(Pointer<Uint8> pointer) withView) {
    super.view(size, withView);

    final pointer = malloc<Uint8>();
    pointer.asTypedList(size).setRange(0, size, _array.buffer.asUint8List());

    try {
      withView(pointer);
    } finally {
      malloc.free(pointer);
    }
  }

  @override
  void resize(int newSize) {
    final newArray = ByteData(newSize);
    newArray.buffer.asUint8List().setRange(0, _array.lengthInBytes, _array.buffer.asUint8List());
    _array = newArray;
  }

  @override
  void free() {
    // gc <3
  }
}

final class NativeByteArray extends ByteArray implements Finalizable {
  Pointer<Uint8> _pointer;
  ByteData _view;

  NativeByteArray._(this._pointer, this._view) : super(size: _view.lengthInBytes) {
    _finalizer.attach(this, _pointer.cast(), detach: this, externalSize: _view.lengthInBytes);
  }

  factory NativeByteArray({required int size}) {
    final pointer = malloc<Uint8>(size);
    final view = pointer.asTypedList(size).buffer.asByteData();

    return NativeByteArray._(pointer, view);
  }

  @override
  ByteData get data => _view;

  @override
  void view(int size, void Function(Pointer<Uint8> pointer) withView) {
    super.view(size, withView);
    withView(_pointer);
  }

  @override
  void resize(int newSize) {
    final newPointer = malloc<Uint8>(newSize);
    newPointer.asTypedList(newSize).setRange(0, _view.lengthInBytes, _view.buffer.asUint8List());

    _finalizer.detach(this);
    malloc.free(_pointer);

    _pointer = newPointer;
    _finalizer.attach(this, _pointer.cast(), detach: this, externalSize: newSize);

    _view = _pointer.asTypedList(newSize).buffer.asByteData();
  }

  @override
  void free() {
    malloc.free(_pointer);
  }

  // ---

  static final _finalizer = NativeFinalizer(malloc.nativeFree);
}
