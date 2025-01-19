import 'dart:async';
import 'dart:ffi';

import 'package:dart_glfw/dart_glfw.dart';
import 'package:ffi/ffi.dart';
import 'package:vector_math/vector_math.dart';

import 'diamond_gl_base.dart';

typedef _GLFWwindowresizefun = Void Function(Pointer<GLFWwindow>, Int, Int);
typedef _GLFWwindowposfun = Void Function(Pointer<GLFWwindow>, Int, Int);

typedef _GLFWkeyfun = Void Function(Pointer<GLFWwindow>, Int, Int, Int, Int);
typedef _GLFWcharfun = Void Function(Pointer<GLFWwindow>, UnsignedInt);
typedef _GLFWcursorposfun = Void Function(Pointer<GLFWwindow>, Double, Double);
typedef _GLFWscrollfun = Void Function(Pointer<GLFWwindow>, Double, Double);
typedef _GLFWmousebuttonfun = Void Function(Pointer<GLFWwindow>, Int, Int, Int);

class OpenGLVersion {
  final int major, minor;
  final bool coreProfile;

  const OpenGLVersion(
    this.major,
    this.minor, {
    this.coreProfile = false,
  });
}

class Window {
  /// The default OpenGL version of contexts created through
  /// this class: 4.5 core profile
  static const defaultContextVersion = OpenGLVersion(4, 5, coreProfile: true);

  static final Map<int, Window> _knownWindows = {};

  late final Pointer<GLFWwindow> _handle;
  final StreamController<Window> _resizeListeners = StreamController.broadcast(sync: true);
  final StreamController<int> _charInputListeners = StreamController.broadcast(sync: true);
  final StreamController<KeyInputEvent> _keyInputListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseInputEvent> _mouseInputListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseMoveEvent> _mouseMoveListeners = StreamController.broadcast(sync: true);
  final StreamController<MouseScrollEvent> _mouseScrollListeners = StreamController.broadcast(sync: true);
  final Vector2 _cursorPos = Vector2.zero();

  late int _x;
  late int _y;
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

    _handle = title.withAsNative((utf8) => glfw.createWindow(width, height, utf8.cast(), nullptr, nullptr));

    if (_handle.address == 0) {
      glfw.terminate();

      //TODO better exception
      throw Exception("Failed to create window");
    }

    final windowX = malloc<Int>();
    final windowY = malloc<Int>();

    glfw.getWindowPos(_handle, windowX, windowY);
    _x = windowX.value;
    _y = windowY.value;

    malloc.free(windowX);
    malloc.free(windowY);

    _knownWindows[_handle.address] = this;
    glfw.setWindowSizeCallback(_handle, Pointer.fromFunction<_GLFWwindowresizefun>(_onResize));
    glfw.setWindowPosCallback(_handle, Pointer.fromFunction<_GLFWwindowposfun>(_onMove));
    glfw.setCursorPosCallback(_handle, Pointer.fromFunction<_GLFWcursorposfun>(_onMousePos));
    glfw.setMouseButtonCallback(_handle, Pointer.fromFunction<_GLFWmousebuttonfun>(_onMouseButton));
    glfw.setScrollCallback(_handle, Pointer.fromFunction<_GLFWscrollfun>(_onScroll));
    glfw.setCharCallback(_handle, Pointer.fromFunction<_GLFWcharfun>(_onChar));
    glfw.setKeyCallback(_handle, Pointer.fromFunction<_GLFWkeyfun>(_onKey));
  }

  static void _onMove(Pointer<GLFWwindow> handle, int x, int y) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._x = x;
    window._y = y;
  }

  static void _onResize(Pointer<GLFWwindow> handle, int width, int height) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._width = width;
    window._height = height;

    window._resizeListeners.add(window);
  }

  static void _onMousePos(Pointer<GLFWwindow> handle, double mouseX, double mouseY) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    final deltaX = mouseX - window._cursorPos.x, deltaY = mouseY - window._cursorPos.y;
    if (deltaX != 0 || deltaY != 0) {
      window._mouseMoveListeners.add(MouseMoveEvent(deltaX, deltaY));
    }

    window._cursorPos.x = mouseX;
    window._cursorPos.y = mouseY;
  }

  static void _onMouseButton(Pointer<GLFWwindow> handle, int button, int action, int mods) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._mouseInputListeners.add(MouseInputEvent(button, action, mods));
  }

  static void _onScroll(Pointer<GLFWwindow> handle, double xOffset, double yOffset) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._mouseScrollListeners.add(MouseScrollEvent(xOffset, yOffset));
  }

  static void _onChar(Pointer<GLFWwindow> handle, int codepoint) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._charInputListeners.add(codepoint);
  }

  static void _onKey(Pointer<GLFWwindow> handle, int key, int scancode, int action, int mods) {
    if (!_knownWindows.containsKey(handle.address)) return;
    final window = _knownWindows[handle.address]!;

    window._keyInputListeners.add(KeyInputEvent(key, scancode, action, mods));
  }

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
    value.withAsNative((utf8) => glfw.setWindowTitle(_handle, utf8.cast()));
  }

  /// Prepare this window for the next frame and present
  /// the current one. Equivalent to a call to [glfw.swapBuffers]
  /// followed by [glfw.pollEvents]
  void nextFrame() {
    glfw.swapBuffers(_handle);
    glfw.pollEvents();
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

  Stream<Window> get onResize => _resizeListeners.stream;
  Stream<int> get onChar => _charInputListeners.stream;
  Stream<KeyInputEvent> get onKey => _keyInputListeners.stream;
  Stream<MouseInputEvent> get onMouseButton => _mouseInputListeners.stream;
  Stream<MouseMoveEvent> get onMouseMove => _mouseMoveListeners.stream;
  Stream<MouseScrollEvent> get onMouseScroll => _mouseScrollListeners.stream;

  int get x => _x;
  int get y => _y;
  int get width => _width;
  int get height => _height;
  Pointer<GLFWwindow> get handle => _handle;
}

class KeyInputEvent {
  final int key, scancode, action, mods;
  KeyInputEvent(this.key, this.scancode, this.action, this.mods);
}

class MouseInputEvent {
  final int button, action, mods;
  MouseInputEvent(this.button, this.action, this.mods);
}

class MouseMoveEvent {
  final double deltaX, deltaY;
  MouseMoveEvent(this.deltaX, this.deltaY);
}

class MouseScrollEvent {
  final double xOffset, yOffset;
  MouseScrollEvent(this.xOffset, this.yOffset);
}
