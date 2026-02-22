// lib/services/rf_engineering_service.dart
// Professional RF engineering analysis using the log-distance path-loss model.
// Implements: coverage model → SNR → PHY rates → capacity → AP count → recs.

import 'dart:math';

import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/rf_engineering_analysis.dart';
import 'package:airreader/models/survey_environment.dart';
import 'package:airreader/utils/constants.dart';

class RfEngineeringService {
  RfEngineeringService._();

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const double _noiseMarginDb = 7.0; // NF + interference headroom
  static const double _thermalNoiseDensityDbmPerHz = -174.0; // kTB @ 290 K
  static const double _protocolEfficiency = 0.65;
  static const int _wallsAssumed = 2; // interior walls AP–edge, conservative

  /// PHY rates per MCS index (1SS, 80 MHz, 802.11ac/ax).
  static const List<double> _phyRates80Mhz = [
    29.3,
    58.5,
    87.8,
    117.0,
    175.5,
    234.0,
    263.3,
    292.5,
    351.0,
    390.0,
  ];

  /// PHY rates per MCS index (1SS, 160 MHz, 802.11ax).
  static const List<double> _phyRates160Mhz = [
    58.5,
    117.0,
    175.5,
    234.0,
    351.0,
    468.0,
    526.5,
    585.0,
    702.0,
    780.0,
  ];

  /// PHY rates per MCS index (1SS, 40 MHz).
  static const List<double> _phyRates40Mhz = [
    13.5,
    27.0,
    40.5,
    54.0,
    81.0,
    108.0,
    121.5,
    135.0,
    162.0,
    180.0,
  ];

  /// PHY rates per MCS index (1SS, 20 MHz).
  static const List<double> _phyRates20Mhz = [
    6.5,
    13.0,
    19.5,
    26.0,
    39.0,
    52.0,
    58.5,
    65.0,
    78.0,
    86.7,
  ];

  // ---------------------------------------------------------------------------
  // Entry point
  // ---------------------------------------------------------------------------

  static RfEngineeringAnalysis analyze(SurveyEnvironment env) {
    final freqMhz = _freqForBand(env.preferredBand);
    final n = env.pathLossExponent;
    final txPowerDbm = env.maxTxPowerDbm;
    const antennaGainDbi = AppConstants.defaultAntennaGainDbi;

    // ---- 1. Coverage -------------------------------------------------------
    final coverage = _analyzeCoverage(
      env,
      freqMhz,
      n,
      txPowerDbm,
      antennaGainDbi,
    );

    // ---- 2. SNR -----------------------------------------------------------
    final snr = _analyzeSnr(env, coverage);

    // ---- 3. PHY rate -------------------------------------------------------
    final phyRate = _analyzePhyRate(env, snr);

    // ---- 4. Capacity -------------------------------------------------------
    final capacity = _analyzeCapacity(env, phyRate);

    // ---- 5. AP count -------------------------------------------------------
    final apCount = _analyzeApCount(env, coverage, capacity);

    // ---- 6. Recommendations ------------------------------------------------
    final recs = _buildRecommendations(
      env,
      coverage,
      snr,
      phyRate,
      capacity,
      apCount,
    );

    return RfEngineeringAnalysis(
      coverage: coverage,
      snr: snr,
      phyRate: phyRate,
      capacity: capacity,
      apCount: apCount,
      recommendations: recs,
    );
  }

  // ---------------------------------------------------------------------------
  // Section helpers
  // ---------------------------------------------------------------------------

