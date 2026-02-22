// lib/models/survey_environment.dart
// Structured environment / building parameters used by the RF Engineering
// Analysis mode to derive path-loss exponents, capacity limits, and design
// recommendations.

import 'package:airreader/models/access_point.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum BuildingType {
  office,
  residential,
  warehouse,
  hospitality,
  healthcare,
  education,
  retail;

  String get label => switch (this) {
    BuildingType.office => 'Office',
    BuildingType.residential => 'Residential',
    BuildingType.warehouse => 'Warehouse / Industrial',
    BuildingType.hospitality => 'Hospitality / Hotel',
    BuildingType.healthcare => 'Healthcare',
    BuildingType.education => 'Education / Campus',
    BuildingType.retail => 'Retail',
  };

  /// Base path-loss exponent (n) for indoor log-distance model.
  double get basePathLossExponent => switch (this) {
    BuildingType.office => 3.0,
    BuildingType.residential => 3.5,
    BuildingType.warehouse => 2.2,
    BuildingType.hospitality => 3.3,
    BuildingType.healthcare => 3.7,
    BuildingType.education => 3.0,
    BuildingType.retail => 2.8,
  };

  /// Typical minimum RSSI design target (dBm) for this environment.
  double get rssiTargetDbm => switch (this) {
    BuildingType.healthcare => -65.0,
    BuildingType.education => -67.0,
    _ => -67.0,
  };
}

enum ConstructionMaterial {
  drywall,
  brickMortar,
  concreteBlock,
  reinforcedConcrete,
  steelFrame,
  timberFrame,
  glass;

  String get label => switch (this) {
    ConstructionMaterial.drywall => 'Drywall / Gypsum',
    ConstructionMaterial.brickMortar => 'Brick & Mortar',
    ConstructionMaterial.concreteBlock => 'Concrete Block',
    ConstructionMaterial.reinforcedConcrete => 'Reinforced Concrete',
    ConstructionMaterial.steelFrame => 'Steel Frame',
    ConstructionMaterial.timberFrame => 'Timber Frame',
    ConstructionMaterial.glass => 'Glass Partition',
  };

  /// Additional path-loss exponent delta added to the building-type base.
  double get pathLossExponentDelta => switch (this) {
    ConstructionMaterial.drywall => 0.0,
    ConstructionMaterial.brickMortar => 0.3,
    ConstructionMaterial.concreteBlock => 0.4,
    ConstructionMaterial.reinforcedConcrete => 0.7,
    ConstructionMaterial.steelFrame => 0.5,
    ConstructionMaterial.timberFrame => 0.1,
    ConstructionMaterial.glass => -0.1,
  };

  /// Typical single-wall penetration loss (dB) at 2.4 GHz.
  double get wallLossDb24Ghz => switch (this) {
    ConstructionMaterial.drywall => 3.0,
    ConstructionMaterial.brickMortar => 8.0,
    ConstructionMaterial.concreteBlock => 12.0,
    ConstructionMaterial.reinforcedConcrete => 15.0,
    ConstructionMaterial.steelFrame => 16.0,
    ConstructionMaterial.timberFrame => 4.0,
    ConstructionMaterial.glass => 2.0,
  };

  /// Typical single-wall penetration loss (dB) at 5 GHz.
  double get wallLossDb5Ghz => switch (this) {
    ConstructionMaterial.drywall => 4.0,
    ConstructionMaterial.brickMortar => 10.0,
    ConstructionMaterial.concreteBlock => 15.0,
    ConstructionMaterial.reinforcedConcrete => 18.0,
    ConstructionMaterial.steelFrame => 20.0,
    ConstructionMaterial.timberFrame => 5.0,
    ConstructionMaterial.glass => 3.0,
  };

  double wallLossForBand(WiFiBand band) =>
      band == WiFiBand.ghz24 ? wallLossDb24Ghz : wallLossDb5Ghz;
}

enum WifiStandard {
  ac,
  ax,
  be;

  String get label => switch (this) {
    WifiStandard.ac => 'Wi-Fi 5 (802.11ac)',
    WifiStandard.ax => 'Wi-Fi 6/6E (802.11ax)',
    WifiStandard.be => 'Wi-Fi 7 (802.11be)',
  };

  String get shortLabel => switch (this) {
    WifiStandard.ac => 'Wi‑Fi 5',
    WifiStandard.ax => 'Wi‑Fi 6/6E',
    WifiStandard.be => 'Wi‑Fi 7',
  };
}

enum ApplicationType {
  webBrowsing,
  voip,
  videoConferencing,
  streaming4k,
  cloudApps,
  highBandwidth;

  String get label => switch (this) {
    ApplicationType.webBrowsing => 'Web / Email',
    ApplicationType.voip => 'VoIP',
    ApplicationType.videoConferencing => 'Video Conferencing',
    ApplicationType.streaming4k => '4K Streaming',
    ApplicationType.cloudApps => 'Cloud Apps / SaaS',
    ApplicationType.highBandwidth => 'High-Bandwidth (Engineering/Media)',
  };

