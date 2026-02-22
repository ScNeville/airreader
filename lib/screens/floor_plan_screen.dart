import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import 'package:airreader/blocs/performance_cubit.dart';
import 'package:airreader/blocs/simulation_cubit.dart';
import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/blocs/ui_bloc.dart';
import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/ap_library.dart';
import 'package:airreader/models/client_device.dart';
import 'package:airreader/models/environment_zone.dart';
import 'package:airreader/models/floor_plan.dart';
import 'package:airreader/models/network_performance.dart';
import 'package:airreader/services/floor_plan_import_service.dart';
import 'package:airreader/services/wall_detection_service.dart';
import 'package:airreader/widgets/building_profile_dialog.dart';
import 'package:airreader/widgets/canvas/floor_plan_canvas.dart';
import 'package:airreader/widgets/floor_plan_side_panel.dart';

const _uuid = Uuid();

class FloorPlanScreen extends StatelessWidget {
  const FloorPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final floorPlan = context.select(
      (SurveyBloc b) => b.state.survey.floorPlan,
    );

    if (floorPlan == null) return const _EmptyState();

    return const _EditorLayout();
  }
}

// ============================================================================
// Empty state – no floor plan loaded yet
// ============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.map_outlined,
            size: 72,
            color: colorScheme.primary.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 20),
          Text(
            'No Floor Plan',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import a PNG or JPEG image to get started.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Import Floor Plan'),
            onPressed: () => _importFloorPlan(context),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Editor layout – canvas + side panel
// ============================================================================

class _EditorLayout extends StatelessWidget {
  const _EditorLayout();

  @override
  Widget build(BuildContext context) {
    final showPerfPanel = context.select((UIBloc b) => b.state.showPerfPanel);
    return Column(
      children: [
        const _Toolbar(),
        const Divider(height: 1),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Canvas area.
                    Expanded(child: _Canvas()),
                    const VerticalDivider(width: 1),
                    // Properties panel.
                    const FloorPlanSidePanel(),
                  ],
                ),
              ),
              if (showPerfPanel) ...[
                const Divider(height: 1),
                const _LivePerfPanel(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Toolbar
// ============================================================================

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) {
    final wallCount = context.select(
      (SurveyBloc b) => b.state.survey.walls.length,
    );
    final apCount = context.select(
      (SurveyBloc b) => b.state.survey.accessPoints.length,
    );
    final isPlacingAP = context.select(
      (UIBloc b) => b.state.activeTool == EditorTool.placeAP,
    );
    final isPlacingClient = context.select(
      (UIBloc b) => b.state.activeTool == EditorTool.placeClient,
    );
    final isDrawingZone = context.select(
      (UIBloc b) => b.state.activeTool == EditorTool.drawZone,
    );
    final zoneCount = context.select(
      (SurveyBloc b) => b.state.survey.zones.length,
    );
    final clientCount = context.select(
      (SurveyBloc b) => b.state.survey.clientDevices.length,
    );

    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: cs.surface,
      child: Row(
        children: [
          // ── File / scale ────────────────────────────────────────────────
          Tooltip(
            message: 'Replace floor plan image',
            child: IconButton(
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              onPressed: () => _importFloorPlan(context),
            ),
          ),
          Tooltip(
            message: 'Set scale',
            child: IconButton(
              icon: const Icon(Icons.straighten_outlined, size: 18),
              onPressed: () => _showScaleDialog(context),
            ),
          ),
          Tooltip(
            message: 'Auto-detect walls from floor plan image',
            child: IconButton(
              icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
              onPressed: () => _detectWalls(context),
            ),
          ),
          Tooltip(
            message: 'Building profile (framing & wall materials)',
            child: IconButton(
              icon: const Icon(Icons.domain_outlined, size: 18),
              onPressed: () => showBuildingProfileDialog(context),
            ),
          ),
          const SizedBox(width: 2),
          const VerticalDivider(width: 1, indent: 8, endIndent: 8),
          const SizedBox(width: 2),

          // ── Heat map ─────────────────────────────────────────────────────
          _HeatMapControls(),
          const SizedBox(width: 4),
          _LiveStatsToggle(),
          const SizedBox(width: 2),
          const VerticalDivider(width: 1, indent: 8, endIndent: 8),
          const SizedBox(width: 2),

          // ── Add AP ───────────────────────────────────────────────────────
          if (isPlacingAP)
            _CancelButton(
              label: 'Cancel AP',
              onPressed: () => context.read<UIBloc>().add(
                const UIEditorToolChanged(EditorTool.select),
              ),
            )
          else
            Tooltip(
              message: 'Add Access Point',
              child: IconButton(
                icon: const Icon(Icons.router_outlined, size: 18),
                onPressed: () => _showApPickerDialog(context),
              ),
            ),

          // ── Add Client ───────────────────────────────────────────────────
          if (isPlacingClient)
            _CancelButton(
              label: 'Cancel Client',
              onPressed: () => context.read<UIBloc>().add(
                const UIEditorToolChanged(EditorTool.select),
              ),
            )
          else
            Tooltip(
              message: 'Add Client Device',
              child: IconButton(
                icon: const Icon(Icons.devices_outlined, size: 18),
                onPressed: () => _showClientPickerDialog(context),
              ),
            ),

          // ── Add Zone ─────────────────────────────────────────────────────
          if (isDrawingZone)
            _CancelButton(
              label: 'Cancel Zone',
              onPressed: () =>
                  context.read<UIBloc>().add(const UIDrawZoneTypeSet(null)),
            )
          else
            Tooltip(
              message: 'Add Environment Zone',
              child: IconButton(
                icon: const Icon(Icons.layers_outlined, size: 18),
                onPressed: () => _showZoneTypePickerDialog(context),
              ),
            ),

          const Spacer(),

          // ── Count badges ─────────────────────────────────────────────────
          if (zoneCount > 0)
            _Badge(
              label: '$zoneCount',
              icon: Icons.layers_outlined,
              color: const Color(0xFF7E57C2),
            ),
          if (clientCount > 0)
            _Badge(
              label: '$clientCount',
              icon: Icons.devices_outlined,
              color: const Color(0xFF009688),
            ),
          if (apCount > 0)
            _Badge(
              label: '$apCount',
              icon: Icons.router_outlined,
              color: cs.secondary,
            ),
          if (wallCount > 0)
            _Badge(
              label: '$wallCount',
              icon: Icons.square_foot_outlined,
              color: cs.primary,
            ),

          // ── Clear walls ───────────────────────────────────────────────────
          if (wallCount > 0)
            IconButton(
              icon: const Icon(Icons.layers_clear_outlined, size: 18),
              tooltip: 'Clear all walls',
              onPressed: () => _confirmClearWalls(context),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Heat map toolbar controls
// ============================================================================

class _HeatMapControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final showHeatMap = context.select((UIBloc b) => b.state.showHeatMap);
    final activeBand = context.select((UIBloc b) => b.state.activeBand);
    final isComputing = context.select(
      (SimulationCubit c) => c.state.isComputing,
    );
    final hasMap = context.select(
      (SimulationCubit c) => c.state.signalMap != null,
    );
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle button
        Tooltip(
          message: showHeatMap ? 'Hide heat map' : 'Show heat map',
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: hasMap
                ? () => context.read<UIBloc>().add(const UIHeatMapToggled())
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isComputing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.thermostat_outlined,
                      size: 16,
                      color: showHeatMap && hasMap
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.45),
                    ),
                  const SizedBox(width: 5),
                  Text(
                    'Heat Map',
                    style: TextStyle(
                      fontSize: 13,
                      color: showHeatMap && hasMap
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.55),
                      fontWeight: showHeatMap && hasMap
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Band pills (only when heat map is on and map is available)
        if (showHeatMap && hasMap) ...[
          const SizedBox(width: 6),
          _BandPill(label: 'Best', band: null, activeBand: activeBand),
          const SizedBox(width: 3),
          _BandPill(label: '2.4', band: WiFiBand.ghz24, activeBand: activeBand),
          const SizedBox(width: 3),
          _BandPill(label: '5', band: WiFiBand.ghz5, activeBand: activeBand),
          const SizedBox(width: 3),
          _BandPill(label: '6', band: WiFiBand.ghz6, activeBand: activeBand),
        ],
      ],
    );
  }
}

class _BandPill extends StatelessWidget {
  const _BandPill({
    required this.label,
    required this.band,
    required this.activeBand,
  });
  final String label;
  final WiFiBand? band;
  final WiFiBand? activeBand;

  @override
  Widget build(BuildContext context) {
    final selected = band == activeBand;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () =>
          context.read<UIBloc>().add(UIActiveBandSet(selected ? null : band)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected
                ? cs.onPrimaryContainer
                : cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Badges & compact toolbar widgets
// ============================================================================

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 12),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_outlined, size: 14),
            const SizedBox(width: 5),
            Text(label),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Canvas bridge (reads BLoC state, feeds FloorPlanCanvas)
// ============================================================================

class _Canvas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final survey = context.watch<SurveyBloc>().state.survey;
    final ui = context.watch<UIBloc>().state;
    final sim = context.watch<SimulationCubit>().state;
    final perfState = context.watch<PerformanceCubit>().state;
    final clientPerfMap = perfState.performance?.perClient;

    if (survey.floorPlan == null) return const SizedBox.shrink();

    // On web, disable dragging while live computation is active to prevent
    // triggering a web-worker recompute on every pointer-move event.
    final dragLocked = kIsWeb && (ui.showHeatMap || ui.showPerfPanel);

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final isDelete =
            event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace;
        if (!isDelete) return KeyEventResult.ignored;

        final apId = ui.selectedAccessPointId;
        if (apId != null) {
          context.read<SurveyBloc>().add(SurveyAccessPointRemoved(apId));
          context.read<UIBloc>().add(const UIAccessPointSelected(null));
          return KeyEventResult.handled;
        }
        final clientId = ui.selectedClientDeviceId;
        if (clientId != null) {
          context.read<SurveyBloc>().add(SurveyClientDeviceRemoved(clientId));
          context.read<UIBloc>().add(const UIClientDeviceSelected(null));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          if (dragLocked) const _DragLockedBanner(),
          Expanded(
            child: FloorPlanCanvas(
              floorPlan: survey.floorPlan!,
              walls: survey.walls,
              accessPoints: survey.accessPoints,
              clients: survey.clientDevices,
              zones: survey.zones,
              selectedWallId: ui.selectedWallId,
              selectedApId: ui.selectedAccessPointId,
              selectedClientId: ui.selectedClientDeviceId,
              selectedZoneId: ui.selectedZoneId,
              activeTool: ui.activeTool,
              drawingMaterial: ui.drawingMaterial,
              zoneTypeBeingDrawn: ui.zoneTypeBeingDrawn,
              signalMap: sim.signalMap,
              showHeatMap: ui.showHeatMap,
              activeBand: ui.activeBand,
              heatMapOpacity: ui.heatMapOpacity,
              clientPerf: clientPerfMap,
              dragLocked: dragLocked,
              onWallAdded: (wall) =>
                  context.read<SurveyBloc>().add(SurveyWallAdded(wall)),
              onWallSelected: (id) =>
                  context.read<UIBloc>().add(UIWallSelected(id)),
              onApPlaced: (x, y) {
                // Sentinel -1,-1 means cancelled.
                if (x < 0 && y < 0) {
                  context.read<UIBloc>().add(
                    const UIEditorToolChanged(EditorTool.select),
                  );
                  return;
                }
                final spec = ui.apBeingPlacedSpec;
                if (spec == null) return;
                final ap = spec.toAccessPoint(id: _uuid.v4(), x: x, y: y);
                context.read<SurveyBloc>().add(SurveyAccessPointAdded(ap));
                context.read<UIBloc>()
                  ..add(UIAccessPointSelected(ap.id))
                  ..add(const UIApBeingPlacedSpecChanged(null))
                  ..add(const UIEditorToolChanged(EditorTool.select));
              },
              onApMoved: (id, x, y) => context.read<SurveyBloc>().add(
                SurveyAccessPointMoved(id, x, y),
              ),
              onApSelected: (id) =>
                  context.read<UIBloc>().add(UIAccessPointSelected(id)),
              onClientPlaced: (x, y) {
                // Sentinel -1,-1 means cancelled.
                if (x < 0 && y < 0) {
                  context.read<UIBloc>().add(
                    const UIEditorToolChanged(EditorTool.select),
                  );
                  return;
                }
                final type = ui.clientBeingPlacedType;
                if (type == null) return;
                final client = ClientDevice(
                  id: _uuid.v4(),
                  name: _defaultClientName(
                    type,
                    survey.clientDevices.length + 1,
                  ),
                  type: type,
                  positionX: x,
                  positionY: y,
                );
                context.read<SurveyBloc>().add(SurveyClientDeviceAdded(client));
                context.read<UIBloc>()
                  ..add(UIClientDeviceSelected(client.id))
                  ..add(const UIClientBeingPlacedChanged(null))
                  ..add(const UIEditorToolChanged(EditorTool.select));
              },
              onClientMoved: (id, x, y) => context.read<SurveyBloc>().add(
                SurveyClientDeviceMoved(id, x, y),
              ),
              onClientSelected: (id) =>
                  context.read<UIBloc>().add(UIClientDeviceSelected(id)),
              onZoneAdded: (zone) {
                context.read<SurveyBloc>().add(SurveyZoneAdded(zone));
                // Stay in drawZone mode so the user can draw multiple zones.
              },
              onZoneSelected: (id) =>
                  context.read<UIBloc>().add(UIZoneSelected(id)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Drag-locked banner (web only, shown when heat map or live stats are active)
// ============================================================================

class _DragLockedBanner extends StatelessWidget {
  const _DragLockedBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: cs.secondaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 13,
            color: cs.onSecondaryContainer.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Dragging is disabled while the Heat Map or Live Stats are active '
              '— turn them off to reposition APs and clients.',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSecondaryContainer.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Helpers
// ============================================================================

String _defaultClientName(ClientDeviceType type, int n) {
  final prefix = switch (type) {
    ClientDeviceType.laptop => 'Laptop',
    ClientDeviceType.smartphone => 'Phone',
    ClientDeviceType.tablet => 'Tablet',
    ClientDeviceType.iotSensor => 'IoT Sensor',
    ClientDeviceType.desktop => 'Desktop',
    ClientDeviceType.smartTv => 'Smart TV',
  };
  return '$prefix $n';
}

/// Opens the client type picker dialog and activates place-client mode.
Future<void> _showClientPickerDialog(BuildContext context) async {
  final type = await showDialog<ClientDeviceType>(
    context: context,
    builder: (_) => const _ClientTypePickerDialog(),
  );
  if (type == null || !context.mounted) return;
  context.read<UIBloc>().add(UIClientBeingPlacedChanged(type));
}

/// Opens the zone type picker dialog and activates draw-zone mode.
Future<void> _showZoneTypePickerDialog(BuildContext context) async {
  final type = await showDialog<ZoneType>(
    context: context,
    builder: (_) => const _ZoneTypePickerDialog(),
  );
  if (type == null || !context.mounted) return;
  context.read<UIBloc>().add(UIDrawZoneTypeSet(type));
}

/// Opens the AP library picker dialog and activates place-AP mode.
Future<void> _showApPickerDialog(BuildContext context) async {
  final spec = await showDialog<ApSpec>(
    context: context,
    builder: (_) => const _ApPickerDialog(),
  );
  if (spec == null || !context.mounted) return;
  context.read<UIBloc>().add(UIApBeingPlacedSpecChanged(spec));
}

Future<void> _importFloorPlan(BuildContext context) async {
  final result = await FloorPlanImportService.pickImage();
  if (result == null) return;
  if (!context.mounted) return;

  final floorPlan = FloorPlan(
    id: _uuid.v4(),
    name: result.name,
    imageBytes: result.bytes,
    imageWidth: result.widthPx,
    imageHeight: result.heightPx,
  );

  context.read<SurveyBloc>().add(SurveyFloorPlanSet(floorPlan));

  // Prompt for scale immediately after import.
  if (context.mounted) await _showScaleDialog(context);
}

Future<void> _detectWalls(BuildContext context) async {
  final survey = context.read<SurveyBloc>().state.survey;
  final floorPlan = survey.floorPlan;
  if (floorPlan == null) return;

  final future = WallDetectionService.detect(
    floorPlan.imageBytes,
    pixelsPerMeter: floorPlan.pixelsPerMeter,
    profile: survey.buildingProfile,
  );

  if (context.mounted) {
    await showWallDetectionSheet(context, detectionFuture: future);
  }
}

Future<void> _showScaleDialog(BuildContext context) async {
  final floorPlan = context.read<SurveyBloc>().state.survey.floorPlan;
  if (floorPlan == null) return;

  final ctrl = TextEditingController(
    text: floorPlan.realWidthMeters.toStringAsFixed(1),
  );

  final result = await showDialog<double>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Set Floor Plan Scale'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Image size: ${floorPlan.imageWidth.toInt()} × '
            '${floorPlan.imageHeight.toInt()} px',
          ),
          const SizedBox(height: 12),
          const Text(
            'What is the real-world width of this floor plan (metres)?',
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Width (m)',
              suffixText: 'm',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final m = double.tryParse(ctrl.text);
            Navigator.pop(context, m);
          },
          child: const Text('Apply'),
        ),
      ],
    ),
  );

  ctrl.dispose();

  if (!context.mounted || result == null || result <= 0) return;

  final ppm = floorPlan.imageWidth / result;
  context.read<SurveyBloc>().add(
    SurveyFloorPlanSet(floorPlan.copyWith(pixelsPerMeter: ppm)),
  );
}

Future<void> _confirmClearWalls(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Clear All Walls?'),
      content: const Text(
        'This will delete all wall segments. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    context.read<SurveyBloc>().add(const SurveyWallsCleared());
    context.read<UIBloc>().add(const UIWallSelected(null));
  }
}

// ============================================================================
// AP Library Picker Dialog
// ============================================================================

class _ApPickerDialog extends StatefulWidget {
  const _ApPickerDialog();

  @override
  State<_ApPickerDialog> createState() => _ApPickerDialogState();
}

class _ApPickerDialogState extends State<_ApPickerDialog> {
  String _selectedBrand = ApLibrary.brands.first;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brands = ApLibrary.brands;
    final models = ApLibrary.forBrand(_selectedBrand);

    return Dialog(
      child: SizedBox(
        width: 600,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.router, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Select Access Point Model',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Body: brand rail + model list
            Expanded(
              child: Row(
                children: [
                  // Brand sidebar
                  Container(
                    width: 160,
                    color: cs.surfaceContainerLow,
                    child: ListView.builder(
                      itemCount: brands.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (_, i) {
                        final brand = brands[i];
                        final selected = brand == _selectedBrand;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: cs.primaryContainer,
                          title: Text(
                            brand,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () => setState(() => _selectedBrand = brand),
                        );
                      },
                    ),
                  ),
                  const VerticalDivider(width: 1),

                  // Model list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: models.length,
                      itemBuilder: (_, i) {
                        final spec = models[i];
                        final bands = spec.supportedBands
                            .map(
                              (b) => switch (b) {
                                WiFiBand.ghz24 => '2.4',
                                WiFiBand.ghz5 => '5',
                                WiFiBand.ghz6 => '6',
                              },
                            )
                            .join(' / ');
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Icon(
                                Icons.wifi,
                                color: cs.onPrimaryContainer,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              spec.model,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '$bands GHz  •  ${spec.maxTxPowerDbm.toStringAsFixed(0)} dBm  •  ${spec.antennaGainDbi.toStringAsFixed(1)} dBi',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () => Navigator.pop(context, spec),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Client Type Picker Dialog
// ============================================================================

class _ClientTypePickerDialog extends StatelessWidget {
  const _ClientTypePickerDialog();

  static final _types = [
    (ClientDeviceType.laptop, Icons.laptop_outlined, 'Laptop'),
    (ClientDeviceType.smartphone, Icons.smartphone_outlined, 'Smartphone'),
    (ClientDeviceType.tablet, Icons.tablet_outlined, 'Tablet'),
    (ClientDeviceType.iotSensor, Icons.sensors_outlined, 'IoT Sensor'),
    (ClientDeviceType.desktop, Icons.computer_outlined, 'Desktop'),
    (ClientDeviceType.smartTv, Icons.tv_outlined, 'Smart TV'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Choose Device Type'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 320,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
          ),
          itemCount: _types.length,
          itemBuilder: (_, i) {
            final (type, icon, label) = _types[i];
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context, type),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 28, color: const Color(0xFF009688)),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ============================================================================
// Zone type picker dialog
// ============================================================================

class _ZoneTypePickerDialog extends StatelessWidget {
  const _ZoneTypePickerDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Select Zone Type'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ZoneType.values.map((type) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: type.zoneColor.withAlpha(50),
                child: Icon(type.icon, color: type.zoneColor, size: 20),
              ),
              title: Text(type.label),
              subtitle: Text(
                type.description,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              onTap: () => Navigator.pop(context, type),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ============================================================================
// Live stats toolbar toggle button
// ============================================================================

class _LiveStatsToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final showPerfPanel = context.select((UIBloc b) => b.state.showPerfPanel);
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: showPerfPanel ? 'Hide live stats' : 'Show live stats',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () =>
            context.read<UIBloc>().add(const UIPerformancePanelToggled()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart_outlined,
                size: 16,
                color: showPerfPanel
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 5),
              Text(
                'Live Stats',
                style: TextStyle(
                  fontSize: 13,
                  color: showPerfPanel
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Live performance bottom panel
// ============================================================================

class _LivePerfPanel extends StatelessWidget {
  const _LivePerfPanel();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PerformanceCubit, PerformanceState>(
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        return SizedBox(
          height: 220,
          child: ColoredBox(
            color: cs.surfaceContainerLow,
            child: Column(
              children: [
                // Header strip
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bar_chart_outlined,
                        size: 13,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Performance',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (state.isComputing)
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: cs.primary,
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        tooltip: 'Hide live stats',
                        onPressed: () => context.read<UIBloc>().add(
                          const UIPerformancePanelToggled(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Body
                Expanded(
                  child:
                      state.performance == null ||
                          (state.performance!.perAp.isEmpty &&
                              state.performance!.perClient.isEmpty)
                      ? Center(
                          child: Text(
                            'Add APs and client devices to see live stats',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 240,
                              child: _CompactApList(
                                performance: state.performance!,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _CompactClientList(
                                performance: state.performance!,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Compact AP list (left side of live panel)
// ============================================================================

class _CompactApList extends StatelessWidget {
  const _CompactApList({required this.performance});
  final NetworkPerformance performance;

  static Color _barColor(double pct) {
    if (pct > 0.8) return Colors.red.shade400;
    if (pct > 0.6) return Colors.orange.shade400;
    return Colors.green.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final aps = performance.perAp.values.toList();
    if (aps.isEmpty) {
      return const Center(
        child: Text(
          'No APs',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      itemCount: aps.length,
      itemBuilder: (context, i) {
        final ap = aps[i];
        final pct = ap.utilisationPct;
        final barColor = _barColor(pct);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.router_outlined, size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ap.apName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${ap.clientIds.length}c',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: barColor.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ap.allocatedMbps > 0
                        ? '${ap.utilisedMbps.toStringAsFixed(0)}/'
                              '${ap.allocatedMbps.toStringAsFixed(0)}'
                        : '${ap.utilisedMbps.toStringAsFixed(0)} Mbps',
                    style: TextStyle(
                      fontSize: 10,
                      color: barColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Compact client list (right side of live panel)
// ============================================================================

class _CompactClientList extends StatelessWidget {
  const _CompactClientList({required this.performance});
  final NetworkPerformance performance;

  static Color _rssiColor(double rssi) {
    if (rssi >= -65) return Colors.green.shade600;
    if (rssi >= -75) return Colors.orange.shade600;
    if (rssi >= -85) return Colors.deepOrange.shade600;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final clients = performance.perClient.values.toList();
    if (clients.isEmpty) {
      return const Center(
        child: Text(
          'No clients',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final selectedId = context.watch<UIBloc>().state.selectedClientDeviceId;
    final surveyClients = context
        .watch<SurveyBloc>()
        .state
        .survey
        .clientDevices;
    final disabledIds = context
        .watch<PerformanceCubit>()
        .state
        .disabledClientIds;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      itemCount: clients.length,
      itemBuilder: (context, i) {
        final c = clients[i];
        final rssiColor = _rssiColor(c.rssiDbm);
        final apName = c.associatedApId != null
            ? (performance.perAp[c.associatedApId]?.apName ?? '—')
            : '—';
        final isSelected = selectedId == c.clientId;
        final isDisabled = disabledIds.contains(c.clientId);
        final device = surveyClients
            .where((d) => d.id == c.clientId)
            .firstOrNull;
        return Opacity(
          opacity: isDisabled ? 0.55 : 1.0,
          child: InkWell(
            onTap: () =>
                context.read<UIBloc>().add(UIClientDeviceSelected(c.clientId)),
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.amber.withValues(alpha: 0.12) : null,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(
                        color: Colors.amber.withValues(alpha: 0.4),
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  // ── Sim toggle ──────────────────────────────────────────
                  GestureDetector(
                    onTap: () => context
                        .read<PerformanceCubit>()
                        .toggleClientDisabled(c.clientId),
                    child: Tooltip(
                      message: isDisabled
                          ? 'Re-enable in simulation'
                          : 'Disable in simulation\n'
                                '(removes from air-time contention)',
                      child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Icon(
                          isDisabled ? Icons.wifi_off : Icons.wifi,
                          size: 13,
                          color: isDisabled
                              ? Colors.grey.shade500
                              : Colors.teal.shade600,
                        ),
                      ),
                    ),
                  ),
                  // ── Device icon ─────────────────────────────────────────
                  Icon(
                    Icons.devices_outlined,
                    size: 12,
                    color: isSelected
                        ? Colors.amber.shade600
                        : (isDisabled ? Colors.grey.shade500 : null),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: Text(
                      c.clientName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: isDisabled ? cs.onSurfaceVariant : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      apName,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // ── RSSI badge ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: rssiColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: rssiColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      c.rssiDbm.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: rssiColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // ── Speed: effective (bold) + bottleneck indicator ──────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDisabled)
                        Text(
                          'OFF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                          ),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${c.effectiveMbps.toStringAsFixed(0)} Mbps',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c.isWanLimited
                                    ? Colors.orange.shade700
                                    : null,
                              ),
                            ),
                            if (c.isWanLimited) ...[
                              const SizedBox(width: 3),
                              Tooltip(
                                message:
                                    'WAN limited — RF could reach '
                                    '${c.rfMaxMbps.toStringAsFixed(0)} Mbps.\n'
                                    'Increase WAN bandwidth to see improvement.',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: Colors.orange.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'WAN',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      Text(
                        c.isWanLimited
                            ? 'RF ${c.rfMaxMbps.toStringAsFixed(0)} / '
                                  'PHY ${c.phyRateMbps.toStringAsFixed(0)}'
                            : 'PHY max ${c.phyRateMbps.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // ── Zone badge (only when zones affect this path) ───────
                  if (c.activeZones.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Zones: ${c.activeZones.join(', ')}\n'
                          'Signal modifier: '
                          '${c.zoneModifierDb >= 0 ? '+' : ''}'
                          '${c.zoneModifierDb.toStringAsFixed(1)} dBm',
                      child: Icon(
                        c.zoneModifierDb >= 0
                            ? Icons.trending_up
                            : Icons.warning_amber_rounded,
                        size: 11,
                        color: c.zoneModifierDb >= 0
                            ? Colors.green.shade600
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                  // ── Band chip ───────────────────────────────────────────
                  if (device != null) ...[
                    const SizedBox(width: 5),
                    _BandChip(
                      preferredBand: device.preferredBand,
                      onBandSelected: (band) {
                        final updated = band == null
                            ? device.copyWith(clearPreferredBand: true)
                            : device.copyWith(preferredBand: band);
                        context.read<SurveyBloc>().add(
                          SurveyClientDeviceUpdated(updated),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Band chip — tap to change the preferred band for a client
// ============================================================================

class _BandChip extends StatelessWidget {
  const _BandChip({required this.preferredBand, required this.onBandSelected});

  final WiFiBand? preferredBand;
  final void Function(WiFiBand?) onBandSelected;

  @override
  Widget build(BuildContext context) {
    final label = preferredBand?.label ?? 'Auto';
    final color = preferredBand == null
        ? Colors.blueGrey
        : (preferredBand == WiFiBand.ghz24
              ? Colors.teal
              : preferredBand == WiFiBand.ghz5
              ? Colors.indigo
              : Colors.deepPurple);

    return PopupMenuButton<WiFiBand?>(
      tooltip: 'Change band',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 20),
      onSelected: onBandSelected,
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('Auto (best throughput)')),
        for (final b in WiFiBand.values)
          PopupMenuItem(value: b, child: Text(b.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 10, color: color),
          ],
        ),
      ),
    );
  }
}