  static RfCoverageResult _analyzeCoverage(
    SurveyEnvironment env,
    double freqMhz,
    double n,
    double txPowerDbm,
    double antennaGainDbi,
  ) {
    // Free-space path loss at d₀ = 1 m:
    // FSPL(1m) = 20·log10(f_MHz) − 27.55
    final fsplAt1m = 20.0 * log(freqMhz) / ln10 - 27.55;

    // Wall loss budget
    final wallLossDb = env.constructionMaterial.wallLossForBand(
      env.preferredBand,
    );
    final totalWallLoss = wallLossDb * _wallsAssumed;

    // Total available link budget (EIRP − noise is handled in SNR section)
    // Here we solve for d where Pr(d) = rssiTarget:
    //   Pr(d) = txPower + antennaGain - [FSPL(1m) + 10n·log10(d)] - wallLoss
    //   rssiTarget = txPower + antennaGain - FSPL(1m) - wallLoss - 10n·log10(d)
    //   10n·log10(d) = txPower + antennaGain - FSPL(1m) - wallLoss - rssiTarget
    final rssiTarget = env.buildingType.rssiTargetDbm;
    final budget =
        txPowerDbm + antennaGainDbi - fsplAt1m - totalWallLoss - rssiTarget;
    final cellRadiusM = pow(10.0, budget / (10.0 * n)).toDouble();
    final cellAreaM2 = pi * cellRadiusM * cellRadiusM;

    // RSSI at exactly the cell edge
    final rssiAtEdge = _predictRssi(
      distM: cellRadiusM,
      freqMhz: freqMhz,
      n: n,
      txPowerDbm: txPowerDbm,
      antennaGainDbi: antennaGainDbi,
      totalWallLossDb: totalWallLoss,
    );

    return RfCoverageResult(
      pathLossExponent: n,
      freqMhz: freqMhz,
      fsplAt1mDb: fsplAt1m,
      txPowerDbm: txPowerDbm,
      antennaGainDbi: antennaGainDbi,
      rssiTargetDbm: rssiTarget,
      cellRadiusM: cellRadiusM,
      cellAreaM2: cellAreaM2,
      rssiAtCellEdgeDbm: rssiAtEdge,
      meetsTarget: rssiAtEdge >= rssiTarget - 0.5,
      wallLossDbPerWall: wallLossDb,
      wallsAssumed: _wallsAssumed,
      totalWallLossDb: totalWallLoss,
    );
  }

  static SnrResult _analyzeSnr(
    SurveyEnvironment env,
    RfCoverageResult coverage,
  ) {
    final chBw = env.channelWidthMhz;
    // Thermal noise: N = kTB → −174 dBm/Hz + 10·log10(BW_Hz)
    final thermalNoise =
        _thermalNoiseDensityDbmPerHz + 10.0 * log(chBw * 1e6) / ln10;
    final noiseFloor = thermalNoise + _noiseMarginDb;

    final snrAtEdge = coverage.rssiAtCellEdgeDbm - noiseFloor;

    // SNR near the AP (assume 3 m reference distance)
    const refDistM = 3.0;
    final rssiNearAp = _predictRssi(
      distM: refDistM,
      freqMhz: coverage.freqMhz,
      n: coverage.pathLossExponent,
      txPowerDbm: coverage.txPowerDbm,
      antennaGainDbi: coverage.antennaGainDbi,
      totalWallLossDb: 0,
    );
    final snrNearAp = rssiNearAp - noiseFloor;

    final mcsEdge = _mcsFromSnr(snrAtEdge);
    final mcsCentre = _mcsFromSnr(snrNearAp).clamp(0, 9);
    final mcsRange = mcsEdge == mcsCentre
        ? 'MCS $mcsEdge'
        : 'MCS $mcsEdge – $mcsCentre';

    return SnrResult(
      noiseFloorDbm: noiseFloor,
      thermalNoiseDbm: thermalNoise,
      noiseMarginDb: _noiseMarginDb,
      snrAtCellEdgeDb: snrAtEdge,
      snrAtCellCentreDb: snrNearAp,
      expectedMcsRange: mcsRange,
      channelWidthMhz: chBw,
    );
  }

