// lib/models/rf_engineering_analysis.dart
// Output model produced by RfEngineeringService.analyze().
// Each section maps to a step in the RF design methodology.

// ---------------------------------------------------------------------------
// Section 1 – RF Coverage Model
// ---------------------------------------------------------------------------

class RfCoverageResult {
  const RfCoverageResult({
    required this.pathLossExponent,
    required this.freqMhz,
    required this.fsplAt1mDb,
    required this.txPowerDbm,
    required this.antennaGainDbi,
    required this.rssiTargetDbm,
    required this.cellRadiusM,
    required this.cellAreaM2,
    required this.rssiAtCellEdgeDbm,
    required this.meetsTarget,
    required this.wallLossDbPerWall,
    required this.wallsAssumed,
    required this.totalWallLossDb,
  });

  /// Path-loss exponent (n) used in 10·n·log10(d).
  final double pathLossExponent;

  /// Centre frequency in MHz.
  final double freqMhz;

  /// Free-space path loss at d₀ = 1 m (dB).
  final double fsplAt1mDb;

  /// AP transmit power (dBm).
  final double txPowerDbm;

  /// AP antenna gain (dBi).
  final double antennaGainDbi;

  /// Design RSSI target at cell edge (dBm).
  final double rssiTargetDbm;

  /// Maximum cell radius where RSSI ≥ target (m).
  final double cellRadiusM;

  /// Single-AP coverage area (m²).
  final double cellAreaM2;

  /// Actual predicted RSSI exactly at the cell edge (dBm).
  final double rssiAtCellEdgeDbm;

  /// Whether the predicted RSSI at cell edge meets the target.
  final bool meetsTarget;

  /// Per-wall penetration loss used in the model (dB).
  final double wallLossDbPerWall;

  /// Number of interior walls assumed between AP and cell edge.
  final int wallsAssumed;

  /// Total wall-penetration budget used (dB).
  final double totalWallLossDb;
}

// ---------------------------------------------------------------------------
// Section 2 – SNR Calculation
// ---------------------------------------------------------------------------

class SnrResult {
  const SnrResult({
    required this.noiseFloorDbm,
    required this.thermalNoiseDbm,
    required this.noiseMarginDb,
    required this.snrAtCellEdgeDb,
    required this.snrAtCellCentreDb,
    required this.expectedMcsRange,
    required this.channelWidthMhz,
  });

  /// System noise floor used (dBm) including NF margin.
  final double noiseFloorDbm;

  /// Thermal noise floor for the channel width (dBm).
  final double thermalNoiseDbm;

  /// Additional noise-figure + interference margin (dB).
  final double noiseMarginDb;

  /// SNR at the cell edge (dB).
  final double snrAtCellEdgeDb;

  /// SNR near the AP / cell centre (reference 3 m) (dB).
  final double snrAtCellCentreDb;

  /// Human-readable MCS range string, e.g. "MCS 5–9".
  final String expectedMcsRange;

  final int channelWidthMhz;
}

// ---------------------------------------------------------------------------
// Section 3 – PHY Rate Estimation
// ---------------------------------------------------------------------------

class PhyRateResult {
  const PhyRateResult({
    required this.spatialStreams,
    required this.mcsAtEdge,
    required this.mcsAtCentre,
    required this.phyRateAtEdgeMbps,
    required this.phyRateAtCentreMbps,
    required this.protocolEfficiency,
    required this.realThroughputAtEdgeMbps,
    required this.realThroughputAtCentreMbps,
    required this.channelWidthMhz,
  });

  /// Number of spatial streams (SS) used in rate calculation.
  final int spatialStreams;

  /// MCS index at the cell edge.
  final int mcsAtEdge;

  /// MCS index near the AP.
  final int mcsAtCentre;

  /// Raw PHY rate at the cell edge (Mbps).
  final double phyRateAtEdgeMbps;

  /// Raw PHY rate near the AP (Mbps).
  final double phyRateAtCentreMbps;

  /// Protocol overhead factor applied (0–1).
  final double protocolEfficiency;

  /// Real application throughput at cell edge (Mbps).
  final double realThroughputAtEdgeMbps;

  /// Real application throughput near the AP (Mbps).
  final double realThroughputAtCentreMbps;

  final int channelWidthMhz;
}

// ---------------------------------------------------------------------------
// Section 4 – Capacity Model
// ---------------------------------------------------------------------------

class CapacityResult {
  const CapacityResult({
    required this.apRealThroughputMbps,
    required this.maxUsersPerApByThroughput,
    required this.perUserMbpsAtMaxLoad,
    required this.targetPerUserMbps,
    required this.concurrentUsersPerAp,
    required this.meetsTarget,
  });

  /// Effective AP throughput available for clients (Mbps).
  final double apRealThroughputMbps;

  /// Maximum number of users an AP can serve at target per-user rate.
  final int maxUsersPerApByThroughput;

  /// Actual per-user throughput when fully loaded (Mbps).
  final double perUserMbpsAtMaxLoad;

  /// Required per-user target (Mbps).
  final double targetPerUserMbps;

  /// Concurrent users assumed per AP after distributing [totalUsers].
  final double concurrentUsersPerAp;

  /// Whether the design meets the per-user throughput target.
  final bool meetsTarget;
}

// ---------------------------------------------------------------------------
// Section 5 – AP Count Estimation
// ---------------------------------------------------------------------------

class ApCountResult {
  const ApCountResult({
    required this.apCountByCoverage,
    required this.apCountByCapacity,
    required this.recommendedApCount,
    required this.limitingFactor,
    required this.totalFloors,
    required this.totalApCount,
  });

  /// APs required to cover the floor area.
  final int apCountByCoverage;

  /// APs required to serve the concurrent user load.
  final int apCountByCapacity;

  /// Higher of the two (recommended per floor).
  final int recommendedApCount;

  /// 'coverage' or 'capacity' — which constraint dominates.
  final String limitingFactor;

  /// Number of floors.
  final int totalFloors;

  /// Total AP count across all floors.
  final int totalApCount;
}

// ---------------------------------------------------------------------------
// Section 6 – Design Recommendations
// ---------------------------------------------------------------------------

class DesignRecommendation {
  const DesignRecommendation({
    required this.category,
    required this.title,
    required this.detail,
    required this.severity,
  });

  final String category;
  final String title;
  final String detail;

  /// 'info', 'warning', or 'critical'.
  final String severity;
}

// ---------------------------------------------------------------------------
// Top-level output
// ---------------------------------------------------------------------------

class RfEngineeringAnalysis {
  const RfEngineeringAnalysis({
    required this.coverage,
    required this.snr,
    required this.phyRate,
    required this.capacity,
    required this.apCount,
    required this.recommendations,
  });

  final RfCoverageResult coverage;
  final SnrResult snr;
  final PhyRateResult phyRate;
  final CapacityResult capacity;
  final ApCountResult apCount;
  final List<DesignRecommendation> recommendations;
}
