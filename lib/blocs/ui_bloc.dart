import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/ap_library.dart';
import 'package:airreader/models/client_device.dart';
import 'package:airreader/models/environment_zone.dart';
import 'package:airreader/models/wall.dart';

// ============================================================================
// Editor tool selection
// ============================================================================

/// Active tool on the floor-plan canvas.
enum EditorTool {
  /// Pan/zoom and select existing elements.
  select,

  /// Click two points to draw a new wall segment.
  drawWall,

  /// Click two points to define a known real-world distance for scale calibration.
  calibrateScale,

  /// Click on the canvas to place a pending AP.
  placeAP,

  /// Click on the canvas to place a pending client device.
  placeClient,

  /// Click two points to draw an environment zone rectangle.
  drawZone,
}

// ============================================================================
// Nav sections
// ============================================================================

enum NavSection {
  floorPlan,
  accessPoints,
  clients,
  zones,
  heatMap,
  performance,
  rfEngineering,
  settings,
}

// ============================================================================
// Events
// ============================================================================

abstract class UIEvent extends Equatable {
  const UIEvent();
  @override
  List<Object?> get props => [];
}

class UINavSectionSelected extends UIEvent {
  const UINavSectionSelected(this.section);
  final NavSection section;
  @override
  List<Object?> get props => [section];
}

class UIAccessPointSelected extends UIEvent {
  const UIAccessPointSelected(this.id);
  final String? id;
  @override
  List<Object?> get props => [id];
}

class UIClientDeviceSelected extends UIEvent {
  const UIClientDeviceSelected(this.id);
  final String? id;
  @override
  List<Object?> get props => [id];
}

class UIActiveBandSet extends UIEvent {
  const UIActiveBandSet(this.band);
  final WiFiBand? band;
  @override
  List<Object?> get props => [band];
}

class UIHeatMapToggled extends UIEvent {
  const UIHeatMapToggled();
}

class UIPerformancePanelToggled extends UIEvent {
  const UIPerformancePanelToggled();
}

class UIHeatMapOpacityChanged extends UIEvent {
  const UIHeatMapOpacityChanged(this.opacity);
  final double opacity;
  @override
  List<Object?> get props => [opacity];
}

class UIThemeDarkSet extends UIEvent {
  const UIThemeDarkSet(this.dark);
  final bool dark;
  @override
  List<Object?> get props => [dark];
}

class UIEditorToolChanged extends UIEvent {
  const UIEditorToolChanged(this.tool);
  final EditorTool tool;
  @override
  List<Object?> get props => [tool];
}

class UIWallSelected extends UIEvent {
  const UIWallSelected(this.id);
  final String? id;
  @override
  List<Object?> get props => [id];
}

class UIDrawingMaterialChanged extends UIEvent {
  const UIDrawingMaterialChanged(this.material);
  final WallMaterial material;
  @override
  List<Object?> get props => [material];
}

class UISavePathChanged extends UIEvent {
  const UISavePathChanged(this.path);
  final String? path;
  @override
  List<Object?> get props => [path];
}

class UIApBeingPlacedSpecChanged extends UIEvent {
  const UIApBeingPlacedSpecChanged(this.spec);
  final ApSpec? spec;
  @override
  List<Object?> get props => [spec?.fullName];
}

class UIClientBeingPlacedChanged extends UIEvent {
  const UIClientBeingPlacedChanged(this.type);
  final ClientDeviceType? type;
  @override
  List<Object?> get props => [type];
}

class UIZoneSelected extends UIEvent {
  const UIZoneSelected(this.id);
  final String? id;
  @override
  List<Object?> get props => [id];
}

/// Setting type to null deactivates zone-drawing mode.
class UIDrawZoneTypeSet extends UIEvent {
  const UIDrawZoneTypeSet(this.type);
  final ZoneType? type;
  @override
  List<Object?> get props => [type];
}

// ============================================================================
// State
// ============================================================================

