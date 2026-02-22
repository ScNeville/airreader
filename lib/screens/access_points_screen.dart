import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/blocs/ui_bloc.dart';
import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/ap_library.dart';

/// Full-screen Access Points management view (NavSection.accessPoints).
class AccessPointsScreen extends StatelessWidget {
  const AccessPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final aps = context.select((SurveyBloc b) => b.state.survey.accessPoints);
    final selectedId = context.select(
      (UIBloc b) => b.state.selectedAccessPointId,
    );

    return Row(
      children: [
        // ── Left panel: AP list (280 px) ──────────────────────────────────
        SizedBox(
          width: 280,
          child: _ApListPanel(aps: aps, selectedId: selectedId),
        ),
        const VerticalDivider(width: 1),
        // ── Right panel: AP config ────────────────────────────────────────
        Expanded(
          child: selectedId == null
              ? const _EmptyDetailView()
              : Builder(
                  builder: (context) {
                    final ap = aps.where((a) => a.id == selectedId).firstOrNull;
                    if (ap == null) return const _EmptyDetailView();
                    return _ApDetailPanel(ap: ap);
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================================
// Left — AP list
// ============================================================================

class _ApListPanel extends StatelessWidget {
  const _ApListPanel({required this.aps, required this.selectedId});
  final List<AccessPoint> aps;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header + Add button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Text(
                'Access Points',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _AddApButton(),
            ],
          ),
        ),
        const Divider(height: 1),

        // AP list / empty state
        Expanded(
          child: aps.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.router_outlined,
                        size: 40,
                        color: cs.onSurface.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No APs placed yet',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Go to Floor Plan → Add AP',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: aps.length,
                  itemBuilder: (_, i) {
                    final ap = aps[i];
                    final selected = ap.id == selectedId;
                    return ListTile(
                      dense: true,
                      selected: selected,
                      selectedTileColor: cs.primaryContainer,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: selected
                            ? cs.primary
                            : cs.surfaceContainerHigh,
                        child: Icon(
                          Icons.wifi,
                          size: 16,
                          color: selected
                              ? cs.onPrimary
                              : cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      title: Text(
                        '${ap.brand} ${ap.model}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        _bandSummary(ap),
                        style: const TextStyle(fontSize: 11),
                      ),
                      onTap: () => context.read<UIBloc>().add(
                        UIAccessPointSelected(ap.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _bandSummary(AccessPoint ap) {
    final active = ap.bands.where((b) => b.enabled).map((b) => b.band.label);
    return active.isEmpty ? 'All bands disabled' : active.join('  ·  ');
  }
}

// ============================================================================
// "Add AP" button — activates placeAP from the floor plan
// ============================================================================

class _AddApButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.add, size: 16),
      label: const Text('Add AP'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      onPressed: () async {
        final spec = await showDialog<ApSpec>(
          context: context,
          builder: (_) => const _ApPickerDialog(),
        );
        if (spec == null || !context.mounted) return;
        // Switch to floor plan and activate place-AP mode
        context.read<UIBloc>()
          ..add(UIApBeingPlacedSpecChanged(spec))
          ..add(const UINavSectionSelected(NavSection.floorPlan));
      },
    );
  }
}

// ============================================================================
// Right — AP detail / config
// ============================================================================

class _ApDetailPanel extends StatelessWidget {
  const _ApDetailPanel({required this.ap});
  final AccessPoint ap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ─────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cs.primaryContainer,
                child: Icon(Icons.wifi, color: cs.onPrimaryContainer, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ap.model,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      ap.brand,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.55),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove AP',
                color: cs.error,
                onPressed: () {
                  context.read<SurveyBloc>().add(
                    SurveyAccessPointRemoved(ap.id),
                  );
                  context.read<UIBloc>().add(const UIAccessPointSelected(null));
                },
              ),
            ],
          ),

          const SizedBox(height: 8),
          _InfoRow(
            'Antenna Gain',
            '${ap.antennaGainDbi.toStringAsFixed(1)} dBi',
          ),
          if (ap.speedAllocationMbps != null)
            _InfoRow('Speed Cap', '${ap.speedAllocationMbps!.toInt()} Mbps'),
          _InfoRow(
            'Position',
            '(${ap.positionX.toStringAsFixed(0)}, ${ap.positionY.toStringAsFixed(0)}) px',
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          Text(
            'Band Configuration',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Bands
          ...ap.bands.map((band) => _BandCard(ap: ap, band: band)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Band card
// ============================================================================

class _BandCard extends StatelessWidget {
  const _BandCard({required this.ap, required this.band});
  final AccessPoint ap;
  final BandConfig band;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bandColor = switch (band.band) {
      WiFiBand.ghz24 => Colors.green,
      WiFiBand.ghz5 => Colors.blue,
      WiFiBand.ghz6 => Colors.purple,
    };
    final channelOptions = [20, 40, 80, 160];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: band.enabled
                        ? bandColor
                        : cs.onSurface.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  band.band.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: band.enabled,
                  onChanged: (v) =>
                      _updateBand(context, band.copyWith(enabled: v)),
                ),
              ],
            ),

            if (band.enabled) ...[
              const SizedBox(height: 12),
              // TX Power row
              Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text('TX Power', style: TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    child: Slider(
                      value: band.txPowerDbm.clamp(10, 30),
                      min: 10,
                      max: 30,
                      divisions: 20,
                      label: '${band.txPowerDbm.toStringAsFixed(0)} dBm',
                      onChanged: (v) =>
                          _updateBand(context, band.copyWith(txPowerDbm: v)),
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      '${band.txPowerDbm.toStringAsFixed(0)} dBm',
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),

              // Channel width row
              Row(
                children: [
                  const SizedBox(
                    width: 100,
                    child: Text(
                      'Channel Width',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: band.channelWidthMhz,
                    isDense: true,
                    items: channelOptions
                        .map(
                          (w) => DropdownMenuItem(
                            value: w,
                            child: Text(
                              '$w MHz',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        _updateBand(context, band.copyWith(channelWidthMhz: v));
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _updateBand(BuildContext context, BandConfig updated) {
    final newBands = ap.bands
        .map((b) => b.band == updated.band ? updated : b)
        .toList();
    final updatedAp = AccessPoint(
      id: ap.id,
      brand: ap.brand,
      model: ap.model,
      positionX: ap.positionX,
      positionY: ap.positionY,
      bands: newBands,
      antennaGainDbi: ap.antennaGainDbi,
      speedAllocationMbps: ap.speedAllocationMbps,
    );
    context.read<SurveyBloc>().add(SurveyAccessPointUpdated(updatedAp));
  }
}

// ============================================================================
// Empty detail view (no AP selected)
// ============================================================================

class _EmptyDetailView extends StatelessWidget {
  const _EmptyDetailView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_tethering_outlined,
            size: 64,
            color: cs.primary.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'Select an Access Point',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose an AP from the list to configure its bands.',
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

// ============================================================================
// AP Library Picker Dialog (shared / reusable)
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

            // Body
            Expanded(
              child: Row(
                children: [
                  // Brand rail
                  Container(
                    width: 160,
                    color: cs.surfaceContainerLow,
                    child: ListView.builder(
                      itemCount: brands.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (_, i) {
                        final brand = brands[i];
                        final sel = brand == _selectedBrand;
                        return ListTile(
                          dense: true,
                          selected: sel,
                          selectedTileColor: cs.primaryContainer,
                          title: Text(
                            brand,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: sel
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
