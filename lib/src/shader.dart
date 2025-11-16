import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:vector_math/vector_math.dart';

import 'diamond_gl_base.dart';

final _logger = getLogger('shader_compiler');

enum GlShaderType {
  vertex(gl_vertexShader),
  tesselationControl(gl_tessControlShader),
  tesselationEvalution(gl_tessEvaluationShader),
  geometry(gl_geometryShader),
  fragment(gl_fragmentShader),
  compute(gl_computeShader);

  final int glType;
  const GlShaderType(this.glType);
}

class GlShader {
  final int _id;

  @factory
  static Future<GlShader> fromFile(File file, GlShaderType type) async {
    final source = await file.readAsString();
    return GlShader(basename(file.path), source, type);
  }

  GlShader(String sourceName, String source, GlShaderType type) : _id = glCreateShader(type.glType) {
    _loadAndCompile(sourceName, source);
  }

  int get id => _id;

  void _loadAndCompile(String sourceName, String source) {
    using((arena) {
      final sourceBuffer = source.toNativeUtf8();

      final sourceArray = arena<Pointer<Utf8>>();
      sourceArray[0] = sourceBuffer;

      glShaderSource(_id, 1, sourceArray.cast(), nullptr);
      glCompileShader(_id);

      final success = arena<Int>();
      glGetShaderiv(_id, gl_compileStatus, success);
      _logger?.fine('Shader "$sourceName" compile success: ${success.value}');

      if (success.value != gl_true) {
        final logLength = arena<Int>();
        glGetShaderiv(_id, gl_infoLogLength, logLength);

        final log = arena<Char>(logLength.value);
        glGetShaderInfoLog(_id, logLength.value, nullptr, log);
        _logger?.severe('Failed to compile shader "$sourceName": ${log.cast<Utf8>().toDartString()}');
      }
    });
  }
}

class GlProgram {
  static final Pointer<Float> _floatBuffer = malloc<Float>(16);

  final int _id;
  final String name;
  final Map<String, int> _uniformCache = {};

  GlProgram(this.name, List<GlShader> shaders) : _id = glCreateProgram() {
    for (final shader in shaders) {
      glAttachShader(_id, shader.id);
    }

    glLinkProgram(_id);

    for (final shader in shaders) {
      glDeleteShader(shader.id);
    }

    final success = malloc<Int>();
    glGetProgramiv(_id, gl_linkStatus, success);
    _logger?.fine('Program "$name link success: ${success.value}');

    if (success.value != gl_true) {
      final logLength = malloc<Int>();
      glGetProgramiv(_id, gl_infoLogLength, logLength);

      final log = malloc<Char>(logLength.value);
      glGetProgramInfoLog(_id, logLength.value, nullptr, log);
      _logger?.severe('Failed to link program "$name": ${log.cast<Utf8>().toDartString()}');

      malloc.free(logLength);
      malloc.free(log);
    }

    malloc.free(success);
  }

  int get id => _id;
  void use() => glUseProgram(_id);

  void uniformMat4(String uniform, Matrix4 value) {
    _floatBuffer.asTypedList(value.storage.length).setRange(0, value.storage.length, value.storage);
    glProgramUniformMatrix4fv(_id, _uniformLocation(uniform), 1, gl_false, _floatBuffer);
  }

  void uniform1f(String uniform, double value) {
    glProgramUniform1f(_id, _uniformLocation(uniform), value);
  }

  void uniform2vf(String uniform, Vector2 vec) => uniform2f(uniform, vec.x, vec.y);
  void uniform2f(String uniform, double x, double y) {
    glProgramUniform2f(_id, _uniformLocation(uniform), x, y);
  }

  void uniform3vf(String uniform, Vector3 vec) => uniform3f(uniform, vec.x, vec.y, vec.z);
  void uniform3f(String uniform, double x, double y, double z) {
    glProgramUniform3f(_id, _uniformLocation(uniform), x, y, z);
  }

  void uniform4vf(String uniform, Vector4 vec) => uniform4f(uniform, vec.x, vec.y, vec.z, vec.w);
  void uniform4f(String uniform, double x, double y, double z, double w) {
    glProgramUniform4f(_id, _uniformLocation(uniform), x, y, z, w);
  }

  void uniform1i(String uniform, int value) {
    glProgramUniform1i(_id, _uniformLocation(uniform), value);
  }

  void uniform2i(String uniform, int x, int y) {
    glProgramUniform2i(_id, _uniformLocation(uniform), x, y);
  }

  void uniform3i(String uniform, int x, int y, int z) {
    glProgramUniform3i(_id, _uniformLocation(uniform), x, y, z);
  }

  void uniform4i(String uniform, int x, int y, int z, int w) {
    glProgramUniform4i(_id, _uniformLocation(uniform), x, y, z, w);
  }

  void uniformSampler(String uniform, int texture, int index) {
    glProgramUniform1i(_id, _uniformLocation(uniform), index);
    glBindTextureUnit(index, texture);
  }

  void ssbo(int binding, int ssboId) {
    glBindBufferBase(gl_shaderStorageBuffer, binding, ssboId);
  }

  int _uniformLocation(String uniform) => _uniformCache.putIfAbsent(
    uniform,
    () => using((arena) => glGetUniformLocation(_id, uniform.toNativeUtf8(allocator: arena).cast())),
  );

  int getAttributeLocation(String attibute) =>
      using((arena) => glGetAttribLocation(_id, attibute.toNativeUtf8(allocator: arena).cast()));
}
