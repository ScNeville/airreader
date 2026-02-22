import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/simulation_cubit.dart';
import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/blocs/ui_bloc.dart';
import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/client_device.dart';
import 'package:airreader/models/signal_map.dart';

/// Full-screen Client Devices management view (NavSection.clients).
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clients = context.select(
      (SurveyBloc b) => b.state.survey.clientDevices,
    );
    final selectedId = context.select(
      (UIBloc b) => b.state.selectedClientDeviceId,
    );

    return Row(
      children: [
        // ── Left panel: client list (280 px) ─────────────────────────────
        SizedBox(
          width: 280,
          child: _ClientListPanel(clients: clients, selectedId: selectedId),
        ),
        const VerticalDivider(width: 1),
        // ── Right panel: client config ────────────────────────────────────
        Expanded(
          child: selectedId == null
              ? const _EmptyDetailView()
              : Builder(
                  builder: (context) {
                    final client = clients
                        .where((c) => c.id == selectedId)
                        .firstOrNull;
                    if (client == null) return const _EmptyDetailView();
                    return _ClientDetailPanel(client: client);
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================================
// Left — client list
// ============================================================================

class _ClientListPanel extends StatelessWidget {
  const _ClientListPanel({required this.clients, required this.selectedId});
  final List<ClientDevice> clients;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header + Add button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Text(
                'Client Devices',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _AddClientButton(),
            ],
          ),
        ),
        const Divider(height: 1),

        // List / empty state
        Expanded(
          child: clients.isEmpty
              ? _EmptyListState(onAdd: () => _pickAndPlaceClient(context))
              : ListView.builder(
                  itemCount: clients.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (_, i) {
                    final c = clients[i];
                    return _ClientTile(client: c, selected: c.id == selectedId);
                  },
                ),
        ),
      ],
    );
  }
}

class _AddClientButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isPlacing = context.select(
      (UIBloc b) => b.state.activeTool == EditorTool.placeClient,
    );

    if (isPlacing) {
      return TextButton.icon(
        icon: const Icon(Icons.cancel_outlined, size: 14),
        label: const Text('Cancel'),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => context.read<UIBloc>().add(
          const UIEditorToolChanged(EditorTool.select),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.add_circle_outline, size: 20),
      tooltip: 'Add Client Device',
      onPressed: () => _pickAndPlaceClient(context),
    );
  }
}

class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client, required this.selected});
  final ClientDevice client;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: cs.secondaryContainer.withValues(alpha: 0.45),
      leading: Icon(
        _iconFor(client.type),
        size: 20,
        color: selected ? cs.secondary : const Color(0xFF009688),
      ),
      title: Text(
        client.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _labelFor(client.type),
        style: const TextStyle(fontSize: 11),
      ),
      onTap: () {
        context.read<UIBloc>().add(UIClientDeviceSelected(client.id));
        // Navigate to floor plan to show client position
        context.read<UIBloc>().add(
          const UINavSectionSelected(NavSection.floorPlan),
        );
      },
    );
  }

  IconData _iconFor(ClientDeviceType t) => switch (t) {
    ClientDeviceType.laptop => Icons.laptop_outlined,
    ClientDeviceType.smartphone => Icons.smartphone_outlined,
    ClientDeviceType.tablet => Icons.tablet_outlined,
    ClientDeviceType.iotSensor => Icons.sensors_outlined,
    ClientDeviceType.desktop => Icons.computer_outlined,
    ClientDeviceType.smartTv => Icons.tv_outlined,
  };

  String _labelFor(ClientDeviceType t) => switch (t) {
    ClientDeviceType.laptop => 'Laptop',
    ClientDeviceType.smartphone => 'Smartphone',
    ClientDeviceType.tablet => 'Tablet',
    ClientDeviceType.iotSensor => 'IoT Sensor',
    ClientDeviceType.desktop => 'Desktop',
    ClientDeviceType.smartTv => 'Smart TV',
  };
}

class _EmptyListState extends StatelessWidget {
  const _EmptyListState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_outlined,
              size: 40,
              color: cs.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No clients yet',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Client'),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Right — client detail
// ============================================================================

class _EmptyDetailView extends StatelessWidget {
  const _EmptyDetailView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'Select a client device to configure it',
        style: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.4),
          fontSize: 14,
        ),
      ),
    );
  }
}

class _ClientDetailPanel extends StatefulWidget {
  const _ClientDetailPanel({required this.client});
  final ClientDevice client;

  @override
  State<_ClientDetailPanel> createState() => _ClientDetailPanelState();
}

