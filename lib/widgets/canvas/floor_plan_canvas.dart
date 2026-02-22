import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/client_device.dart';
import 'package:airreader/models/environment_zone.dart';
import 'package:airreader/models/floor_plan.dart';
import 'package:airreader/models/network_performance.dart';
import 'package:airreader/models/signal_map.dart';
import 'package:airreader/models/wall.dart';
import 'package:airreader/widgets/canvas/ap_painter.dart';
import 'package:airreader/widgets/canvas/client_painter.dart';
import 'package:airreader/widgets/canvas/heat_map_painter.dart';
import 'package:airreader/widgets/canvas/wall_painter.dart';
import 'package:airreader/widgets/canvas/zone_painter.dart';

const _uuid = Uuid();

// Callbacks fired by the canvas.
typedef OnWallAdded = void Function(WallSegment wall);
typedef OnWallSelected = void Function(String? id);
typedef OnApPlaced = void Function(double x, double y);
typedef OnApMoved = void Function(String id, double x, double y);
typedef OnApSelected = void Function(String? id);
typedef OnClientPlaced = void Function(double x, double y);
typedef OnClientMoved = void Function(String id, double x, double y);
typedef OnClientSelected = void Function(String? id);
typedef OnZoneAdded = void Function(EnvironmentZone zone);
typedef OnZoneSelected = void Function(String? id);

/// Interactive floor-plan canvas.
///
/// Supports:
///   - Zoom & pan (scroll / two-finger drag).
///   - Draw-wall mode: click start → click end.
///   - Select mode: click a wall or AP to select it; drag an AP to move it.
///   - Place-AP mode: click to drop a pending AP, right-click to cancel.
class FloorPlanCanvas extends StatefulWidget {
  const FloorPlanCanvas({
    super.key,
    required this.floorPlan,
    required this.walls,
    required this.accessPoints,
    required this.clients,
    required this.zones,
    required this.selectedWallId,
    required this.selectedApId,
    required this.selectedClientId,
    required this.selectedZoneId,
    required this.activeTool,
    required this.drawingMaterial,
    required this.zoneTypeBeingDrawn,
    required this.onWallAdded,
    required this.onWallSelected,
    required this.onApPlaced,
    required this.onApMoved,
    required this.onApSelected,
    required this.onClientPlaced,
    required this.onClientMoved,
    required this.onClientSelected,
    required this.onZoneAdded,
    required this.onZoneSelected,
    this.signalMap,
    this.showHeatMap = false,
    this.activeBand,
    this.heatMapOpacity = 0.55,
    this.clientPerf,
    this.dragLocked = false,
  });

  final FloorPlan floorPlan;
  final List<WallSegment> walls;
  final List<AccessPoint> accessPoints;
  final List<ClientDevice> clients;
  final List<EnvironmentZone> zones;
  final String? selectedWallId;
  final String? selectedApId;
  final String? selectedClientId;
  final String? selectedZoneId;
  final dynamic activeTool; // EditorTool – dynamic to avoid circular import
  final WallMaterial drawingMaterial;
  final ZoneType? zoneTypeBeingDrawn;
  final OnWallAdded onWallAdded;
  final OnWallSelected onWallSelected;
  final OnApPlaced onApPlaced;
  final OnApMoved onApMoved;
  final OnApSelected onApSelected;
  final OnClientPlaced onClientPlaced;
  final OnClientMoved onClientMoved;
  final OnClientSelected onClientSelected;
  final OnZoneAdded onZoneAdded;
  final OnZoneSelected onZoneSelected;

  // Heat map
  final SignalMap? signalMap;
  final bool showHeatMap;
  final WiFiBand? activeBand;
  final double heatMapOpacity;

  /// Optional per-client performance data — used to draw throughput badges.
  final Map<String, ClientPerf>? clientPerf;

  /// When true, AP and client dragging is disabled (used on web during live
  /// computation to prevent triggering a recompute on every pointer-move).
  final bool dragLocked;

  @override
  State<FloorPlanCanvas> createState() => _FloorPlanCanvasState();
}

