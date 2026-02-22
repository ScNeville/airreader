import 'package:flutter/material.dart';

import 'package:airreader/models/access_point.dart';

// ============================================================================
// Zone type definitions (with RF modifiers)
// ============================================================================

/// The type of environment zone, each carrying RF signal modifiers.
///
/// [dbmAll] is added to every band's received signal inside the zone.
/// [dbm24], [dbm5], [dbm6] are *additional* per-band offsets stacked on top.
enum ZoneType {
  kitchen(
    label: 'Kitchen / Appliances',
    description:
        'Microwave ovens and appliances cause heavy 2.4 GHz interference.',
    icon: Icons.microwave_outlined,
    zoneColor: Color(0xFFFF7043),
    dbmAll: -2.0,
    dbm24: -5.0, // heavy impact on 2.4 GHz
    dbm5: -1.0,
    dbm6: 0.0,
  ),
  outdoor(
    label: 'Outdoor Area',
    description: 'Open air — lower path loss, signal travels farther.',
    icon: Icons.landscape_outlined,
    zoneColor: Color(0xFF66BB6A),
    dbmAll: 4.0, // free-space bonus
    dbm24: 0.0,
    dbm5: 0.0,
    dbm6: 0.0,
  ),
  timberFrame(
    label: 'Timber Frame',
    description: 'Light wood-frame construction. Minimal extra attenuation.',
    icon: Icons.cabin_outlined,
    zoneColor: Color(0xFFCE93D8),
    dbmAll: -2.0,
    dbm24: 0.0,
    dbm5: 0.0,
    dbm6: 0.0,
  ),
  steelFrame(
    label: 'Steel Frame',
    description:
        'Metal structural frame heavily attenuates all bands, especially 5+ GHz.',
    icon: Icons.business_outlined,
    zoneColor: Color(0xFF78909C),
    dbmAll: -8.0,
    dbm24: 0.0,
    dbm5: -3.0,
    dbm6: -5.0,
  ),
  concreteBlock(
    label: 'Concrete / Masonry',
    description: 'Dense concrete or block walls throughout.',
    icon: Icons.domain_outlined,
    zoneColor: Color(0xFF8D6E63),
    dbmAll: -6.0,
    dbm24: 0.0,
    dbm5: -2.0,
    dbm6: -3.0,
  ),
  rfInterference(
    label: 'RF Interference',
    description: 'General RF interference (industrial, medical equipment).',
    icon: Icons.signal_wifi_off_outlined,
    zoneColor: Color(0xFFEF5350),
    dbmAll: -4.0,
    dbm24: -3.0,
    dbm5: -1.0,
    dbm6: 0.0,
  );

  const ZoneType({
    required this.label,
    required this.description,
    required this.icon,
    required this.zoneColor,
    required this.dbmAll,
    required this.dbm24,
    required this.dbm5,
    required this.dbm6,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color zoneColor;

  /// Base modifier applied to all bands (dBm, positive = boost, negative = loss).
  final double dbmAll;

  /// Extra modifier for 2.4 GHz on top of [dbmAll].
  final double dbm24;

  /// Extra modifier for 5 GHz on top of [dbmAll].
  final double dbm5;

  /// Extra modifier for 6 GHz on top of [dbmAll].
  final double dbm6;

  /// Total dBm modifier for a given frequency (MHz).
  double modifierForFrequencyMhz(double freqMhz) {
    if (freqMhz < 3000) return dbmAll + dbm24;
    if (freqMhz < 6000) return dbmAll + dbm5;
    return dbmAll + dbm6;
  }

  /// Total dBm modifier for a given [WiFiBand].
  double modifierForBand(WiFiBand band) {
    return modifierForFrequencyMhz(band.defaultFrequencyMhz);
  }
}

// ============================================================================
// EnvironmentZone model
// ============================================================================

/// A rectangular area on the floor plan that modifies the local RF environment.
class EnvironmentZone {
  EnvironmentZone({
    required this.id,
    required this.name,
    required this.type,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final String id;
  String name;
  ZoneType type;

  /// Rectangle corners in floor-plan pixel coordinates (order not guaranteed).
  double x1, y1, x2, y2;

  // Normalised bounds.
  double get left => x1 < x2 ? x1 : x2;
  double get top => y1 < y2 ? y1 : y2;
  double get right => x1 > x2 ? x1 : x2;
  double get bottom => y1 > y2 ? y1 : y2;
  double get width => right - left;
  double get height => bottom - top;

  Rect get rect => Rect.fromLTRB(left, top, right, bottom);

  bool containsPoint(double px, double py) =>
      px >= left && px <= right && py >= top && py <= bottom;

  EnvironmentZone copyWith({
    String? name,
    ZoneType? type,
    double? x1,
    double? y1,
    double? x2,
    double? y2,
  }) => EnvironmentZone(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    x1: x1 ?? this.x1,
    y1: y1 ?? this.y1,
    x2: x2 ?? this.x2,
    y2: y2 ?? this.y2,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
  };

  factory EnvironmentZone.fromJson(Map<String, dynamic> json) =>
      EnvironmentZone(
        id: json['id'] as String,
        name: json['name'] as String,
        type: ZoneType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ZoneType.timberFrame,
        ),
        x1: (json['x1'] as num).toDouble(),
        y1: (json['y1'] as num).toDouble(),
        x2: (json['x2'] as num).toDouble(),
        y2: (json['y2'] as num).toDouble(),
      );
}