  static PhyRateResult _analyzePhyRate(SurveyEnvironment env, SnrResult snr) {
    final ss = env.clientSpatialStreams.clamp(1, 3);
    final mcsEdge = _mcsFromSnr(snr.snrAtCellEdgeDb);
    final mcsCentre = _mcsFromSnr(snr.snrAtCellCentreDb).clamp(0, 9);
    final chBw = env.channelWidthMhz;

    final phyEdge = _phyRate(mcsEdge, chBw) * ss;
    final phyCentre = _phyRate(mcsCentre, chBw) * ss;

    return PhyRateResult(
      spatialStreams: ss,
      mcsAtEdge: mcsEdge,
      mcsAtCentre: mcsCentre,
      phyRateAtEdgeMbps: phyEdge,
      phyRateAtCentreMbps: phyCentre,
      protocolEfficiency: _protocolEfficiency,
      realThroughputAtEdgeMbps: phyEdge * _protocolEfficiency,
      realThroughputAtCentreMbps: phyCentre * _protocolEfficiency,
      channelWidthMhz: chBw,
    );
  }

  static CapacityResult _analyzeCapacity(
    SurveyEnvironment env,
    PhyRateResult phyRate,
  ) {
    // Use cell-edge throughput as the conservative AP throughput baseline.
    // In practice, a mix of near/far clients averages somewhere in between;
    // cell-edge is worst-case for capacity planning.
    final apThroughput = phyRate.realThroughputAtEdgeMbps;
    final perUserTarget = env.effectivePerUserMbps;

    final maxUsers = apThroughput <= 0
        ? 0
        : (apThroughput / perUserTarget).floor();

    final perUserAtLoad = maxUsers > 0 ? apThroughput / maxUsers : 0.0;

    return CapacityResult(
      apRealThroughputMbps: apThroughput,
      maxUsersPerApByThroughput: maxUsers,
      perUserMbpsAtMaxLoad: perUserAtLoad,
      targetPerUserMbps: perUserTarget,
      concurrentUsersPerAp: env.concurrentUsers.toDouble(),
      meetsTarget: perUserAtLoad >= perUserTarget * 0.9,
    );
  }

  static ApCountResult _analyzeApCount(
    SurveyEnvironment env,
    RfCoverageResult coverage,
    CapacityResult capacity,
  ) {
    final apCountCoverage = coverage.cellAreaM2 <= 0
        ? 1
        : (env.floorAreaM2 / coverage.cellAreaM2).ceil();
    final apCountCapacity = capacity.maxUsersPerApByThroughput <= 0
        ? env
              .concurrentUsers // fallback: 1 user per AP
        : (env.concurrentUsers / capacity.maxUsersPerApByThroughput).ceil();

    final recommended = apCountCoverage > apCountCapacity
        ? apCountCoverage
        : apCountCapacity;
    final limiting = apCountCoverage >= apCountCapacity
        ? 'coverage'
        : 'capacity';

    return ApCountResult(
      apCountByCoverage: apCountCoverage.clamp(1, 9999),
      apCountByCapacity: apCountCapacity.clamp(1, 9999),
      recommendedApCount: recommended.clamp(1, 9999),
      limitingFactor: limiting,
      totalFloors: env.numberOfFloors,
      totalApCount: (recommended * env.numberOfFloors).clamp(1, 9999),
    );
  }

  // ---------------------------------------------------------------------------
  // Recommendations engine
  // ---------------------------------------------------------------------------

