import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:airreader/models/wall.dart';

/// Paints wall segments and the in-progress drawing preview onto the canvas.
///
/// Each wall is rendered as a composite two-line symbol:
///  ──────────────  solid line   = outer face  (outer material colour)
///  - - - - - - -  dashed line  = inner lining (inner material colour,
///                                or ghost grey when unset)
///
/// A small midpoint badge (●) is drawn in the classification colour:
///   orange  = exterior   blue = interior   grey = unclassified
class WallPainter extends CustomPainter {
  WallPainter({
    required this.walls,
    required this.selectedWallId,
    this.previewStart,
    this.previewEnd,
    this.canvasScale = 1.0,
  });

  final List<WallSegment> walls;
  final String? selectedWallId;
  final Offset? previewStart;
  final Offset? previewEnd;
  final double canvasScale;

  static const double _baseStrokeWidth = 4.0;
  static const double _selectedExtraWidth = 2.0;
  static const double _hitRadius = 8.0;

  // Classification badge colours.
  static const Color _exteriorColor = Color(0xFFE65100); // deep-orange
  static const Color _interiorColor = Color(0xFF1565C0); // dark-blue
  static const Color _unclassifiedColor = Color(0xFF9E9E9E); // grey

  static Color _classColor(WallClassification c) => switch (c) {
    WallClassification.exterior => _exteriorColor,
    WallClassification.interior => _interiorColor,
    _ => _unclassifiedColor,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final sw = (_baseStrokeWidth / canvasScale).clamp(1.5, 12.0);
    // Perpendicular offset for the inner-lining dashed line.
    final offset = sw * 1.2;
    // Badge dot radius.
    final badgeR = (sw * 0.9).clamp(3.0, 10.0);
    // Dash length and gap, scale-aware.
    final dashLen = (8.0 / canvasScale).clamp(3.0, 20.0);
    final gapLen = (5.0 / canvasScale).clamp(2.0, 14.0);

    for (final wall in walls) {
      final isSelected = wall.id == selectedWallId;
      final outerColor = isSelected
          ? Colors.amber
          : Color(wall.material.definition.color.toARGB32());

      final p1 = Offset(wall.startX, wall.startY);
      final p2 = Offset(wall.endX, wall.endY);

      // ── Perpendicular unit vector ──────────────────────────────────────────
      final (perpX, perpY) = _perp(p1, p2);

      // ── 1. Outer solid line ─────────────────────────────────────────────────
      final outerPaint = Paint()
        ..color = outerColor
        ..strokeWidth = isSelected ? sw + _selectedExtraWidth : sw
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(p1, p2, outerPaint);

      // ── 2. Inner dashed line (parallel, offset) ────────────────────────────
      final innerColor = isSelected
          ? Colors.amber.withValues(alpha: 0.55)
          : wall.innerMaterial != null
          ? Color(
              wall.innerMaterial!.definition.color.toARGB32(),
            ).withValues(alpha: 0.75)
          : _classColor(wall.classification).withValues(alpha: 0.25);

      final innerPaint = Paint()
        ..color = innerColor
        ..strokeWidth = (sw * 0.55).clamp(1.0, 6.0)
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke;

      final q1 = Offset(p1.dx + perpX * offset, p1.dy + perpY * offset);
      final q2 = Offset(p2.dx + perpX * offset, p2.dy + perpY * offset);
      canvas.drawPath(_dashedPath(q1, q2, dashLen, gapLen), innerPaint);

      // ── 3. Midpoint classification badge ───────────────────────────────────
      if (!isSelected) {
        final mx = (p1.dx + p2.dx) / 2;
        final my = (p1.dy + p2.dy) / 2;
        final badgeColor = _classColor(wall.classification);

        // Filled circle.
        canvas.drawCircle(
          Offset(mx, my),
          badgeR,
          Paint()..color = badgeColor.withValues(alpha: 0.85),
        );
        // White ring.
        canvas.drawCircle(
          Offset(mx, my),
          badgeR,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.6)
            ..strokeWidth = (1.5 / canvasScale).clamp(0.5, 3.0)
            ..style = PaintingStyle.stroke,
        );
      }

      // ── 4. Selection handles ───────────────────────────────────────────────
      if (isSelected) {
        final handlePaint = Paint()
          ..color = Colors.amber
          ..style = PaintingStyle.fill;
        final r = (_hitRadius / canvasScale).clamp(3.0, 16.0);
        canvas.drawCircle(p1, r, handlePaint);
        canvas.drawCircle(p2, r, handlePaint);
      }
    }

    // ── Preview wall ──────────────────────────────────────────────────────────
    if (previewStart != null && previewEnd != null) {
      canvas.drawLine(
        previewStart!,
        previewEnd!,
        Paint()
          ..color = Colors.cyanAccent.withValues(alpha: 0.85)
          ..strokeWidth = (_baseStrokeWidth / canvasScale).clamp(1.5, 12.0)
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(
        previewStart!,
        (_hitRadius / canvasScale).clamp(3.0, 16.0),
        Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.fill,
      );
    }
  }

  // ---------------------------------------------------------------------------

  /// Returns the normalised perpendicular unit vector for line p1→p2.
  static (double, double) _perp(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-6) return (0, 1);
    return (-dy / len, dx / len);
  }

  /// Builds a dashed [Path] from [start] to [end].
  static Path _dashedPath(
    Offset start,
    Offset end,
    double dashLen,
    double gapLen,
  ) {
    final path = Path();
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1e-6) return path;
    final ux = dx / length;
    final uy = dy / length;
    double pos = 0;
    bool drawing = true;
    while (pos < length) {
      final segLen = drawing ? dashLen : gapLen;
      final next = pos + segLen > length ? length : pos + segLen;
      if (drawing) {
        path.moveTo(start.dx + ux * pos, start.dy + uy * pos);
        path.lineTo(start.dx + ux * next, start.dy + uy * next);
      }
      pos = next;
      drawing = !drawing;
    }
    return path;
  }

  @override
  bool shouldRepaint(WallPainter old) =>
      old.walls != walls ||
      old.selectedWallId != selectedWallId ||
      old.previewStart != previewStart ||
      old.previewEnd != previewEnd ||
      old.canvasScale != canvasScale;
}
