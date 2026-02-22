import 'dart:math' as math;

import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/environment_zone.dart';
import 'package:airreader/models/network_performance.dart';
import 'package:airreader/models/survey.dart';
import 'package:airreader/models/wall.dart';

/// Synchronous analytical computation of network performance.
///
/// Unlike the heat-map renderer this runs on the main isolate; it only touches
/// O(clients × APs) data points rather than O(pixels) so it is fast enough to
/// run inline and debounce via the cubit.
class NetworkPerformanceService {
  NetworkPerformanceService._();

  // --------------------------------------------------------------------------
  // Constants
  // --------------------------------------------------------------------------

  /// Thermal noise floor (dBm) used for SNR calculation.
  static const double _noiseFloorDbm = -95.0;

  /// 802.11ac 1-spatial-stream PHY rates (Mbps) at 80 MHz for MCS 0..9.
  static const List<double> _phyRates80Mhz = [
    29.3, //  MCS 0  – BPSK  1/2
    58.5, //  MCS 1  – QPSK  1/2
    87.8, //  MCS 2  – QPSK  3/4
    117.0, // MCS 3  – 16-QAM 1/2
    175.5, // MCS 4  – 16-QAM 3/4
    234.0, // MCS 5  – 64-QAM 2/3
    263.3, // MCS 6  – 64-QAM 3/4
    292.5, // MCS 7  – 64-QAM 5/6
    351.0, // MCS 8  – 256-QAM 3/4
    390.0, // MCS 9  – 256-QAM 5/6
  ];

