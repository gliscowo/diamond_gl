import 'package:dart_glfw/dart_glfw.dart';
import 'package:dart_opengl/dart_opengl.dart';
import 'package:logging/logging.dart';

final gl = loadOpenGLFromPath();
final glfw = loadGLFWFromPath('');

late final Logger? baseLogger;
Logger? getLogger(String system) {
  if (baseLogger == null) return null;
  return Logger('${baseLogger!.name}.$system');
}

bool _initialized = false;
bool get diamondGLInitialized => _initialized;

void initDiamondGL({Logger? logger}) {
  if (_initialized) return;

  baseLogger = logger;
  _initialized = true;
}
