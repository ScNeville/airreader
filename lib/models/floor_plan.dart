import 'dart:convert';
import 'dart:typed_data';

/// A floor plan loaded from an image file.
class FloorPlan {
  FloorPlan({
    required this.id,
    required this.name,
    required this.imageBytes,
    required this.imageWidth,
    required this.imageHeight,
    this.pixelsPerMeter = 100.0,
  });

  final String id;
  final String name;

  /// Raw image bytes (PNG / JPG).
  final Uint8List imageBytes;

  /// Native pixel dimensions of the imported image.
  final double imageWidth;
  final double imageHeight;

  /// Scale: how many pixels equal one real-world metre.
  /// Defaults to 100 px/m until the user calibrates.
  final double pixelsPerMeter;

  double get realWidthMeters => imageWidth / pixelsPerMeter;
  double get realHeightMeters => imageHeight / pixelsPerMeter;

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageBytes': base64Encode(imageBytes),
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'pixelsPerMeter': pixelsPerMeter,
  };

  factory FloorPlan.fromJson(Map<String, dynamic> json) => FloorPlan(
    id: json['id'] as String,
    name: json['name'] as String,
    imageBytes: base64Decode(json['imageBytes'] as String),
    imageWidth: (json['imageWidth'] as num).toDouble(),
    imageHeight: (json['imageHeight'] as num).toDouble(),
    pixelsPerMeter: (json['pixelsPerMeter'] as num).toDouble(),
  );

  FloorPlan copyWith({
    String? name,
    Uint8List? imageBytes,
    double? imageWidth,
    double? imageHeight,
    double? pixelsPerMeter,
  }) {
    return FloorPlan(
      id: id,
      name: name ?? this.name,
      imageBytes: imageBytes ?? this.imageBytes,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      pixelsPerMeter: pixelsPerMeter ?? this.pixelsPerMeter,
    );
  }
}
