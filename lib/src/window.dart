import 'dart:async';
import 'dart:ffi';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart';
import 'package:vector_math/vector_math.dart';

import 'diamond_gl_base.dart';

typedef _GLFWwindowposfun = Void Function(Pointer<GLFWwindow>, Int, Int);
typedef _GLFWwindowsizefun = Void Function(Pointer<GLFWwindow>, Int, Int);
typedef _GLFWwindowclosefun = Void Function(Pointer<GLFWwindow>);
typedef _GLFWwindowrefreshfun = Void Function(Pointer<GLFWwindow>);
typedef _GLFWwindowfocusfun = Void Function(Pointer<GLFWwindow>, Int);
typedef _GLFWwindowiconifyfun = Void Function(Pointer<GLFWwindow>, Int);
typedef _GLFWwindowmaximizefun = Void Function(Pointer<GLFWwindow>, Int);
typedef _GLFWframebuffersizefun = Void Function(Pointer<GLFWwindow>, Int, Int);
typedef _GLFWwindowcontentscalefun = Void Function(Pointer<GLFWwindow>, Float, Float);

typedef _GLFWmousebuttonfun = Void Function(Pointer<GLFWwindow>, Int, Int, Int);
typedef _GLFWcursorposfun = Void Function(Pointer<GLFWwindow>, Double, Double);
typedef _GLFWcursorenterfun = Void Function(Pointer<GLFWwindow>, Int);
typedef _GLFWscrollfun = Void Function(Pointer<GLFWwindow>, Double, Double);

typedef _GLFWkeyfun = Void Function(Pointer<GLFWwindow>, Int, Int, Int, Int);
typedef _GLFWcharfun = Void Function(Pointer<GLFWwindow>, UnsignedInt);
typedef _GLFWcharmodsfun = Void Function(Pointer<GLFWwindow>, UnsignedInt, Int);

typedef _GLFWdropfun = Void Function(Pointer<GLFWwindow>, Int, Pointer<Pointer<Char>>);

class OpenGLVersion {
  final int major, minor;
  final bool coreProfile;

  const OpenGLVersion(this.major, this.minor, {this.coreProfile = false});
}

class Window {
  /// The default OpenGL version of contexts created through
  /// this class: 4.5 core profile
  static const defaultContextVersion = OpenGLVersion(4, 5, coreProfile: true);

  static final Map<int, Window> _knownWindows = {};

  late final Pointer<GLFWwindow> _handle;
  final StreamController<WindowMoveEvent> _moveListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowResizeEvent> _resizeListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowCloseEvent> _closeListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowRefreshEvent> _refreshListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowFocusEvent> _focusListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowIconifyEvent> _iconifyListeners = StreamController.broadcast(sync: true);
  final StreamController<WindowMaximizeEvent> _maximizeListeners = StreamController.broadcast(sync: true);
  final StreamController<FramebufferResizeEvent> _framebufferResizeListeners = StreamController.broadcast(sync: true);
  final StreamController<ContentRescaleEvent> _rescaleListeners = StreamController.broadcast(sync: true);

  final StreamController<MouseInputEvent> _mouseInputListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseMoveEvent> _mouseMoveListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseEnterEvent> _mouseEnterListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseLeaveEvent> _mouseLeaveListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseScrollEvent> _mouseScrollListeners = StreamController.broadcast(sync: true);

  final StreamController<KeyInputEvent> _keyInputListeners = StreamController.broadcast(sync: true);
  final StreamController<CharEvent> _charInputListeners = StreamController.broadcast(sync: true);
  final StreamController<CharModsEvent> _charModsListeners = StreamController.broadcast(sync: true);

  final StreamController<FilesDroppedEvent> _dropListeners = StreamController.broadcast(sync: true);

  final Vector2 _cursorPos = Vector2.zero();
  late int _x;
  late int _y;
  late int _framebufferWidth;
  late int _framebufferHeight;
  int _width;
  int _height;

  String _title;
  bool _fullscreen = false;
  int _restoreX = 0;
  int _restoreY = 0;
  int _restoreWidth = 0;
  int _restoreHeight = 0;

