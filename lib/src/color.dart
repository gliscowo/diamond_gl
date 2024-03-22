import 'package:vector_math/vector_math.dart';

class Color {
  final Vector4 _storage;

  static final Color black = Color.rgb(0, 0, 0);
  static final Color white = Color.rgb(1, 1, 1);
  static final Color red = Color.rgb(1, 0, 0);
  static final Color green = Color.rgb(0, 1, 0);
  static final Color blue = Color.rgb(0, 0, 1);

  Color(Vector4 color) : _storage = Vector4.copy(color);

  Color.rgb(double red, double green, double blue, [double alpha = 1]) : this(Vector4(red, green, blue, alpha));

  factory Color.ofArgb(int argb) {
    return Color.rgb(
      ((argb >> 16) & 0xFF) / 255,
      ((argb >> 8) & 0xFF) / 255,
      (argb & 0xFF) / 255,
      (argb >>> 24) / 255,
    );
  }

  factory Color.ofRgb(int rgb) {
    return Color.rgb(
      ((rgb >> 16) & 0xFF) / 255,
      ((rgb >> 8) & 0xFF) / 255,
      (rgb & 0xFF) / 255,
    );
  }

  factory Color.ofHsv(double hue, double saturation, double value, [double alpha = 1]) {
    final rgbColor = Vector4.zero();
    Colors.hsvToRgb(Vector4(hue, saturation, value, alpha), rgbColor);
    return Color(rgbColor);
  }

  double get r => _storage.r;
  double get g => _storage.g;
  double get b => _storage.b;
  double get a => _storage.a;

  int get rgb => (r * 255).toInt() << 16 | (g * 255).toInt() << 8 | (b * 255).toInt();

  int get argb => (a * 255).toInt() << 24 | (r * 255).toInt() << 16 | (g * 255).toInt() << 8 | (b * 255).toInt();

  Vector4 get hsv {
    final hsv = Vector4.zero();
    Colors.rgbToHsv(_storage, hsv);
    return hsv;
  }

  Color copyWith({double? r, double? g, double? b, double? a}) =>
      Color.rgb(r ?? this.r, g ?? this.g, b ?? this.b, a ?? this.a);

  Vector4 asVector() => Vector4.copy(_storage);

  String toHexString(bool alpha) {
    return alpha ? argb.toRadixString(16).padLeft(8, "0") : rgb.toRadixString(16).padLeft(6, "0");
  }
}
