import 'dart:ffi';

import 'package:dart_opengl/dart_opengl.dart';
import 'package:diamond_gl/glfw.dart';
import 'package:diamond_gl/src/diamond_gl_base.dart';
import 'package:ffi/ffi.dart';

const Map<int, String> _glMessageTypes = {
  gl_debugTypeMarker: 'MARKER',
  gl_debugTypeDeprecatedBehavior: 'DEPRECATED_BEHAVIOR',
  gl_debugTypeError: 'ERROR',
  gl_debugTypeOther: 'OTHER',
  gl_debugTypePerformance: 'PERFORMANCE',
  gl_debugTypePortability: 'PORTABILITY',
  gl_debugTypePushGroup: 'PUSH_GROUP',
  gl_debugTypePopGroup: 'POP_GROUP',
};

const Map<int, String> _glSeverities = {
  gl_debugSeverityNotification: 'NOTIFICATION',
  gl_debugSeverityLow: 'LOW',
  gl_debugSeverityMedium: 'MEDIUM',
  gl_debugSeverityHigh: 'HIGH',
};

final class DiamondGLDebugSettings {
  static var minGlDebugSeverity = gl_debugSeverityNotification;
  static var printGlDebugStacktrace = false;
  static var printGlfwDebugStacktrace = false;
}

void attachGlErrorCallback() {
  glEnable(gl_debugOutput);
  glEnable(gl_debugOutputSynchronous);
  glDebugMessageCallback(Pointer.fromFunction(_onGlError), nullptr);
}

void attachGlfwErrorCallback() {
  glfwSetErrorCallback(Pointer.fromFunction(_onGlfwError));
}

final _glLogger = getLogger('opengl');
final _glfwLogger = getLogger('glfw');

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

  final logMessage =
      'OpenGL Debug Message, type ${_glMessageTypes[type]} severity ${_glSeverities[severity]}: ${message.cast<Utf8>().toDartString()}';

  if (severity > gl_debugSeverityLow) {
    _glLogger!.warning(logMessage);
  } else if (severity > gl_debugSeverityNotification) {
    _glLogger!.info(logMessage);
  } else {
    _glLogger!.fine(logMessage);
  }

  if (DiamondGLDebugSettings.printGlDebugStacktrace) _glLogger!.warning(StackTrace.current);
}

void _onGlfwError(int errorCode, Pointer<Char> description) {
  if (_glfwLogger == null) return;

  _glfwLogger!.severe('GLFW Error: ${description.cast<Utf8>().toDartString()} ($errorCode)');
  if (DiamondGLDebugSettings.printGlDebugStacktrace) _glfwLogger!.warning(StackTrace.current);
}
