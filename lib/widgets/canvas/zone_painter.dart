import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:airreader/models/environment_zone.dart';

/// Paints environment zones as semi-transparent coloured rectangles.
///
/// Renders:
///   - Filled rect at 25% opacity (zone colour)
///   - Dashed border at 70% opacity
///   - Zone type icon glyph + label at the centre
///   - Thicker solid highlight border for the selected zone
///   - Live preview rect while the user draws a new zone (two-click pattern)
class ZonePainter extends CustomPainter {
  ZonePainter({
    required this.zones,
    required this.scale,
    this.selectedZoneId,
    this.previewStart,
    this.previewCursor,
    this.previewZoneType,
  });

  final List<EnvironmentZone> zones;
  final double scale;
  final String? selectedZoneId;
  final Offset? previewStart;
  final Offset? previewCursor;
  final ZoneType? previewZoneType;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static Path _dashedRect(Rect r, double dash, double gap) {
    final path = Path();
    // Top edge
    double x = r.left;
    while (x < r.right) {
      path.moveTo(x, r.top);
      path.lineTo(math.min(x + dash, r.right), r.top);
      x += dash + gap;
    }
    // Bottom edge
    x = r.left;
    while (x < r.right) {
      path.moveTo(x, r.bottom);
      path.lineTo(math.min(x + dash, r.right), r.bottom);
      x += dash + gap;
    }
    // Left edge
    double y = r.top;
    while (y < r.bottom) {
      path.moveTo(r.left, y);
      path.lineTo(r.left, math.min(y + dash, r.bottom));
      y += dash + gap;
    }
    // Right edge
    y = r.top;
    while (y < r.bottom) {
      path.moveTo(r.right, y);
      path.lineTo(r.right, math.min(y + dash, r.bottom));
      y += dash + gap;
    }
    return path;
  }

  void _drawZone(Canvas canvas, EnvironmentZone zone, bool selected) {
    final rect = zone.rect;
    final color = zone.type.zoneColor;

    // Fill
    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withAlpha(64)
        ..style = PaintingStyle.fill,
    );

    // Border
    if (selected) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 / scale,
      );
    } else {
      canvas.drawPath(
        _dashedRect(rect, 8 / scale, 5 / scale),
        Paint()
          ..color = color.withAlpha(180)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale,
      );
    }

    // Icon + label at centre
    if (rect.width > 30 / scale && rect.height > 20 / scale) {
      _drawLabel(canvas, zone, rect);
    }
  }

  void _drawLabel(Canvas canvas, EnvironmentZone zone, Rect rect) {
    final color = zone.type.zoneColor;
    final shortSide = rect.shortestSide;
    final iconSize = (shortSide * 0.22 / scale).clamp(10.0, 28.0);
    final labelFontSize = (iconSize * 0.7).clamp(7.0, 12.0);

    // Icon glyph via TextPainter
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(zone.type.icon.codePoint),
        style: TextStyle(
          fontFamily: zone.type.icon.fontFamily,
          package: zone.type.icon.fontPackage,
          fontSize: iconSize,
          color: color.withAlpha(210),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Label
    final displayName = zone.name.isNotEmpty ? zone.name : zone.type.label;
    final labelPainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: TextStyle(
          fontSize: labelFontSize,
          color: color.withAlpha(210),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: (rect.width - 8 / scale).clamp(1.0, double.infinity));

    final totalH = iconPainter.height + 2 + labelPainter.height;
    final startY = rect.center.dy - totalH / 2;

    iconPainter.paint(
      canvas,
      Offset(rect.center.dx - iconPainter.width / 2, startY),
    );
    labelPainter.paint(
      canvas,
      Offset(
        rect.center.dx - labelPainter.width / 2,
        startY + iconPainter.height + 2,
      ),
    );
  }

  void _drawPreview(Canvas canvas) {
    final start = previewStart;
    final cursor = previewCursor;
    if (start == null || cursor == null) return;

    final rect = Rect.fromPoints(start, cursor);
    final color = previewZoneType?.zoneColor ?? Colors.white;

    canvas.drawRect(
      rect,
      Paint()
        ..color = color.withAlpha(30)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      _dashedRect(rect, 8 / scale, 5 / scale),
      Paint()
        ..color = color.withAlpha(160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / scale,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final zone in zones) {
      _drawZone(canvas, zone, zone.id == selectedZoneId);
    }
    _drawPreview(canvas);
  }

  @override
  bool shouldRepaint(ZonePainter old) =>
      old.zones != zones ||
      old.selectedZoneId != selectedZoneId ||
      old.scale != scale ||
      old.previewStart != previewStart ||
      old.previewCursor != previewCursor ||
      old.previewZoneType != previewZoneType;
}
