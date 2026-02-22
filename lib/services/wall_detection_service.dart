// lib/services/wall_detection_service.dart
//
// Automatically detects walls from a floor-plan image using computer vision
// (no external API required). Works well on clean architectural drawings,
// monochrome floor plans, and most PDF/SVG imports.
//
// Algorithm
// ─────────
//  1. Downscale image to ≤800 px on the longest side (fast processing).
//  2. Convert RGBA → grayscale and threshold at `darkThreshold` to produce a
//     binary "wall pixel" map.
//  3. Horizontal scan  – for every row, collect runs of consecutive dark pixels
//     ≥ `minRunPx`. These are candidate horizontal wall segments.
//  4. Vertical scan    – same for columns → vertical candidate segments.
//  5. Merge / dedup    – group parallel collinear runs that are within
//     `mergeGapPx` of each other into a single wall segment.
//  6. Scale back       – convert pixel coordinates → floor-plan coordinates
//     using `pixelsPerMeter`.
//  7. Classify         – walls whose midpoint is within the outer
//     `perimeterFraction` of the detected bounding box are marked `exterior`;
//     the rest are marked `interior`.
//  8. Apply building profile materials based on classification.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:airreader/models/building_profile.dart';
import 'package:airreader/models/wall.dart';

const _uuid = Uuid();

// ============================================================================
// Public API
// ============================================================================

class WallDetectionService {
  WallDetectionService._();

  /// Detect walls in [imageBytes] (PNG/JPEG) and return a list of
  /// [WallSegment]s scaled to the floor-plan coordinate space defined by
  /// [pixelsPerMeter].
  ///
  /// [profile] is used to assign default materials to exterior / interior walls.
  ///
  /// Returns an empty list if the image cannot be decoded or no walls are found.
  static Future<List<WallSegment>> detect(
    Uint8List imageBytes, {
    double pixelsPerMeter = 100.0,
    BuildingProfile profile = BuildingProfile.defaults,
    int darkThreshold = 100, // 0-255: pixels darker than this = wall
    double minWallLengthM = 0.4, // minimum wall length in real-world metres
    double perimeterFraction = 0.06, // fraction from edge → exterior
  }) async {
    // ─── Step 1: Decode image on main thread (dart:ui required) ──────────────
    final pixelData = await _decodeToPixels(imageBytes);
    if (pixelData == null) return [];

    // ─── Steps 2–7: Run heavy processing in a background isolate ─────────────
    final minRunPx = max(
      4,
      (minWallLengthM * pixelsPerMeter * (pixelData.width / pixelData.srcWidth))
          .round(),
    );

    final params = _DetectionParams(
      bytes: pixelData.bytes,
      width: pixelData.width,
      height: pixelData.height,
      darkThreshold: darkThreshold,
      minRunPx: minRunPx,
      mergeGapPx: max(3, (pixelData.width / 100).round()), // ~1% of width
      perimeterFraction: perimeterFraction,
    );

    final rawWalls = await compute(_detectWallsIsolate, params);

    // ─── Step 8: Convert to WallSegments with real-world coordinates ──────────
    // The downscaled pixel coords need to be mapped back to original image
    // coords via the downscale factor, then to metres via pixelsPerMeter.
    final downscaleFactor = pixelData.srcWidth / pixelData.width;

    final segments = rawWalls.map((raw) {
      final x1 = (raw['x1'] as double) * downscaleFactor;
      final y1 = (raw['y1'] as double) * downscaleFactor;
      final x2 = (raw['x2'] as double) * downscaleFactor;
      final y2 = (raw['y2'] as double) * downscaleFactor;
      final isExterior = raw['exterior'] as bool;

      final classification = isExterior
          ? WallClassification.exterior
          : WallClassification.interior;
      final material = isExterior
          ? profile.exteriorMaterial
          : profile.interiorMaterial;
      // Exterior walls have an inner lining (e.g. drywall on brick).
      // Interior partitions are single-layer so innerMaterial stays null.
      final innerMaterial = isExterior ? profile.exteriorInnerMaterial : null;

      return WallSegment(
        id: _uuid.v4(),
        startX: x1,
        startY: y1,
        endX: x2,
        endY: y2,
        material: material,
        innerMaterial: innerMaterial,
        classification: classification,
      );
    }).toList();

    // ─── Step 9: Collapse stacked lines into composite walls ──────────────────
    // The CV scanner emits one segment per dark pixel-run.  The internal
    // _mergeRuns collapses runs within `mergeGapPx` (downscaled px), but
    // variations in darkness or image noise can leave multiple near-parallel
    // segments for the same physical wall.  Here we do a second pass that:
    //   • uses a threshold derived from the actual merge gap so it scales with
    //     image resolution, and
    //   • also requires longitudinal overlap so only truly co-spatial runs
    //     are collapsed.
    final mergeGapPx = max(3, (pixelData.width / 100).round());
    final stackThreshPx = (mergeGapPx * downscaleFactor * 1.5).clamp(
      12.0,
      80.0,
    );
    return _mergeStackedWalls(segments, stackThresholdPx: stackThreshPx);
  }