class _FloorPlanCanvasState extends State<FloorPlanCanvas>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();
  final _clipKey = GlobalKey(); // used to measure the viewport for auto-fit

  // Animation controller for the client → AP line dash animation.
  late final AnimationController _lineAnimController;
  static const _lineAnimDuration = Duration(milliseconds: 1200);

  // Wall drawing state.
  Offset? _drawStart;
  Offset? _drawCursor;

  // Zone drawing state.
  Offset? _zoneDrawStart;
  Offset? _zoneDrawCursor;

  // AP placement preview.
  Offset? _apPlaceCursor;

  // Client placement preview.
  Offset? _clientPlaceCursor;

  // AP drag state.
  String? _draggingApId;
  Offset? _dragOffset; // scene offset from AP centre to pointer at drag start.

  // Client drag state.
  String? _draggingClientId;
  Offset? _clientDragOffset;

  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    // Drive the dashed association-line animation.
    _lineAnimController = AnimationController(
      vsync: this,
      duration: _lineAnimDuration,
    );
    _updateLineAnim();
    // Fit the floor plan to the viewport on first render.
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
  }

  @override
  void didUpdateWidget(FloorPlanCanvas old) {
    super.didUpdateWidget(old);
    // Re-fit whenever a new floor plan is loaded.
    if (old.floorPlan.id != widget.floorPlan.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitView());
    }
    // Start/stop animation when selection changes.
    if (old.selectedClientId != widget.selectedClientId ||
        old.selectedApId != widget.selectedApId) {
      _updateLineAnim();
    }
  }

  /// Starts the association-line animation when something is selected,
  /// stops it when the selection is cleared (to avoid wasteful repaints).
  void _updateLineAnim() {
    final hasSelection =
        widget.selectedClientId != null || widget.selectedApId != null;
    if (hasSelection && !_lineAnimController.isAnimating) {
      _lineAnimController.repeat();
    } else if (!hasSelection && _lineAnimController.isAnimating) {
      _lineAnimController.stop();
    }
  }

  /// Scales and centres the floor plan so it fills the visible viewport.
  void _fitView() {
    if (!mounted) return;
    final box = _clipKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final vpW = box.size.width;
    final vpH = box.size.height;
    if (vpW <= 0 || vpH <= 0) return;

    final imgW = widget.floorPlan.imageWidth;
    final imgH = widget.floorPlan.imageHeight;
    if (imgW <= 0 || imgH <= 0) return;

    final s = math.min(vpW / imgW, vpH / imgH);
    final tx = (vpW - imgW * s) / 2.0;
    final ty = (vpH - imgH * s) / 2.0;

    // Build the scale-then-translate matrix directly to avoid deprecated API:
    // [ s  0  0  tx ]
    // [ 0  s  0  ty ]
    // [ 0  0  1   0 ]
    // [ 0  0  0   1 ]
    final m = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
    _transformController.value = m;
    setState(() {
      _scale = s;
    });
  }

  @override
  void dispose() {
    _lineAnimController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Coordinate helpers
  // ---------------------------------------------------------------------------

  /// Convert a viewport-space offset to scene (image) coordinates.
  Offset _toScene(Offset viewportOffset) =>
      _transformController.toScene(viewportOffset);

  /// Extract the current zoom factor from the transformation matrix.
  double _currentScale() {
    final m = _transformController.value;
    return math.sqrt(
      m.entry(0, 0) * m.entry(0, 0) + m.entry(1, 0) * m.entry(1, 0),
    );
  }

  // ---------------------------------------------------------------------------
  // Hit-testing
  // ---------------------------------------------------------------------------

  static const double _apHitRadius = 20.0;
  static const double _clientHitRadius = 16.0;

  String? _hitTestAp(Offset point) {
    final hitR = (_apHitRadius / _currentScale()).clamp(8.0, 40.0);
    for (final ap in widget.accessPoints.reversed) {
      if ((point - Offset(ap.positionX, ap.positionY)).distance <= hitR) {
        return ap.id;
      }
    }
    return null;
  }

  String? _hitTestClient(Offset point) {
    final hitR = (_clientHitRadius / _currentScale()).clamp(6.0, 30.0);
    for (final c in widget.clients.reversed) {
      if ((point - Offset(c.positionX, c.positionY)).distance <= hitR) {
        return c.id;
      }
    }
    return null;
  }

  /// Returns the id of the zone that contains [point], or null.
  String? _hitTestZone(Offset point) {
    for (final zone in widget.zones.reversed) {
      if (zone.containsPoint(point.dx, point.dy)) return zone.id;
    }
    return null;
  }

  /// Returns the id of the wall closest to [point] within [threshold] pixels
  /// (in scene coordinates), or null if none.
  String? _hitTestWall(Offset point, {double threshold = 10.0}) {
    String? best;
    double bestDist = double.infinity;

    for (final wall in widget.walls) {
      final dist = _distanceToSegment(
        point,
        Offset(wall.startX, wall.startY),
        Offset(wall.endX, wall.endY),
      );
      if (dist < threshold && dist < bestDist) {
        bestDist = dist;
        best = wall.id;
      }
    }
    return best;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final lengthSq = ab.distanceSquared;
    if (lengthSq == 0) return (p - a).distance;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) / lengthSq;
    final clamped = t.clamp(0.0, 1.0);
    final closest = a + ab * clamped;
    return (p - closest).distance;
  }

  // ---------------------------------------------------------------------------
  // Gesture handling
  // ---------------------------------------------------------------------------

  String get _toolName => widget.activeTool.toString().split('.').last;

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kSecondaryMouseButton) {
      _cancelAll();
      return;
    }

    final scene = _toScene(event.localPosition);

    switch (_toolName) {
      case 'drawWall':
        _handleDrawTap(scene);
      case 'select':
        _handleSelectDown(scene);
      case 'placeAP':
        _handlePlaceApTap(scene);
      case 'placeClient':
        _handlePlaceClientTap(scene);
      case 'drawZone':
        _handleDrawZoneTap(scene);
      default:
        break;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final scene = _toScene(event.localPosition);

    if (_toolName == 'drawWall' && _drawStart != null) {
      setState(() {
        _drawCursor = scene;
        _scale = _currentScale();
      });
      return;
    }

    if (_toolName == 'drawZone' && _zoneDrawStart != null) {
      setState(() {
        _zoneDrawCursor = scene;
        _scale = _currentScale();
      });
      return;
    }

    if (_toolName == 'placeAP') {
      setState(() => _apPlaceCursor = scene);
      return;
    }

    if (_toolName == 'placeClient') {
      setState(() => _clientPlaceCursor = scene);
      return;
    }

    if (_toolName == 'select' && _draggingApId != null && _dragOffset != null) {
      final newCenter = scene - _dragOffset!;
      widget.onApMoved(_draggingApId!, newCenter.dx, newCenter.dy);
    }

    if (_toolName == 'select' &&
        _draggingClientId != null &&
        _clientDragOffset != null) {
      final newCenter = scene - _clientDragOffset!;
      widget.onClientMoved(_draggingClientId!, newCenter.dx, newCenter.dy);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_draggingApId != null) {
      setState(() {
        _draggingApId = null;
        _dragOffset = null;
      });
    }
    if (_draggingClientId != null) {
      setState(() {
        _draggingClientId = null;
        _clientDragOffset = null;
      });
    }
  }

  void _handleDrawTap(Offset scene) {
    if (_drawStart == null) {
      setState(() => _drawStart = scene);
    } else {
      final start = _drawStart!;
      final end = scene;

      // Reject near-duplicate walls: both endpoints must be >8 scene-pixels
      // from every existing wall to avoid stacking on the same line.
      final dedupThresh = (8.0 / _currentScale()).clamp(4.0, 20.0);
      final isDuplicate = widget.walls.any((w) {
        final d1 = _distanceToSegment(
          start,
          Offset(w.startX, w.startY),
          Offset(w.endX, w.endY),
        );
        final d2 = _distanceToSegment(
          end,
          Offset(w.startX, w.startY),
          Offset(w.endX, w.endY),
        );
        return d1 < dedupThresh && d2 < dedupThresh;
      });

      if (!isDuplicate) {
        widget.onWallAdded(
          WallSegment(
            id: _uuid.v4(),
            startX: start.dx,
            startY: start.dy,
            endX: end.dx,
            endY: end.dy,
            material: widget.drawingMaterial,
          ),
        );
      }

      setState(() {
        _drawStart = null;
        _drawCursor = null;
      });
    }
  }

  void _handleSelectDown(Offset scene) {
    // APs take priority, then clients, then walls.
    final apId = _hitTestAp(scene);
    if (apId != null) {
      widget.onApSelected(apId);
      widget.onClientSelected(null);
      widget.onWallSelected(null);
      if (!widget.dragLocked) {
        final ap = widget.accessPoints.firstWhere((a) => a.id == apId);
        setState(() {
          _draggingApId = apId;
          _dragOffset = scene - Offset(ap.positionX, ap.positionY);
        });
      }
      return;
    }
    final clientId = _hitTestClient(scene);
    if (clientId != null) {
      widget.onClientSelected(clientId);
      widget.onApSelected(null);
      widget.onWallSelected(null);
      if (!widget.dragLocked) {
        final c = widget.clients.firstWhere((c) => c.id == clientId);
        setState(() {
          _draggingClientId = clientId;
          _clientDragOffset = scene - Offset(c.positionX, c.positionY);
        });
      }
      return;
    }
    widget.onApSelected(null);
    widget.onClientSelected(null);
    widget.onZoneSelected(_hitTestZone(scene));
    widget.onWallSelected(
      _hitTestWall(scene, threshold: (10.0 / _currentScale()).clamp(5.0, 30.0)),
    );
  }

  void _handlePlaceApTap(Offset scene) {
    widget.onApPlaced(scene.dx, scene.dy);
    setState(() => _apPlaceCursor = null);
  }

  void _handlePlaceClientTap(Offset scene) {
    widget.onClientPlaced(scene.dx, scene.dy);
    setState(() => _clientPlaceCursor = null);
  }

  void _handleDrawZoneTap(Offset scene) {
    if (_zoneDrawStart == null) {
      setState(() {
        _zoneDrawStart = scene;
        _zoneDrawCursor = scene;
      });
    } else {
      final x1 = _zoneDrawStart!.dx;
      final y1 = _zoneDrawStart!.dy;
      final x2 = scene.dx;
      final y2 = scene.dy;
      // Ignore tiny accidental clicks.
      if ((x2 - x1).abs() > 4 && (y2 - y1).abs() > 4) {
        widget.onZoneAdded(
          EnvironmentZone(
            id: _uuid.v4(),
            name: '',
            type: widget.zoneTypeBeingDrawn ?? ZoneType.rfInterference,
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
          ),
        );
      }
      setState(() {
        _zoneDrawStart = null;
        _zoneDrawCursor = null;
      });
    }
  }

  void _cancelAll() {
    if (_toolName == 'placeAP') {
      widget.onApPlaced(-1, -1);
    }
    if (_toolName == 'placeClient') {
      widget.onClientPlaced(-1, -1);
    }
    setState(() {
      _drawStart = null;
      _drawCursor = null;
      _zoneDrawStart = null;
      _zoneDrawCursor = null;
      _apPlaceCursor = null;
      _clientPlaceCursor = null;
      _draggingApId = null;
      _dragOffset = null;
      _draggingClientId = null;
      _clientDragOffset = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDrawing = _toolName == 'drawWall';
    final isPlacingAP = _toolName == 'placeAP';
    final isPlacingClient = _toolName == 'placeClient';
    final isDrawingZone = _toolName == 'drawZone';
    final isDragging = _draggingApId != null || _draggingClientId != null;

    return ClipRect(
      key: _clipKey,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: InteractiveViewer(
          transformationController: _transformController,
          constrained: false,
          minScale: 0.05,
          maxScale: 8.0,
          panEnabled:
              (!isDrawing || _drawStart == null) &&
              (!isDrawingZone || _zoneDrawStart == null) &&
              !isDragging,
          scaleEnabled: !isDragging,
          onInteractionUpdate: (_) {
            final s = _currentScale();
            if ((s - _scale).abs() > 0.01) setState(() => _scale = s);
          },
          child: SizedBox(
            width: widget.floorPlan.imageWidth,
            height: widget.floorPlan.imageHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Floor plan image.
                Positioned.fill(
                  child: Image.memory(
                    widget.floorPlan.imageBytes,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),

                // Heat map overlay (below AP rings, above floor plan).
                if (widget.showHeatMap && widget.signalMap != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: HeatMapPainter(
                        signalMap: widget.signalMap!,
                        activeBand: widget.activeBand,
                        opacity: widget.heatMapOpacity,
                      ),
                    ),
                  ),

                // Environment zones (above heat map, below APs).
                Positioned.fill(
                  child: CustomPaint(
                    painter: ZonePainter(
                      zones: widget.zones,
                      selectedZoneId: widget.selectedZoneId,
                      scale: _scale,
                      previewStart: isDrawingZone ? _zoneDrawStart : null,
                      previewCursor: isDrawingZone ? _zoneDrawCursor : null,
                      previewZoneType: widget.zoneTypeBeingDrawn,
                    ),
                  ),
                ),

                // AP coverage rings + icons.
                Positioned.fill(
                  child: CustomPaint(
                    painter: ApPainter(
                      accessPoints: widget.accessPoints,
                      selectedApId: widget.selectedApId,
                      canvasScale: _scale,
                      pixelsPerMeter: widget.floorPlan.pixelsPerMeter,
                      previewPosition: isPlacingAP ? _apPlaceCursor : null,
                    ),
                  ),
                ),

                // Client devices + association lines.
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _lineAnimController,
                    builder: (context, _) => CustomPaint(
                      painter: ClientPainter(
                        clients: widget.clients,
                        accessPoints: widget.accessPoints,
                        signalMap: widget.signalMap,
                        selectedClientId: widget.selectedClientId,
                        selectedApId: widget.selectedApId,
                        canvasScale: _scale,
                        previewPosition: isPlacingClient
                            ? _clientPlaceCursor
                            : null,
                        clientPerf: widget.clientPerf,
                        dashOffset: _lineAnimController.value,
                      ),
                    ),
                  ),
                ),

                // Wall overlay.
                Positioned.fill(
                  child: CustomPaint(
                    painter: WallPainter(
                      walls: widget.walls,
                      selectedWallId: widget.selectedWallId,
                      previewStart: _drawStart,
                      previewEnd: _drawCursor,
                      canvasScale: _scale,
                    ),
                  ),
                ),

                // Cursor override.
                if (isDrawing ||
                    isDrawingZone ||
                    isPlacingAP ||
                    isPlacingClient ||
                    isDragging)
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: isDragging
                          ? SystemMouseCursors.grabbing
                          : SystemMouseCursors.precise,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