  static List<DesignRecommendation> _buildRecommendations(
    SurveyEnvironment env,
    RfCoverageResult coverage,
    SnrResult snr,
    PhyRateResult phyRate,
    CapacityResult capacity,
    ApCountResult apCount,
  ) {
    final recs = <DesignRecommendation>[];

    // ---- Band steering ----
    if (env.preferredBand == WiFiBand.ghz24) {
      recs.add(
        const DesignRecommendation(
          category: 'Band Selection',
          title: 'Consider migrating to 5 GHz or 6 GHz',
          detail:
              '2.4 GHz is highly congested in multi-tenant environments and limited '
              'to 3 non-overlapping 20 MHz channels (1, 6, 11). 5 GHz offers 25+ '
              'non-overlapping 80 MHz channels and significantly higher throughput.',
          severity: 'warning',
        ),
      );
    }

    if (env.preferredBand == WiFiBand.ghz5 &&
        env.wifiStandard == WifiStandard.ax) {
      recs.add(
        const DesignRecommendation(
          category: 'Band Selection',
          title: 'Wi-Fi 6E 6 GHz band available',
          detail:
              'Wi-Fi 6E enables 1200 MHz of clean spectrum in the 6 GHz band '
              '(no legacy interference). Use for high-density or latency-sensitive '
              'deployments where client support exists.',
          severity: 'info',
        ),
      );
    }

    // ---- SNR / RSSI warnings ----
    if (snr.snrAtCellEdgeDb < 10) {
      recs.add(
        DesignRecommendation(
          category: 'Coverage',
          title:
              'Cell edge SNR too low (${snr.snrAtCellEdgeDb.toStringAsFixed(1)} dB)',
          detail:
              'SNR below 10 dB cannot sustain any HT MCS rate. Reduce AP '
              'spacing (increase AP count), increase TX power, or upgrade antennas.',
          severity: 'critical',
        ),
      );
    } else if (snr.snrAtCellEdgeDb < 20) {
      recs.add(
        DesignRecommendation(
          category: 'Coverage',
          title:
              'Low cell edge SNR (${snr.snrAtCellEdgeDb.toStringAsFixed(1)} dB)',
          detail:
              'SNR of ${snr.snrAtCellEdgeDb.toStringAsFixed(1)} dB limits the cell '
              'edge to MCS ${_mcsFromSnr(snr.snrAtCellEdgeDb)}. Consider a denser '
              'deployment or a roaming threshold of −70 dBm so clients hand off earlier.',
          severity: 'warning',
        ),
      );
    }

    // ---- RSSI target ----
    if (!coverage.meetsTarget) {
      recs.add(
        DesignRecommendation(
          category: 'Coverage',
          title: 'RSSI target not met at design cell radius',
          detail:
              'Predicted RSSI at cell edge is ${coverage.rssiAtCellEdgeDbm.toStringAsFixed(1)} dBm '
              '(target ${coverage.rssiTargetDbm.toStringAsFixed(0)} dBm). Reduce cell '
              'radius (add APs) or increase TX power.',
          severity: 'warning',
        ),
      );
    }

    // ---- Capacity ----
    if (!capacity.meetsTarget) {
      recs.add(
        DesignRecommendation(
          category: 'Capacity',
          title: 'Per-user throughput target at risk',
          detail:
              'With ${env.concurrentUsers} concurrent users and '
              '${apCount.recommendedApCount} APs, each AP serves ~'
              '${capacity.concurrentUsersPerAp.toStringAsFixed(0)} users but the '
              'effective per-user rate (${capacity.perUserMbpsAtMaxLoad.toStringAsFixed(1)} Mbps) '
              'is below the ${capacity.targetPerUserMbps.toStringAsFixed(0)} Mbps target. '
              'Increase AP count or use a more capable Wi-Fi standard.',
          severity: 'warning',
        ),
      );
    }

    // ---- Channel plan ----
    if (env.preferredBand == WiFiBand.ghz5 && env.channelWidthMhz == 160) {
      recs.add(
        const DesignRecommendation(
          category: 'Channel Planning',
          title: '160 MHz channels reduce reuse options',
          detail:
              '160 MHz consumes half the 5 GHz spectrum and leaves only 2 '
              'non-overlapping channels. In multi-AP deployments consider 80 MHz '
              'for better channel reuse and lower co-channel interference.',
          severity: 'warning',
        ),
      );
    }

    if (env.preferredBand == WiFiBand.ghz24 && env.channelWidthMhz > 20) {
      recs.add(
        const DesignRecommendation(
          category: 'Channel Planning',
          title: '2.4 GHz channel width should be 20 MHz',
          detail:
              '40 MHz channels on 2.4 GHz virtually guarantee co-channel '
              'interference. Always use 20 MHz channels on 2.4 GHz.',
          severity: 'critical',
        ),
      );
    }

    // ---- TX power ----
    if (env.maxTxPowerDbm > 23) {
      recs.add(
        DesignRecommendation(
          category: 'Power Management',
          title: 'High TX power (${env.maxTxPowerDbm.toStringAsFixed(0)} dBm)',
          detail:
              'Very high TX power creates large cells that increase co-channel '
              'interference between APs. Enable dynamic TX power control (Cisco '
              'TPC / Aruba ARM) and target 17–20 dBm for indoor enterprise.',
          severity: 'info',
        ),
      );
    }

    if (env.maxTxPowerDbm < 14) {
      recs.add(
        DesignRecommendation(
          category: 'Power Management',
          title: 'Low TX power (${env.maxTxPowerDbm.toStringAsFixed(0)} dBm)',
          detail:
              'TX power below 14 dBm may result in insufficient coverage. '
              'Check regulatory limits and verify the AP supports higher output.',
          severity: 'warning',
        ),
      );
    }

    // ---- Roaming config ----
    recs.add(
      DesignRecommendation(
        category: 'Roaming',
        title: 'Set roaming threshold to −70 dBm',
        detail:
            'Configure BSS Transition Management (802.11v) and 802.11r Fast '
            'Transition. Set roaming trigger at −70 dBm (above the −${coverage.rssiTargetDbm.abs().toStringAsFixed(0)} dBm '
            'design floor) to give clients ample time to roam before the signal fails.',
        severity: 'info',
      ),
    );

    // ---- MIMO ----
    if (env.clientSpatialStreams < 2) {
      recs.add(
        const DesignRecommendation(
          category: 'Device Policy',
          title: 'Upgrade to 2×2 MIMO clients',
          detail:
              '1×1 MIMO clients achieve half the PHY rate of 2×2 MIMO at the '
              'same SNR. Modern laptops and phones are predominantly 2×2; ensure '
              'any IoT or thin-client endpoints also support at least 2 streams.',
          severity: 'info',
        ),
      );
    }

    // ---- Wi-Fi standard upgrade ----
    if (env.wifiStandard == WifiStandard.ac && apCount.totalApCount > 5) {
      recs.add(
        const DesignRecommendation(
          category: 'Technology',
          title: 'Consider Wi-Fi 6 (802.11ax)',
          detail:
              'Wi-Fi 6 OFDMA significantly improves performance in high-density '
              'deployments by scheduling multiple clients in a single PPDU. BSS '
              'Coloring reduces co-channel interference in overlapping cells. '
              'Replace Wi-Fi 5 APs with Wi-Fi 6 during the next refresh cycle.',
          severity: 'info',
        ),
      );
    }

    return recs;
  }

