import 'package:airreader/models/access_point.dart';

/// Type of virtual client device.
enum ClientDeviceType {
  laptop(label: 'Laptop'),
  smartphone(label: 'Smartphone'),
  tablet(label: 'Tablet'),
  iotSensor(label: 'IoT Sensor'),
  desktop(label: 'Desktop PC'),
  smartTv(label: 'Smart TV');

  const ClientDeviceType({required this.label});
  final String label;
}

/// A virtual client device placed on the floor plan.
class ClientDevice {
  ClientDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.positionX,
    required this.positionY,
    this.preferredBand,
    this.manualApId,
  });

  final String id;
  final String name;
  final ClientDeviceType type;

  /// Position in floor-plan pixel coordinates.
  double positionX;
  double positionY;

  /// Preferred frequency band for association. null = auto (best signal).
  final WiFiBand? preferredBand;

  /// If set, forces association to this AP id; otherwise best-signal wins.
  final String? manualApId;

  ClientDevice copyWith({
    String? name,
    ClientDeviceType? type,
    double? positionX,
    double? positionY,
    WiFiBand? preferredBand,
    bool clearPreferredBand = false,
    String? manualApId,
    bool clearManualApId = false,
  }) {
    return ClientDevice(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      preferredBand: clearPreferredBand
          ? null
          : (preferredBand ?? this.preferredBand),
      manualApId: clearManualApId ? null : (manualApId ?? this.manualApId),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'positionX': positionX,
    'positionY': positionY,
    'preferredBand': preferredBand?.name,
    'manualApId': manualApId,
  };

  factory ClientDevice.fromJson(Map<String, dynamic> json) => ClientDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    type: ClientDeviceType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => ClientDeviceType.laptop,
    ),
    positionX: (json['positionX'] as num).toDouble(),
    positionY: (json['positionY'] as num).toDouble(),
    preferredBand: json['preferredBand'] == null
        ? null
        : WiFiBand.values.firstWhere(
            (b) => b.name == json['preferredBand'],
            orElse: () => WiFiBand.ghz5,
          ),
    manualApId: json['manualApId'] as String?,
  );
}