  // ---------------------------------------------------------------------------

  /// Collapses groups of co-linear, overlapping segments into single composite
  /// [WallSegment]s.  Within each group the first segment keeps its geometry
  /// and material; the last segment's material is stored as
  /// [WallSegment.innerMaterial]; intermediates are discarded.
  static List<WallSegment> _mergeStackedWalls(
    List<WallSegment> walls, {
    double stackThresholdPx = 18.0, // max perpendicular distance = same stack
    double angleTolDeg = 12.0, // direction tolerance
  }) {
    if (walls.length <= 1) return walls;

    // Normalised direction angle 0..180°.
    double wallAngle(WallSegment w) {
      final dx = w.endX - w.startX;
      final dy = w.endY - w.startY;
      var a = atan2(dy, dx) * 180 / pi;
      if (a < 0) a += 180;
      return a;
    }

    // Perpendicular distance from (px,py) to the infinite line through w.
    double perpDist(double px, double py, WallSegment w) {
      final dx = w.endX - w.startX;
      final dy = w.endY - w.startY;
      final len = sqrt(dx * dx + dy * dy);
      if (len < 1e-6) {
        return sqrt(
          (px - w.startX) * (px - w.startX) + (py - w.startY) * (py - w.startY),
        );
      }
      return ((px - w.startX) * dy - (py - w.startY) * dx).abs() / len;
    }

    // Longitudinal overlap: project both walls onto wall A's direction axis
    // and check whether the projected intervals overlap.  This prevents merging
    // two parallel walls on opposite sides of a room that happen to share the
    // same infinite line (e.g. both are east-facing walls).
    bool longitudinalOverlap(WallSegment a, WallSegment b) {
      final dx = a.endX - a.startX;
      final dy = a.endY - a.startY;
      final len = sqrt(dx * dx + dy * dy);
      if (len < 1e-6) return false;
      final ux = dx / len;
      final uy = dy / len;
      // Project A onto its own axis → always [0, len]
      final aMin = 0.0;
      final aMax = len;
      // Project B's endpoints
      final bP1 = (b.startX - a.startX) * ux + (b.startY - a.startY) * uy;
      final bP2 = (b.endX - a.startX) * ux + (b.endY - a.startY) * uy;
      final bMin = min(bP1, bP2);
      final bMax = max(bP1, bP2);
      // Intervals overlap when neither is entirely before or after the other.
      return bMax >= aMin && bMin <= aMax;
    }

    // Two walls are "stacked" when:
    //  1. Their directions match within angleTolDeg.
    //  2. Each wall's midpoint is within stackThresholdPx of the other's
    //     infinite line.
    //  3. They have overlapping extent along the wall direction.
    bool sameStack(WallSegment a, WallSegment b) {
      var diff = (wallAngle(a) - wallAngle(b)).abs() % 180;
      if (diff > 90) diff = 180 - diff;
      if (diff > angleTolDeg) return false;
      final mbx = (b.startX + b.endX) / 2;
      final mby = (b.startY + b.endY) / 2;
      final max = (a.startX + a.endX) / 2;
      final may = (a.startY + a.endY) / 2;
      if (perpDist(mbx, mby, a) >= stackThresholdPx) return false;
      if (perpDist(max, may, b) >= stackThresholdPx) return false;
      return longitudinalOverlap(a, b);
    }

    final used = List<bool>.filled(walls.length, false);
    final result = <WallSegment>[];

    for (int i = 0; i < walls.length; i++) {
      if (used[i]) continue;
      final group = <WallSegment>[walls[i]];
      used[i] = true;

      // Transitive grouping: keep scanning until no new members are added.
      bool grew = true;
      while (grew) {
        grew = false;
        for (int j = 0; j < walls.length; j++) {
          if (used[j]) continue;
          // Accept if the candidate matches ANY current group member.
          if (group.any((g) => sameStack(g, walls[j]))) {
            group.add(walls[j]);
            used[j] = true;
            grew = true;
          }
        }
      }

      if (group.length == 1) {
        result.add(group.first);
      } else {
        // first = outermost layer, last = innermost lining; middle discarded.
        final first = group.first;
        final last = group.last;
        result.add(first.copyWith(innerMaterial: last.material));
      }
    }

    return result;
  }
}

