import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/building_profile.dart';
import 'package:airreader/models/client_device.dart';
import 'package:airreader/models/environment_zone.dart';
import 'package:airreader/models/floor_plan.dart';
import 'package:airreader/models/survey.dart';
import 'package:airreader/models/wall.dart';

const _uuid = Uuid();

// ============================================================================
// Events
// ============================================================================

abstract class SurveyEvent extends Equatable {
  const SurveyEvent();
  @override
  List<Object?> get props => [];
}

class SurveyRenamed extends SurveyEvent {
  const SurveyRenamed(this.name);
  final String name;
  @override
  List<Object?> get props => [name];
}

class SurveyFloorPlanSet extends SurveyEvent {
  const SurveyFloorPlanSet(this.floorPlan);
  final FloorPlan floorPlan;
  @override
  List<Object?> get props => [floorPlan];
}

class SurveyFloorPlanCleared extends SurveyEvent {
  const SurveyFloorPlanCleared();
}

class SurveyWallAdded extends SurveyEvent {
  const SurveyWallAdded(this.wall);
  final WallSegment wall;
  @override
  List<Object?> get props => [wall];
}

class SurveyWallUpdated extends SurveyEvent {
  const SurveyWallUpdated(this.wall);
  final WallSegment wall;
  @override
  List<Object?> get props => [wall];
}

