import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/blocs/ui_bloc.dart';
import 'package:airreader/models/environment_zone.dart';

class ZonesScreen extends StatelessWidget {
  const ZonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final zones = context.select((SurveyBloc b) => b.state.survey.zones);

    return Row(
      children: [
        // Left panel – zone list
        SizedBox(width: 280, child: _ZoneList(zones: zones)),
        const VerticalDivider(width: 1),
        // Right panel – zone detail
        Expanded(child: _ZoneDetail(zones: zones)),
      ],
    );
  }
}

// ============================================================================
// Zone list
// ============================================================================

class _ZoneList extends StatelessWidget {
  const _ZoneList({required this.zones});
  final List<EnvironmentZone> zones;

  @override
  Widget build(BuildContext context) {
    final selectedId = context.select((UIBloc b) => b.state.selectedZoneId);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Row(
            children: [
              Text(
                'Environment Zones',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Go to floor plan to draw a zone',
                child: IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => _goDrawZone(context),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (zones.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.layers_outlined,
                    size: 40,
                    color: cs.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No zones yet',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Draw a Zone'),
                    onPressed: () => _goDrawZone(context),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: zones.length,
              itemBuilder: (context, i) {
                final zone = zones[i];
                final selected = zone.id == selectedId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: zone.type.zoneColor.withAlpha(50),
                    child: Icon(
                      zone.type.icon,
                      color: zone.type.zoneColor,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    zone.name.isNotEmpty ? zone.name : zone.type.label,
                    style: TextStyle(
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: zone.name.isNotEmpty
                      ? Text(
                          zone.type.label,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  selected: selected,
                  selectedTileColor: cs.primary.withValues(alpha: 0.08),
                  onTap: () =>
                      context.read<UIBloc>().add(UIZoneSelected(zone.id)),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    tooltip: 'Remove zone',
                    onPressed: () {
                      context.read<SurveyBloc>().add(
                        SurveyZoneRemoved(zone.id),
                      );
                      if (selectedId == zone.id) {
                        context.read<UIBloc>().add(const UIZoneSelected(null));
                      }
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _goDrawZone(BuildContext context) {
    // Navigate to floor plan screen and show zone type picker
    context.read<UIBloc>().add(
      const UINavSectionSelected(NavSection.floorPlan),
    );
  }
}

// ============================================================================
// Zone detail
// ============================================================================

class _ZoneDetail extends StatelessWidget {
  const _ZoneDetail({required this.zones});
  final List<EnvironmentZone> zones;

  @override
  Widget build(BuildContext context) {
    final selectedId = context.select((UIBloc b) => b.state.selectedZoneId);
    final EnvironmentZone? zone = selectedId == null
        ? null
        : zones.where((z) => z.id == selectedId).firstOrNull;

    if (zone == null) {
      return Center(
        child: Text(
          zones.isEmpty
              ? 'Draw zones on the floor plan to define signal environments.'
              : 'Select a zone to view its details.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return _ZoneEditor(zone: zone);
  }
}

// ============================================================================
// Zone editor (detail panel)
// ============================================================================

class _ZoneEditor extends StatefulWidget {
  const _ZoneEditor({required this.zone});
  final EnvironmentZone zone;

  @override
  State<_ZoneEditor> createState() => _ZoneEditorState();
}

class _ZoneEditorState extends State<_ZoneEditor> {
  late final TextEditingController _nameCtrl;
  late ZoneType _zoneType;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.zone.name);
    _zoneType = widget.zone.type;
  }

  @override
  void didUpdateWidget(_ZoneEditor old) {
    super.didUpdateWidget(old);
    if (old.zone.id != widget.zone.id) {
      _nameCtrl.text = widget.zone.name;
      _zoneType = widget.zone.type;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    context.read<SurveyBloc>().add(
      SurveyZoneUpdated(
        widget.zone.copyWith(name: _nameCtrl.text, type: _zoneType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_zoneType.icon, color: _zoneType.zoneColor, size: 28),
              const SizedBox(width: 12),
              Text(
                'Zone Details',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Name field
          Text('Name', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              hintText: 'Optional zone name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _save(),
            onEditingComplete: _save,
          ),
          const SizedBox(height: 20),

          // Zone type picker
          Text('Zone Type', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ZoneType>(
                value: _zoneType,
                isDense: true,
                isExpanded: true,
                items: ZoneType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(t.icon, color: t.zoneColor, size: 18),
                        const SizedBox(width: 10),
                        Text(t.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (t) {
                  if (t == null) return;
                  setState(() => _zoneType = t);
                  Future.microtask(() => _save());
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _zoneType.description,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),

          // RF modifier summary card
          _RfModifierCard(type: _zoneType),
          const SizedBox(height: 24),

          // Save button
          FilledButton(onPressed: _save, child: const Text('Save Changes')),
        ],
      ),
    );
  }
}

// ============================================================================
// RF modifier info card
// ============================================================================

class _RfModifierCard extends StatelessWidget {
  const _RfModifierCard({required this.type});
  final ZoneType type;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String fmtDb(double v) =>
        v >= 0 ? '+${v.toStringAsFixed(1)} dB' : '${v.toStringAsFixed(1)} dB';
    Color colorForValue(double v) => v > 0
        ? const Color(0xFF43A047)
        : v < 0
        ? const Color(0xFFE53935)
        : cs.onSurface.withValues(alpha: 0.5);

    final rows = [
      ('All bands (base)', type.dbmAll),
      ('2.4 GHz (extra)', type.dbm24),
      ('5 GHz (extra)', type.dbm5),
      ('6 GHz (extra)', type.dbm6),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.signal_cellular_alt_outlined,
                size: 16,
                color: cs.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Signal Modifiers',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.$1, style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    fmtDb(r.$2),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorForValue(r.$2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
