import 'package:airreader/utils/constants.dart';

/// Supported WiFi frequency bands.
enum WiFiBand {
  ghz24(
    label: '2.4 GHz',
    defaultFrequencyMhz: 2437.0,
    defaultChannelWidthMhz: 20,
  ),
  ghz5(label: '5 GHz', defaultFrequencyMhz: 5180.0, defaultChannelWidthMhz: 80),
  ghz6(label: '6 GHz', defaultFrequencyMhz: 5955.0, defaultChannelWidthMhz: 80);

  const WiFiBand({
    required this.label,
    required this.defaultFrequencyMhz,
    required this.defaultChannelWidthMhz,
  });

  final String label;
  final double defaultFrequencyMhz;

  /// Sensible default channel width for APs on this band:
  /// 20 MHz for 2.4 GHz (most common; interference-limited),
  /// 80 MHz for 5 / 6 GHz (802.11ac/ax standard minimum).
  final int defaultChannelWidthMhz;
}

/// Configuration for a single frequency band on an [AccessPoint].
class BandConfig {
  BandConfig({
    required this.band,
    this.enabled = true,
    this.txPowerDbm = AppConstants.defaultTxPowerDbm,
    int? channelWidthMhz,
  }) : channelWidthMhz = channelWidthMhz ?? band.defaultChannelWidthMhz;

  final WiFiBand band;
  bool enabled;
  double txPowerDbm;

  /// Channel width in MHz: 20, 40, 80, or 160.
  int channelWidthMhz;

  double get frequencyMhz => band.defaultFrequencyMhz;

  BandConfig copyWith({
    bool? enabled,
    double? txPowerDbm,
    int? channelWidthMhz,
  }) {
    return BandConfig(
      band: band,
      enabled: enabled ?? this.enabled,
      txPowerDbm: txPowerDbm ?? this.txPowerDbm,
      channelWidthMhz: channelWidthMhz ?? this.channelWidthMhz,
    );
  }

  Map<String, dynamic> toJson() => {
    'band': band.name,
    'enabled': enabled,
    'txPowerDbm': txPowerDbm,
    'channelWidthMhz': channelWidthMhz,
  };

  factory BandConfig.fromJson(Map<String, dynamic> json) => BandConfig(
    band: WiFiBand.values.firstWhere((b) => b.name == json['band']),
    enabled: json['enabled'] as bool,
    txPowerDbm: (json['txPowerDbm'] as num).toDouble(),
    channelWidthMhz: json['channelWidthMhz'] as int,
  );
}

/// A virtual access point placed on the floor plan.
class AccessPoint {
  AccessPoint({
    required this.id,
    required this.brand,
    required this.model,
    required this.positionX,
    required this.positionY,
    List<BandConfig>? bands,
    this.antennaGainDbi = 2.0,
    this.speedAllocationMbps,
  }) : bands =
           bands ??
           [BandConfig(band: WiFiBand.ghz24), BandConfig(band: WiFiBand.ghz5)];

  final String id;
  final String brand;
  final String model;

  /// Position in floor-plan pixel coordinates.
  double positionX;
  double positionY;

  /// Frequency-band configurations for this AP.
  final List<BandConfig> bands;

  /// Antenna gain in dBi (used in link-budget calculations).
  final double antennaGainDbi;

  /// Optional bandwidth cap for this AP in Mbps (null = unlimited).
  final double? speedAllocationMbps;

  /// Convenience: return enabled bands only.
  List<BandConfig> get enabledBands => bands.where((b) => b.enabled).toList();

  AccessPoint copyWith({
    String? brand,
    String? model,
    double? positionX,
    double? positionY,
    List<BandConfig>? bands,
    double? antennaGainDbi,
    double? speedAllocationMbps,
  }) {
    return AccessPoint(
      id: id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      bands: bands ?? this.bands,
      antennaGainDbi: antennaGainDbi ?? this.antennaGainDbi,
      speedAllocationMbps: speedAllocationMbps ?? this.speedAllocationMbps,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'brand': brand,
    'model': model,
    'positionX': positionX,
    'positionY': positionY,
    'bands': bands.map((b) => b.toJson()).toList(),
    'antennaGainDbi': antennaGainDbi,
    'speedAllocationMbps': speedAllocationMbps,
  };

  factory AccessPoint.fromJson(Map<String, dynamic> json) => AccessPoint(
    id: json['id'] as String,
    brand: json['brand'] as String,
    model: json['model'] as String,
    positionX: (json['positionX'] as num).toDouble(),
    positionY: (json['positionY'] as num).toDouble(),
    bands: (json['bands'] as List)
        .map((b) => BandConfig.fromJson(b as Map<String, dynamic>))
        .toList(),
    antennaGainDbi: (json['antennaGainDbi'] as num).toDouble(),
    speedAllocationMbps: json['speedAllocationMbps'] != null
        ? (json['speedAllocationMbps'] as num).toDouble()
        : null,
  );
}
