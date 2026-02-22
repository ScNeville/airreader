import 'package:flutter/material.dart';

import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/signal_map.dart';

/// Paints a signal-strength heat map overlay derived from a [SignalMap].
///
/// Each grid cell is painted as a solid rectangle whose colour encodes the
/// received signal level (dBm):
///
///   ≥ −55 dBm  → green   (excellent)
///   −55..−65   → yellow  (good)
///   −65..−75   → orange  (fair)
///   ≥ −85      → red     (poor)
///   < −85 dBm  → transparent (no signal)
///
/// [activeBand] selects which band grid to display; null = best signal across
/// all bands.
///
/// [opacity] scales the alpha of all coloured cells (0 = invisible, 1 = full).
class HeatMapPainter extends CustomPainter {
  HeatMapPainter({
    required this.signalMap,
    required this.activeBand,
    required this.opacity,
  });

  final SignalMap signalMap;
  final WiFiBand? activeBand;
  final double opacity;

  // dBm scale ends
  static const double _minDbm = -90.0; // below this → transparent
  static const double _maxDbm = -50.0; // above this → full-green

  @override
  void paint(Canvas canvas, Size size) {
    final res = signalMap.resolution.toDouble();
    final paint = Paint()..style = PaintingStyle.fill;

    final band = activeBand;
    final gridCols = signalMap.gridCols;
    final gridRows = signalMap.gridRows;

    for (int row = 0; row < gridRows; row++) {
      final py = row * res;
      for (int col = 0; col < gridCols; col++) {
        final double dBm;
        if (band != null) {
          dBm = signalMap.signalAt(band, col * res, py);
        } else {
          dBm = signalMap.bestSignalAt(col * res, py);
        }

        final color = _signalColor(dBm, opacity);
        if (color.a == 0) continue; // transparent → skip

        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(col * res, py, res, res), paint);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // colour mapping
  // ---------------------------------------------------------------------------

  static Color _signalColor(double dBm, double opacity) {
    if (dBm <= _minDbm) return const Color(0x00000000);

    final t = ((dBm - _minDbm) / (_maxDbm - _minDbm)).clamp(0.0, 1.0);

    // Fade in gently near the noise floor so there's no hard edge.
    final fadeAlpha = t < 0.1 ? t / 0.1 : 1.0;
    final alpha = (fadeAlpha * opacity).clamp(0.0, 1.0);

    final Color rgb;
    if (t < 0.25) {
      // red → orange
      rgb = Color.lerp(
        const Color(0xFFE53935),
        const Color(0xFFFF7043),
        t / 0.25,
      )!;
    } else if (t < 0.5) {
      // orange → yellow
      rgb = Color.lerp(
        const Color(0xFFFF7043),
        const Color(0xFFFFEE58),
        (t - 0.25) / 0.25,
      )!;
    } else if (t < 0.75) {
      // yellow → light green
      rgb = Color.lerp(
        const Color(0xFFFFEE58),
        const Color(0xFF9CCC65),
        (t - 0.5) / 0.25,
      )!;
    } else {
      // light green → deep green
      rgb = Color.lerp(
        const Color(0xFF9CCC65),
        const Color(0xFF2E7D32),
        (t - 0.75) / 0.25,
      )!;
    }

    return rgb.withValues(alpha: alpha);
  }

  // ---------------------------------------------------------------------------

  @override
  bool shouldRepaint(HeatMapPainter old) =>
      old.signalMap != signalMap ||
      old.activeBand != activeBand ||
      old.opacity != opacity;
}

// ============================================================================
// Colour scale constants – reused by legend widgets.
// ============================================================================

/// dBm breakpoints and labels for the heat map colour scale.
const List<({double dBm, String label, Color color})> kHeatMapScale = [
  (dBm: -50, label: '≥ −50 dBm', color: Color(0xFF2E7D32)),
  (dBm: -60, label: '−60 dBm', color: Color(0xFF9CCC65)),
  (dBm: -70, label: '−70 dBm', color: Color(0xFFFFEE58)),
  (dBm: -80, label: '−80 dBm', color: Color(0xFFFF7043)),
  (dBm: -90, label: '≤ −90 dBm', color: Color(0xFFE53935)),
];
