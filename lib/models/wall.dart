import 'package:airreader/models/material_definition.dart';

/// Whether a wall was detected / classified as part of the exterior shell
/// (outer perimeter) or an interior partition, or is not yet classified.
enum WallClassification { exterior, interior, unclassified }

/// Enum of supported wall material types.
///
/// Each variant carries a reference to its [WallMaterialDefinition] from the
/// catalogue, giving the simulation engine accurate per-band attenuation data.
enum WallMaterial {
  drywall(WallMaterialCatalogue.drywall),
  wood(WallMaterialCatalogue.wood),
  glassClear(WallMaterialCatalogue.glassClear),
  glassLowE(WallMaterialCatalogue.glassLowE),
  brick(WallMaterialCatalogue.brick),
  concreteUnreinforced(WallMaterialCatalogue.concreteUnreinforced),
  concreteReinforced(WallMaterialCatalogue.concreteReinforced),
  metal(WallMaterialCatalogue.metal),
  custom(WallMaterialCatalogue.custom);

  const WallMaterial(this.definition);

  /// Full material specification (loss per band, thickness, colour, etc.).
  final WallMaterialDefinition definition;

  /// Convenience accessors forwarded from the definition.
  String get label => definition.label;
  double get typicalThicknessCm => definition.typicalThicknessCm;
  double get loss24GhzDb => definition.loss24GhzDb;
  double get loss5GhzDb => definition.loss5GhzDb;
  double get loss6GhzDb => definition.loss6GhzDb;

  /// Resolve a [WallMaterial] from a stored [name] string.
  static WallMaterial fromName(String name) => WallMaterial.values.firstWhere(
    (m) => m.name == name,
    orElse: () => WallMaterial.drywall,
  );
}

/// A single wall segment defined by two endpoints in floor-plan pixel space.
class WallSegment {
  WallSegment({
    required this.id,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    this.material = WallMaterial.drywall,
    this.innerMaterial,
    double? thicknessCm,
    this.customLoss24GhzDb,
    this.customLoss5GhzDb,
    this.customLoss6GhzDb,
    this.classification = WallClassification.unclassified,
  }) : thicknessCm = thicknessCm ?? material.typicalThicknessCm;

  final String id;

  /// Endpoints in floor-plan pixel coordinates.
  final double startX;
  final double startY;
  final double endX;
  final double endY;

  final WallMaterial material;

  /// Optional inner lining material for composite walls.
  ///
  /// Exterior walls often have an inner face (e.g. drywall on the inside of
  /// a brick shell). When set, the total RF attenuation is the sum of both
  /// layers. [null] means a single-layer wall (typical for interior partitions).
  final WallMaterial? innerMaterial;

  /// Physical thickness in centimetres.
  /// Defaults to the material's [WallMaterial.typicalThicknessCm].
  final double thicknessCm;

  // Custom per-band loss values – only used when material == WallMaterial.custom.
  final double? customLoss24GhzDb;
  final double? customLoss5GhzDb;
  final double? customLoss6GhzDb;

  /// Whether this wall is an exterior shell wall or an interior partition.
  final WallClassification classification;

  // ---------------------------------------------------------------------------
  // Band-aware attenuation helpers
  // ---------------------------------------------------------------------------

  /// Attenuation in dB for a signal at [frequencyMhz] passing through this wall.
  ///
  /// For composite walls (e.g. brick outer + drywall inner) the losses of both
  /// layers are summed.
  double attenuationForFrequencyMhz(double frequencyMhz) {
    double loss;
    if (material == WallMaterial.custom) {
      if (frequencyMhz < 3000) {
        loss = customLoss24GhzDb ?? 5.0;
      } else if (frequencyMhz < 5900) {
        loss = customLoss5GhzDb ?? 8.0;
      } else {
        loss = customLoss6GhzDb ?? 10.0;
      }
    } else {
      loss = material.definition.lossForFrequencyMhz(frequencyMhz);
    }
    if (innerMaterial != null) {
      loss += innerMaterial!.definition.lossForFrequencyMhz(frequencyMhz);
    }
    return loss;
  }

