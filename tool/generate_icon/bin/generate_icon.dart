import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart';

void main() {
  const size = 1024;
  const out  = '../../assets/icon';

  Directory(out).createSync(recursive: true);

  // ── Brand colours ────────────────────────────────────────────────────────────
  final charcoal = ColorRgb8(0x1A, 0x1A, 0x1A);
  final lime     = ColorRgb8(0xC5, 0xD8, 0x00);
  final limeA    = ColorRgba8(0xC5, 0xD8, 0x00, 0xFF);
  final clear    = ColorRgba8(0, 0, 0, 0);

  // ── Full icon (charcoal bg + lime "3F") ──────────────────────────────────────
  {
    final img = Image(width: size, height: size);
    fill(img, color: charcoal);
    _drawRoundRect(img, 80, 80, size - 80, size - 80,
        radius: 90, color: lime, strokeWidth: 26);
    _drawText3F(img, size, lime);

    File('$out/app_icon.png').writeAsBytesSync(encodePng(img));
    print('✓  app_icon.png');
  }

  // ── Adaptive foreground (transparent bg + lime "3F") ─────────────────────────
  {
    final img = Image(width: size, height: size, numChannels: 4);
    fill(img, color: clear);
    _drawText3F(img, size, limeA);

    File('$out/app_icon_fg.png').writeAsBytesSync(encodePng(img));
    print('✓  app_icon_fg.png');
  }

  print('\nDone! Run from the project root:');
  print('  flutter pub run flutter_launcher_icons');
}

// ── Draw "3F" using built-in arial48 font, scaled with copyResize ─────────────

void _drawText3F(Image dst, int size, Color textColor) {
  const text = '3F';
  final font  = arial48;

  // Measure width by summing xadvance for each character
  int textW = 0;
  int textH = font.lineHeight;
  for (final ch in text.runes) {
    final glyph = font.characters[ch];
    if (glyph != null) textW += glyph.xAdvance;
  }

  // Render into a small surface
  final small = Image(width: textW + 4, height: textH + 4, numChannels: 4);
  fill(small, color: ColorRgba8(0, 0, 0, 0));
  drawString(small, text, font: font, x: 2, y: 2, color: textColor);

  // Scale up so text spans ~50% of icon width
  final scale  = (size * 0.50) / textW;
  final scaled = copyResize(
    small,
    width:         (small.width  * scale).round(),
    height:        (small.height * scale).round(),
    interpolation: Interpolation.cubic,
  );

  // Composite centred, shifted slightly upward
  final dx = (size - scaled.width)  ~/ 2;
  final dy = (size - scaled.height) ~/ 2;
  compositeImage(dst, scaled, dstX: dx, dstY: dy);
}

// ── Rounded-rect stroke ───────────────────────────────────────────────────────

void _drawRoundRect(
  Image img,
  int x0, int y0, int x1, int y1, {
  required int radius,
  required Color color,
  required int strokeWidth,
}) {
  final r = radius;

  // Straight edges
  for (var t = 0; t < strokeWidth; t++) {
    drawLine(img, x1: x0 + r, y1: y0 + t, x2: x1 - r, y2: y0 + t,
        color: color);
    drawLine(img, x1: x0 + r, y1: y1 - t, x2: x1 - r, y2: y1 - t,
        color: color);
    drawLine(img, x1: x0 + t, y1: y0 + r, x2: x0 + t, y2: y1 - r,
        color: color);
    drawLine(img, x1: x1 - t, y1: y0 + r, x2: x1 - t, y2: y1 - r,
        color: color);
  }

  // Corner arcs
  _arc(img, x0 + r, y0 + r, r, math.pi,       3 * math.pi / 2, color, strokeWidth);
  _arc(img, x1 - r, y0 + r, r, 3 * math.pi / 2, 2 * math.pi,   color, strokeWidth);
  _arc(img, x1 - r, y1 - r, r, 0,              math.pi / 2,     color, strokeWidth);
  _arc(img, x0 + r, y1 - r, r, math.pi / 2,   math.pi,         color, strokeWidth);
}

void _arc(Image img, int cx, int cy, int r,
    double startRad, double endRad, Color color, int strokeWidth) {
  const steps = 300;
  for (var t = 0; t < strokeWidth; t++) {
    for (var i = 0; i <= steps; i++) {
      final angle = startRad + (endRad - startRad) * i / steps;
      final x = (cx + (r - t) * math.cos(angle)).round();
      final y = (cy + (r - t) * math.sin(angle)).round();
      if (x >= 0 && y >= 0 && x < img.width && y < img.height) {
        img.setPixel(x, y, color);
      }
    }
  }
}
