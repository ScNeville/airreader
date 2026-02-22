import 'package:airreader/models/access_point.dart';

/// Specification of a real-world AP model used in the library browser.
class ApSpec {
  const ApSpec({
    required this.brand,
    required this.model,
    required this.antennaGainDbi,
    required this.supportedBands,
    this.maxTxPowerDbm = 20.0,
    this.description = '',
  });

  final String brand;
  final String model;
  final double antennaGainDbi;
  final List<WiFiBand> supportedBands;
  final double maxTxPowerDbm;
  final String description;

  String get fullName => '$brand $model';

  /// Create a default [AccessPoint] from this spec at a given position.
  AccessPoint toAccessPoint({
    required String id,
    required double x,
    required double y,
  }) {
    return AccessPoint(
      id: id,
      brand: brand,
      model: model,
      positionX: x,
      positionY: y,
      antennaGainDbi: antennaGainDbi,
      bands: supportedBands
          .map((b) => BandConfig(band: b, txPowerDbm: maxTxPowerDbm))
          .toList(),
    );
  }
}

/// Built-in catalogue of real-world AP models.
class ApLibrary {
  ApLibrary._();

  static const List<ApSpec> catalogue = [
    // ------------------------------------------------------------------
    // Ubiquiti UniFi
    // ------------------------------------------------------------------
    ApSpec(
      brand: 'Ubiquiti',
      model: 'UniFi AP Lite',
      antennaGainDbi: 3.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 20.0,
      description: 'Entry-level dual-band indoor AP',
    ),
    ApSpec(
      brand: 'Ubiquiti',
      model: 'UniFi AP Pro',
      antennaGainDbi: 3.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 22.0,
      description: 'High-performance dual-band indoor AP',
    ),
    ApSpec(
      brand: 'Ubiquiti',
      model: 'UniFi AP LR',
      antennaGainDbi: 6.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 24.0,
      description: 'Long-range dual-band indoor AP',
    ),
    ApSpec(
      brand: 'Ubiquiti',
      model: 'UniFi WiFi 6',
      antennaGainDbi: 3.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 22.0,
      description: 'WiFi 6 dual-band ceiling AP',
    ),
    ApSpec(
      brand: 'Ubiquiti',
      model: 'UniFi WiFi 6E',
      antennaGainDbi: 3.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5, WiFiBand.ghz6],
      maxTxPowerDbm: 22.0,
      description: 'WiFi 6E tri-band ceiling AP',
    ),

    // ------------------------------------------------------------------
    // Cisco Meraki
    // ------------------------------------------------------------------
    ApSpec(
      brand: 'Cisco Meraki',
      model: 'MR36',
      antennaGainDbi: 5.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 20.0,
      description: 'WiFi 6 dual-band enterprise indoor AP',
    ),
    ApSpec(
      brand: 'Cisco Meraki',
      model: 'MR46',
      antennaGainDbi: 5.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 22.0,
      description: 'High-performance WiFi 6 enterprise AP',
    ),
    ApSpec(
      brand: 'Cisco Meraki',
      model: 'MR56',
      antennaGainDbi: 5.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5, WiFiBand.ghz6],
      maxTxPowerDbm: 23.0,
      description: 'WiFi 6E tri-band enterprise indoor AP',
    ),

    // ------------------------------------------------------------------
    // Aruba
    // ------------------------------------------------------------------
    ApSpec(
      brand: 'Aruba',
      model: 'AP-505',
      antennaGainDbi: 3.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 21.0,
      description: 'WiFi 6 indoor AP for small/medium spaces',
    ),
    ApSpec(
      brand: 'Aruba',
      model: 'AP-635',
      antennaGainDbi: 4.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5, WiFiBand.ghz6],
      maxTxPowerDbm: 23.0,
      description: 'WiFi 6E tri-band indoor AP',
    ),

    // ------------------------------------------------------------------
    // TP-Link Omada
    // ------------------------------------------------------------------
    ApSpec(
      brand: 'TP-Link',
      model: 'EAP225',
      antennaGainDbi: 4.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 20.0,
      description: 'AC1750 dual-band ceiling AP',
    ),
    ApSpec(
      brand: 'TP-Link',
      model: 'EAP670',
      antennaGainDbi: 4.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 23.0,
      description: 'WiFi 6 AX3000 dual-band ceiling AP',
    ),
    ApSpec(
      brand: 'TP-Link',
      model: 'EAP773',
      antennaGainDbi: 4.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5, WiFiBand.ghz6],
      maxTxPowerDbm: 23.0,
      description: 'WiFi 7 tri-band ceiling AP',
    ),

    // ------------------------------------------------------------------
    // Netgear
    // ------------------------------------------------------------------
    ApSpec(
      brand: 'Netgear',
      model: 'WAX630',
      antennaGainDbi: 4.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5, WiFiBand.ghz6],
      maxTxPowerDbm: 23.0,
      description: 'Tri-band WiFi 6 ceiling AP',
    ),

    // ------------------------------------------------------------------
    // Generic / Custom
    // ------------------------------------------------------------------
    ApSpec(
      brand: 'Generic',
      model: 'Custom AP',
      antennaGainDbi: 2.0,
      supportedBands: [WiFiBand.ghz24, WiFiBand.ghz5],
      maxTxPowerDbm: 20.0,
      description: 'User-defined generic access point',
    ),
  ];

  static List<String> get brands =>
      catalogue.map((s) => s.brand).toSet().toList();

  static List<ApSpec> forBrand(String brand) =>
      catalogue.where((s) => s.brand == brand).toList();
}
