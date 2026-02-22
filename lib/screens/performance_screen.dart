import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/performance_cubit.dart';
import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/models/network_performance.dart';

// ============================================================================
// Root screen widget
// ============================================================================

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PerformanceCubit, PerformanceState>(
      builder: (context, state) {
        return Column(
          children: [
            _TopBar(
              performance: state.performance,
              isComputing: state.isComputing,
            ),
            const Divider(height: 1),
            Expanded(
              child: state.performance == null
                  ? const _EmptyView()
                  : _Body(performance: state.performance!),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// Top bar  – WAN speed input + global summary
// ============================================================================

class _TopBar extends StatefulWidget {
  const _TopBar({required this.performance, required this.isComputing});
  final NetworkPerformance? performance;
  final bool isComputing;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  late final TextEditingController _wanCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final wan = context.read<SurveyBloc>().state.survey.totalWanBandwidthMbps;
    _wanCtrl = TextEditingController(
      text: wan != null ? wan.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _wanCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final val = double.tryParse(_wanCtrl.text);
    context.read<SurveyBloc>().add(SurveyWanBandwidthSet(val));
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final perf = widget.performance;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: cs.surfaceContainerHighest.withOpacity(0.4),
      child: Row(
        children: [
          const Icon(Icons.speed_outlined, size: 18),
          const SizedBox(width: 8),
          const Text('WAN bandwidth:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _wanCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                suffixText: 'Mbps',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: '—',
              ),
              onChanged: (_) => setState(() => _editing = true),
              onSubmitted: (_) => _submit(),
              onEditingComplete: _submit,
            ),
          ),
          if (_editing) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.check, size: 16),
              tooltip: 'Apply',
              onPressed: _submit,
              visualDensity: VisualDensity.compact,
            ),
          ],
          const Spacer(),
          if (widget.isComputing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (perf != null) ...[
            _SummaryChip(
              label: '${perf.perAp.length} APs',
              icon: Icons.router_outlined,
              color: cs.primary,
            ),
            const SizedBox(width: 8),
            _SummaryChip(
              label: '${perf.perClient.length} clients',
              icon: Icons.devices_outlined,
              color: cs.secondary,
            ),
            const SizedBox(width: 8),
            _SummaryChip(
              label: '${perf.totalUtilisedMbps.toStringAsFixed(0)} Mbps used',
              icon: Icons.bar_chart_outlined,
              color: cs.tertiary,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Empty state
// ============================================================================

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.network_check_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Add a floor plan, access points and client devices\n'
            'to see performance estimates.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Body – AP panel + client table
// ============================================================================

class _Body extends StatelessWidget {
  const _Body({required this.performance});
  final NetworkPerformance performance;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: AP cards
        SizedBox(width: 360, child: _ApPanel(performance: performance)),
        const VerticalDivider(width: 1),
        // Right: client table
        Expanded(child: _ClientPanel(performance: performance)),
      ],
    );
  }
}

// ============================================================================
// AP panel
// ============================================================================

class _ApPanel extends StatelessWidget {
  const _ApPanel({required this.performance});
  final NetworkPerformance performance;

  @override
  Widget build(BuildContext context) {
    final aps = performance.perAp.values.toList();
    if (aps.isEmpty) {
      return const Center(
        child: Text('No APs', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: aps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) =>
          _ApCard(apPerf: aps[i], performance: performance),
    );
  }
}

class _ApCard extends StatelessWidget {
  const _ApCard({required this.apPerf, required this.performance});
  final ApPerf apPerf;
  final NetworkPerformance performance;

  Color _utilisationColor(double pct) {
    if (pct > 0.8) return Colors.red.shade400;
    if (pct > 0.6) return Colors.orange.shade400;
    return Colors.green.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = apPerf.utilisationPct;
    final barColor = _utilisationColor(pct);

    final clientNames = apPerf.clientIds
        .map((id) => performance.perClient[id]?.clientName ?? id)
        .join(', ');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                const Icon(Icons.router_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    apPerf.apName,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${apPerf.clientIds.length} client${apPerf.clientIds.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Allocation row
            Row(
              children: [
                Text(
                  apPerf.allocatedMbps > 0
                      ? '${apPerf.utilisedMbps.toStringAsFixed(0)} / '
                            '${apPerf.allocatedMbps.toStringAsFixed(0)} Mbps'
                      : '${apPerf.utilisedMbps.toStringAsFixed(0)} Mbps used',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (apPerf.allocatedMbps > 0)
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
              ],
            ),
            if (apPerf.allocatedMbps > 0) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: barColor.withOpacity(0.18),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
            // Client names (if any)
            if (clientNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                clientNames,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
            // Warnings
            if (apPerf.warnings.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: apPerf.warnings
                    .map((w) => _WarningChip(label: w))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Client panel
// ============================================================================

class _ClientPanel extends StatelessWidget {
  const _ClientPanel({required this.performance});
  final NetworkPerformance performance;

  @override
  Widget build(BuildContext context) {
    final clients = performance.perClient.values.toList();
    if (clients.isEmpty) {
      return const Center(
        child: Text('No clients', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          child: const Row(
            children: [
              SizedBox(width: 28),
              _HeaderCell('Client', flex: 3),
              _HeaderCell('AP / Band', flex: 3),
              _HeaderCell('RSSI', flex: 2),
              _HeaderCell('SNR', flex: 2),
              _HeaderCell('MCS', flex: 1),
              _HeaderCell('Est. Mbps', flex: 2),
              SizedBox(width: 120), // warnings column
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: clients.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, i) =>
                _ClientRow(clientPerf: clients[i], performance: performance),
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.flex});
  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({required this.clientPerf, required this.performance});
  final ClientPerf clientPerf;
  final NetworkPerformance performance;

  static Color _rssiColor(double rssi) {
    if (rssi >= -65) return Colors.green.shade600;
    if (rssi >= -75) return Colors.orange.shade600;
    if (rssi >= -85) return Colors.deepOrange.shade600;
    return Colors.red.shade700;
  }

  static IconData _clientIcon(ClientPerf perf) {
    // ClientPerf doesn't carry device type — use a generic icon.
    return Icons.devices_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final perf = clientPerf;

    final apPerf = perf.associatedApId != null
        ? performance.perAp[perf.associatedApId]
        : null;
    final apName = apPerf?.apName ?? '—';
    final bandLabel = perf.associatedBand?.label ?? '—';
    final rssiColor = _rssiColor(perf.rssiDbm);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(_clientIcon(perf), size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              perf.clientName,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  apName,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bandLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: rssiColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: rssiColor.withOpacity(0.5)),
              ),
              child: Text(
                '${perf.rssiDbm.toStringAsFixed(0)} dBm',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: rssiColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${perf.snrDb.toStringAsFixed(0)} dB',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text('${perf.mcsIndex}', style: theme.textTheme.bodySmall),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${perf.effectiveMbps.toStringAsFixed(1)} Mbps',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Wrap(
              spacing: 3,
              runSpacing: 3,
              children: perf.warnings
                  .map((w) => _WarningChip(label: w))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared warning chip
// ============================================================================

class _WarningChip extends StatelessWidget {
  const _WarningChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber.shade700.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 10,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.amber.shade900),
          ),
        ],
      ),
    );
  }
}
