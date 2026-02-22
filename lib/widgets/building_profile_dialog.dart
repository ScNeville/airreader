// lib/widgets/building_profile_dialog.dart
// Dialog that lets the user:
//  • Set the building's framing type (timber/steel/etc.)
//  • Set the default exterior wall material
//  • Set the default interior partition material
//  • Apply those materials to all existing classified walls in bulk

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/models/building_profile.dart';
import 'package:airreader/models/wall.dart';

/// Show the building-profile configuration dialog.
Future<void> showBuildingProfileDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => BlocProvider.value(
      value: context.read<SurveyBloc>(),
      child: const _BuildingProfileDialog(),
    ),
  );
}

class _BuildingProfileDialog extends StatefulWidget {
  const _BuildingProfileDialog();

  @override
  State<_BuildingProfileDialog> createState() => _BuildingProfileDialogState();
}

class _BuildingProfileDialogState extends State<_BuildingProfileDialog> {
  late BuildingProfile _profile;
  bool _applyToWalls = true;

  @override
  void initState() {
    super.initState();
    _profile = context.read<SurveyBloc>().state.survey.buildingProfile;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final survey = context.read<SurveyBloc>().state.survey;
    final extCount = survey.walls
        .where((w) => w.classification == WallClassification.exterior)
        .length;
    final intCount = survey.walls
        .where((w) => w.classification == WallClassification.interior)
        .length;
    final hasClassified = extCount > 0 || intCount > 0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.domain_outlined, color: cs.primary, size: 22),
          const SizedBox(width: 10),
          const Text('Building Profile'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoText(
                context,
                'Set the construction type for this building. These defaults '
                'are applied automatically when walls are detected or manually '
                'via "Apply to Walls" below.',
              ),
              const SizedBox(height: 20),

              // ── Framing ────────────────────────────────────────────────────
              _SectionHeader('Structural Framing'),
              const SizedBox(height: 8),
              _framingGrid(context),
              const SizedBox(height: 20),

              // ── Exterior wall material ──────────────────────────────────────
              _SectionHeader('Exterior Wall — Outer Face'),
              const SizedBox(height: 4),
              _infoText(
                context,
                'The outer structural layer of perimeter walls '
                '(e.g. brick, concrete block, stone).',
              ),
              const SizedBox(height: 8),
              _MaterialDropdown(
                value: _profile.exteriorMaterial,
                onChanged: (m) => setState(
                  () => _profile = _profile.copyWith(exteriorMaterial: m),
                ),
                exclude: const [],
              ),
              const SizedBox(height: 20),

              // ── Exterior wall inner lining ──────────────────────────────────
              _SectionHeader('Exterior Wall — Inner Lining'),
              const SizedBox(height: 4),
              _infoText(
                context,
                'The inner face of exterior walls. A signal crossing from '
                'outside must penetrate both layers '
                '(e.g. brick outer + drywall inner).',
              ),
              const SizedBox(height: 8),
              _MaterialDropdown(
                value: _profile.exteriorInnerMaterial,
                onChanged: (m) => setState(
                  () => _profile = _profile.copyWith(exteriorInnerMaterial: m),
                ),
                exclude: const [],
              ),
              const SizedBox(height: 20),

              // ── Interior wall material ──────────────────────────────────────
              _SectionHeader('Interior Partition Material'),
              const SizedBox(height: 4),
              _infoText(
                context,
                'Applied to all internal dividing walls. Usually determined '
                'by the framing type.',
              ),
              const SizedBox(height: 8),
              _MaterialDropdown(
                value: _profile.interiorMaterial,
                onChanged: (m) => setState(
                  () => _profile = _profile.copyWith(interiorMaterial: m),
                ),
                exclude: const [],
              ),

              // ── Apply-to-walls toggle (only shown when there are classified walls) ──
              if (hasClassified) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apply to existing walls'),
                  subtitle: Text(
                    'Updates materials on $extCount exterior and '
                    '$intCount interior walls already on the floor plan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  value: _applyToWalls,
                  onChanged: (v) => setState(() => _applyToWalls = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  void _save() {
    context.read<SurveyBloc>().add(
      SurveyBuildingProfileSet(_profile, applyToWalls: _applyToWalls),
    );
    Navigator.pop(context);
  }

  // ── Framing grid ──────────────────────────────────────────────────────────

  Widget _framingGrid(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FramingType.values.map((f) {
        final selected = _profile.framingType == f;
        return _FramingChip(
          value: f,
          selected: selected,
          onTap: () {
            setState(() {
              _profile = _profile.copyWith(
                framingType: f,
                // Auto-suggest interior material based on framing
                interiorMaterial: f.defaultInteriorMaterial,
              );
            });
          },
        );
      }).toList(),
    );
  }
}

// ============================================================================
// Detect walls progress/result sheet
// ============================================================================

/// Shows a bottom sheet or dialog while wall detection is running, then
/// confirms the result before committing to the survey.
Future<void> showWallDetectionSheet(
  BuildContext context, {
  required Future<List<dynamic>> detectionFuture,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (ctx) => BlocProvider.value(
      value: context.read<SurveyBloc>(),
      child: _WallDetectionSheet(detectionFuture: detectionFuture),
    ),
  );
}

class _WallDetectionSheet extends StatefulWidget {
  const _WallDetectionSheet({required this.detectionFuture});
  final Future<List<dynamic>> detectionFuture;

  @override
  State<_WallDetectionSheet> createState() => _WallDetectionSheetState();
}

class _WallDetectionSheetState extends State<_WallDetectionSheet> {
  List<dynamic>? _walls;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.detectionFuture
        .then((walls) {
          if (mounted) setState(() => _walls = walls);
        })
        .catchError((e) {
          if (mounted) setState(() => _error = e.toString());
        });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_error != null) {
      return _SheetFrame(
        title: 'Detection Failed',
        icon: Icons.error_outline,
        iconColor: cs.error,
        content: Text(_error!, style: TextStyle(color: cs.error)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    if (_walls == null) {
      return _SheetFrame(
        title: 'Detecting Walls…',
        icon: Icons.search,
        iconColor: cs.primary,
        content: const LinearProgressIndicator(),
        actions: const [],
      );
    }

    // Result
    final walls = _walls!;
    final extCount = walls
        .where(
          (w) => (w as dynamic).classification == WallClassification.exterior,
        )
        .length;
    final intCount = walls.length - extCount;

    if (walls.isEmpty) {
      return _SheetFrame(
        title: 'No Walls Found',
        icon: Icons.search_off_outlined,
        iconColor: cs.tertiary,
        content: Text(
          'No wall lines could be detected in this floor plan.\n\n'
          'Tips:\n'
          '• Use a high-contrast black-on-white floor plan image\n'
          '• Make sure walls are drawn as solid lines\n'
          '• Try adjusting scale calibration first',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return _SheetFrame(
      title: 'Walls Detected',
      icon: Icons.check_circle_outline,
      iconColor: Colors.green.shade600,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatRow('Total walls detected', '${walls.length}'),
          _StatRow('Exterior walls', '$extCount  (assigned exterior material)'),
          _StatRow('Interior walls', '$intCount  (assigned interior material)'),
          const SizedBox(height: 12),
          Text(
            'Existing manually-drawn walls will be replaced. '
            'You can adjust individual wall materials afterwards.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () {
            // Cast back to List<WallSegment>
            context.read<SurveyBloc>().add(
              SurveyWallsBulkReplaced(walls.cast()),
            );
            Navigator.pop(context);
          },
          child: const Text('Apply Walls'),
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.content,
    required this.actions,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
          const SizedBox(height: 20),
          if (actions.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children:
                  actions.expand((w) => [w, const SizedBox(width: 8)]).toList()
                    ..removeLast(),
            ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Re-usable sub-widgets
// ============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

Widget _infoText(BuildContext context, String text) {
  return Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    ),
  );
}

class _FramingChip extends StatelessWidget {
  const _FramingChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final FramingType value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          value.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? cs.onPrimaryContainer : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _MaterialDropdown extends StatelessWidget {
  const _MaterialDropdown({
    required this.value,
    required this.onChanged,
    required this.exclude,
  });

  final WallMaterial value;
  final ValueChanged<WallMaterial> onChanged;
  final List<WallMaterial> exclude;

  @override
  Widget build(BuildContext context) {
    final items = WallMaterial.values
        .where((m) => !exclude.contains(m))
        .toList();

    return DropdownButtonFormField<WallMaterial>(
      initialValue: value,
      isDense: true,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items
          .map(
            (m) => DropdownMenuItem(
              value: m,
              child: Text(m.label, style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
      onChanged: (m) {
        if (m != null) onChanged(m);
      },
    );
  }
}
