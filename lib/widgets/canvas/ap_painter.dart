import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:airreader/models/access_point.dart';

/// Paints [AccessPoint] icons and FSPL-based coverage rings on the canvas.
class ApPainter extends CustomPainter {
  ApPainter({
    required this.accessPoints,
    required this.selectedApId,
    required this.canvasScale,
    required this.pixelsPerMeter,
    this.previewPosition,
  });

  final List<AccessPoint> accessPoints;
  final String? selectedApId;
  final double canvasScale;
  final double pixelsPerMeter;

  /// When non-null, an AP ghost is drawn at this scene position to preview
  /// placement before the user commits.
  final Offset? previewPosition;

  static const double _apRadius = 16.0;

  // Signal threshold used for coverage ring: "fair" indoor coverage.
  static const double _coverageThresholdDbm = -70.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw placed APs.
    for (final ap in accessPoints) {
      final isSelected = ap.id == selectedApId;
      final center = Offset(ap.positionX, ap.positionY);
      _drawCoverageRings(canvas, ap, center);
      _drawApIcon(canvas, center, isSelected: isSelected);
      _drawLabel(canvas, center, ap.model, isSelected: isSelected);
    }

    // Draw placement ghost.
    if (previewPosition != null) {
      _drawApIcon(canvas, previewPosition!, isGhost: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Coverage rings
  // ---------------------------------------------------------------------------

  void _drawCoverageRings(Canvas canvas, AccessPoint ap, Offset center) {
    final bands = ap.enabledBands;
    // Draw from largest to smallest so outer rings don't hide inner ones.
    final sorted = [...bands]
      ..sort(
        (a, b) => _coverageRadiusPx(
          ap.antennaGainDbi,
          a,
        ).compareTo(_coverageRadiusPx(ap.antennaGainDbi, b)),
      );

    for (final band in sorted.reversed) {
      final r = _coverageRadiusPx(ap.antennaGainDbi, band);
      final color = _bandColor(band.band);

      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.06)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.5 / canvasScale).clamp(0.5, 3.0);

      canvas.drawCircle(center, r, fillPaint);
      canvas.drawCircle(center, r, borderPaint);
    }
  }

  /// FSPL-based radius in pixels to the [_coverageThresholdDbm] signal level.
  double _coverageRadiusPx(double antennaGainDbi, BandConfig band) {
    final txPower = band.txPowerDbm;
    final freqMhz = band.frequencyMhz;
    // FSPL inversion:
    //   d = 10 ^ ((Ptx + Gtx - threshold + 27.55 - 20·log10(f_MHz)) / 20)
    final logF = 20 * math.log(freqMhz) / math.ln10;
    final exponent =
        (txPower + antennaGainDbi - _coverageThresholdDbm + 27.55 - logF) /
        20.0;
    final distanceMeters = math.pow(10, exponent) as double;
    return (distanceMeters * pixelsPerMeter).clamp(0.0, 8000.0);
  }

  // ---------------------------------------------------------------------------
  // AP icon
  // ---------------------------------------------------------------------------

