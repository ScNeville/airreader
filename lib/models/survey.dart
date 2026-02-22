import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/building_profile.dart';
import 'package:airreader/models/client_device.dart';
import 'package:airreader/models/environment_zone.dart';
import 'package:airreader/models/floor_plan.dart';
import 'package:airreader/models/wall.dart';

/// The top-level data container for a single WiFi survey project.
class Survey {
  Survey({
    required this.id,
    required this.name,
    this.floorPlan,
    List<WallSegment>? walls,
    List<AccessPoint>? accessPoints,
    List<ClientDevice>? clientDevices,
    List<EnvironmentZone>? zones,
    this.totalWanBandwidthMbps,
    this.buildingProfile = BuildingProfile.defaults,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : walls = walls ?? [],
       accessPoints = accessPoints ?? [],
       clientDevices = clientDevices ?? [],
       zones = zones ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;

  FloorPlan? floorPlan;
  List<WallSegment> walls;
  List<AccessPoint> accessPoints;
  List<ClientDevice> clientDevices;
  List<EnvironmentZone> zones;

  /// Total WAN bandwidth available for the whole network (Mbps).
  double? totalWanBandwidthMbps;

  /// Building construction profile used for auto-detected wall defaults.
  BuildingProfile buildingProfile;

  final DateTime createdAt;
  DateTime updatedAt;

  Survey copyWith({
    String? name,
    FloorPlan? floorPlan,
    List<WallSegment>? walls,
    List<AccessPoint>? accessPoints,
    List<ClientDevice>? clientDevices,
    List<EnvironmentZone>? zones,
    double? totalWanBandwidthMbps,
    BuildingProfile? buildingProfile,
  }) {
    return Survey(
      id: id,
      name: name ?? this.name,
      floorPlan: floorPlan ?? this.floorPlan,
      walls: walls ?? List.from(this.walls),
      accessPoints: accessPoints ?? List.from(this.accessPoints),
      clientDevices: clientDevices ?? List.from(this.clientDevices),
      zones: zones ?? List.from(this.zones),
      totalWanBandwidthMbps:
          totalWanBandwidthMbps ?? this.totalWanBandwidthMbps,
      buildingProfile: buildingProfile ?? this.buildingProfile,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'floorPlan': floorPlan?.toJson(),
    'walls': walls.map((w) => w.toJson()).toList(),
    'accessPoints': accessPoints.map((ap) => ap.toJson()).toList(),
    'clientDevices': clientDevices.map((d) => d.toJson()).toList(),
    'zones': zones.map((z) => z.toJson()).toList(),
    'totalWanBandwidthMbps': totalWanBandwidthMbps,
    'buildingProfile': buildingProfile.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Survey.fromJson(Map<String, dynamic> json) => Survey(
    id: json['id'] as String,
    name: json['name'] as String,
    floorPlan: json['floorPlan'] != null
        ? FloorPlan.fromJson(json['floorPlan'] as Map<String, dynamic>)
        : null,
    walls: (json['walls'] as List? ?? [])
        .map((w) => WallSegment.fromJson(w as Map<String, dynamic>))
        .toList(),
    accessPoints: (json['accessPoints'] as List? ?? [])
        .map((ap) => AccessPoint.fromJson(ap as Map<String, dynamic>))
        .toList(),
    clientDevices: (json['clientDevices'] as List? ?? [])
        .map((d) => ClientDevice.fromJson(d as Map<String, dynamic>))
        .toList(),
    zones: (json['zones'] as List? ?? [])
        .map((z) => EnvironmentZone.fromJson(z as Map<String, dynamic>))
        .toList(),
    totalWanBandwidthMbps: json['totalWanBandwidthMbps'] != null
        ? (json['totalWanBandwidthMbps'] as num).toDouble()
        : null,
    buildingProfile: json['buildingProfile'] != null
        ? BuildingProfile.fromJson(
            json['buildingProfile'] as Map<String, dynamic>,
          )
        : BuildingProfile.defaults,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
