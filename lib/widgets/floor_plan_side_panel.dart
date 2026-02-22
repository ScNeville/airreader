import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/blocs/ui_bloc.dart';
import 'package:airreader/models/wall.dart';
import 'package:airreader/widgets/material_picker_widget.dart';

/// Right-hand properties panel for the floor-plan editor.
///
/// Shows:
///   • Tool buttons (Select / Draw Wall)
///   • Scale info
///   • Draw-wall settings (material + default thickness) when draw tool active
///   • Selected wall properties (material, thickness, attenuation, delete)
class FloorPlanSidePanel extends StatelessWidget {
  const FloorPlanSidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UIBloc, UIState>(
      builder: (context, ui) {
        return Container(
          width: 280,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ToolSection(activeTool: ui.activeTool),
              const Divider(height: 1),
              if (ui.activeTool == EditorTool.drawWall)
                _DrawWallSettings(material: ui.drawingMaterial)
              else if (ui.selectedWallId != null)
                _SelectedWallPanel(wallId: ui.selectedWallId!),
              if (ui.activeTool == EditorTool.select &&
                  ui.selectedWallId == null)
                _ScaleInfoPanel(),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tool selector
// ---------------------------------------------------------------------------

class _ToolSection extends StatelessWidget {
  const _ToolSection({required this.activeTool});
  final EditorTool activeTool;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tools',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ToolButton(
                icon: Icons.pan_tool_outlined,
                label: 'Select',
                active: activeTool == EditorTool.select,
                onTap: () => context.read<UIBloc>().add(
                  const UIEditorToolChanged(EditorTool.select),
                ),
              ),
              const SizedBox(width: 8),
              _ToolButton(
                icon: Icons.edit_outlined,
                label: 'Draw Wall',
                active: activeTool == EditorTool.drawWall,
                onTap: () => context.read<UIBloc>().add(
                  const UIEditorToolChanged(EditorTool.drawWall),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            activeTool == EditorTool.drawWall
                ? 'Click to set start point, click again to finish wall.'
                : 'Click a wall to select and edit it.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? colorScheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: active
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Draw-wall settings
// ---------------------------------------------------------------------------

class _DrawWallSettings extends StatelessWidget {
  const _DrawWallSettings({required this.material});
  final WallMaterial material;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wall Material',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          MaterialPickerWidget(
            selected: material,
            onSelected: (m) =>
                context.read<UIBloc>().add(UIDrawingMaterialChanged(m)),
          ),
          const SizedBox(height: 12),
          _AttenuationPreview(material: material),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selected wall panel
// ---------------------------------------------------------------------------

class _SelectedWallPanel extends StatelessWidget {
  const _SelectedWallPanel({required this.wallId});
  final String wallId;

  @override
  Widget build(BuildContext context) {
    final walls = context.select((SurveyBloc b) => b.state.survey.walls);
    final wall =
        walls.cast<dynamic>().firstWhere(
              (w) => (w as dynamic).id == wallId,
              orElse: () => null,
            )
            as dynamic;

    if (wall == null) return const SizedBox.shrink();

    final outerMaterial = wall.material as WallMaterial;
    final innerMaterial = wall.innerMaterial as WallMaterial?;
    final classification = wall.classification as WallClassification;

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Wall Properties',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: Theme.of(context).colorScheme.error,
                  tooltip: 'Delete wall',
                  onPressed: () {
                    context.read<SurveyBloc>().add(SurveyWallRemoved(wallId));
                    context.read<UIBloc>().add(const UIWallSelected(null));
                  },
                ),
              ],
            ),

            // ── Classification toggle ─────────────────────────────────────
            _ClassificationToggle(
              value: classification,
              onChanged: (c) {
                context.read<SurveyBloc>().add(
                  SurveyWallUpdated(
                    (wall as dynamic).copyWith(classification: c),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // ── Outer / primary material ────────────────────────────────────
            _SectionLabel('Outer Material'),
            const SizedBox(height: 6),
            MaterialPickerWidget(
              selected: outerMaterial,
              onSelected: (m) {
                context.read<SurveyBloc>().add(
                  SurveyWallUpdated((wall as dynamic).copyWith(material: m)),
                );
              },
            ),

            // ── Inner lining material ────────────────────────────────────────
            const SizedBox(height: 16),
            _SectionLabel(
              classification == WallClassification.exterior
                  ? 'Inner Lining (e.g. drywall on brick)'
                  : 'Inner Lining (optional second layer)',
            ),
            const SizedBox(height: 6),
            _InnerMaterialPicker(
              selected: innerMaterial,
              onSelected: (m) {
                context.read<SurveyBloc>().add(
                  SurveyWallUpdated(
                    (wall as dynamic).copyWith(innerMaterial: m),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
            _ThicknessInput(wall: wall),
            const SizedBox(height: 12),
            _AttenuationPreview(
              material: outerMaterial,
              innerMaterial: innerMaterial,
            ),
            if (outerMaterial == WallMaterial.custom) ...[
              const SizedBox(height: 12),
              _CustomLossInputs(wall: wall),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small section label helper
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Classification toggle (Exterior / Interior / Unclassified)
// ---------------------------------------------------------------------------

class _ClassificationToggle extends StatelessWidget {
  const _ClassificationToggle({required this.value, required this.onChanged});

  final WallClassification value;
  final ValueChanged<WallClassification> onChanged;

  static const _items = [
    (WallClassification.exterior, 'Exterior', Color(0xFFE65100)),
    (WallClassification.interior, 'Interior', Color(0xFF1565C0)),
    (WallClassification.unclassified, '?', Color(0xFF9E9E9E)),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _items.map((item) {
        final (cls, label, color) = item;
        final selected = value == cls;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(cls),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.18)
                    : Colors.transparent,
                border: Border.all(
                  color: selected ? color : color.withValues(alpha: 0.3),
                  width: selected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected ? color : color.withValues(alpha: 0.6),
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Inner lining material picker (None + all materials)
// ---------------------------------------------------------------------------

class _InnerMaterialPicker extends StatelessWidget {
  const _InnerMaterialPicker({
    required this.selected,
    required this.onSelected,
  });

  /// null means "no inner lining" (single-layer wall).
  final WallMaterial? selected;

  /// Called with null when the user chooses "None".
  final ValueChanged<WallMaterial?> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final noneSelected = selected == null;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // ── None chip ──────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => onSelected(null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: noneSelected ? cs.surfaceContainerHighest : cs.surface,
              border: Border.all(
                color: noneSelected
                    ? cs.outline
                    : cs.outline.withValues(alpha: 0.35),
                width: noneSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.layers_clear_outlined,
                  size: 12,
                  color: noneSelected
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  'None',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: noneSelected
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.55),
                    fontWeight: noneSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Material chips ────────────────────────────────────────────────
        ...WallMaterial.values.map((m) {
          final isSelected = m == selected;
          final matColor = Color(m.definition.color.toARGB32());
          return Tooltip(
            message:
                '${m.definition.description}\n'
                '2.4 GHz: ${m.loss24GhzDb} dB  •  '
                '5 GHz: ${m.loss5GhzDb} dB  •  '
                '6 GHz: ${m.loss6GhzDb} dB',
            preferBelow: false,
            child: GestureDetector(
              onTap: () => onSelected(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? matColor.withValues(alpha: 0.25)
                      : cs.surface,
                  border: Border.all(
                    color: isSelected
                        ? matColor
                        : cs.outline.withValues(alpha: 0.35),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: matColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      m.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Thickness input
// ---------------------------------------------------------------------------

class _ThicknessInput extends StatefulWidget {
  const _ThicknessInput({required this.wall});
  final dynamic wall;

  @override
  State<_ThicknessInput> createState() => _ThicknessInputState();
}

class _ThicknessInputState extends State<_ThicknessInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.wall.thicknessCm.toStringAsFixed(1),
    );
  }

  @override
  void didUpdateWidget(_ThicknessInput old) {
    super.didUpdateWidget(old);
    final newVal = widget.wall.thicknessCm.toStringAsFixed(1);
    if (_ctrl.text != newVal) _ctrl.text = newVal;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Thickness (cm)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 70,
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: Theme.of(context).textTheme.bodySmall,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) {
              final cm = double.tryParse(v);
              if (cm != null && cm > 0) {
                context.read<SurveyBloc>().add(
                  SurveyWallUpdated(widget.wall.copyWith(thicknessCm: cm)),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Custom loss inputs (only shown for Custom material)
// ---------------------------------------------------------------------------

class _CustomLossInputs extends StatelessWidget {
  const _CustomLossInputs({required this.wall});
  final dynamic wall;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Attenuation (dB)',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        _LossField(
          label: '2.4 GHz',
          value: wall.customLoss24GhzDb ?? 5.0,
          onChanged: (v) => context.read<SurveyBloc>().add(
            SurveyWallUpdated(wall.copyWith(customLoss24GhzDb: v)),
          ),
        ),
        const SizedBox(height: 4),
        _LossField(
          label: '5 GHz',
          value: wall.customLoss5GhzDb ?? 8.0,
          onChanged: (v) => context.read<SurveyBloc>().add(
            SurveyWallUpdated(wall.copyWith(customLoss5GhzDb: v)),
          ),
        ),
        const SizedBox(height: 4),
        _LossField(
          label: '6 GHz',
          value: wall.customLoss6GhzDb ?? 10.0,
          onChanged: (v) => context.read<SurveyBloc>().add(
            SurveyWallUpdated(wall.copyWith(customLoss6GhzDb: v)),
          ),
        ),
      ],
    );
  }
}

class _LossField extends StatefulWidget {
  const _LossField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_LossField> createState() => _LossFieldState();
}

class _LossFieldState extends State<_LossField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toStringAsFixed(1));
  }

  @override
  void didUpdateWidget(_LossField old) {
    super.didUpdateWidget(old);
    final newVal = widget.value.toStringAsFixed(1);
    if (_ctrl.text != newVal) _ctrl.text = newVal;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: Theme.of(context).textTheme.bodySmall,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
              suffixText: 'dB',
            ),
            onSubmitted: (v) {
              final db = double.tryParse(v);
              if (db != null && db >= 0) widget.onChanged(db);
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Attenuation preview
// ---------------------------------------------------------------------------

class _AttenuationPreview extends StatelessWidget {
  const _AttenuationPreview({required this.material, this.innerMaterial});
  final WallMaterial material;
  final WallMaterial? innerMaterial;

  @override
  Widget build(BuildContext context) {
    if (material == WallMaterial.custom) return const SizedBox.shrink();

    final has2 = innerMaterial != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            has2
                ? 'Combined Signal Loss (both layers)'
                : 'Signal Loss per Wall',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _BandRow(
            label: '2.4 GHz',
            db: material.loss24GhzDb + (innerMaterial?.loss24GhzDb ?? 0),
            color: Colors.green,
          ),
          const SizedBox(height: 3),
          _BandRow(
            label: '5 GHz',
            db: material.loss5GhzDb + (innerMaterial?.loss5GhzDb ?? 0),
            color: Colors.blue,
          ),
          const SizedBox(height: 3),
          _BandRow(
            label: '6 GHz',
            db: material.loss6GhzDb + (innerMaterial?.loss6GhzDb ?? 0),
            color: Colors.purple,
          ),
          if (has2) ...[
            const SizedBox(height: 6),
            Text(
              '${material.label} + ${innerMaterial!.label}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              material.definition.impactSummary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({required this.label, required this.db, required this.color});

  final String label;
  final double db;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 55,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Text(
          '${db.toStringAsFixed(1)} dB',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Scale info (shown when select tool, nothing selected)
// ---------------------------------------------------------------------------

class _ScaleInfoPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final floorPlan = context.select(
      (SurveyBloc b) => b.state.survey.floorPlan,
    );
    if (floorPlan == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Floor Plan Scale',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${floorPlan.pixelsPerMeter.toStringAsFixed(1)} px/m',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${floorPlan.realWidthMeters.toStringAsFixed(1)} m × '
              '${floorPlan.realHeightMeters.toStringAsFixed(1)} m',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