  void _drawApIcon(
    Canvas canvas,
    Offset center, {
    bool isSelected = false,
    bool isGhost = false,
  }) {
    final r = (_apRadius / canvasScale).clamp(8.0, 28.0);

    Color bgColor;
    Color borderColor;
    double borderWidth;

    if (isGhost) {
      bgColor = const Color(0xFF1565C0).withValues(alpha: 0.5);
      borderColor = Colors.white.withValues(alpha: 0.7);
      borderWidth = 1.5 / canvasScale;
    } else if (isSelected) {
      bgColor = Colors.amber.shade900;
      borderColor = Colors.amber.shade800;
      borderWidth = 2.5 / canvasScale;
    } else {
      bgColor = const Color(0xFF1565C0);
      borderColor = Colors.white.withValues(alpha: 0.9);
      borderWidth = 1.5 / canvasScale;
    }

    if (!isGhost) {
      // Dark outer shadow ring for contrast against any floor plan background.
      canvas.drawCircle(
        center,
        r + (3.5 / canvasScale).clamp(1.5, 5.0),
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      // White separation ring.
      canvas.drawCircle(
        center,
        r + (1.5 / canvasScale).clamp(0.8, 2.5),
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
    }

    // Background circle.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.fill,
    );

    // Border.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    // WiFi arcs.
    _drawWifiArcs(
      canvas,
      center,
      r,
      color: isGhost
          ? Colors.white.withValues(alpha: 0.7)
          : isSelected
          ? Colors.amber.shade300
          : Colors.white,
    );
  }

  /// Draws a WiFi fan icon (3 arcs + dot) centred at [center].
  void _drawWifiArcs(
    Canvas canvas,
    Offset center,
    double r, {
    required Color color,
  }) {
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.8 / canvasScale).clamp(0.8, 3.0)
      ..strokeCap = StrokeCap.round;

    final scale = r * 0.58;
    // Shift the icon origin downward inside the circle.
    final origin = Offset(center.dx, center.dy + scale * 0.25);

    // Three arcs: small, medium, large – pointing upward.
    for (int i = 1; i <= 3; i++) {
      final arcR = scale * (i / 3.5);
      final rect = Rect.fromCircle(center: origin, radius: arcR);
      // Start angle: upper-left; sweep: upper half.
      canvas.drawArc(
        rect,
        math.pi + math.pi / 5,
        math.pi * 3 / 5,
        false,
        iconPaint,
      );
    }

    // Centre dot.
    canvas.drawCircle(
      Offset(origin.dx, origin.dy + scale * 0.06),
      (2.2 / canvasScale).clamp(1.0, 4.0),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  // ---------------------------------------------------------------------------
  // Label
  // ---------------------------------------------------------------------------

  void _drawLabel(
    Canvas canvas,
    Offset center,
    String text, {
    bool isSelected = false,
  }) {
    // All sizes are in scene units. Dividing by canvasScale converts a
    // fixed screen-pixel value to the correct scene-unit size so the label
    // appears the same physical size regardless of zoom level.
    final fontSize = 14.0 / canvasScale;
    // Match the clamped icon radius used in _drawApIcon so position is consistent.
    final iconR = (_apRadius / canvasScale).clamp(8.0, 28.0);
    final shadowRing = (3.5 / canvasScale).clamp(1.5, 5.0);
    final labelY = center.dy + iconR + shadowRing + 5.0 / canvasScale;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          // Always white text on a dark pill — readable on any background.
          color: Colors.white,
          letterSpacing: 0.1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padH = 7.0 / canvasScale;
    final padV = 4.0 / canvasScale;
    final cornerR = 5.0 / canvasScale;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, labelY + tp.height / 2),
        width: tp.width + padH * 2,
        height: tp.height + padV * 2,
      ),
      Radius.circular(cornerR),
    );

    // Drop shadow.
    canvas.drawRRect(
      bgRect.shift(Offset(0, 2.0 / canvasScale)),
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );

    // Pill background: amber accent border when selected, dark navy otherwise.
    final pillColor = isSelected
        ? const Color(0xFF1565C0) // bright blue when selected
        : const Color(0xFF1A237E); // deep navy normally
    canvas.drawRRect(
      bgRect,
      Paint()..color = pillColor.withValues(alpha: 0.95),
    );

    // Accent border on selected.
    if (isSelected) {
      canvas.drawRRect(
        bgRect,
        Paint()
          ..color = Colors.amber.shade700
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / canvasScale,
      );
    }

    tp.paint(canvas, Offset(center.dx - tp.width / 2, labelY));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Color _bandColor(WiFiBand band) => switch (band) {
    WiFiBand.ghz24 => const Color(0xFF4CAF50),
    WiFiBand.ghz5 => const Color(0xFF2196F3),
    WiFiBand.ghz6 => const Color(0xFF9C27B0),
  };

  @override
  bool shouldRepaint(ApPainter old) =>
      old.accessPoints != accessPoints ||
      old.selectedApId != selectedApId ||
      old.canvasScale != canvasScale ||
      old.pixelsPerMeter != pixelsPerMeter ||
      old.previewPosition != previewPosition;
}