  /// MAC / protocol overhead efficiency factor (CSMA/CA, ACKs, headers etc.)
  static const double _protocolEfficiency = 0.65;

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Compute [NetworkPerformance] from [survey] data without hitting the
  /// background isolate.  Returns null if there are no APs or clients.
  static NetworkPerformance? compute(
    Survey survey, {
    Set<String> disabledClientIds = const {},
  }) {
    final aps = survey.accessPoints;
    final clients = survey.clientDevices;

    if (aps.isEmpty || clients.isEmpty) {
      return NetworkPerformance(
        perAp: const {},
        perClient: const {},
        totalWanMbps: survey.totalWanBandwidthMbps,
        totalUtilisedMbps: 0,
      );
    }

    final walls = survey.walls;
    final zones = survey.zones;
    final wanMbps = survey.totalWanBandwidthMbps;

    // Pre-build a (apId → band → BandConfig) lookup used in association.
    final apBandConfig = <String, Map<WiFiBand, BandConfig>>{
      for (final ap in aps)
        ap.id: {
          for (final b in ap.bands)
            if (b.enabled) b.band: b,
        },
    };

    // ------------------------------------------------------------------
    // Step 1: Compute RSSI for every (client, AP, band) triplet.
    // ------------------------------------------------------------------

    // rssiTable[clientId][apId][band] = dBm
    final rssiTable = <String, Map<String, Map<WiFiBand, double>>>{};

    for (final client in clients) {
      final perAp = <String, Map<WiFiBand, double>>{};
      for (final ap in aps) {
        final perBand = <WiFiBand, double>{};
        for (final bandCfg in ap.bands) {
          if (!bandCfg.enabled) continue;
          final rssi = _computeRssi(
            txPowerDbm: bandCfg.txPowerDbm,
            antennaGainDbi: ap.antennaGainDbi,
            frequencyMhz: bandCfg.frequencyMhz,
            apX: ap.positionX,
            apY: ap.positionY,
            clientX: client.positionX,
            clientY: client.positionY,
            pixelsPerMeter: survey.floorPlan?.pixelsPerMeter ?? 50.0,
            walls: walls,
            zones: zones,
          );
          perBand[bandCfg.band] = rssi;
        }
        if (perBand.isNotEmpty) perAp[ap.id] = perBand;
      }
      rssiTable[client.id] = perAp;
    }

    // ------------------------------------------------------------------
    // Step 2: Determine which AP (and band) each client associates with.
    // ------------------------------------------------------------------
    // Association is decided by the band/AP pair that yields the highest
    // *achievable PHY rate* (SNR → MCS → rate × channelWidth), not by raw
    // RSSI.  This means:
    //   • 5 GHz / 6 GHz with wider channels wins at short range even if its
    //     raw RSSI is slightly lower than 2.4 GHz.
    //   • Changing channel width / frequency on an AP immediately changes
    //     which band clients prefer and what throughput they get.
    //   • manual AP override and preferredBand are still respected.
    final association = <String, _Association>{};

    for (final client in clients) {
      final perAp = rssiTable[client.id] ?? {};

      // Manual override takes first priority.
      if (client.manualApId != null) {
        final manualBands = perAp[client.manualApId];
        final cfgs = apBandConfig[client.manualApId];
        if (manualBands != null && manualBands.isNotEmpty && cfgs != null) {
          final best = _bestBandByThroughput(
            manualBands,
            cfgs,
            client.preferredBand,
          );
          association[client.id] = _Association(
            client.manualApId!,
            best.key,
            best.value,
          );
          continue;
        }
      }

      // Pick the AP+band that gives the highest achievable PHY rate,
      // respecting preferredBand if set.
      _Association? bestAssoc;
      double bestRate = double.negativeInfinity;
      for (final apEntry in perAp.entries) {
        final cfgs = apBandConfig[apEntry.key];
        if (cfgs == null) continue;
        final best = _bestBandByThroughput(
          apEntry.value,
          cfgs,
          client.preferredBand,
        );
        // Score = PHY rate at the chosen band (not just RSSI).
        final snr = best.value - _noiseFloorDbm;
        final mcs = _mcsFromSnr(snr);
        final cfg = cfgs[best.key];
        final rate = cfg != null
            ? _phyRates80Mhz[mcs] * (cfg.channelWidthMhz / 80.0)
            : 0.0;
        if (rate > bestRate) {
          bestRate = rate;
          bestAssoc = _Association(apEntry.key, best.key, best.value);
        }
      }
      if (bestAssoc != null) {
        association[client.id] = bestAssoc;
      }
    }

    // ------------------------------------------------------------------
    // Step 3: Group clients by AP and per-AP WAN allocation.
    // ------------------------------------------------------------------

    // apClients[apId] = [clientIds]
    final apClients = <String, List<String>>{};
    for (final ap in aps) {
      apClients[ap.id] = [];
    }
    for (final client in clients) {
      // Disabled clients are excluded from air-time contention so the
      // remaining enabled clients get a larger share of the medium.
      if (disabledClientIds.contains(client.id)) continue;
      final assoc = association[client.id];
      if (assoc != null) {
        apClients.putIfAbsent(assoc.apId, () => []).add(client.id);
      }
    }

    // Per-AP WAN allocation.
    // If an AP has speedAllocationMbps set explicitly, use that.
    // Otherwise divide WAN equally among APs that have at least one client.
    final activeAps = aps.where((a) => (apClients[a.id]?.isNotEmpty) ?? false);
    final activeCount = activeAps.length;

    double apAllocation(AccessPoint ap) {
      if (ap.speedAllocationMbps != null) return ap.speedAllocationMbps!;
      if (wanMbps != null && activeCount > 0) return wanMbps / activeCount;
      return double.infinity; // unconstrained if no WAN set
    }

    // ------------------------------------------------------------------
    // Step 4: Compute per-client throughput.
    // ------------------------------------------------------------------
    final perClientMap = <String, ClientPerf>{};

    for (final client in clients) {
      final assoc = association[client.id];
      if (assoc == null) {
        // No AP visible — dead zone
        perClientMap[client.id] = ClientPerf(
          clientId: client.id,
          clientName: client.name,
          rssiDbm: _noiseFloorDbm,
          snrDb: 0,
          mcsIndex: 0,
          phyRateMbps: 0,
          effectiveMbps: 0,
          warnings: ['No AP coverage'],
          isDisabled: disabledClientIds.contains(client.id),
        );
        continue;
      }

      final ap = aps.firstWhere((a) => a.id == assoc.apId);
      final bandCfg = ap.bands.firstWhere(
        (b) => b.band == assoc.band,
        orElse: () => BandConfig(band: assoc.band),
      );

      final rssi = assoc.rssiDbm;
      final snr = rssi - _noiseFloorDbm;
      final mcs = _mcsFromSnr(snr);
      final baseRate = _phyRates80Mhz[mcs];

      // Scale by actual channel width vs the 80 MHz reference table.
      final scaledRate = baseRate * (bandCfg.channelWidthMhz / 80.0);

      // ── Zone info (which zones cross the AP→client path) ──────────────
      final zoneInfo = _zonesOnPath(
        apX: ap.positionX,
        apY: ap.positionY,
        clientX: client.positionX,
        clientY: client.positionY,
        zones: zones,
        band: assoc.band,
      );

      final isClientDisabled = disabledClientIds.contains(client.id);

      final warnings = <String>[];
      if (rssi < -80) {
        warnings.add('Very poor signal');
      } else if (rssi < -70) {
        warnings.add('Poor signal');
      }

      // Disabled devices: report the theoretical PHY rate so users can
      // see what they'd get, but zero effective throughput so the perf
      // panel clearly shows the device is off.
      if (isClientDisabled) {
        perClientMap[client.id] = ClientPerf(
          clientId: client.id,
          clientName: client.name,
          associatedApId: assoc.apId,
          associatedBand: assoc.band,
          rssiDbm: rssi,
          snrDb: snr,
          mcsIndex: mcs,
          phyRateMbps: scaledRate,
          effectiveMbps: 0,
          warnings: warnings,
          isDisabled: true,
          activeZones: zoneInfo.zoneNames,
          zoneModifierDb: zoneInfo.modifierDb,
        );
        continue;
      }

      // ── RF air-time share ──────────────────────────────────────────────
      // Only ENABLED clients on the same AP contend for air time.  Disabled
      // clients have already been removed from apClients so clientCount
      // reflects the true number of active contenders.
      final clientCount = math.max(1, apClients[ap.id]?.length ?? 1);
      final rfShare = scaledRate * _protocolEfficiency / clientCount;

      // ── WAN cap (per-client share of the AP's WAN allocation) ──────────
      final apAlloc = apAllocation(ap);
      final wanShare = apAlloc.isFinite
          ? apAlloc / clientCount
          : double.infinity;

      // Effective throughput is bounded by whichever constraint is tighter.
      final effective = math.min(rfShare, wanShare);
      final isWanLimited = wanShare.isFinite && wanShare < rfShare;

      if (effective < 5.0) warnings.add('Low throughput');
      if (isWanLimited) warnings.add('Speed capped by WAN limit');

      perClientMap[client.id] = ClientPerf(
        clientId: client.id,
        clientName: client.name,
        associatedApId: assoc.apId,
        associatedBand: assoc.band,
        rssiDbm: rssi,
        snrDb: snr,
        mcsIndex: mcs,
        phyRateMbps: scaledRate,
        effectiveMbps: effective,
        warnings: warnings,
        activeZones: zoneInfo.zoneNames,
        zoneModifierDb: zoneInfo.modifierDb,
        isWanLimited: isWanLimited,
        rfMaxMbps: rfShare,
      );
    }

    // ------------------------------------------------------------------
    // Step 5: Build per-AP metrics.
    // ------------------------------------------------------------------
    final perApMap = <String, ApPerf>{};

    for (final ap in aps) {
      final clientIds = apClients[ap.id] ?? [];
      final apAlloc = apAllocation(ap);
      double utilisedMbps = 0;
      for (final cid in clientIds) {
        utilisedMbps += perClientMap[cid]?.effectiveMbps ?? 0;
      }
      final utilisationPct = apAlloc.isInfinite
          ? 0.0
          : (utilisedMbps / apAlloc).clamp(0.0, 1.0);

      final warnings = <String>[];
      if (utilisationPct > 0.8) warnings.add('AP overloaded');
      if (clientIds.isEmpty) warnings.add('No clients');

      final apName = [
        ap.brand,
        ap.model,
      ].where((s) => s.isNotEmpty).join(' ').trim();

      perApMap[ap.id] = ApPerf(
        apId: ap.id,
        apName: apName.isEmpty ? 'AP' : apName,
        clientIds: List.unmodifiable(clientIds),
        allocatedMbps: apAlloc.isInfinite ? 0 : apAlloc,
        utilisedMbps: utilisedMbps,
        utilisationPct: utilisationPct,
        warnings: List.unmodifiable(warnings),
      );
    }

    final totalUtilised = perClientMap.values.fold(
      0.0,
      (sum, c) => sum + c.effectiveMbps,
    );

    return NetworkPerformance(
      perAp: Map.unmodifiable(perApMap),
      perClient: Map.unmodifiable(perClientMap),
      totalWanMbps: wanMbps,
      totalUtilisedMbps: totalUtilised,
    );
  }

