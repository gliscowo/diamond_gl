import 'package:dart_opengl/dart_opengl.dart';

import 'buffer.dart';
import 'diamond_gl_base.dart';
import 'shader.dart';

enum VertexElement {
  float(4, glFloat);

  final int size, glType;
  const VertexElement(this.size, this.glType);
}

class VertexDescriptor<VertexFunction extends Function> {
  static final _logger = getLogger('vertex_descriptor');
  static final _missingAttrs = Expando<Set<String>>();

  final VertexFunction Function(BufferWriter) _builderFactory;
  final List<_VertexAttribute> _attributes = [];
  int _vertexSize = 0;

  VertexDescriptor(void Function(void Function(String, VertexElement, int)) attributeSetup, this._builderFactory) {
    attributeSetup((name, element, count) {
      _attributes.add(_VertexAttribute(name, element, count, _vertexSize));
      _vertexSize += element.size * count;
    });
  }

  void prepareAttributes(int vao, GlProgram program) {
    for (final attr in _attributes) {
      final location = program.getAttributeLocation(attr.name);
      if (location == -1 && _isKnownToMissAttr(program, attr.name)) {
        _logger?.warning('Did not find attribute "${attr.name}" in program "${program.name}"');
        _markMissingAttr(program, attr.name);

        continue;
      }

      gl.enableVertexArrayAttrib(vao, location);
      gl.vertexArrayAttribBinding(vao, location, 0);
      gl.vertexArrayAttribFormat(
        vao,
        location,
        attr.count,
        attr.element.glType,
        glFalse,
        attr.offset,
      );
    }
  }

  static bool _isKnownToMissAttr(GlProgram program, String attr) => !(_missingAttrs[program]?.contains(attr) ?? false);

  static void _markMissingAttr(GlProgram program, String attr) {
    if (_missingAttrs[program] == null) _missingAttrs[program] = <String>{};
    _missingAttrs[program]!.add(attr);
  }

  VertexFunction createBuilder(BufferWriter buffer) => _builderFactory(buffer);
  int get vertexSize => _vertexSize;
}

class _VertexAttribute {
  final String name;
  final VertexElement element;
  final int count, offset;

  _VertexAttribute(this.name, this.element, this.count, this.offset);
}
