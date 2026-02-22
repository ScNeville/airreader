import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/simulation_cubit.dart';
import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/blocs/ui_bloc.dart';
import 'package:airreader/models/access_point.dart';
import 'package:airreader/widgets/canvas/floor_plan_canvas.dart';
import 'package:airreader/widgets/canvas/heat_map_painter.dart';

/// Dedicated Heat Map view with band selector, opacity slider, and dBm legend.
///
/// Always shows the heat map overlay on. Uses the same [FloorPlanCanvas] but
/// with expanded controls in a floating control panel.
class HeatMapScreen extends StatelessWidget {
  const HeatMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final floorPlan = context.select(
      (SurveyBloc b) => b.state.survey.floorPlan,
    );

    if (floorPlan == null) {
      return const _NoFloorPlanView();
    }

    return const _HeatMapLayout();
  }
}

// ============================================================================
// Layout
// ============================================================================

class _HeatMapLayout extends StatelessWidget {
  const _HeatMapLayout();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Canvas fills the whole space.
        const _HeatMapCanvas(),

        // Floating control panel – top-right.
        Positioned(top: 12, right: 12, child: const _ControlPanel()),

        // Floating legend – bottom-right.
        Positioned(bottom: 16, right: 12, child: const _Legend()),
      ],
    );
  }
}

// ============================================================================
// Canvas bridge
// ============================================================================

class _HeatMapCanvas extends StatelessWidget {
  const _HeatMapCanvas();

  @override
  Widget build(BuildContext context) {
    final survey = context.watch<SurveyBloc>().state.survey;
    final ui = context.watch<UIBloc>().state;
    final sim = context.watch<SimulationCubit>().state;

    if (survey.floorPlan == null) return const SizedBox.shrink();

    // Heat map is always on in this screen; use current opacity & band.
    return FloorPlanCanvas(
      floorPlan: survey.floorPlan!,
      walls: survey.walls,
      accessPoints: survey.accessPoints,
      clients: survey.clientDevices,
      zones: survey.zones,
      selectedWallId: null,
      selectedApId: null,
      selectedClientId: null,
      selectedZoneId: null,
      activeTool: EditorTool.select, // read-only in heat map view
      drawingMaterial: ui.drawingMaterial,
      zoneTypeBeingDrawn: null,
      signalMap: sim.signalMap,
      showHeatMap: true,
      activeBand: ui.activeBand,
      heatMapOpacity: ui.heatMapOpacity,
      onWallAdded: (_) {},
      onWallSelected: (_) {},
      onApPlaced: (_, _) {},
      onApMoved: (_, _, _) {},
      onApSelected: (_) {},
      onClientPlaced: (_, _) {},
      onClientMoved: (_, _, _) {},
      onClientSelected: (_) {},
      onZoneAdded: (_) {},
      onZoneSelected: (_) {},
    );
  }
}

// ============================================================================
// Floating control panel
// ============================================================================

class _ControlPanel extends StatelessWidget {
  const _ControlPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeBand = context.select((UIBloc b) => b.state.activeBand);
    final opacity = context.select((UIBloc b) => b.state.heatMapOpacity);
    final isComputing = context.select(
      (SimulationCubit c) => c.state.isComputing,
    );
    final hasMap = context.select(
      (SimulationCubit c) => c.state.signalMap != null,
    );

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: cs.surfaceContainerHigh.withValues(alpha: 0.96),
      child: SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.thermostat_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Heat Map',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (isComputing)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  else if (!hasMap)
                    Tooltip(
                      message: 'Place APs on the floor plan to compute',
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: cs.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Band selector
              Text(
                'Frequency Band',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _PanelBandChip(label: 'Best', band: null, active: activeBand),
                  const SizedBox(width: 4),
                  _PanelBandChip(
                    label: '2.4 GHz',
                    band: WiFiBand.ghz24,
                    active: activeBand,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _PanelBandChip(
                    label: '5 GHz',
                    band: WiFiBand.ghz5,
                    active: activeBand,
                  ),
                  const SizedBox(width: 4),
                  _PanelBandChip(
                    label: '6 GHz',
                    band: WiFiBand.ghz6,
                    active: activeBand,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Opacity
              Text(
                'Opacity  ${(opacity * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Slider(
                value: opacity,
                min: 0.1,
                max: 1.0,
                divisions: 18,
                onChanged: (v) =>
                    context.read<UIBloc>().add(UIHeatMapOpacityChanged(v)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelBandChip extends StatelessWidget {
  const _PanelBandChip({
    required this.label,
    required this.band,
    required this.active,
  });
  final String label;
  final WiFiBand? band;
  final WiFiBand? active;

  @override
  Widget build(BuildContext context) {
    final selected = band == active;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            context.read<UIBloc>().add(UIActiveBandSet(selected ? null : band)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? cs.onPrimaryContainer
                  : cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Legend
// ============================================================================

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(10),
      color: cs.surfaceContainerHigh.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Signal Strength',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            ...kHeatMapScale.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: entry.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cs.onSurface.withValues(alpha: 0.2),
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No signal',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
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
// No floor plan
// ============================================================================

class _NoFloorPlanView extends StatelessWidget {
  const _NoFloorPlanView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.thermostat_outlined,
            size: 64,
            color: cs.primary.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'No Floor Plan',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Import a floor plan and place APs to view the heat map.',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