  // --------------------------------------------------------------------------
  // Private helpers
  // --------------------------------------------------------------------------

  /// Compute received signal strength (dBm) for a single AP→client ray.
  static double _computeRssi({
    required double txPowerDbm,
    required double antennaGainDbi,
    required double frequencyMhz,
    required double apX,
    required double apY,
    required double clientX,
    required double clientY,
    required double pixelsPerMeter,
    required List<WallSegment> walls,
    required List<EnvironmentZone> zones,
  }) {
    final dx = clientX - apX;
    final dy = clientY - apY;
    final distM = (math.sqrt(dx * dx + dy * dy) / pixelsPerMeter).clamp(
      0.1,
      5000.0,
    );

    // FSPL-based indoor path-loss.
    // We use a path-loss exponent of n = 3.5, which is the IEEE 802.11
    // residential-indoor standard (vs n = 2.0 for free space).  Free-space
    // keeps every device at MCS9 regardless of distance; n = 3.5 gives
    // realistic speed drop-off and makes zones / walls meaningful.
    //
    //   PL(d) = 20·log10(f_MHz) − 27.55 + 35·log10(d_m)
    final fsplDb =
        35.0 * math.log(distM) / math.ln10 +
        20.0 * math.log(frequencyMhz) / math.ln10 -
        27.55;

    // Wall attenuation.
    double wallLoss = 0.0;
    for (final wall in walls) {
      if (_segmentsIntersect(
        apX,
        apY,
        clientX,
        clientY,
        wall.startX,
        wall.startY,
        wall.endX,
        wall.endY,
      )) {
        wallLoss += wall.attenuationForFrequencyMhz(frequencyMhz);
      }
    }

    // Zone modifiers.
    double zoneMod = 0.0;
    for (final zone in zones) {
      if (_segmentIntersectsRect(
        apX,
        apY,
        clientX,
        clientY,
        zone.left,
        zone.top,
        zone.right,
        zone.bottom,
      )) {
        zoneMod += zone.type.modifierForFrequencyMhz(frequencyMhz);
      }
    }

    return txPowerDbm + antennaGainDbi - fsplDb - wallLoss + zoneMod;
  }