  /// Minimum recommended per-user throughput (Mbps).
  double get minPerUserMbps => switch (this) {
    ApplicationType.webBrowsing => 2.0,
    ApplicationType.voip => 0.5,
    ApplicationType.videoConferencing => 4.0,
    ApplicationType.streaming4k => 25.0,
    ApplicationType.cloudApps => 5.0,
    ApplicationType.highBandwidth => 50.0,
  };
}

// ---------------------------------------------------------------------------
// Main model
// ---------------------------------------------------------------------------

class SurveyEnvironment {
  const SurveyEnvironment({
    required this.buildingType,
    required this.floorAreaM2,
    required this.ceilingHeightM,
    required this.constructionMaterial,
    required this.numberOfFloors,
    required this.concurrentUsers,
    required this.applicationTypes,
    required this.targetPerUserMbps,
    required this.clientSpatialStreams,
    required this.preferredBand,
    required this.wifiStandard,
    required this.channelWidthMhz,
    required this.maxTxPowerDbm,
  });

  final BuildingType buildingType;
  final double floorAreaM2;
  final double ceilingHeightM;
  final ConstructionMaterial constructionMaterial;
  final int numberOfFloors;

  /// Simultaneous connected clients (per floor).
  final int concurrentUsers;

  /// Application mix driving worst-case bandwidth demand.
  final Set<ApplicationType> applicationTypes;

  /// Minimum target throughput per user (Mbps).
  final double targetPerUserMbps;

  /// Client device spatial streams (1, 2, or 3).
  final int clientSpatialStreams;

  final WiFiBand preferredBand;
  final WifiStandard wifiStandard;

  /// Channel width in MHz (20 / 40 / 80 / 160).
  final int channelWidthMhz;

  /// Maximum AP TX power (dBm).
  final double maxTxPowerDbm;

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  /// Combined path-loss exponent from building type + material.
  double get pathLossExponent =>
      buildingType.basePathLossExponent +
      constructionMaterial.pathLossExponentDelta;

  /// Max per-user demand from the selected application types.
  double get maxApplicationMbps => applicationTypes.isEmpty
      ? targetPerUserMbps
      : applicationTypes
            .map((a) => a.minPerUserMbps)
            .reduce((a, b) => a > b ? a : b);

  /// Maximum application per-user demand (uses the higher of user-entered
  /// target and the application-derived minimum).
  double get effectivePerUserMbps => targetPerUserMbps > maxApplicationMbps
      ? targetPerUserMbps
      : maxApplicationMbps;

  // ---------------------------------------------------------------------------
  // Factory / copy
  // ---------------------------------------------------------------------------

  SurveyEnvironment copyWith({
    BuildingType? buildingType,
    double? floorAreaM2,
    double? ceilingHeightM,
    ConstructionMaterial? constructionMaterial,
    int? numberOfFloors,
    int? concurrentUsers,
    Set<ApplicationType>? applicationTypes,
    double? targetPerUserMbps,
    int? clientSpatialStreams,
    WiFiBand? preferredBand,
    WifiStandard? wifiStandard,
    int? channelWidthMhz,
    double? maxTxPowerDbm,
  }) {
    return SurveyEnvironment(
      buildingType: buildingType ?? this.buildingType,
      floorAreaM2: floorAreaM2 ?? this.floorAreaM2,
      ceilingHeightM: ceilingHeightM ?? this.ceilingHeightM,
      constructionMaterial: constructionMaterial ?? this.constructionMaterial,
      numberOfFloors: numberOfFloors ?? this.numberOfFloors,
      concurrentUsers: concurrentUsers ?? this.concurrentUsers,
      applicationTypes: applicationTypes ?? this.applicationTypes,
      targetPerUserMbps: targetPerUserMbps ?? this.targetPerUserMbps,
      clientSpatialStreams: clientSpatialStreams ?? this.clientSpatialStreams,
      preferredBand: preferredBand ?? this.preferredBand,
      wifiStandard: wifiStandard ?? this.wifiStandard,
      channelWidthMhz: channelWidthMhz ?? this.channelWidthMhz,
      maxTxPowerDbm: maxTxPowerDbm ?? this.maxTxPowerDbm,
    );
  }

  static SurveyEnvironment get defaults => const SurveyEnvironment(
    buildingType: BuildingType.office,
    floorAreaM2: 500,
    ceilingHeightM: 2.7,
    constructionMaterial: ConstructionMaterial.drywall,
    numberOfFloors: 1,
    concurrentUsers: 50,
    applicationTypes: {ApplicationType.cloudApps},
    targetPerUserMbps: 10,
    clientSpatialStreams: 2,
    preferredBand: WiFiBand.ghz5,
    wifiStandard: WifiStandard.ax,
    channelWidthMhz: 80,
    maxTxPowerDbm: 20,
  );
}
