import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' as fd;

import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/environment_zone.dart';
import 'package:airreader/models/floor_plan.dart';
import 'package:airreader/models/signal_map.dart';
import 'package:airreader/models/wall.dart';

// ---------------------------------------------------------------------------
// Parameter bundle (records are sendable across isolates / web workers)
// ---------------------------------------------------------------------------

typedef _SimParams = ({
  double imageWidth,
  double imageHeight,
  double pixelsPerMeter,
  List<AccessPoint> accessPoints,
  List<WallSegment> walls,
  List<EnvironmentZone> zones,
  int resolution,
});

// Top-level so Flutter's compute() can reference it on web.
SignalMap _computeSimulation(_SimParams p) => RfSimulationService._doCompute(p);

/// RF signal simulation engine.
///
/// Computes a [SignalMap] by:
///   1. Applying the Free-Space Path Loss (FSPL) formula from each AP to every
///      grid cell on the floor plan.
///   2. Summing per-band wall-attenuation dB loss for every [WallSegment] whose
///      line intersects the ray from the AP to the grid cell.
///   3. Selecting the best (highest) received-signal level across all APs at
///      each grid cell.
///
/// Heavy computation runs in a background isolate / web-worker via
/// Flutter's [compute].
class RfSimulationService {
  RfSimulationService._();

  /// Floor-plan pixels per grid cell on each axis. Smaller = more detailed.
  static const int defaultResolution = 6;

  static const double _noiseFloor = kNoSignal;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Compute a [SignalMap] in a background isolate.
  static Future<SignalMap> compute({
    required FloorPlan floorPlan,
    required List<AccessPoint> accessPoints,
    required List<WallSegment> walls,
    List<EnvironmentZone> zones = const [],
    int resolution = defaultResolution,
  }) {
    final params = (
      imageWidth: floorPlan.imageWidth,
      imageHeight: floorPlan.imageHeight,
      pixelsPerMeter: floorPlan.pixelsPerMeter,
      accessPoints: accessPoints,
      walls: walls,
      zones: zones,
      resolution: resolution,
    );
    // Flutter's compute() works on both native (isolate) and web (web-worker).
    return fd.compute(_computeSimulation, params);
  }

  // ---------------------------------------------------------------------------
  // Core computation (runs in background isolate)
  // ---------------------------------------------------------------------------

  static SignalMap _doCompute(_SimParams p) {
    final imageWidth = p.imageWidth;
    final imageHeight = p.imageHeight;
    final pixelsPerMeter = p.pixelsPerMeter;
    final accessPoints = p.accessPoints;
    final walls = p.walls;
    final zones = p.zones;
    final resolution = p.resolution;

    final gridCols = (imageWidth / resolution).ceil() + 1;
    final gridRows = (imageHeight / resolution).ceil() + 1;
    final cellCount = gridCols * gridRows;

    final bandGrids = <WiFiBand, Float32List>{};

    for (final band in WiFiBand.values) {
      final grid = Float32List(cellCount);
      grid.fillRange(0, cellCount, _noiseFloor);

      for (final ap in accessPoints) {
        // Find this band's config on the AP (skip if absent or disabled).
        BandConfig? bandConfig;
        for (final b in ap.bands) {
          if (b.band == band && b.enabled) {
            bandConfig = b;
            break;
          }
        }
        if (bandConfig == null) continue;

        final txPower = bandConfig.txPowerDbm;
        final freqMhz = bandConfig.frequencyMhz;
        final gain = ap.antennaGainDbi;
        final apX = ap.positionX;
        final apY = ap.positionY;

        // Constant part of FSPL: 20·log10(f_MHz) – 27.55
        final fsplConst = 20.0 * math.log(freqMhz) / math.ln10 - 27.55;
        // We use indoor path-loss exponent n = 3.5 (residential indoor)
        // rather than n = 2.0 (FSPL / free-space).  See network_performance_service.

        for (int row = 0; row < gridRows; row++) {
          final py = row * resolution.toDouble();
          for (int col = 0; col < gridCols; col++) {
            final px = col * resolution.toDouble();

            // Distance in metres (clamped to 0.1 m to avoid log(0)).
            final dx = px - apX;
            final dy = py - apY;
            final distM = (math.sqrt(dx * dx + dy * dy) / pixelsPerMeter).clamp(
              0.1,
              double.infinity,
            );

            // Indoor path-loss (n=3.5): 35·log10(d_m) + 20·log10(f_MHz) – 27.55
            final fsplDb = 35.0 * math.log(distM) / math.ln10 + fsplConst;

            // Wall attenuation: sum dB for every wall the ray crosses.
            double wallLoss = 0.0;
            for (final wall in walls) {
              if (_segmentsIntersect(
                apX,
                apY,
                px,
                py,
                wall.startX,
                wall.startY,
                wall.endX,
                wall.endY,
              )) {
                wallLoss += wall.attenuationForFrequencyMhz(freqMhz);
              }
            }

            // Received signal level (dBm).
            double rx = txPower + gain - fsplDb - wallLoss;

            // Zone attenuation / boost:
            // Apply whenever the ray from AP to this cell either starts in,
            // ends in, or passes through the zone rectangle.
            for (final zone in zones) {
              if (_segmentIntersectsRect(
                apX,
                apY,
                px,
                py,
                zone.left,
                zone.top,
                zone.right,
                zone.bottom,
              )) {
                rx += zone.type.modifierForFrequencyMhz(freqMhz);
              }
            }

            final idx = row * gridCols + col;
            if (rx > grid[idx]) {
              grid[idx] = rx.clamp(_noiseFloor, 30.0);
            }
          }
        }
      }

      bandGrids[band] = grid;
    }

    return SignalMap(
      gridCols: gridCols,
      gridRows: gridRows,
      resolution: resolution,
      bandGrids: bandGrids,
    );
  }