  /// Return the (band, rssi) entry that yields the highest achievable PHY
  /// rate for the given [rssiByBand] map and AP [bandConfigs].
  ///
  /// If [preferred] is set and present in the map, only that band is
  /// considered (honouring the user's explicit preference).
  static MapEntry<WiFiBand, double> _bestBandByThroughput(
    Map<WiFiBand, double> rssiByBand,
    Map<WiFiBand, BandConfig> bandConfigs,
    WiFiBand? preferred,
  ) {
    final candidates = preferred != null && rssiByBand.containsKey(preferred)
        ? {preferred: rssiByBand[preferred]!}
        : rssiByBand;

    MapEntry<WiFiBand, double>? best;
    double bestRate = double.negativeInfinity;
    for (final entry in candidates.entries) {
      final cfg = bandConfigs[entry.key];
      if (cfg == null) continue;
      final snr = entry.value - _noiseFloorDbm;
      final rate =
          _phyRates80Mhz[_mcsFromSnr(snr)] * (cfg.channelWidthMhz / 80.0);
      if (rate > bestRate) {
        bestRate = rate;
        best = entry;
      }
    }

    // Fallback: just return the strongest RSSI entry (shouldn't happen
    // unless all band configs are missing).
    return best ??
        rssiByBand.entries.reduce((a, b) => a.value >= b.value ? a : b);
  }

