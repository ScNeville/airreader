import 'package:flutter/material.dart';

/// Per-band RF attenuation data and physical properties for a wall material.
///
/// Loss values are midpoints of the empirical ranges from materials.txt.
/// They are used by the RF simulation engine to calculate signal degradation
/// as a ray passes through a wall segment.
class WallMaterialDefinition {
  const WallMaterialDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.impactSummary,
    required this.typicalThicknessCm,
    required this.loss24GhzDb,
    required this.loss5GhzDb,
    required this.loss6GhzDb,
    required this.color,
  });

  /// Stable string key – matches the [WallMaterial] enum name.
  final String id;

  /// Human-readable name shown in the UI.
  final String label;

  /// One-line description of the material.
  final String description;

  /// Short qualitative impact label  (e.g. "High attenuation").
  final String impactSummary;

  /// Default / typical wall thickness in centimetres.
  final double typicalThicknessCm;

  // ------ Per-band midpoint attenuation values (dB per wall crossing) -------

  /// 2.4 GHz signal loss in dB.
  final double loss24GhzDb;

  /// 5 GHz signal loss in dB.
  final double loss5GhzDb;

  /// 6 GHz signal loss in dB.
  final double loss6GhzDb;

  // ------ UI colour for floor-plan rendering --------------------------------

  /// Representative colour used when drawing this wall on the canvas.
  final Color color;

  /// Return the approximate attenuation in dB for [frequencyMhz].
  ///
  /// Interpolates / selects the closest band value.
  double lossForFrequencyMhz(double frequencyMhz) {
    if (frequencyMhz < 3000) return loss24GhzDb; // 2.4 GHz band
    if (frequencyMhz < 5900) return loss5GhzDb; // 5 GHz band
    return loss6GhzDb; // 6 GHz band
  }
}

// ============================================================================
// Catalogue – one entry per row in materials.txt
// ============================================================================

/// All built-in wall material definitions.
///
/// Source: materials.txt
/// Loss values are midpoints of the documented empirical ranges.
class WallMaterialCatalogue {
  WallMaterialCatalogue._();

  // --------------------------------------------------------------------------
  // Drywall / Gypsum board
  //   Thickness: ~1–2 cm  →  mid 1.5 cm
  //   2.4 GHz: 2–4 dB     →  mid 3 dB
  //   5 GHz:   4–6 dB     →  mid 5 dB
  //   6 GHz:   6–8 dB     →  mid 7 dB
  //   Impact: Very low (~≤5 % speed drop)
  // --------------------------------------------------------------------------
  static const drywall = WallMaterialDefinition(
    id: 'drywall',
    label: 'Drywall / Gypsum',
    description: 'Standard interior partition wall (1–2 cm gypsum board).',
    impactSummary: 'Very low – ≤5 % speed drop',
    typicalThicknessCm: 1.5,
    loss24GhzDb: 3.0,
    loss5GhzDb: 5.0,
    loss6GhzDb: 7.0,
    color: Color(0xFFD4C9A8),
  );

  // --------------------------------------------------------------------------
  // Wood / Timber
  //   Thickness: ~2–5 cm  →  mid 3.5 cm
  //   2.4 GHz: 3–6 dB     →  mid 4.5 dB
  //   5 GHz:   6–10 dB    →  mid 8 dB
  //   6 GHz:   8–12 dB    →  mid 10 dB
  //   Impact: Low–moderate
  // --------------------------------------------------------------------------
  static const wood = WallMaterialDefinition(
    id: 'wood',
    label: 'Wood / Timber',
    description: 'Timber framing, wooden partition or furniture (2–5 cm).',
    impactSummary: 'Low–moderate',
    typicalThicknessCm: 3.5,
    loss24GhzDb: 4.5,
    loss5GhzDb: 8.0,
    loss6GhzDb: 10.0,
    color: Color(0xFFA0785A),
  );

  // --------------------------------------------------------------------------
  // Glass (clear)
  //   Thickness: ~0.5–1 cm  →  mid 0.75 cm
  //   2.4 GHz: 1–3 dB       →  mid 2 dB
  //   5 GHz:   3–5 dB       →  mid 4 dB
  //   6 GHz:   5–7 dB       →  mid 6 dB
  //   Impact: Minor
  // --------------------------------------------------------------------------
  static const glassClear = WallMaterialDefinition(
    id: 'glassClear',
    label: 'Glass (Clear)',
    description: 'Standard clear glazing (0.5–1 cm).',
    impactSummary: 'Minor impact',
    typicalThicknessCm: 0.75,
    loss24GhzDb: 2.0,
    loss5GhzDb: 4.0,
    loss6GhzDb: 6.0,
    color: Color(0xFFADD8E6),
  );