  // ---------------------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------------------

  /// Returns true if line segment A→B strictly intersects segment C→D.
  /// Endpoint touches are excluded so the AP's own position is never a hit.
  static bool _segmentsIntersect(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
    double dx,
    double dy,
  ) {
    final d1x = bx - ax;
    final d1y = by - ay;
    final d2x = dx - cx;
    final d2y = dy - cy;

    final denom = d1x * d2y - d1y * d2x;
    if (denom.abs() < 1e-10) return false; // parallel / collinear

    final t = ((cx - ax) * d2y - (cy - ay) * d2x) / denom;
    final u = ((cx - ax) * d1y - (cy - ay) * d1x) / denom;

    // t ∈ (0, 1): on the ray from AP strictly before the target point.
    // u ∈ [0, 1]: on the wall segment.
    return t > 1e-6 && t < 1.0 - 1e-6 && u >= 0.0 && u <= 1.0;
  }

  /// Returns true if line segment A→B passes through or has an endpoint inside
  /// the axis-aligned rectangle defined by [left], [top], [right], [bottom].
  static bool _segmentIntersectsRect(
    double ax,
    double ay,
    double bx,
    double by,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    // Either endpoint inside the rect counts (AP or cell is inside the zone).
    if (ax >= left && ax <= right && ay >= top && ay <= bottom) return true;
    if (bx >= left && bx <= right && by >= top && by <= bottom) return true;
    // Otherwise check if the segment crosses any of the 4 edges.
    return _segmentsCross(ax, ay, bx, by, left, top, right, top) ||
        _segmentsCross(ax, ay, bx, by, right, top, right, bottom) ||
        _segmentsCross(ax, ay, bx, by, right, bottom, left, bottom) ||
        _segmentsCross(ax, ay, bx, by, left, bottom, left, top);
  }

  /// Loose segment intersection (endpoints included, no ε exclusion).
  static bool _segmentsCross(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
    double dx,
    double dy,
  ) {
    final d1x = bx - ax;
    final d1y = by - ay;
    final d2x = dx - cx;
    final d2y = dy - cy;
    final denom = d1x * d2y - d1y * d2x;
    if (denom.abs() < 1e-10) return false; // parallel
    final t = ((cx - ax) * d2y - (cy - ay) * d2x) / denom;
    final u = ((cx - ax) * d1y - (cy - ay) * d1x) / denom;
    return t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0;
  }
}
