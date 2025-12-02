import 'dart:ffi';

import 'package:clawclip/glfw.dart';
import 'package:clawclip/src/clawclip_logging.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:ffi/ffi.dart';

enum GlMessageType {
  marker(glDebugTypeMarker),
  deprecatedBehavior(glDebugTypeDeprecatedBehavior),
  error(glDebugTypeError),
  other(glDebugTypeOther),
  performance(glDebugTypePerformance),
  portability(glDebugTypePortability),
  pushGroup(glDebugTypePushGroup),
  popGroup(glDebugTypePopGroup);

  final int gl;
  const GlMessageType(this.gl);

  static final _nameLookup = {for (final type in GlMessageType.values) type.gl: type.name};
}

enum GlSeverity {
  notification(glDebugSeverityNotification),
  low(glDebugSeverityLow),
  medium(glDebugSeverityMedium),
  high(glDebugSeverityHigh);

  final int gl;
  const GlSeverity(this.gl);

  bool operator >(GlSeverity other) => index > other.index;
  bool operator >=(GlSeverity other) => index >= other.index;
  bool operator <(GlSeverity other) => index < other.index;
  bool operator <=(GlSeverity other) => index <= other.index;

  static final _nameLookup = {for (final type in GlSeverity.values) type.gl: type.name};
}

void attachGlErrorCallbackToContext() {
  gl.enable(glDebugOutput);
  gl.enable(glDebugOutputSynchronous);
  gl.debugMessageCallback(Pointer.fromFunction(_onGlError), nullptr);

  final config = clawlipLoggingConfig!.glConfig!;
  for (final messageType in GlMessageType.values) {
    for (final severity in GlSeverity.values) {
      gl.debugMessageControl(
        glDontCare,
        messageType.gl,
        severity.gl,
        0,
        nullptr,
        config.messageFilter(messageType, severity) ? glTrue : glFalse,
      );
    }
  }
}

void attachGlfwErrorCallback() {
  glfwSetErrorCallback(Pointer.fromFunction(_onGlfwError));
}

final _glLogger = createLogger('opengl');
final _glfwLogger = createLogger('glfw');

void _onGlError(
  int source,
  int type,
  int id,
  int severity,
  int length,
  Pointer<Char> message,
  Pointer<Void> userParam,
) {
  if (_glLogger == null) return;

  final logMessage =
      'OpenGL Debug Message, type ${GlMessageType._nameLookup[type]} severity ${GlSeverity._nameLookup[severity]}: ${message.cast<Utf8>().toDartString()}';

  if (severity > glDebugSeverityLow) {
    _glLogger!.warning(logMessage);
  } else if (severity > glDebugSeverityNotification) {
    _glLogger!.info(logMessage);
  } else {
    _glLogger!.fine(logMessage);
  }

  if (clawlipLoggingConfig!.glConfig!.printStacktraces) _glLogger!.warning(StackTrace.current);
}

void _onGlfwError(int errorCode, Pointer<Char> description) {
  if (_glfwLogger == null) return;

  _glfwLogger!.severe('GLFW Error: ${description.cast<Utf8>().toDartString()} ($errorCode)');
  if (clawlipLoggingConfig!.glfwConfig!.printStacktraces) _glfwLogger!.warning(StackTrace.current);
}
