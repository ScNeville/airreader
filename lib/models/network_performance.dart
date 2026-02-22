import 'package:airreader/models/access_point.dart';

// ============================================================================
// Per-client performance data
// ============================================================================

/// Computed RF and throughput metrics for a single [ClientDevice].
class ClientPerf {
  const ClientPerf({
    required this.clientId,
    required this.clientName,
    this.associatedApId,
    this.associatedBand,
    required this.rssiDbm,
    required this.snrDb,
    required this.mcsIndex,
    required this.phyRateMbps,
    required this.effectiveMbps,
    this.warnings = const [],
    this.isDisabled = false,
    this.activeZones = const [],
    this.zoneModifierDb = 0.0,
    this.isWanLimited = false,
    this.rfMaxMbps = 0.0,
  });

  /// ID of the associated [ClientDevice].
  final String clientId;

  /// Display name of the client.
  final String clientName;

  /// ID of the [AccessPoint] the client is associated with, or null if no
  /// suitable AP was found.
  final String? associatedApId;

  /// The WiFi band used for association.
  final WiFiBand? associatedBand;

  /// Received signal strength at the client position (dBm).
  final double rssiDbm;

  /// Signal-to-noise ratio: [rssiDbm] − noise floor (−95 dBm).
  final double snrDb;

  /// 802.11ac MCS index (0–9) derived from [snrDb].
  final int mcsIndex;

  /// Maximum theoretical 802.11 PHY rate for this MCS + channel width
  /// before protocol overhead or air-time sharing (Mbps).  This is the
  /// "headline" speed you'd see on a spec sheet.
  final double phyRateMbps;

  /// Estimated useful throughput after protocol overhead, air-time sharing,
  /// and WAN cap (Mbps).
  final double effectiveMbps;

  /// Human-readable warning strings (e.g. "Poor signal").
  final List<String> warnings;

  /// Whether this client has been toggled off in the simulation.
  /// Disabled clients are excluded from air-time contention so remaining
  /// clients get a larger share of the medium.
  final bool isDisabled;

  /// Display names of environment zones whose boundaries the AP→client
  /// signal path crosses.  May include zones that boost OR attenuate.
  final List<String> activeZones;

  /// Net dBm modifier applied by [activeZones] to this client's signal path.
  /// Negative = net attenuation; positive = net boost (e.g. outdoor zone).
  final double zoneModifierDb;

  /// True when the WAN bandwidth cap (not RF quality) is the limiting factor.
  /// Moving the device or fixing zones won't help — increase the WAN speed.
  final bool isWanLimited;

  /// The RF-only throughput ceiling before the WAN cap is applied (Mbps).
  /// Equals [effectiveMbps] when not WAN-limited.
  final double rfMaxMbps;
}

// ============================================================================
// Per-AP performance data
// ============================================================================

/// Aggregate performance metrics for a single [AccessPoint].
class ApPerf {
  const ApPerf({
    required this.apId,
    required this.apName,
    required this.clientIds,
    required this.allocatedMbps,
    required this.utilisedMbps,
    required this.utilisationPct,
    this.warnings = const [],
  });

  /// ID of the [AccessPoint].
  final String apId;

  /// Display name built from brand + model.
  final String apName;

  /// IDs of all clients associated to this AP.
  final List<String> clientIds;

  /// Bandwidth allocated to this AP from the WAN link (Mbps).
  final double allocatedMbps;

  /// Sum of [ClientPerf.effectiveMbps] for all clients on this AP (Mbps).
  final double utilisedMbps;

  /// Utilisation fraction 0.0–1.0 (utilisedMbps / allocatedMbps).
  final double utilisationPct;

  /// Human-readable warnings (e.g. "AP overloaded").
  final List<String> warnings;
}

// ============================================================================
// Top-level network performance snapshot
// ============================================================================

/// A full snapshot of network performance for the current survey.
class NetworkPerformance {
  const NetworkPerformance({
    required this.perAp,
    required this.perClient,
    required this.totalWanMbps,
    required this.totalUtilisedMbps,
  });

  /// Per-AP metrics keyed by AP ID.
  final Map<String, ApPerf> perAp;

  /// Per-client metrics keyed by client ID.
  final Map<String, ClientPerf> perClient;

  /// Total WAN bandwidth configured on the survey (Mbps), may be null.
  final double? totalWanMbps;

  /// Sum of all client effective throughput (Mbps).
  final double totalUtilisedMbps;
}