class SurveyWallRemoved extends SurveyEvent {
  const SurveyWallRemoved(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class SurveyWallsCleared extends SurveyEvent {
  const SurveyWallsCleared();
}

/// Replace ALL walls with a new list (used when auto-detecting walls).
class SurveyWallsBulkReplaced extends SurveyEvent {
  const SurveyWallsBulkReplaced(this.walls);
  final List<WallSegment> walls;
  @override
  List<Object?> get props => [walls.length];
}

/// Update the building profile and optionally re-apply materials to walls.
class SurveyBuildingProfileSet extends SurveyEvent {
  const SurveyBuildingProfileSet(this.profile, {this.applyToWalls = true});
  final BuildingProfile profile;

  /// When true, bulk-update wall materials based on each wall's classification.
  final bool applyToWalls;
  @override
  List<Object?> get props => [profile.framingType, applyToWalls];
}

/// Bulk-apply [material] to every wall whose classification matches [classification].
class SurveyWallClassMaterialApplied extends SurveyEvent {
  const SurveyWallClassMaterialApplied(this.classification, this.material);
  final WallClassification classification;
  final WallMaterial material;
  @override
  List<Object?> get props => [classification, material];
}

class SurveyAccessPointAdded extends SurveyEvent {
  const SurveyAccessPointAdded(this.ap);
  final AccessPoint ap;
  @override
  List<Object?> get props => [ap];
}

class SurveyAccessPointUpdated extends SurveyEvent {
  const SurveyAccessPointUpdated(this.ap);
  final AccessPoint ap;
  @override
  List<Object?> get props => [ap];
}

class SurveyAccessPointMoved extends SurveyEvent {
  const SurveyAccessPointMoved(this.id, this.x, this.y);
  final String id;
  final double x;
  final double y;
  @override
  List<Object?> get props => [id, x, y];
}

class SurveyAccessPointRemoved extends SurveyEvent {
  const SurveyAccessPointRemoved(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class SurveyClientDeviceAdded extends SurveyEvent {
  const SurveyClientDeviceAdded(this.device);
  final ClientDevice device;
  @override
  List<Object?> get props => [device];
}

class SurveyClientDeviceUpdated extends SurveyEvent {
  const SurveyClientDeviceUpdated(this.device);
  final ClientDevice device;
  @override
  List<Object?> get props => [device];
}

class SurveyClientDeviceRemoved extends SurveyEvent {
  const SurveyClientDeviceRemoved(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class SurveyClientDeviceMoved extends SurveyEvent {
  const SurveyClientDeviceMoved(this.id, this.x, this.y);
  final String id;
  final double x;
  final double y;
  @override
  List<Object?> get props => [id, x, y];
}

// Environment zones
class SurveyZoneAdded extends SurveyEvent {
  const SurveyZoneAdded(this.zone);
  final EnvironmentZone zone;
  @override
  List<Object?> get props => [zone.id];
}

class SurveyZoneUpdated extends SurveyEvent {
  const SurveyZoneUpdated(this.zone);
  final EnvironmentZone zone;
  @override
  List<Object?> get props => [zone.id];
}

class SurveyZoneRemoved extends SurveyEvent {
  const SurveyZoneRemoved(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class SurveyWanBandwidthSet extends SurveyEvent {
  const SurveyWanBandwidthSet(this.mbps);
  final double? mbps;
  @override
  List<Object?> get props => [mbps];
}

class SurveyNewStarted extends SurveyEvent {
  const SurveyNewStarted();
}

class SurveyLoaded extends SurveyEvent {
  const SurveyLoaded(this.survey);
  final Survey survey;
  @override
  List<Object?> get props => [survey.id];
}

// ============================================================================
// State
// ============================================================================

// SurveyState intentionally does NOT extend Equatable: every new
// SurveyState object is distinct by identity, so moves/rapid edits
// always propagate to listeners (Equatable + DateTime.now() at the
// same microsecond would otherwise silently discard events).
class SurveyState {
  const SurveyState(this.survey);
  final Survey survey;
}

// ============================================================================
// BLoC
// ============================================================================

class SurveyBloc extends Bloc<SurveyEvent, SurveyState> {
  SurveyBloc()
    : super(SurveyState(Survey(id: _uuid.v4(), name: 'Untitled Survey'))) {
    on<SurveyRenamed>(_onRenamed);
    on<SurveyFloorPlanSet>(_onFloorPlanSet);
    on<SurveyFloorPlanCleared>(_onFloorPlanCleared);
    on<SurveyWallAdded>(_onWallAdded);
    on<SurveyWallUpdated>(_onWallUpdated);
    on<SurveyWallRemoved>(_onWallRemoved);
    on<SurveyWallsCleared>(_onWallsCleared);
    on<SurveyWallsBulkReplaced>(_onWallsBulkReplaced);
    on<SurveyBuildingProfileSet>(_onBuildingProfileSet);
    on<SurveyWallClassMaterialApplied>(_onWallClassMaterialApplied);
    on<SurveyAccessPointAdded>(_onAccessPointAdded);
    on<SurveyAccessPointUpdated>(_onAccessPointUpdated);
    on<SurveyAccessPointMoved>(_onAccessPointMoved);
    on<SurveyAccessPointRemoved>(_onAccessPointRemoved);
    on<SurveyClientDeviceAdded>(_onClientDeviceAdded);
    on<SurveyClientDeviceUpdated>(_onClientDeviceUpdated);
    on<SurveyClientDeviceMoved>(_onClientDeviceMoved);
    on<SurveyClientDeviceRemoved>(_onClientDeviceRemoved);
    on<SurveyZoneAdded>(_onZoneAdded);
    on<SurveyZoneUpdated>(_onZoneUpdated);
    on<SurveyZoneRemoved>(_onZoneRemoved);
    on<SurveyWanBandwidthSet>(_onWanBandwidthSet);
    on<SurveyNewStarted>(_onNewStarted);
    on<SurveyLoaded>(_onLoaded);
  }

  Survey get _s => state.survey;

  void _onRenamed(SurveyRenamed e, Emitter<SurveyState> emit) =>
      emit(SurveyState(_s.copyWith(name: e.name)));

  void _onFloorPlanSet(SurveyFloorPlanSet e, Emitter<SurveyState> emit) =>
      emit(SurveyState(_s.copyWith(floorPlan: e.floorPlan)));

  void _onFloorPlanCleared(
    SurveyFloorPlanCleared e,
    Emitter<SurveyState> emit,
  ) => emit(SurveyState(_s.copyWith(floorPlan: null)));

  void _onWallAdded(SurveyWallAdded e, Emitter<SurveyState> emit) =>
      emit(SurveyState(_s.copyWith(walls: [..._s.walls, e.wall])));

  void _onWallUpdated(SurveyWallUpdated e, Emitter<SurveyState> emit) => emit(
    SurveyState(
      _s.copyWith(
        walls: _s.walls.map((w) => w.id == e.wall.id ? e.wall : w).toList(),
      ),
    ),
  );

  void _onWallRemoved(SurveyWallRemoved e, Emitter<SurveyState> emit) => emit(
    SurveyState(
      _s.copyWith(walls: _s.walls.where((w) => w.id != e.id).toList()),
    ),
  );

  void _onWallsCleared(SurveyWallsCleared e, Emitter<SurveyState> emit) =>
      emit(SurveyState(_s.copyWith(walls: [])));

  void _onWallsBulkReplaced(
    SurveyWallsBulkReplaced e,
    Emitter<SurveyState> emit,
  ) => emit(SurveyState(_s.copyWith(walls: e.walls)));

  void _onBuildingProfileSet(
    SurveyBuildingProfileSet e,
    Emitter<SurveyState> emit,
  ) {
    List<WallSegment> walls = _s.walls;
    if (e.applyToWalls && walls.isNotEmpty) {
      walls = walls.map((w) {
        return switch (w.classification) {
          // Exterior walls get the outer-face material + inner lining.
          WallClassification.exterior => w.copyWith(
            material: e.profile.exteriorMaterial,
            innerMaterial: e.profile.exteriorInnerMaterial,
          ),
          // Interior partitions are single-layer — clear any inner material.
          WallClassification.interior => w.copyWith(
            material: e.profile.interiorMaterial,
            innerMaterial: null,
          ),
          _ => w,
        };
      }).toList();
    }
    emit(SurveyState(_s.copyWith(buildingProfile: e.profile, walls: walls)));
  }

  void _onWallClassMaterialApplied(
    SurveyWallClassMaterialApplied e,
    Emitter<SurveyState> emit,
  ) {
    final walls = _s.walls.map((w) {
      if (w.classification == e.classification) {
        return w.copyWith(material: e.material);
      }
      return w;
    }).toList();
    emit(SurveyState(_s.copyWith(walls: walls)));
  }

  void _onAccessPointAdded(
    SurveyAccessPointAdded e,
    Emitter<SurveyState> emit,
  ) => emit(SurveyState(_s.copyWith(accessPoints: [..._s.accessPoints, e.ap])));

  void _onAccessPointUpdated(
    SurveyAccessPointUpdated e,
    Emitter<SurveyState> emit,
  ) => emit(
    SurveyState(
      _s.copyWith(
        accessPoints: _s.accessPoints
            .map((ap) => ap.id == e.ap.id ? e.ap : ap)
            .toList(),
      ),
    ),
  );

  void _onAccessPointMoved(
    SurveyAccessPointMoved e,
    Emitter<SurveyState> emit,
  ) => emit(
    SurveyState(
      _s.copyWith(
        accessPoints: _s.accessPoints.map((ap) {
          return ap.id == e.id
              ? ap.copyWith(positionX: e.x, positionY: e.y)
              : ap;
        }).toList(),
      ),
    ),
  );

  void _onAccessPointRemoved(
    SurveyAccessPointRemoved e,
    Emitter<SurveyState> emit,
  ) => emit(
    SurveyState(
      _s.copyWith(
        accessPoints: _s.accessPoints.where((ap) => ap.id != e.id).toList(),
      ),
    ),
  );

  void _onClientDeviceAdded(
    SurveyClientDeviceAdded e,
    Emitter<SurveyState> emit,
  ) => emit(
    SurveyState(_s.copyWith(clientDevices: [..._s.clientDevices, e.device])),
  );

  void _onClientDeviceUpdated(
    SurveyClientDeviceUpdated e,
    Emitter<SurveyState> emit,
  ) => emit(
    SurveyState(
      _s.copyWith(
        clientDevices: _s.clientDevices
            .map((d) => d.id == e.device.id ? e.device : d)
            .toList(),
      ),
    ),
  );

  void _onClientDeviceRemoved(
    SurveyClientDeviceRemoved e,
    Emitter<SurveyState> emit,
  ) => emit(
    SurveyState(
      _s.copyWith(
        clientDevices: _s.clientDevices.where((d) => d.id != e.id).toList(),
      ),
    ),
  );

  void _onClientDeviceMoved(
    SurveyClientDeviceMoved e,
    Emitter<SurveyState> emit,
  ) => emit(
    SurveyState(
      _s.copyWith(
        clientDevices: _s.clientDevices.map((d) {
          return d.id == e.id ? d.copyWith(positionX: e.x, positionY: e.y) : d;
        }).toList(),
      ),
    ),
  );

  void _onWanBandwidthSet(SurveyWanBandwidthSet e, Emitter<SurveyState> emit) =>
      emit(SurveyState(_s.copyWith(totalWanBandwidthMbps: e.mbps)));

  void _onZoneAdded(SurveyZoneAdded e, Emitter<SurveyState> emit) =>
      emit(SurveyState(_s.copyWith(zones: [..._s.zones, e.zone])));

  void _onZoneUpdated(SurveyZoneUpdated e, Emitter<SurveyState> emit) => emit(
    SurveyState(
      _s.copyWith(
        zones: _s.zones.map((z) => z.id == e.zone.id ? e.zone : z).toList(),
      ),
    ),
  );

  void _onZoneRemoved(SurveyZoneRemoved e, Emitter<SurveyState> emit) => emit(
    SurveyState(
      _s.copyWith(zones: _s.zones.where((z) => z.id != e.id).toList()),
    ),
  );

  void _onNewStarted(SurveyNewStarted e, Emitter<SurveyState> emit) =>
      emit(SurveyState(Survey(id: _uuid.v4(), name: 'Untitled Survey')));

  void _onLoaded(SurveyLoaded e, Emitter<SurveyState> emit) =>
      emit(SurveyState(e.survey));
}