  // --------------------------------------------------------------------------
  // Brick (solid clay)
  //   Thickness: ~15–20 cm  →  mid 17.5 cm
  //   2.4 GHz:  8–14 dB     →  mid 11 dB
  //   5 GHz:   18–25 dB     →  mid 21.5 dB
  //   6 GHz:   28–38 dB     →  mid 33 dB
  //   Impact: Moderate; can reduce speeds noticeably
  // --------------------------------------------------------------------------
  static const brick = WallMaterialDefinition(
    id: 'brick',
    label: 'Brick (Solid Clay)',
    description: 'Solid clay brick masonry (15–20 cm).',
    impactSummary: 'Moderate – noticeable speed reduction',
    typicalThicknessCm: 17.5,
    loss24GhzDb: 11.0,
    loss5GhzDb: 21.5,
    loss6GhzDb: 33.0,
    color: Color(0xFFC0522A),
  );

  // --------------------------------------------------------------------------
  // Concrete (unreinforced)
  //   Thickness: ~15 cm
  //   2.4 GHz: 10–15 dB  →  mid 12.5 dB
  //   5 GHz:   20–28 dB  →  mid 24 dB
  //   6 GHz:   32–45 dB  →  mid 38.5 dB
  //   Impact: High attenuation
  // --------------------------------------------------------------------------
  static const concreteUnreinforced = WallMaterialDefinition(
    id: 'concreteUnreinforced',
    label: 'Concrete (Unreinforced)',
    description: 'Plain concrete slab or block wall (~15 cm).',
    impactSummary: 'High attenuation',
    typicalThicknessCm: 15.0,
    loss24GhzDb: 12.5,
    loss5GhzDb: 24.0,
    loss6GhzDb: 38.5,
    color: Color(0xFF9E9E9E),
  );

  // --------------------------------------------------------------------------
  // Concrete + Rebar (reinforced)
  //   Thickness: ~15 cm
  //   2.4 GHz: 25–35 dB  →  mid 30 dB
  //   5 GHz:   30–45 dB  →  mid 37.5 dB
  //   6 GHz:   45–65 dB  →  mid 55 dB
  //   Impact: Very high; often no usable signal
  // --------------------------------------------------------------------------
  static const concreteReinforced = WallMaterialDefinition(
    id: 'concreteReinforced',
    label: 'Concrete (Reinforced)',
    description:
        'Reinforced concrete with rebar (~15 cm). '
        'Often blocks signal entirely.',
    impactSummary: 'Very high – often no usable signal',
    typicalThicknessCm: 15.0,
    loss24GhzDb: 30.0,
    loss5GhzDb: 37.5,
    loss6GhzDb: 55.0,
    color: Color(0xFF616161),
  );

  // --------------------------------------------------------------------------
  // Metal (solid)
  //   Thickness: varies (default 5 cm)
  //   2.4 GHz: 35–45 dB  →  mid 40 dB
  //   5 GHz:   40+ dB    →  42 dB
  //   6 GHz:   45+ dB    →  47 dB
  //   Impact: Near-complete blockage
  // --------------------------------------------------------------------------
  static const metal = WallMaterialDefinition(
    id: 'metal',
    label: 'Metal (Solid)',
    description: 'Steel partitions, metal cladding or ductwork.',
    impactSummary: 'Near-complete signal blockage',
    typicalThicknessCm: 5.0,
    loss24GhzDb: 40.0,
    loss5GhzDb: 42.0,
    loss6GhzDb: 47.0,
    color: Color(0xFF78909C),
  );

  // --------------------------------------------------------------------------
  // Tinted / Low-E glass
  //   Thickness: ~0.5 cm
  //   2.4 GHz:  3–5 dB   →  mid 4 dB
  //   5 GHz:   12–20 dB  →  mid 16 dB
  //   6 GHz:   22–30 dB  →  mid 26 dB
  //   Impact: Moderate to severe for 5/6 GHz
  // --------------------------------------------------------------------------
  static const glassLowE = WallMaterialDefinition(
    id: 'glassLowE',
    label: 'Tinted / Low-E Glass',
    description:
        'Tinted or low-emissivity glazing with metallic coating (~0.5 cm). '
        'Severe at 5/6 GHz.',
    impactSummary: 'Moderate–severe (especially 5/6 GHz)',
    typicalThicknessCm: 0.5,
    loss24GhzDb: 4.0,
    loss5GhzDb: 16.0,
    loss6GhzDb: 26.0,
    color: Color(0xFF7FB3C8),
  );

  // --------------------------------------------------------------------------
  // Custom (user-defined)
  // --------------------------------------------------------------------------
  static const custom = WallMaterialDefinition(
    id: 'custom',
    label: 'Custom',
    description: 'User-defined material with manually specified attenuation.',
    impactSummary: 'User defined',
    typicalThicknessCm: 10.0,
    loss24GhzDb: 0.0,
    loss5GhzDb: 0.0,
    loss6GhzDb: 0.0,
    color: Color(0xFFCE93D8),
  );

  /// All materials in display order.
  static const List<WallMaterialDefinition> all = [
    drywall,
    wood,
    glassClear,
    glassLowE,
    brick,
    concreteUnreinforced,
    concreteReinforced,
    metal,
    custom,
  ];

  /// Look up a definition by its [id] string.
  static WallMaterialDefinition byId(String id) {
    return all.firstWhere((m) => m.id == id, orElse: () => custom);
  }
}