// ============================================================================
// Private: image decoding (main thread only – dart:ui)
// ============================================================================

class _PixelData {
  const _PixelData({
    required this.bytes,
    required this.width,
    required this.height,
    required this.srcWidth,
  });

  final Uint8List bytes; // RGBA, width × height × 4
  final int width; // downscaled width
  final int height; // downscaled height
  final double srcWidth; // original image width (for back-scaling)
}

Future<_PixelData?> _decodeToPixels(Uint8List imageBytes) async {
  const maxDim = 800;
  try {
    // First pass: get native dimensions without target constraint
    final refCodec = await ui.instantiateImageCodec(imageBytes);
    final refFrame = await refCodec.getNextFrame();
    final srcW = refFrame.image.width.toDouble();
    final srcH = refFrame.image.height.toDouble();
    refFrame.image.dispose();
    refCodec.dispose();

    // Determine target width to keep longest side ≤ maxDim
    int targetW, targetH;
    if (srcW >= srcH) {
      targetW = min(maxDim, srcW.toInt());
      targetH = (srcH * targetW / srcW).round();
    } else {
      targetH = min(maxDim, srcH.toInt());
      targetW = (srcW * targetH / srcH).round();
    }

    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final frame = await codec.getNextFrame();
    final img = frame.image;
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    codec.dispose();

    if (bd == null) return null;
    return _PixelData(
      bytes: bd.buffer.asUint8List(),
      width: targetW,
      height: targetH,
      srcWidth: srcW,
    );
  } catch (_) {
    return null;
  }
}

// ============================================================================
// Private: detection logic (runs in background isolate via compute)
// ============================================================================

