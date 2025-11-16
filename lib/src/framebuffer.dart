import 'dart:ffi';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';

import 'color.dart';
import 'window.dart';

class GlFramebuffer {
  late int _fbo, _colorAttachmentId;

  int _width, _height;
  late final bool _stencil;

  GlFramebuffer(this._width, this._height, {bool stencil = false}) {
    _stencil = stencil;
    _createFboAndTextures();
  }

  factory GlFramebuffer.trackingWindow(Window window, {bool stencil = false}) =>
      GlFramebuffer(window.framebufferWidth, window.framebufferHeight, stencil: stencil)..trackWindow(window);

  void _createFboAndTextures() {
    final idPointer = malloc<UnsignedInt>();
    glCreateFramebuffers(1, idPointer);
    _fbo = idPointer.value;
    malloc.free(idPointer);

    _colorAttachmentId = _genGlObject((_, ptr) => glCreateTextures(gl_texture2d, 1, ptr));

    glTextureStorage2D(_colorAttachmentId, 1, gl_rgba8, _width, _height);
    glTextureParameteri(_colorAttachmentId, gl_textureMinFilter, gl_linear);
    glTextureParameteri(_colorAttachmentId, gl_textureMagFilter, gl_linear);
    glTextureParameteri(_colorAttachmentId, gl_textureWrapS, gl_clampToEdge);
    glTextureParameteri(_colorAttachmentId, gl_textureWrapT, gl_clampToEdge);

    glNamedFramebufferTexture(_fbo, gl_colorAttachment0, _colorAttachmentId, 0);

    if (_stencil) {
      final depthStencilRenderbuffer = _genGlObject(glCreateRenderbuffers);
      glNamedRenderbufferStorage(depthStencilRenderbuffer, gl_depth24Stencil8, _width, _height);
      glNamedFramebufferRenderbuffer(_fbo, gl_depthStencilAttachment, gl_renderbuffer, depthStencilRenderbuffer);
    } else {
      final depthRenderbuffer = _genGlObject(glCreateRenderbuffers);
      glNamedRenderbufferStorage(depthRenderbuffer, gl_depthComponent, _width, _height);
      glNamedFramebufferRenderbuffer(_fbo, gl_depthAttachment, gl_renderbuffer, depthRenderbuffer);
    }
  }

  void trackWindow(Window window) {
    window.onFramebufferResize.listen((event) {
      _width = event.newWidth;
      _height = event.newHeight;

      delete();
      _createFboAndTextures();
    });
  }

  void clear({Color? color, double? depth, int? stencil}) {
    if (color != null) {
      final colorPtr = malloc<Float>(4);
      colorPtr[0] = color.r;
      colorPtr[1] = color.g;
      colorPtr[2] = color.b;
      colorPtr[3] = color.a;
      glClearNamedFramebufferfv(_fbo, gl_color, 0, colorPtr);
      malloc.free(colorPtr);
    }

    if (depth != null) {
      final depthPtr = malloc<Float>();
      depthPtr.value = depth;
      glClearNamedFramebufferfv(_fbo, gl_depth, 0, depthPtr);
      malloc.free(depthPtr);
    }

    if (stencil != null) {
      final stencilPtr = malloc<Int>();
      stencilPtr.value = stencil;
      glClearNamedFramebufferiv(_fbo, gl_stencil, 0, stencilPtr);
      malloc.free(stencilPtr);
    }
  }

  void bind({bool draw = true, bool read = true}) => glBindFramebuffer(_target(draw, read), _fbo);
  void unbind({bool draw = true, bool read = true}) => glBindFramebuffer(_target(draw, read), 0);

  void delete() {
    _deleteGlObject(glDeleteFramebuffers, _fbo);
    _deleteGlObject(glDeleteTextures, _colorAttachmentId);
  }

  int get width => _width;
  int get height => _height;
  int get colorAttachment => _colorAttachmentId;
  int get fbo => _fbo;

  int _target(bool draw, bool read) => switch ((draw, read)) {
    (true, true) => gl_framebuffer,
    (true, false) => gl_drawFramebuffer,
    (false, true) => gl_readFramebuffer,
    _ => throw ArgumentError('Either draw or read must be set'),
  };

  int _genGlObject(void Function(int, Pointer<UnsignedInt>) factory) {
    final object = malloc<UnsignedInt>();
    factory(1, object);
    final objectId = object.value;
    malloc.free(object);

    return objectId;
  }

  int _deleteGlObject(void Function(int, Pointer<UnsignedInt>) destructor, int resource) {
    final object = malloc<UnsignedInt>();
    object.value = resource;

    destructor(1, object);
    final objectId = object.value;
    malloc.free(object);

    return objectId;
  }
}
