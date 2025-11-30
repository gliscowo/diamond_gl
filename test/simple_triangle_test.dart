import 'dart:math';

import 'package:diamond_gl/diamond_gl.dart';
import 'package:diamond_gl/glfw.dart';
import 'package:diamond_gl/opengl.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart';

typedef Vertex = ({Vector3 pos, double yOffset, Color color});
final vertexDescriptor = VertexDescriptor<Vertex>([
  .f32x3(name: 'aPos', getter: (vertex) => vertex.pos),
  .f32(name: 'aYOffset', getter: (vertex) => vertex.yOffset),
  .color(name: 'aColor', getter: (vertex) => vertex.color),
]);

const vertexShaderSource = '''
#version 330 core

in vec3 aPos;
in vec4 aColor;
in float aYOffset;

out vec4 vColor;

void main() {
  gl_Position = vec4(aPos.x, aPos.y + aYOffset, aPos.z, 1.0);
  vColor = aColor;
}
''';

const fragmentShaderSource = '''
#version 330 core

in vec4 vColor;
out vec4 fragColor;

void main() {
  fragColor = vColor;
}
''';

void main() {
  test('simple triangle', () {
    Logger.root.onRecord.listen((event) {
      print('[${event.loggerName}] (${event.level}) ${event.message}');
    });
    initDiamondGL(logger: Logger('dgl'));
    attachGlErrorCallback();
    attachGlfwErrorCallback();

    glfwInitHint(glfwWaylandLibdecor, glfwWaylandDisableLibdecor);

    glfwInit();
    final window = Window(800, 600, 'diamond_gl triangle test', flags: [.transparentFramebuffer, .undecorated]);

    window.activateContext();
    window.onFramebufferResize.listen((event) {
      gl.viewport(0, 0, event.newWidth, event.newHeight);
    });

    print(glfwGetWindowAttrib(window.handle, glfwDecorated));

    glfwSwapInterval(0);

    final vertexShader = GlShader('vertexShaderSource', vertexShaderSource, .vertex);
    final fragmentShader = GlShader('fragmentShaderSource', fragmentShaderSource, .fragment);

    final program = GlProgram('theProgram', [vertexShader, fragmentShader]);
    program.use();

    final mesh = MeshBuffer(vertexDescriptor, program);

    while (glfwWindowShouldClose(window.handle) != glfwTrue) {
      gl.clearColor(1, 1, 1, 0);
      gl.clear(glColorBufferBit);

      final color1 = Color.ofHsv((glfwGetTime() / 15) % 1, .75, 1);
      final color2 = Color.ofHsv((glfwGetTime() / 10) % 1, .75, 1);
      final color3 = Color.ofHsv((glfwGetTime() / 5) % 1, .75, 1);

      mesh
        ..clear()
        ..writeVertices([
          (pos: Vector3(0, .5, 0), yOffset: sin(glfwGetTime()) * .2, color: color1),
          (pos: Vector3(-.5, -.5, 0), yOffset: sin(glfwGetTime() * 4) * .05, color: color2),
          (pos: Vector3(.5, -.5, 0), yOffset: sin(glfwGetTime() * 8) * .05, color: color3),
        ])
        ..upload(usage: .dynamicDraw)
        ..draw();

      glfwPollEvents();
      glfwSwapBuffers(window.handle);
    }
  });
}