  Window(
    int width,
    int height,
    String title, {
    OpenGLVersion contextVersion = defaultContextVersion,
    bool floating = false,
    int msaaSamples = 0,
    bool debug = false,
  })  : _title = title,
        _width = width,
        _height = height {
    glfw.windowHint(glfwContextVersionMajor, contextVersion.major);
    glfw.windowHint(glfwContextVersionMinor, contextVersion.minor);
    glfw.windowHint(glfwOpenglProfile, contextVersion.coreProfile ? glfwOpenglCoreProfile : glfwOpenglCompatProfile);

    if (floating) glfw.windowHint(glfwFloating, glfwTrue);
    if (msaaSamples != 0) glfw.windowHint(glfwSamples, msaaSamples);
    if (debug) glfw.windowHint(glfwOpenglDebugContext, glfwTrue);

    using((arena) {
      _handle = glfw.createWindow(width, height, title.toNativeUtf8(allocator: arena).cast(), nullptr, nullptr);

      if (_handle.address == 0) {
        final stringPtr = arena<Pointer<Utf8>>();
        final errorCode = glfw.getError(stringPtr.cast());

        final errorDescription = stringPtr.value.toDartString();

        glfw.terminate();
        throw WindowInitializationException(errorCode, errorDescription);
      }

      final x = arena<Int>();
      final y = arena<Int>();

      glfw.getWindowPos(_handle, x, y);
      _x = x.value;
      _y = y.value;

      glfw.getFramebufferSize(_handle, x, y);
      _framebufferWidth = x.value;
      _framebufferHeight = y.value;
    });

    _knownWindows[_handle.address] = this;
    glfw.setWindowPosCallback(_handle, Pointer.fromFunction<_GLFWwindowposfun>(_onMove));
    glfw.setWindowSizeCallback(_handle, Pointer.fromFunction<_GLFWwindowsizefun>(_onResize));
    glfw.setWindowCloseCallback(_handle, Pointer.fromFunction<_GLFWwindowclosefun>(_onClose));
    glfw.setWindowRefreshCallback(_handle, Pointer.fromFunction<_GLFWwindowrefreshfun>(_onRefresh));
    glfw.setWindowFocusCallback(_handle, Pointer.fromFunction<_GLFWwindowfocusfun>(_onFocus));
    glfw.setWindowIconifyCallback(_handle, Pointer.fromFunction<_GLFWwindowiconifyfun>(_onIconify));
    glfw.setWindowMaximizeCallback(_handle, Pointer.fromFunction<_GLFWwindowmaximizefun>(_onMaximize));
    glfw.setFramebufferSizeCallback(_handle, Pointer.fromFunction<_GLFWframebuffersizefun>(_onFramebufferResize));
    glfw.setWindowContentScaleCallback(_handle, Pointer.fromFunction<_GLFWwindowcontentscalefun>(_onContentRescale));

    glfw.setMouseButtonCallback(_handle, Pointer.fromFunction<_GLFWmousebuttonfun>(_onMouseButton));
    glfw.setCursorPosCallback(_handle, Pointer.fromFunction<_GLFWcursorposfun>(_onMousePos));
    glfw.setCursorEnterCallback(_handle, Pointer.fromFunction<_GLFWcursorenterfun>(_onMouseEnter));
    glfw.setScrollCallback(_handle, Pointer.fromFunction<_GLFWscrollfun>(_onScroll));

    glfw.setKeyCallback(_handle, Pointer.fromFunction<_GLFWkeyfun>(_onKey));
    glfw.setCharCallback(_handle, Pointer.fromFunction<_GLFWcharfun>(_onChar));
    glfw.setCharModsCallback(_handle, Pointer.fromFunction<_GLFWcharmodsfun>(_onCharMods));

    glfw.setDropCallback(_handle, Pointer.fromFunction<_GLFWdropfun>(_onDrop));
  }

  static void _onMove(Pointer<GLFWwindow> handle, int x, int y) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    final deltaX = x - window._x, deltaY = y - window._y;
    if (deltaX != 0 || deltaY != 0) {
      window._moveListeners.add((deltaX: deltaX, deltaY: deltaY));
    }