  double get attenuation24GhzDb {
    final base = material == WallMaterial.custom
        ? (customLoss24GhzDb ?? 5.0)
        : material.loss24GhzDb;
    return base + (innerMaterial?.loss24GhzDb ?? 0.0);
  }

  double get attenuation5GhzDb {
    final base = material == WallMaterial.custom
        ? (customLoss5GhzDb ?? 8.0)
        : material.loss5GhzDb;
    return base + (innerMaterial?.loss5GhzDb ?? 0.0);
  }

  double get attenuation6GhzDb {
    final base = material == WallMaterial.custom
        ? (customLoss6GhzDb ?? 10.0)
        : material.loss6GhzDb;
    return base + (innerMaterial?.loss6GhzDb ?? 0.0);
  }

  // ---------------------------------------------------------------------------

  // Sentinel used by copyWith to distinguish "omitted" from explicit null.
  static const _absent = Object();

  WallSegment copyWith({
    double? startX,
    double? startY,
    double? endX,
    double? endY,
    WallMaterial? material,
    // Use Object? so callers can pass null to *clear* the inner material.
    Object? innerMaterial = _absent,
    double? thicknessCm,
    double? customLoss24GhzDb,
    double? customLoss5GhzDb,
    double? customLoss6GhzDb,
    WallClassification? classification,
  }) {
    return WallSegment(
      id: id,
      startX: startX ?? this.startX,
      startY: startY ?? this.startY,
      endX: endX ?? this.endX,
      endY: endY ?? this.endY,
      material: material ?? this.material,
      innerMaterial: identical(innerMaterial, _absent)
          ? this.innerMaterial
          : innerMaterial as WallMaterial?,
      thicknessCm: thicknessCm ?? this.thicknessCm,
      customLoss24GhzDb: customLoss24GhzDb ?? this.customLoss24GhzDb,
      customLoss5GhzDb: customLoss5GhzDb ?? this.customLoss5GhzDb,
      customLoss6GhzDb: customLoss6GhzDb ?? this.customLoss6GhzDb,
      classification: classification ?? this.classification,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'id': id,
    'startX': startX,
    'startY': startY,
    'endX': endX,
    'endY': endY,
    'material': material.name,
    if (innerMaterial != null) 'innerMaterial': innerMaterial!.name,
    'thicknessCm': thicknessCm,
    'classification': classification.name,
    if (customLoss24GhzDb != null) 'customLoss24GhzDb': customLoss24GhzDb,
    if (customLoss5GhzDb != null) 'customLoss5GhzDb': customLoss5GhzDb,
    if (customLoss6GhzDb != null) 'customLoss6GhzDb': customLoss6GhzDb,
  };

  factory WallSegment.fromJson(Map<String, dynamic> json) => WallSegment(
    id: json['id'] as String,
    startX: (json['startX'] as num).toDouble(),
    startY: (json['startY'] as num).toDouble(),
    endX: (json['endX'] as num).toDouble(),
    endY: (json['endY'] as num).toDouble(),
    material: WallMaterial.fromName(json['material'] as String),
    innerMaterial: json['innerMaterial'] != null
        ? WallMaterial.fromName(json['innerMaterial'] as String)
        : null,
    thicknessCm: (json['thicknessCm'] as num).toDouble(),
    classification: json['classification'] != null
        ? WallClassification.values.firstWhere(
            (c) => c.name == json['classification'] as String,
            orElse: () => WallClassification.unclassified,
          )
        : WallClassification.unclassified,
    customLoss24GhzDb: json['customLoss24GhzDb'] != null
        ? (json['customLoss24GhzDb'] as num).toDouble()
        : null,
    customLoss5GhzDb: json['customLoss5GhzDb'] != null
        ? (json['customLoss5GhzDb'] as num).toDouble()
        : null,
    customLoss6GhzDb: json['customLoss6GhzDb'] != null
        ? (json['customLoss6GhzDb'] as num).toDouble()
        : null,
  );
}