class _ClientDetailPanelState extends State<_ClientDetailPanel> {
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.client.name);
  }

  @override
  void didUpdateWidget(_ClientDetailPanel old) {
    super.didUpdateWidget(old);
    if (old.client.id != widget.client.id) {
      _nameCtrl.text = widget.client.name;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _update(ClientDevice updated) {
    context.read<SurveyBloc>().add(SurveyClientDeviceUpdated(updated));
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final cs = Theme.of(context).colorScheme;
    final aps = context.select((SurveyBloc b) => b.state.survey.accessPoints);
    final signalMap = context.select((SimulationCubit c) => c.state.signalMap);

    final double? rssi = signalMap != null
        ? (client.preferredBand != null
              ? signalMap.signalAt(
                  client.preferredBand!,
                  client.positionX,
                  client.positionY,
                )
              : signalMap.bestSignalAt(client.positionX, client.positionY))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(
                _iconFor(client.type),
                size: 28,
                color: const Color(0xFF009688),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  client.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: cs.error.withValues(alpha: 0.8),
                ),
                tooltip: 'Remove Client',
                onPressed: () {
                  context.read<SurveyBloc>().add(
                    SurveyClientDeviceRemoved(client.id),
                  );
                  context.read<UIBloc>().add(
                    const UIClientDeviceSelected(null),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),
          const _SectionLabel('Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                _update(client.copyWith(name: v.trim()));
              }
            },
          ),

          const SizedBox(height: 20),
          const _SectionLabel('Device Type'),
          const SizedBox(height: 8),
          DropdownButtonFormField<ClientDeviceType>(
            initialValue: client.type,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: ClientDeviceType.values
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(_iconFor(t), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _labelFor(t),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (t) {
              if (t != null) _update(client.copyWith(type: t));
            },
          ),

          const SizedBox(height: 20),
          const _SectionLabel('Preferred Band'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _BandChip(
                label: 'Auto',
                selected: client.preferredBand == null,
                onTap: () => _update(client.copyWith(clearPreferredBand: true)),
              ),
              _BandChip(
                label: '2.4 GHz',
                selected: client.preferredBand == WiFiBand.ghz24,
                onTap: () =>
                    _update(client.copyWith(preferredBand: WiFiBand.ghz24)),
              ),
              _BandChip(
                label: '5 GHz',
                selected: client.preferredBand == WiFiBand.ghz5,
                onTap: () =>
                    _update(client.copyWith(preferredBand: WiFiBand.ghz5)),
              ),
              _BandChip(
                label: '6 GHz',
                selected: client.preferredBand == WiFiBand.ghz6,
                onTap: () =>
                    _update(client.copyWith(preferredBand: WiFiBand.ghz6)),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const _SectionLabel('AP Association Override'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: client.manualApId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'Automatic (best signal)',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              ...aps.map(
                (ap) => DropdownMenuItem<String?>(
                  value: ap.id,
                  child: Text(
                    '${ap.brand} ${ap.model}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
            onChanged: (id) => _update(
              client.copyWith(manualApId: id, clearManualApId: id == null),
            ),
          ),

          if (rssi != null && rssi > kNoSignal) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Signal Level'),
            const SizedBox(height: 8),
            _RssiDisplay(rssi: rssi),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(ClientDeviceType t) => switch (t) {
    ClientDeviceType.laptop => Icons.laptop_outlined,
    ClientDeviceType.smartphone => Icons.smartphone_outlined,
    ClientDeviceType.tablet => Icons.tablet_outlined,
    ClientDeviceType.iotSensor => Icons.sensors_outlined,
    ClientDeviceType.desktop => Icons.computer_outlined,
    ClientDeviceType.smartTv => Icons.tv_outlined,
  };

  String _labelFor(ClientDeviceType t) => switch (t) {
    ClientDeviceType.laptop => 'Laptop',
    ClientDeviceType.smartphone => 'Smartphone',
    ClientDeviceType.tablet => 'Tablet',
    ClientDeviceType.iotSensor => 'IoT Sensor',
    ClientDeviceType.desktop => 'Desktop',
    ClientDeviceType.smartTv => 'Smart TV',
  };
}

// ============================================================================
// Small shared widgets
// ============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF009688).withValues(alpha: 0.15)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF009688)
                : cs.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected
                ? const Color(0xFF009688)
                : cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _RssiDisplay extends StatelessWidget {
  const _RssiDisplay({required this.rssi});
  final double rssi;

  @override
  Widget build(BuildContext context) {
    final color = rssi >= -65
        ? const Color(0xFF4CAF50)
        : rssi >= -75
        ? const Color(0xFFFF9800)
        : const Color(0xFFF44336);

    final label = rssi >= -65
        ? 'Excellent'
        : rssi >= -75
        ? 'Good'
        : rssi >= -85
        ? 'Fair'
        : 'Poor';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '${rssi.toStringAsFixed(1)} dBm',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Helpers
// ============================================================================

Future<void> _pickAndPlaceClient(BuildContext context) async {
  final type = await showDialog<ClientDeviceType>(
    context: context,
    builder: (_) => const _ClientTypePickerDialog(),
  );
  if (type == null || !context.mounted) return;
  context.read<UIBloc>().add(UIClientBeingPlacedChanged(type));
}

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
