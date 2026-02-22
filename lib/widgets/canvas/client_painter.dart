import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/client_device.dart';
import 'package:airreader/models/network_performance.dart';
import 'package:airreader/models/signal_map.dart';

/// Paints client device icons, association lines to their AP, and RSSI badges.
class ClientPainter extends CustomPainter {
  ClientPainter({
    required this.clients,
    required this.accessPoints,
    required this.signalMap,
    required this.selectedClientId,
    required this.canvasScale,
    this.selectedApId,
    this.previewPosition,
    this.clientPerf,
    this.dashOffset = 0.0,
  });

  final List<ClientDevice> clients;
  final Map<String, ClientPerf>? clientPerf;
  final List<AccessPoint> accessPoints;
  final SignalMap? signalMap;
  final String? selectedClientId;

  /// When an AP is selected, its ID is stored here so all connected clients
  /// get an animated line flowing away from the AP toward the client.
  final String? selectedApId;
  final double canvasScale;

  /// Ghost position during placement mode.
  final Offset? previewPosition;

  /// Animation phase (0.0–1.0) used to make association line dashes march
  /// toward the AP.
  final double dashOffset;

  static const double _clientRadius = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw association lines first (behind icons).
    // Disabled clients have no active RF link so we skip their line.
    for (final client in clients) {
      if (clientPerf?[client.id]?.isDisabled ?? false) continue;
      final ap = _associatedAp(client);
      if (ap != null) {
        _drawAssociationLine(canvas, client, ap);
      }
    }

    // Draw client icons.
    for (final client in clients) {
      final center = Offset(client.positionX, client.positionY);
      final isSelected = client.id == selectedClientId;
      final rssi = _rssiForClient(client);
      final isDisabled = clientPerf?[client.id]?.isDisabled ?? false;
      _drawClientIcon(
        canvas,
        center,
        client.type,
        clientId: client.id,
        isSelected: isSelected,
        isDisabled: isDisabled,
        rssiDbm: rssi,
      );
    }