  /// Return the net zone modifier and display names for every zone whose
  /// rectangle is crossed by (or contains an endpoint of) the AP→client path.
  static ({double modifierDb, List<String> zoneNames}) _zonesOnPath({
    required double apX,
    required double apY,
    required double clientX,
    required double clientY,
    required List<EnvironmentZone> zones,
    required WiFiBand band,
  }) {
    double mod = 0.0;
    final names = <String>[];
    for (final zone in zones) {
      if (_segmentIntersectsRect(
        apX,
        apY,
        clientX,
        clientY,
        zone.left,
        zone.top,
        zone.right,
        zone.bottom,
      )) {
        mod += zone.type.modifierForBand(band);
        names.add(zone.name.isNotEmpty ? zone.name : zone.type.label);
      }
    }
    return (modifierDb: mod, zoneNames: names);
  }

  /// Map SNR (dB) to MCS index 0–9.
  static int _mcsFromSnr(double snrDb) {
    if (snrDb >= 38) return 9;
    if (snrDb >= 35) return 8;
    if (snrDb >= 33) return 7;
    if (snrDb >= 30) return 6;
    if (snrDb >= 28) return 5;
    if (snrDb >= 25) return 4;
    if (snrDb >= 20) return 3;
    if (snrDb >= 15) return 2;
    if (snrDb >= 10) return 1;
    return 0;
  }

  // --------------------------------------------------------------------------
  // Geometry helpers (mirrored from RfSimulationService)
  // --------------------------------------------------------------------------

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
    final d1 = _cross(dx - cx, dy - cy, ax - cx, ay - cy);
    final d2 = _cross(dx - cx, dy - cy, bx - cx, by - cy);
    final d3 = _cross(bx - ax, by - ay, cx - ax, cy - ay);
    final d4 = _cross(bx - ax, by - ay, dx - ax, dy - ay);
    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  static double _cross(double ux, double uy, double vx, double vy) =>
      ux * vy - uy * vx;

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
    // Segment endpoint inside rect → intersects.
    if (_pointInRect(ax, ay, left, top, right, bottom)) return true;
    if (_pointInRect(bx, by, left, top, right, bottom)) return true;
    // Check against each of the four rect edges.
    if (_segmentsIntersect(ax, ay, bx, by, left, top, right, top)) return true;
    if (_segmentsIntersect(ax, ay, bx, by, right, top, right, bottom))
      return true;
    if (_segmentsIntersect(ax, ay, bx, by, right, bottom, left, bottom))
      return true;
    if (_segmentsIntersect(ax, ay, bx, by, left, bottom, left, top))
      return true;
    return false;
  }

  static bool _pointInRect(
    double px,
    double py,
    double left,
    double top,
    double right,
    double bottom,
  ) => px >= left && px <= right && py >= top && py <= bottom;
}

// ============================================================================
// Private data class used during association step
// ============================================================================

class _Association {
  const _Association(this.apId, this.band, this.rssiDbm);
  final String apId;
  final WiFiBand band;
  final double rssiDbm;
}