    window._x = x;
    window._y = y;
  }

  static void _onResize(Pointer<GLFWwindow> handle, int width, int height) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._width = width;
    window._height = height;

    window._resizeListeners.add((newWidth: width, newHeight: height));
  }

  static void _onClose(Pointer<GLFWwindow> handle) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._closeListeners.add(const ());
  }

  static void _onRefresh(Pointer<GLFWwindow> handle) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._refreshListeners.add(const ());
  }

  static void _onFocus(Pointer<GLFWwindow> handle, int focus) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._focusListeners.add((nowFocused: focus == glfwTrue));
  }

  static void _onIconify(Pointer<GLFWwindow> handle, int iconify) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._iconifyListeners.add((nowIconified: iconify == glfwTrue));
  }

  static void _onMaximize(Pointer<GLFWwindow> handle, int maximize) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._maximizeListeners.add((nowMaximized: maximize == glfwTrue));
  }

  static void _onFramebufferResize(Pointer<GLFWwindow> handle, int width, int height) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._framebufferWidth = width;
    window._framebufferHeight = height;

    window._framebufferResizeListeners.add((newWidth: width, newHeight: height));
  }

  static void _onContentRescale(Pointer<GLFWwindow> handle, double xScale, double yScale) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._rescaleListeners.add((xScale: xScale, yScale: yScale));
  }

  static void _onMouseButton(Pointer<GLFWwindow> handle, int button, int action, int mods) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._mouseInputListeners.add((button: button, action: action, mods: mods));
  }

  static void _onMousePos(Pointer<GLFWwindow> handle, double mouseX, double mouseY) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    final deltaX = mouseX - window._cursorPos.x, deltaY = mouseY - window._cursorPos.y;
    if (deltaX != 0 || deltaY != 0) {
      window._mouseMoveListeners.add((deltaX: deltaX, deltaY: deltaY));
    }

    window._cursorPos.x = mouseX;
    window._cursorPos.y = mouseY;
  }

  static void _onMouseEnter(Pointer<GLFWwindow> handle, int enter) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    (enter == glfwTrue ? window._mouseEnterListeners : window._mouseLeaveListeners).add(const ());
  }

  static void _onScroll(Pointer<GLFWwindow> handle, double xOffset, double yOffset) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._mouseScrollListeners.add((xOffset: xOffset, yOffset: yOffset));
  }

  static void _onKey(Pointer<GLFWwindow> handle, int key, int scancode, int action, int mods) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._keyInputListeners.add((key: key, scancode: scancode, action: action, mods: mods));
  }

  static void _onChar(Pointer<GLFWwindow> handle, int codepoint) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._charInputListeners.add((codepoint: codepoint));
  }

  static void _onCharMods(Pointer<GLFWwindow> handle, int codepoint, int mods) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._charModsListeners.add((codepoint: codepoint, mods: mods));
  }

  static void _onDrop(Pointer<GLFWwindow> handle, int pathCount, Pointer<Pointer<Char>> nativePaths) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    final paths = List.filled(pathCount, '');
    for (var i = 0; i < pathCount; i++) {
      paths[i] = nativePaths[i].cast<Utf8>().toDartString();
    }

    window._dropListeners.add((paths: paths));
  }

  void activateContext() => glfw.makeContextCurrent(_handle);
  static void dropContext() => glfw.makeContextCurrent(nullptr);

  void _enterFullscreen() {
    _restoreX = _x;
    _restoreY = _y;
    _restoreWidth = _width;
    _restoreHeight = _height;

    final width = malloc<Int>();
    final height = malloc<Int>();
    final monitors = malloc<Int>();

    final monitor = glfw.getMonitors(monitors)[0];
    glfw.getMonitorWorkarea(monitor, nullptr, nullptr, width, height);

    glfw.setWindowMonitor(_handle, monitor, 0, 0, width.value, height.value, glfwDontCare);

    malloc.free(width);
    malloc.free(height);
    malloc.free(monitors);
  }

  void _exitFullscreen() =>
      glfw.setWindowMonitor(_handle, nullptr, _restoreX, _restoreY, _restoreWidth, _restoreHeight, glfwDontCare);

  bool get fullscreen => _fullscreen;
  set fullscreen(bool value) {
    if (value == _fullscreen) return;

    _fullscreen = value;
    _fullscreen ? _enterFullscreen() : _exitFullscreen();
  }

  String get title => _title;
  set title(String value) {
    if (value == _title) return;

    _title = value;
    using((arena) {
      glfw.setWindowTitle(_handle, title.toNativeUtf8(allocator: arena).cast());
    });
  }

  void setIcon(Image icon) {
    var image = malloc<GLFWimage>();
    image.ref.width = icon.width;
    image.ref.height = icon.height;

    final convertedIcon = icon.convert(format: Format.uint8, numChannels: 4, alpha: 255);

    final bufferSize = convertedIcon.width * convertedIcon.height * convertedIcon.numChannels;
    final glfwBuffer = malloc<Uint8>(bufferSize);

    glfwBuffer.asTypedList(bufferSize).setRange(0, bufferSize, convertedIcon.data!.buffer.asUint8List());
    image.ref.pixels = glfwBuffer.cast();

    glfw.setWindowIcon(_handle, 1, image);
    malloc.free(glfwBuffer);
    malloc.free(image);
  }

  /// Prepare this window for the next frame and present
  /// the current one. Equivalent to a call to [glfw.swapBuffers]
  /// followed by [glfw.pollEvents]
  void nextFrame() {
    glfw.swapBuffers(_handle);
    glfw.pollEvents();
  }

  void dispose() {
    glfw.destroyWindow(_handle);
    _knownWindows.remove(_handle.address);
  }

  double get cursorX => _cursorPos.x;
  set cursorX(double value) {
    if (value == _cursorPos.x) return;

    _cursorPos.x = value;
    glfw.setCursorPos(_handle, _cursorPos.x, _cursorPos.y);
  }

  double get cursorY => _cursorPos.y;
  set cursorY(double value) {
    if (value == _cursorPos.y) return;

    _cursorPos.y = value;
    glfw.setCursorPos(_handle, _cursorPos.x, _cursorPos.y);
  }

  Vector2 get cursorPos => _cursorPos.xy;

  Stream<WindowMoveEvent> get onMove => _moveListeners.stream;
  Stream<WindowResizeEvent> get onResize => _resizeListeners.stream;
  Stream<WindowCloseEvent> get onClose => _closeListeners.stream;
  Stream<WindowRefreshEvent> get onRefresh => _refreshListeners.stream;
  Stream<WindowFocusEvent> get onFocus => _focusListeners.stream;
  Stream<WindowIconifyEvent> get onIconify => _iconifyListeners.stream;
  Stream<WindowMaximizeEvent> get onMaximize => _maximizeListeners.stream;
  Stream<FramebufferResizeEvent> get onFramebufferResize => _framebufferResizeListeners.stream;
  Stream<ContentRescaleEvent> get onContentRescale => _rescaleListeners.stream;

  Stream<MouseInputEvent> get onMouseButton => _mouseInputListeners.stream;
  Stream<MouseMoveEvent> get onMouseMove => _mouseMoveListeners.stream;
  Stream<MouseEnterEvent> get onMouseEnter => _mouseEnterListeners.stream;
  Stream<MouseLeaveEvent> get onMouseLeave => _mouseLeaveListeners.stream;
  Stream<MouseScrollEvent> get onMouseScroll => _mouseScrollListeners.stream;

  Stream<KeyInputEvent> get onKey => _keyInputListeners.stream;
  Stream<CharEvent> get onChar => _charInputListeners.stream;
  Stream<CharModsEvent> get onCharMods => _charModsListeners.stream;

  Stream<FilesDroppedEvent> get onFilesDropped => _dropListeners.stream;

  int get x => _x;
  int get y => _y;
  int get width => _width;
  int get height => _height;
  int get framebufferWidth => _framebufferWidth;
  int get framebufferHeight => _framebufferHeight;
  Pointer<GLFWwindow> get handle => _handle;
}

