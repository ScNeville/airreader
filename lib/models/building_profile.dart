// lib/models/building_profile.dart
// Global building construction profile: exterior shell material, interior
// partition material, and structural framing type. Applied to WallSegments
// in bulk via the survey bloc.

import 'package:airreader/models/wall.dart';

/// The structural framing system used in the building.
/// Affects path-loss exponent and interior wall defaults.
enum FramingType {
  timberFrame,
  steelFrame,
  concreteFrame,
  masonryLoadBearing;

  String get label => switch (this) {
    FramingType.timberFrame => 'Timber Frame',
    FramingType.steelFrame => 'Steel Frame',
    FramingType.concreteFrame => 'Concrete / RC Frame',
    FramingType.masonryLoadBearing => 'Masonry Load-bearing',
  };

  /// Default interior partition wall material for this framing system.
  WallMaterial get defaultInteriorMaterial => switch (this) {
    FramingType.timberFrame => WallMaterial.drywall,
    FramingType.steelFrame => WallMaterial.drywall,
    FramingType.concreteFrame => WallMaterial.concreteUnreinforced,
    FramingType.masonryLoadBearing => WallMaterial.brick,
  };
}

/// Building-wide construction profile used to:
///  1. Supply defaults when auto-detecting walls.
///  2. Drive "Apply to all exterior / interior walls" bulk updates.
class BuildingProfile {
  const BuildingProfile({
    this.framingType = FramingType.timberFrame,
    this.exteriorMaterial = WallMaterial.brick,
    this.exteriorInnerMaterial = WallMaterial.drywall,
    this.interiorMaterial = WallMaterial.drywall,
  });

  /// Structural framing system.
  final FramingType framingType;

  /// The outer-face material of the perimeter shell (e.g. brick, concrete).
  final WallMaterial exteriorMaterial;

  /// The inner-face lining of exterior walls (e.g. drywall on brick).
  /// This is the second layer that an RF signal must penetrate when crossing
  /// an exterior wall from outside to inside.
  final WallMaterial exteriorInnerMaterial;

  /// Material applied to interior partitions.
  final WallMaterial interiorMaterial;

  BuildingProfile copyWith({
    FramingType? framingType,
    WallMaterial? exteriorMaterial,
    WallMaterial? exteriorInnerMaterial,
    WallMaterial? interiorMaterial,
  }) {
    return BuildingProfile(
      framingType: framingType ?? this.framingType,
      exteriorMaterial: exteriorMaterial ?? this.exteriorMaterial,
      exteriorInnerMaterial:
          exteriorInnerMaterial ?? this.exteriorInnerMaterial,
      interiorMaterial: interiorMaterial ?? this.interiorMaterial,
    );
  }

  Map<String, dynamic> toJson() => {
    'framingType': framingType.name,
    'exteriorMaterial': exteriorMaterial.name,
    'exteriorInnerMaterial': exteriorInnerMaterial.name,
    'interiorMaterial': interiorMaterial.name,
  };

  factory BuildingProfile.fromJson(
    Map<String, dynamic> json,
  ) => BuildingProfile(
    framingType: FramingType.values.firstWhere(
      (f) => f.name == json['framingType'],
      orElse: () => FramingType.timberFrame,
    ),
    exteriorMaterial: WallMaterial.fromName(json['exteriorMaterial'] as String),
    exteriorInnerMaterial: json['exteriorInnerMaterial'] != null
        ? WallMaterial.fromName(json['exteriorInnerMaterial'] as String)
        : WallMaterial.drywall,
    interiorMaterial: WallMaterial.fromName(json['interiorMaterial'] as String),
  );

  static const defaults = BuildingProfile();
}