class _DetectionParams {
  const _DetectionParams({
    required this.bytes,
    required this.width,
    required this.height,
    required this.darkThreshold,
    required this.minRunPx,
    required this.mergeGapPx,
    required this.perimeterFraction,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int darkThreshold;
  final int minRunPx;
  final int mergeGapPx;
  final double perimeterFraction;
}

/// Top-level function so `compute` can dispatch it to a background isolate.
List<Map<String, dynamic>> _detectWallsIsolate(_DetectionParams p) {
  // ── Grayscale + threshold ─────────────────────────────────────────────────
  // 1 = dark (wall pixel), 0 = light (background)
  final wall = Uint8List(p.width * p.height);
  for (var i = 0; i < p.width * p.height; i++) {
    final r = p.bytes[i * 4];
    final g = p.bytes[i * 4 + 1];
    final b = p.bytes[i * 4 + 2];
    final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
    wall[i] = gray < p.darkThreshold ? 1 : 0;
  }

  // ── Horizontal scan ───────────────────────────────────────────────────────
  final hRuns = <_Run>[];
  for (var y = 0; y < p.height; y++) {
    int? runStart;
    for (var x = 0; x <= p.width; x++) {
      final dark = x < p.width && wall[y * p.width + x] == 1;
      if (dark && runStart == null) {
        runStart = x;
      } else if (!dark && runStart != null) {
        final len = x - runStart;
        if (len >= p.minRunPx) {
          hRuns.add(_Run(axis: 0, pos: y, a: runStart, b: x - 1));
        }
        runStart = null;
      }
    }
  }

  // ── Vertical scan ─────────────────────────────────────────────────────────
  final vRuns = <_Run>[];
  for (var x = 0; x < p.width; x++) {
    int? runStart;
    for (var y = 0; y <= p.height; y++) {
      final dark = y < p.height && wall[y * p.width + x] == 1;
      if (dark && runStart == null) {
        runStart = y;
      } else if (!dark && runStart != null) {
        final len = y - runStart;
        if (len >= p.minRunPx) {
          vRuns.add(_Run(axis: 1, pos: x, a: runStart, b: y - 1));
        }
        runStart = null;
      }
    }
  }

  // ── Merge parallel collinear runs ─────────────────────────────────────────
  final mergedH = _mergeRuns(hRuns, p.mergeGapPx);
  final mergedV = _mergeRuns(vRuns, p.mergeGapPx);

  // ── Convert to wall descriptions ──────────────────────────────────────────
  final raw = <_RawWall>[];
  for (final r in mergedH) {
    raw.add(
      _RawWall(
        x1: r.a.toDouble(),
        y1: r.pos.toDouble(),
        x2: r.b.toDouble(),
        y2: r.pos.toDouble(),
      ),
    );
  }
  for (final r in mergedV) {
    raw.add(
      _RawWall(
        x1: r.pos.toDouble(),
        y1: r.a.toDouble(),
        x2: r.pos.toDouble(),
        y2: r.b.toDouble(),
      ),
    );
  }

  if (raw.isEmpty) return [];

  // ── Bounding-box exterior classification ──────────────────────────────────
  double minX = double.infinity, maxX = 0, minY = double.infinity, maxY = 0;
  for (final w in raw) {
    minX = min(minX, min(w.x1, w.x2));
    maxX = max(maxX, max(w.x1, w.x2));
    minY = min(minY, min(w.y1, w.y2));
    maxY = max(maxY, max(w.y1, w.y2));
  }
  final zoneX = (maxX - minX) * p.perimeterFraction;
  final zoneY = (maxY - minY) * p.perimeterFraction;

  return raw.map((w) {
    // Midpoint check
    final mx = (w.x1 + w.x2) / 2;
    final my = (w.y1 + w.y2) / 2;
    final exterior =
        mx <= minX + zoneX ||
        mx >= maxX - zoneX ||
        my <= minY + zoneY ||
        my >= maxY - zoneY;
    return {
      'x1': w.x1,
      'y1': w.y1,
      'x2': w.x2,
      'y2': w.y2,
      'exterior': exterior,
    };
  }).toList();
}

// ── Merge helper ──────────────────────────────────────────────────────────────
//
// Groups runs on the same axis that are within `gapPx` of each other
// positionally AND have overlapping or touching ranges on the other axis.
// Returns one merged run per group (median position, union range).

List<_Run> _mergeRuns(List<_Run> runs, int gapPx) {
  if (runs.isEmpty) return [];

  // Sort: primarily by position (y for horizontal, x for vertical),
  // secondarily by range start.
  runs.sort((a, b) {
    final cmp = a.pos.compareTo(b.pos);
    return cmp != 0 ? cmp : a.a.compareTo(b.a);
  });

  final groups = <List<_Run>>[];
  List<_Run> current = [runs.first];

  for (var i = 1; i < runs.length; i++) {
    final r = runs[i];
    final last = current.last;

    // Same group if close positionally AND x/y ranges overlap or touch.
    final posClose = (r.pos - last.pos).abs() <= gapPx;
    final rangesOverlap = r.a <= last.b + gapPx && r.b >= last.a - gapPx;

    if (posClose && rangesOverlap) {
      current.add(r);
    } else {
      groups.add(current);
      current = [r];
    }
  }
  groups.add(current);

  return groups.map((g) {
    // Median position, union range
    final sortedPos = g.map((r) => r.pos).toList()..sort();
    final medPos = sortedPos[sortedPos.length ~/ 2];
    final minA = g.map((r) => r.a).reduce(min);
    final maxB = g.map((r) => r.b).reduce(max);
    return _Run(axis: g.first.axis, pos: medPos, a: minA, b: maxB);
  }).toList();
}

// ── Data classes (isolate-local) ──────────────────────────────────────────────

class _Run {
  const _Run({
    required this.axis, // 0=horizontal, 1=vertical
    required this.pos, // y for horizontal, x for vertical
    required this.a, // range start (x for horiz, y for vert)
    required this.b, // range end
  });
  final int axis;
  final int pos;
  final int a;
  final int b;
}

class _RawWall {
  const _RawWall({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
  final double x1, y1, x2, y2;
}