typedef WindowMoveEvent = ({int deltaX, int deltaY});
typedef WindowResizeEvent = ({int newWidth, int newHeight});
typedef WindowCloseEvent = ();
typedef WindowRefreshEvent = ();
typedef WindowFocusEvent = ({bool nowFocused});
typedef WindowIconifyEvent = ({bool nowIconified});
typedef WindowMaximizeEvent = ({bool nowMaximized});
typedef FramebufferResizeEvent = ({int newWidth, int newHeight});
typedef ContentRescaleEvent = ({double xScale, double yScale});

typedef MouseInputEvent = ({int button, int action, int mods});
typedef MouseMoveEvent = ({double deltaX, double deltaY});
typedef MouseEnterEvent = ();
typedef MouseLeaveEvent = ();
typedef MouseScrollEvent = ({double xOffset, double yOffset});

typedef KeyInputEvent = ({int key, int scancode, int action, int mods});
typedef CharEvent = ({int codepoint});
typedef CharModsEvent = ({int codepoint, int mods});

typedef FilesDroppedEvent = ({List<String> paths});

class WindowInitializationException {
  final int glfwErrorCode;
  final String errorDescription;

  WindowInitializationException(this.glfwErrorCode, this.errorDescription);

  @override
  String toString() => 'could not create window: $errorDescription (glfw error $glfwErrorCode)';
}