class UIState extends Equatable {
  const UIState({
    this.selectedSection = NavSection.floorPlan,
    this.selectedAccessPointId,
    this.selectedClientDeviceId,
    this.selectedWallId,
    this.selectedZoneId,
    this.activeTool = EditorTool.select,
    this.drawingMaterial = WallMaterial.drywall,
    this.activeBand,
    this.showHeatMap = false,
    this.showPerfPanel = false,
    this.heatMapOpacity = 0.55,
    this.darkMode = true,
    this.currentFilePath,
    this.apBeingPlacedSpec,
    this.clientBeingPlacedType,
    this.zoneTypeBeingDrawn,
  });

  final NavSection selectedSection;
  final String? selectedAccessPointId;
  final String? selectedClientDeviceId;

  /// Currently selected wall segment id (null = none).
  final String? selectedWallId;

  /// Currently selected environment zone id (null = none).
  final String? selectedZoneId;

  /// Zone type currently being drawn; null = not drawing.
  final ZoneType? zoneTypeBeingDrawn;

  /// Active editor tool on the floor-plan canvas.
  final EditorTool activeTool;

  /// Material used when drawing new wall segments.
  final WallMaterial drawingMaterial;

  /// Which band's heat map to display; null = best-signal overlay.
  final WiFiBand? activeBand;

  final bool showHeatMap;
  final bool showPerfPanel;

  /// Heat map overlay opacity, 0.0–1.0.
  final double heatMapOpacity;
  final bool darkMode;

  /// Absolute path of the currently open project file; null = unsaved.
  final String? currentFilePath;

  /// The AP spec waiting to be placed on the canvas; null = not placing.
  final ApSpec? apBeingPlacedSpec;

  /// Client device type waiting to be placed; null = not placing.
  final ClientDeviceType? clientBeingPlacedType;

  UIState copyWith({
    NavSection? selectedSection,
    String? selectedAccessPointId,
    String? selectedClientDeviceId,
    String? selectedWallId,
    String? selectedZoneId,
    bool clearSelectedWall = false,
    bool clearSelectedAp = false,
    bool clearSelectedClient = false,
    bool clearSelectedZone = false,
    EditorTool? activeTool,
    WallMaterial? drawingMaterial,
    WiFiBand? activeBand,
    bool clearActiveBand = false,
    bool? showHeatMap,
    bool? showPerfPanel,
    double? heatMapOpacity,
    bool? darkMode,
    String? currentFilePath,
    bool clearFilePath = false,
    ApSpec? apBeingPlacedSpec,
    bool clearApBeingPlaced = false,
    ClientDeviceType? clientBeingPlacedType,
    bool clearClientBeingPlaced = false,
    ZoneType? zoneTypeBeingDrawn,
    bool clearZoneTypeBeingDrawn = false,
  }) {
    return UIState(
      selectedSection: selectedSection ?? this.selectedSection,
      selectedAccessPointId: clearSelectedAp
          ? null
          : (selectedAccessPointId ?? this.selectedAccessPointId),
      selectedClientDeviceId: clearSelectedClient
          ? null
          : (selectedClientDeviceId ?? this.selectedClientDeviceId),
      selectedWallId: clearSelectedWall
          ? null
          : (selectedWallId ?? this.selectedWallId),
      selectedZoneId: clearSelectedZone
          ? null
          : (selectedZoneId ?? this.selectedZoneId),
      activeTool: activeTool ?? this.activeTool,
      drawingMaterial: drawingMaterial ?? this.drawingMaterial,
      activeBand: clearActiveBand ? null : (activeBand ?? this.activeBand),
      showHeatMap: showHeatMap ?? this.showHeatMap,
      showPerfPanel: showPerfPanel ?? this.showPerfPanel,
      heatMapOpacity: heatMapOpacity ?? this.heatMapOpacity,
      darkMode: darkMode ?? this.darkMode,
      currentFilePath: clearFilePath
          ? null
          : (currentFilePath ?? this.currentFilePath),
      apBeingPlacedSpec: clearApBeingPlaced
          ? null
          : (apBeingPlacedSpec ?? this.apBeingPlacedSpec),
      clientBeingPlacedType: clearClientBeingPlaced
          ? null
          : (clientBeingPlacedType ?? this.clientBeingPlacedType),
      zoneTypeBeingDrawn: clearZoneTypeBeingDrawn
          ? null
          : (zoneTypeBeingDrawn ?? this.zoneTypeBeingDrawn),
    );
  }

