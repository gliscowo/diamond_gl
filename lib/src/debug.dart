import 'dart:ffi';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/src/diamond_gl_base.dart';
import 'package:ffi/ffi.dart';

const Map<int, String> _glMessageTypes = {
  glDebugTypeMarker: "MARKER",
  glDebugTypeDeprecatedBehavior: "DEPRECATED_BEHAVIOR",
  glDebugTypeError: "ERROR",
  glDebugTypeOther: "OTHER",
  glDebugTypePerformance: "PERFORMANCE",
  glDebugTypePortability: "PORTABILITY",
  glDebugTypePushGroup: "PUSH_GROUP",
  glDebugTypePopGroup: "POP_GROUP",
};

const Map<int, String> _glSeverities = {
  glDebugSeverityNotification: "NOTIFICATION",
  glDebugSeverityLow: "LOW",
  glDebugSeverityMedium: "MEDIUM",
  glDebugSeverityHigh: "HIGH",
};

final class DiamondGLDebugSettings {
  static var minGlDebugSeverity = glDebugSeverityNotification;
  static var printGlDebugStacktrace = false;
  static var printGlfwDebugStacktrace = false;
}

void attachGlErrorCallback() {
  gl.enable(glDebugOutput);
  gl.enable(glDebugOutputSynchronous);
  gl.debugMessageCallback(Pointer.fromFunction(_onGlError), nullptr);
}

void attachGlfwErrorCallback() {
  glfw.setErrorCallback(Pointer.fromFunction(_onGlfwError));
}

final _glLogger = getLogger("opengl");
final _glfwLogger = getLogger("glfw");

void _onGlError(
  int source,
  int type,
  int id,
  int severity,
  int length,
  Pointer<Char> message,
  Pointer<Void> userParam,
) {
  if (_glLogger == null || severity < DiamondGLDebugSettings.minGlDebugSeverity) return;

  _glLogger!.warning(
      "OpenGL Debug Message, type ${_glMessageTypes[type]} severity ${_glSeverities[severity]}: ${message.cast<Utf8>().toDartString()}");
  if (DiamondGLDebugSettings.printGlDebugStacktrace) _glLogger!.warning(StackTrace.current);
}

void _onGlfwError(int errorCode, Pointer<Char> description) {
  if (_glfwLogger == null) return;

  _glfwLogger!.severe('GLFW Error: ${description.cast<Utf8>().toDartString()} ($errorCode)');
  if (DiamondGLDebugSettings.printGlDebugStacktrace) _glfwLogger!.warning(StackTrace.current);
}