  // ---------------------------------------------------------------------------
  // Private maths helpers
  // ---------------------------------------------------------------------------

  /// Log-distance RSSI prediction (dBm).
  static double _predictRssi({
    required double distM,
    required double freqMhz,
    required double n,
    required double txPowerDbm,
    required double antennaGainDbi,
    required double totalWallLossDb,
  }) {
    if (distM <= 0) return txPowerDbm + antennaGainDbi;
    // PL(d) = FSPL(1m) + 10n·log10(d)
    final pl =
        (20.0 * log(freqMhz) / ln10 - 27.55) + 10.0 * n * log(distM) / ln10;
    return txPowerDbm + antennaGainDbi - pl - totalWallLossDb;
  }

  /// Resolve the band centre frequency.
  static double _freqForBand(WiFiBand band) => switch (band) {
    WiFiBand.ghz24 => 2437.0,
    WiFiBand.ghz5 => 5180.0,
    WiFiBand.ghz6 => 5955.0,
  };

  /// SNR (dB) → MCS index (0–9).
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

  /// PHY rate (1SS) for given MCS + channel width.
  static double _phyRate(int mcs, int channelWidthMhz) {
    final idx = mcs.clamp(0, 9);
    return switch (channelWidthMhz) {
      160 => _phyRates160Mhz[idx],
      80 => _phyRates80Mhz[idx],
      40 => _phyRates40Mhz[idx],
      _ => _phyRates20Mhz[idx],
    };
  }
}