  @override
  List<Object?> get props => [
    selectedSection,
    selectedAccessPointId,
    selectedClientDeviceId,
    selectedWallId,
    selectedZoneId,
    activeTool,
    drawingMaterial,
    activeBand,
    showHeatMap,
    showPerfPanel,
    heatMapOpacity,
    darkMode,
    currentFilePath,
    apBeingPlacedSpec?.fullName,
    clientBeingPlacedType,
    zoneTypeBeingDrawn,
  ];
}

// ============================================================================
// BLoC
// ============================================================================

class UIBloc extends Bloc<UIEvent, UIState> {
  UIBloc() : super(const UIState()) {
    on<UINavSectionSelected>(
      (e, emit) => emit(state.copyWith(selectedSection: e.section)),
    );
    on<UIAccessPointSelected>(
      (e, emit) => emit(state.copyWith(selectedAccessPointId: e.id)),
    );
    on<UIClientDeviceSelected>((e, emit) {
      if (e.id == null) {
        emit(state.copyWith(clearSelectedClient: true));
      } else {
        emit(state.copyWith(selectedClientDeviceId: e.id));
      }
    });
    on<UIActiveBandSet>(
      (e, emit) => e.band == null
          ? emit(state.copyWith(clearActiveBand: true))
          : emit(state.copyWith(activeBand: e.band)),
    );
    on<UIHeatMapToggled>(
      (e, emit) => emit(state.copyWith(showHeatMap: !state.showHeatMap)),
    );
    on<UIPerformancePanelToggled>(
      (e, emit) => emit(state.copyWith(showPerfPanel: !state.showPerfPanel)),
    );
    on<UIHeatMapOpacityChanged>(
      (e, emit) => emit(state.copyWith(heatMapOpacity: e.opacity)),
    );
    on<UIThemeDarkSet>((e, emit) => emit(state.copyWith(darkMode: e.dark)));
    on<UIEditorToolChanged>(
      (e, emit) =>
          emit(state.copyWith(activeTool: e.tool, clearSelectedWall: true)),
    );
    on<UIWallSelected>((e, emit) {
      if (e.id == null) {
        emit(state.copyWith(clearSelectedWall: true));
      } else {
        emit(state.copyWith(selectedWallId: e.id, clearSelectedAp: true));
      }
    });
    on<UIDrawingMaterialChanged>(
      (e, emit) => emit(state.copyWith(drawingMaterial: e.material)),
    );
    on<UISavePathChanged>((e, emit) {
      if (e.path == null) {
        emit(state.copyWith(clearFilePath: true));
      } else {
        emit(state.copyWith(currentFilePath: e.path));
      }
    });
    on<UIApBeingPlacedSpecChanged>((e, emit) {
      if (e.spec == null) {
        emit(state.copyWith(clearApBeingPlaced: true));
      } else {
        emit(
          state.copyWith(
            apBeingPlacedSpec: e.spec,
            activeTool: EditorTool.placeAP,
            selectedSection: NavSection.floorPlan,
          ),
        );
      }
    });
    on<UIClientBeingPlacedChanged>((e, emit) {
      if (e.type == null) {
        emit(state.copyWith(clearClientBeingPlaced: true));
      } else {
        emit(
          state.copyWith(
            clientBeingPlacedType: e.type,
            activeTool: EditorTool.placeClient,
            selectedSection: NavSection.floorPlan,
          ),
        );
      }
    });
    on<UIZoneSelected>((e, emit) {
      if (e.id == null) {
        emit(state.copyWith(clearSelectedZone: true));
      } else {
        emit(
          state.copyWith(
            selectedZoneId: e.id,
            clearSelectedAp: true,
            clearSelectedWall: true,
          ),
        );
      }
    });
    on<UIDrawZoneTypeSet>((e, emit) {
      if (e.type == null) {
        emit(
          state.copyWith(
            clearZoneTypeBeingDrawn: true,
            activeTool: EditorTool.select,
          ),
        );
      } else {
        emit(
          state.copyWith(
            zoneTypeBeingDrawn: e.type,
            activeTool: EditorTool.drawZone,
            selectedSection: NavSection.floorPlan,
          ),
        );
      }
    });
  }
}
