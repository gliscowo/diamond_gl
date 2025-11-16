import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';

import 'diamond_gl_base.dart';
import 'shader.dart';
import 'vertex_descriptor.dart';

class MeshBuffer<VF extends Function> {
  final GlBufferObject _vbo = GlBufferObject.array();
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
  bool get isEmpty => _buffer._cursor == 0;

  void upload({bool dynamic = false}) {
    _vbo.upload(_buffer, dynamic ? BufferUsage.dynamicDraw : BufferUsage.staticDraw);
  }

  void clear() {
    _buffer.rewind();
  }

  void draw({int mode = glTriangles}) {
    _vao.draw(vertexCount, mode: mode);
  }

  void drawInstanced(int instanceCount, {int mode = glTriangles}) {
    _vao.drawInstanced(vertexCount, instanceCount, mode: mode);
  }

  void delete() {
    _vbo.delete();
    _vao.delete();
  }
}

enum BufferUsage {
  streamDraw(glStreamDraw),
  streamRead(glStreamRead),
  streamCopy(glStreamCopy),
  staticDraw(glStaticDraw),
  staticRead(glStaticRead),
  staticCopy(glStaticCopy),
  dynamicDraw(glDynamicDraw),
  dynamicRead(glDynamicRead),
  dynamicCopy(glDynamicCopy);

  final int glType;
  const BufferUsage(this.glType);
}

class GlBufferObject {
  final int type;

  late final int _id;
  int _glObjectSize = 0;

  GlBufferObject.array() : this._(glArrayBufferBinding);
  GlBufferObject.shaderStorage() : this._(glShaderStorageBuffer);
  GlBufferObject.other(int type) : this._(type);

  GlBufferObject._(this.type) {
    final idPointer = malloc<UnsignedInt>();
    gl.createBuffers(1, idPointer);
    _id = idPointer.value;
    malloc.free(idPointer);
  }

  int get id => _id;

  void upload(BufferWriter data, BufferUsage usage) {
    final (buffer, size, free) = data.prepareForUploading();

    if (size != 0) {
      if (size > _glObjectSize) {
        gl.namedBufferData(_id, size, buffer, usage.glType);
        _glObjectSize = size;
      } else {
        gl.namedBufferSubData(_id, 0, size, buffer);
      }
    }

    if (free) malloc.free(buffer);
  }

  @Deprecated('Prefer DSA')
  void bind() => gl.bindBuffer(type, _id);
  @Deprecated('Prefer DSA')
  void unbind() => gl.bindBuffer(type, 0);

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

  void draw(int count, {int mode = glTriangles}) {
    bind();
    gl.drawArrays(mode, 0, count);
    unbind();
  }

  void drawInstanced(int count, int instanceCount, {int mode = glTriangles}) {
    bind();
    gl.drawArraysInstanced(mode, 0, count, instanceCount);
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
  static final _logger = getLogger('buffer_writer');
  static const _uint32Size = Uint32List.bytesPerElement;
  static const _float32Size = Float32List.bytesPerElement;

  ByteData _data;
  int _cursor = 0;

  BufferWriter([int initialSize = 64]) : _data = ByteData(64);
  factory BufferWriter.native([int initialSize = 64]) => NativeBufferWriter._(initialSize);

  void u32(int f) {
    _ensureCapacity(_uint32Size);

    _data.setUint32(_cursor, f, Endian.host);
    _cursor += _uint32Size;
  }

  void u32x2(int a, int b) {
    _ensureCapacity(_uint32Size * 2);

    _data
      ..setUint32(_cursor + _uint32Size * 0, a, Endian.host)
      ..setUint32(_cursor + _uint32Size * 1, b, Endian.host);
    _cursor += _uint32Size * 2;
  }

  void u32x3(int a, int b, int c) {
    _ensureCapacity(_uint32Size * 3);

    _data
      ..setUint32(_cursor + _uint32Size * 0, a, Endian.host)
      ..setUint32(_cursor + _uint32Size * 1, b, Endian.host)
      ..setUint32(_cursor + _uint32Size * 2, c, Endian.host);
    _cursor += _uint32Size * 3;
  }

  void u32x4(int a, int b, int c, int d) {
    _ensureCapacity(_uint32Size * 4);

    _data
      ..setUint32(_cursor + _uint32Size * 0, a, Endian.host)
      ..setUint32(_cursor + _uint32Size * 1, b, Endian.host)
      ..setUint32(_cursor + _uint32Size * 2, c, Endian.host)
      ..setUint32(_cursor + _uint32Size * 3, d, Endian.host);
    _cursor += _uint32Size * 4;
  }

  void f32(double f) {
    _ensureCapacity(_float32Size);

    _data.setFloat32(_cursor, f, Endian.host);
    _cursor += _float32Size;
  }

  void f32x2(double a, double b) {
    _ensureCapacity(_float32Size * 2);

    _data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host);
    _cursor += _float32Size * 2;
  }

  void f32x3(double a, double b, double c) {
    _ensureCapacity(_float32Size * 3);

    _data
      ..setFloat32(_cursor + _float32Size * 0, a, Endian.host)
      ..setFloat32(_cursor + _float32Size * 1, b, Endian.host)
      ..setFloat32(_cursor + _float32Size * 2, c, Endian.host);
    _cursor += _float32Size * 3;
  }

  void f32x4(double a, double b, double c, double d) {
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

  (Pointer<Void>, int, bool) prepareForUploading() {
    final nativeBuffer = malloc<Uint8>(_cursor);
    nativeBuffer.asTypedList(_cursor).setRange(0, _cursor, _data.buffer.asUint8List());

    return (nativeBuffer.cast(), _cursor, true);
  }

  void _ensureCapacity(int bytes) {
    if (_cursor + bytes <= _data.lengthInBytes) return;

    BufferWriter._logger?.fine(
      'Growing BufferWriter $hashCode from ${_data.lengthInBytes} to ${_data.lengthInBytes * 2} bytes to fit ${_cursor + bytes}',
    );

    final newData = ByteData(_data.lengthInBytes * 2);
    newData.buffer.asUint8List().setRange(0, _data.lengthInBytes, _data.buffer.asUint8List());
    _data = newData;
  }
}

final class NativeBufferWriter extends BufferWriter {
  static final _finalizer = Finalizer<Pointer<Uint8>>(malloc.free);

  late Pointer<Uint8> _pointer;

  NativeBufferWriter._(int initialSize) {
    _pointer = malloc<Uint8>(initialSize);
    _data = _pointer.asTypedList(initialSize).buffer.asByteData();

    _finalizer.attach(this, _pointer, detach: this);
  }

  @override
  (Pointer<Void>, int, bool) prepareForUploading() => (_pointer.cast(), _cursor, false);

  @override
  void _ensureCapacity(int bytes) {
    if (_cursor + bytes <= _data.lengthInBytes) return;

    BufferWriter._logger?.fine(
      'Growing BufferWriter $hashCode from ${_data.lengthInBytes} to ${_data.lengthInBytes * 2} bytes to fit ${_cursor + bytes}',
    );

    final newPointer = malloc<Uint8>(_data.lengthInBytes * 2);
    newPointer.asTypedList(_data.lengthInBytes * 2).setRange(0, _data.lengthInBytes, _data.buffer.asUint8List());

    _finalizer.detach(this);
    malloc.free(_pointer);

    _pointer = newPointer;
    _finalizer.attach(this, _pointer, detach: this);

    _data = _pointer.asTypedList(_data.lengthInBytes * 2).buffer.asByteData();
  }
}
