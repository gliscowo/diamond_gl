import 'package:logging/logging.dart';

Logger? baseLogger;
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
