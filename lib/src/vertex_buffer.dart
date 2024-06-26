import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';

import 'diamond_gl_base.dart';
import 'shader.dart';
import 'vertex_descriptor.dart';

class MeshBuffer<VF extends Function> {
  final GlVertexBuffer _vbo = GlVertexBuffer();
  final GlVertexArray _vao = GlVertexArray();
  final VertexDescriptor<VF> _descriptor;
  final GlProgram program;

  BufferWriter _buffer;
  late VF _vertex;

  MeshBuffer(VertexDescriptor<VF> descriptor, this.program, {int initialBufferSize = 1024})
      : _descriptor = descriptor,
        _buffer = BufferWriter(initialBufferSize) {
    gl.vertexArrayVertexBuffer(_vao._id, 0, _vbo._id, 0, descriptor.vertexSize);
    descriptor.prepareAttributes(_vao._id, program);

    _vertex = descriptor.createBuilder(_buffer);
  }

  VF get vertex => _vertex;

  BufferWriter get buffer => _buffer;
  set buffer(BufferWriter buffer) {
    _buffer = buffer;
    _vertex = _descriptor.createBuilder(_buffer);
  }

  int get vertexCount => _buffer._cursor ~/ _descriptor.vertexSize;

  void upload({bool dynamic = false}) {
    _vbo.upload(_buffer, dynamic: dynamic);
  }

  void clear() {
    _buffer.rewind();
  }

  void draw() {
    _vao.draw(vertexCount);
  }

  void delete() {
    _vbo.delete();
    _vao.delete();
  }
}

class GlVertexBuffer {
  late final int _id;
  int _vboSize = 0;

  GlVertexBuffer() {
    final idPointer = malloc<UnsignedInt>();
    gl.createBuffers(1, idPointer);
    _id = idPointer.value;
    malloc.free(idPointer);
  }

  void upload(BufferWriter data, {bool dynamic = false}) {
    final (buffer, free) = data.prepareForUploading();

    if (data._cursor > _vboSize) {
      gl.namedBufferData(_id, data._cursor, buffer, dynamic ? glDynamicDraw : glStaticDraw);
      _vboSize = data._cursor;
    } else {
      gl.namedBufferSubData(_id, 0, data._cursor, buffer);
    }

    if (free) malloc.free(buffer);
  }

  @Deprecated("Prefer DSA")
  void bind() => gl.bindBuffer(glArrayBuffer, _id);
  @Deprecated("Prefer DSA")
  void unbind() => gl.bindBuffer(glArrayBuffer, 0);

  void delete() {
    final idPointer = malloc<UnsignedInt>();
    idPointer.value = _id;
    gl.deleteBuffers(1, idPointer);
    malloc.free(idPointer);
  }
}

class GlVertexArray {
  late final int _id;

  GlVertexArray() {
    final idPointer = calloc<UnsignedInt>();
    gl.createVertexArrays(1, idPointer);
    _id = idPointer.value;
  }

  void draw(int count) {
    bind();
    gl.drawArrays(glTriangles, 0, count);
    unbind();
  }

  void bind() {
    gl.bindVertexArray(_id);
  }

  void unbind() {
    gl.bindVertexArray(0);
  }

  void delete() {
    final idPointer = malloc<UnsignedInt>();
    idPointer.value = _id;
    gl.deleteVertexArrays(1, idPointer);
    malloc.free(idPointer);
  }
}

final class BufferWriter {
  static final _logger = getLogger("buffer_writer");
  static const _float32Size = Float32List.bytesPerElement;

  ByteData _data;
  int _cursor = 0;

  BufferWriter([int initialSize = 64]) : _data = ByteData(64);
  factory BufferWriter.native([int initialSize = 64]) => NativeBufferWriter._(initialSize);

  void float2(double a, double b) {
    _ensureCapacity(_float32Size * 2);

    _data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host);
    _cursor += _float32Size * 2;
  }

  void float3(double a, double b, double c) {
    _ensureCapacity(_float32Size * 3);

    _data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host)
      ..setFloat32(_cursor + _float32Size * 2, c, Endian.host);
    _cursor += _float32Size * 3;
  }

  void float4(double a, double b, double c, double d) {
    _ensureCapacity(_float32Size * 4);

    _data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host)
      ..setFloat32(_cursor + _float32Size * 2, c, Endian.host)
      ..setFloat32(_cursor + _float32Size * 3, d, Endian.host);
    _cursor += _float32Size * 4;
  }

  void rewind() {
    _cursor = 0;
  }

  int elements(int vertexSizeInBytes) => _cursor ~/ vertexSizeInBytes;

  (Pointer<Void>, bool) prepareForUploading() {
    final nativeBuffer = malloc<Uint8>(_cursor);
    nativeBuffer.asTypedList(_cursor).setRange(0, _cursor, _data.buffer.asUint8List());

    return (nativeBuffer.cast(), true);
  }

  void _ensureCapacity(int bytes) {
    if (_cursor + bytes <= _data.lengthInBytes) return;

    BufferWriter._logger?.fine(
      "Growing BufferWriter $hashCode from ${_data.lengthInBytes} to ${_data.lengthInBytes * 2} bytes to fit ${_cursor + bytes}",
    );

    final newData = ByteData(_data.lengthInBytes * 2);
    newData.buffer.asUint8List().setRange(0, _data.lengthInBytes, _data.buffer.asUint8List());
    _data = newData;
  }
}

final class NativeBufferWriter extends BufferWriter {
  late Pointer<Uint8> _pointer;

  NativeBufferWriter._(int initialSize) {
    _pointer = malloc<Uint8>(initialSize);
    _data = _pointer.asTypedList(initialSize).buffer.asByteData();
  }

  @override
  (Pointer<Void>, bool) prepareForUploading() => (_pointer.cast(), false);

  @override
  void _ensureCapacity(int bytes) {
    if (_cursor + bytes <= _data.lengthInBytes) return;

    BufferWriter._logger?.fine(
      "Growing BufferWriter $hashCode from ${_data.lengthInBytes} to ${_data.lengthInBytes * 2} bytes to fit ${_cursor + bytes}",
    );

    final newPointer = malloc<Uint8>(_data.lengthInBytes * 2);
    newPointer.asTypedList(_data.lengthInBytes * 2).setRange(0, _data.lengthInBytes, _data.buffer.asUint8List());
    malloc.free(_pointer);
    _pointer = newPointer;
    _data = _pointer.asTypedList(_data.lengthInBytes * 2).buffer.asByteData();
  }
}