    // Ghost.
    if (previewPosition != null) {
      _drawClientIcon(
        canvas,
        previewPosition!,
        ClientDeviceType.laptop,
        isGhost: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Association line
  // ---------------------------------------------------------------------------

  void _drawAssociationLine(
    Canvas canvas,
    ClientDevice client,
    AccessPoint ap,
  ) {
    final start = Offset(client.positionX, client.positionY);
    final end = Offset(ap.positionX, ap.positionY);

    final rssi = _rssiForClient(client);
    final isClientSelected = client.id == selectedClientId;
    // Client selection takes priority: suppress AP-driven animation so that
    // selecting a client never shows AP→client flow on any line.
    final isApSelected = selectedClientId == null && ap.id == selectedApId;
    final isAnimated = isClientSelected || isApSelected;

    final color = isAnimated
        ? Colors.amber.shade700
        : _rssiColor(rssi).withValues(alpha: 0.45);

    final paint = Paint()
      ..color = color
      ..strokeWidth = (isAnimated ? 2.0 : 1.0) / canvasScale
      ..style = PaintingStyle.stroke;

    // Dashed line.
    final path = Path();
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1) return;

    final dashLen = 8.0 / canvasScale;
    final gapLen = 5.0 / canvasScale;
    final period = dashLen + gapLen;
    final ux = dx / dist;
    final uy = dy / dist;

    // For client→AP flow (client selected): phase advances forward (0→1).
    // For AP→client flow (AP selected): phase advances backward — achieved by
    // reversing the phase so dashes march from AP toward the client.
    double phaseShift;
    if (!isAnimated) {
      phaseShift = 0.0; // static
    } else if (isApSelected) {
      // Reverse: dashes flow from AP toward client.
      phaseShift = (1.0 - dashOffset) * period;
    } else {
      // Forward: dashes flow from client toward AP.
      phaseShift = dashOffset * period;
    }

    final steps = (dist / period).ceil() + 2;
    for (int i = -1; i < steps; i++) {
      final t0 = i * period + phaseShift;
      if (t0 >= dist) break;
      final t0c = t0.clamp(0.0, dist);
      final t1c = (t0 + dashLen).clamp(0.0, dist);
      if (t1c <= t0c + 0.001) continue;
      path.moveTo(start.dx + ux * t0c, start.dy + uy * t0c);
      path.lineTo(start.dx + ux * t1c, start.dy + uy * t1c);
    }

    canvas.drawPath(path, paint);

    // Only draw the arrowhead when animated.
    if (!isAnimated) return;

    const arrowLen = 6.0;
    final arrowR = arrowLen / canvasScale;

    final double tipX, tipY, arrowAngle;
    if (isApSelected) {
      // Arrow points FROM AP TOWARD client → tip sits just outside client icon.
      tipX = start.dx + ux * (_clientRadius / canvasScale + arrowR * 0.5);
      tipY = start.dy + uy * (_clientRadius / canvasScale + arrowR * 0.5);
      arrowAngle = math.atan2(-dy, -dx); // reversed direction
    } else {
      // Arrow points toward AP.
      tipX = end.dx - ux * (_apRadius / canvasScale + arrowR * 0.5);
      tipY = end.dy - uy * (_apRadius / canvasScale + arrowR * 0.5);
      arrowAngle = math.atan2(dy, dx);
    }

    final arrowPath = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(
        tipX - arrowR * math.cos(arrowAngle - 0.4),
        tipY - arrowR * math.sin(arrowAngle - 0.4),
      )
      ..lineTo(
        tipX - arrowR * math.cos(arrowAngle + 0.4),
        tipY - arrowR * math.sin(arrowAngle + 0.4),
      )
      ..close();

    canvas.drawPath(
      arrowPath,
      paint
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  static const double _apRadius = 16.0;

  // ---------------------------------------------------------------------------
  // Client icon
  // ---------------------------------------------------------------------------

  void _drawClientIcon(
    Canvas canvas,
    Offset center,
    ClientDeviceType type, {
    String? clientId,
    bool isSelected = false,
    bool isGhost = false,
    bool isDisabled = false,
    double? rssiDbm,
  }) {
    final r = (_clientRadius / canvasScale).clamp(6.0, 22.0);

    final Color bg;
    final Color border;
    final double borderW;

    if (isGhost) {
      bg = Colors.teal.withValues(alpha: 0.45);
      border = Colors.white.withValues(alpha: 0.6);
      borderW = 1.2 / canvasScale;
    } else if (isDisabled) {
      bg = Colors.grey.shade700.withValues(alpha: 0.50);
      border = Colors.grey.shade500.withValues(alpha: 0.45);
      borderW = 1.0 / canvasScale;
    } else if (isSelected) {
      bg = Colors.amber.shade700;
      border = Colors.amber.shade200;
      borderW = 2.2 / canvasScale;
    } else {
      bg = Colors.teal.shade700;
      border = Colors.white.withValues(alpha: 0.85);
      borderW = 1.4 / canvasScale;
    }

    // Background circle.
    // Non-ghost icons get a dark shadow ring + white separation ring for
    // contrast against any floor plan background.
    if (!isGhost) {
      canvas.drawCircle(
        center,
        r + (3.0 / canvasScale).clamp(1.5, 4.5),
        Paint()..color = Colors.black.withValues(alpha: 0.32),
      );
      canvas.drawCircle(
        center,
        r + (1.2 / canvasScale).clamp(0.6, 2.0),
        Paint()..color = Colors.white.withValues(alpha: 0.70),
      );
    }
    canvas.drawCircle(center, r, Paint()..color = bg);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderW,
    );

    // Icon glyph.
    final iconPaint = Paint()
      ..color = isGhost
          ? Colors.white.withValues(alpha: 0.6)
          : isDisabled
          ? Colors.grey.shade400
          : isSelected
          ? Colors.amber.shade100
          : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.4 / canvasScale).clamp(0.8, 2.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawDeviceGlyph(canvas, center, r, type, iconPaint);

    // RSSI badge under the icon (skip for disabled or ghost).
    if (!isGhost && !isDisabled && rssiDbm != null && rssiDbm > -110) {
      _drawRssiBadge(canvas, center, r, rssiDbm);
    }

    // 'OFF' label below disabled clients.
    if (isDisabled && !isGhost) {
      _drawOffBadge(canvas, center, r);
    }

    // Throughput badge above the icon when selected (skip for disabled).
    if (isSelected && !isGhost && !isDisabled) {
      final id = clientId;
      if (id != null) {
        final perf = clientPerf?[id];
        if (perf != null) {
          _drawThroughputBadge(canvas, center, r, perf);
        }
      }
    }
  }

  void _drawDeviceGlyph(
    Canvas canvas,
    Offset center,
    double r,
    ClientDeviceType type,
    Paint paint,
  ) {
    final s = r * 0.55;
    switch (type) {
      case ClientDeviceType.laptop:
        // Screen + base.
        final screen = Rect.fromCenter(
          center: center.translate(0, -s * 0.25),
          width: s * 1.4,
          height: s * 0.9,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(screen, Radius.circular(s * 0.12)),
          paint,
        );
        canvas.drawLine(
          center.translate(-s * 0.85, s * 0.5),
          center.translate(s * 0.85, s * 0.5),
          paint,
        );
      case ClientDeviceType.smartphone:
        // Phone shape.
        final phone = Rect.fromCenter(
          center: center,
          width: s * 0.7,
          height: s * 1.3,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(phone, Radius.circular(s * 0.18)),
          paint,
        );
        canvas.drawCircle(
          center.translate(0, s * 0.5),
          s * 0.1,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
      case ClientDeviceType.tablet:
        final tab = Rect.fromCenter(
          center: center,
          width: s * 1.0,
          height: s * 1.3,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(tab, Radius.circular(s * 0.12)),
          paint,
        );
      case ClientDeviceType.iotSensor:
        // Circle with dot.
        canvas.drawCircle(center, s * 0.65, paint);
        canvas.drawCircle(center, s * 0.18, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
      case ClientDeviceType.desktop:
        // Monitor + stand.
        final mon = Rect.fromCenter(
          center: center.translate(0, -s * 0.2),
          width: s * 1.4,
          height: s * 0.9,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(mon, Radius.circular(s * 0.1)),
          paint,
        );
        canvas.drawLine(
          center.translate(0, s * 0.25),
          center.translate(0, s * 0.55),
          paint,
        );
        canvas.drawLine(
          center.translate(-s * 0.35, s * 0.55),
          center.translate(s * 0.35, s * 0.55),
          paint,
        );
      case ClientDeviceType.smartTv:
        // Wide screen + legs.
        final tv = Rect.fromCenter(
          center: center.translate(0, -s * 0.15),
          width: s * 1.5,
          height: s * 0.85,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(tv, Radius.circular(s * 0.08)),
          paint,
        );
        canvas.drawLine(
          center.translate(-s * 0.25, s * 0.27),
          center.translate(-s * 0.35, s * 0.55),
          paint,
        );
        canvas.drawLine(
          center.translate(s * 0.25, s * 0.27),
          center.translate(s * 0.35, s * 0.55),
          paint,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // 'OFF' badge for disabled clients
  // ---------------------------------------------------------------------------

  void _drawOffBadge(Canvas canvas, Offset center, double r) {
    const text = 'OFF';
    final fontSize = 13.0 / canvasScale;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white70,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padH = 4.0 / canvasScale;
    final padV = 2.5 / canvasScale;
    final pillW = tp.width + padH * 2;
    final pillH = tp.height + padV * 2;
    final shadowRing = 3.0 / canvasScale;
    final pillTop = center.dy + r + shadowRing + 4.0 / canvasScale;
    final pillCenter = Offset(center.dx, pillTop + pillH / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pillCenter, width: pillW, height: pillH),
        Radius.circular(pillH / 2),
      ),
      Paint()..color = Colors.grey.shade700.withValues(alpha: 0.80),
    );

    tp.paint(canvas, Offset(center.dx - tp.width / 2, pillTop + padV));
  }

  // ---------------------------------------------------------------------------
  // Throughput badge (shown above selected client)
  // ---------------------------------------------------------------------------

  void _drawThroughputBadge(
    Canvas canvas,
    Offset center,
    double r,
    ClientPerf perf,
  ) {
    final mbps = perf.effectiveMbps;
    final bandLabel = perf.associatedBand?.label ?? '?';
    // When WAN-limited, show "X Mbps WAN" so the user immediately knows why.
    final line1 =
        '${mbps >= 10 ? mbps.toStringAsFixed(0) : mbps.toStringAsFixed(1)} Mbps'
        '${perf.isWanLimited ? ' ▲WAN' : ''}';
    final line2 = perf.isWanLimited
        ? 'RF ${perf.rfMaxMbps.toStringAsFixed(0)} · $bandLabel'
        : bandLabel;

    final fontSize = 13.0 / canvasScale;
    final smallFontSize = 11.0 / canvasScale;

    final tp1 = TextPainter(
      text: TextSpan(
        text: line1,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: perf.isWanLimited ? const Color(0xFFFFCC02) : Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tp2 = TextPainter(
      text: TextSpan(
        text: line2,
        style: TextStyle(
          fontSize: smallFontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padH = 7.0 / canvasScale;
    final padV = 4.0 / canvasScale;
    final gap = 2.0 / canvasScale;
    final contentW = math.max(tp1.width, tp2.width);
    final pillW = contentW + padH * 2;
    final pillH = tp1.height + gap + tp2.height + padV * 2;
    final pillBottom = center.dy - r - 4.0 / canvasScale;
    final pillTop = pillBottom - pillH;
    final pillCenter = Offset(center.dx, pillTop + pillH / 2);

    // Pill colour: orange-tinted when WAN-limited, dark teal otherwise.
    final pillColor = perf.isWanLimited
        ? const Color(0xFF7B4000)
        : const Color(0xFF006064);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pillCenter, width: pillW, height: pillH),
        Radius.circular(pillH / 2),
      ),
      Paint()..color = pillColor,
    );

    // Line 1: Mbps (+ WAN tag)
    tp1.paint(canvas, Offset(center.dx - tp1.width / 2, pillTop + padV));
    // Line 2: RF max · band  (or just band when not limited)
    tp2.paint(
      canvas,
      Offset(center.dx - tp2.width / 2, pillTop + padV + tp1.height + gap),
    );
  }

  // ---------------------------------------------------------------------------
  // RSSI badge
  // ---------------------------------------------------------------------------

  void _drawRssiBadge(Canvas canvas, Offset center, double r, double rssiDbm) {
    final color = _rssiColor(rssiDbm);
    final text = '${rssiDbm.round()} dBm';
    // True screen-space font size: always 13 logical pixels regardless of zoom.
    final fontSize = 13.0 / canvasScale;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padH = 6.0 / canvasScale;
    final padV = 3.5 / canvasScale;
    final pillW = tp.width + padH * 2;
    final pillH = tp.height + padV * 2;
    final shadowRing = 3.0 / canvasScale;
    final pillTop = center.dy + r + shadowRing + 4.0 / canvasScale;
    final pillCenter = Offset(center.dx, pillTop + pillH / 2);

    // Shadow.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pillCenter.translate(0, 1.5 / canvasScale),
          width: pillW,
          height: pillH,
        ),
        Radius.circular(pillH / 2),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.30),
    );

    // Solid coloured pill.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: pillCenter, width: pillW, height: pillH),
        Radius.circular(pillH / 2),
      ),
      Paint()..color = color,
    );

    // White text centred in the pill.
    tp.paint(canvas, Offset(center.dx - tp.width / 2, pillTop + padV));
  }

  // ---------------------------------------------------------------------------
  // Association helpers
  // ---------------------------------------------------------------------------

  AccessPoint? _associatedAp(ClientDevice client) {
    if (client.manualApId != null) {
      return accessPoints.where((a) => a.id == client.manualApId).firstOrNull;
    }
    // Best-signal AP for the client's preferred band.
    return _bestApForClient(client);
  }

  AccessPoint? _bestApForClient(ClientDevice client) {
    if (accessPoints.isEmpty) return null;

    // The composite SignalMap doesn't carry per-AP breakdown, so we can't
    // determine which AP contributes more signal from it.  Instead rank by
    // Euclidean pixel distance — the nearer AP is the most likely association.
    AccessPoint? best;
    double bestDist = double.infinity;
    for (final ap in accessPoints) {
      final d = math.sqrt(
        math.pow(ap.positionX - client.positionX, 2) +
            math.pow(ap.positionY - client.positionY, 2),
      );
      if (d < bestDist) {
        bestDist = d;
        best = ap;
      }
    }
    return best;
  }

  double _rssiForClient(ClientDevice client) {
    if (signalMap == null) return kNoSignal;
    final band = client.preferredBand;
    if (band == null) {
      return signalMap!.bestSignalAt(client.positionX, client.positionY);
    }
    final rssi = signalMap!.signalAt(band, client.positionX, client.positionY);
    return rssi > kNoSignal
        ? rssi
        : signalMap!.bestSignalAt(client.positionX, client.positionY);
  }

  static Color _rssiColor(double dBm) {
    if (dBm >= -55) return const Color(0xFF2E7D32);
    if (dBm >= -65) return const Color(0xFF9CCC65);
    if (dBm >= -75) return const Color(0xFFFFB300); // amber 700 – darker yellow
    if (dBm >= -85) return const Color(0xFFFF7043);
    return const Color(0xFFE53935);
  }

  @override
  bool shouldRepaint(ClientPainter old) =>
      old.clients != clients ||
      old.accessPoints != accessPoints ||
      old.signalMap != signalMap ||
      old.selectedClientId != selectedClientId ||
      old.selectedApId != selectedApId ||
      old.canvasScale != canvasScale ||
      old.previewPosition != previewPosition ||
      old.clientPerf != clientPerf ||
      old.dashOffset != dashOffset;
}
