import 'package:clawclip/src/debug.dart';
import 'package:logging/logging.dart';

class GlLoggingConfig {
  final bool Function(GlMessageType type, GlSeverity severity) messageFilter;
  final bool printStacktraces;

  const GlLoggingConfig({this.messageFilter = _severityLowAllTypes, this.printStacktraces = false});

  static bool _severityLowAllTypes(GlMessageType type, GlSeverity severity) => severity >= .low;
  static const severityLowAllTypesNoStacktraces = GlLoggingConfig();
}

class GlfwLoggingConfig {
  final bool printStacktraces;
  const GlfwLoggingConfig({this.printStacktraces = false});

  static const noStacktraces = GlfwLoggingConfig();
}

typedef ClawclipLoggingConfig = ({Logger? baseLogger, GlLoggingConfig? glConfig, GlfwLoggingConfig? glfwConfig});

// ---

ClawclipLoggingConfig? _loggingConfig;
ClawclipLoggingConfig? get clawlipLoggingConfig => _loggingConfig;

void clawclipSetupLoggingInIsolate({Logger? baseLogger, GlLoggingConfig? glConfig, GlfwLoggingConfig? glfwConfig}) {
  assert(_loggingConfig == null, 'attempted to configure clawclip logging twice');
  _loggingConfig = (baseLogger: baseLogger, glConfig: glConfig, glfwConfig: glfwConfig);

  if (glfwConfig != null) {
    attachGlfwErrorCallback();
  }
}

// ---

Logger? createLogger(String system) {
  if (clawlipLoggingConfig?.baseLogger == null) return null;
  return Logger('${clawlipLoggingConfig!.baseLogger!.name}.$system');
}
