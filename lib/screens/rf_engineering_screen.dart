// lib/screens/rf_engineering_screen.dart
// Professional RF engineering analysis screen — structured input form
// on the left, six-section analysis report on the right.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:airreader/models/access_point.dart';
import 'package:airreader/models/rf_engineering_analysis.dart';
import 'package:airreader/models/survey_environment.dart';
import 'package:airreader/services/rf_engineering_service.dart';

// ============================================================================
// Root widget
// ============================================================================

class RfEngineeringScreen extends StatefulWidget {
  const RfEngineeringScreen({super.key});

  @override
  State<RfEngineeringScreen> createState() => _RfEngineeringScreenState();
}

class _RfEngineeringScreenState extends State<RfEngineeringScreen> {
  SurveyEnvironment _env = SurveyEnvironment.defaults;
  RfEngineeringAnalysis? _analysis;

  void _runAnalysis() {
    setState(() {
      _analysis = RfEngineeringService.analyze(_env);
    });
  }

  void _updateEnv(SurveyEnvironment updated) {
    setState(() {
      _env = updated;
      _analysis = null; // clear stale results
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left: input form ──────────────────────────────────────────────
        SizedBox(
          width: 360,
          child: Column(
            children: [
              Expanded(
                child: _InputForm(env: _env, onChanged: _updateEnv),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _runAnalysis,
                  icon: const Icon(Icons.calculate_outlined, size: 18),
                  label: const Text('Run Analysis'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // ── Right: results ────────────────────────────────────────────────
        Expanded(
          child: _analysis == null
              ? _EmptyResults(onAnalyze: _runAnalysis)
              : _ResultsView(analysis: _analysis!, env: _env),
        ),
      ],
    );
  }
}

// ============================================================================
// Input form
// ============================================================================

class _InputForm extends StatelessWidget {
  const _InputForm({required this.env, required this.onChanged});

  final SurveyEnvironment env;
  final ValueChanged<SurveyEnvironment> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FormSection(
          title: 'Building & Environment',
          children: [
            _DropdownField<BuildingType>(
              label: 'Building Type',
              value: env.buildingType,
              items: BuildingType.values,
              itemLabel: (v) => v.label,
              onChanged: (v) => onChanged(env.copyWith(buildingType: v)),
            ),
            const SizedBox(height: 10),
            _DropdownField<ConstructionMaterial>(
              label: 'Primary Construction',
              value: env.constructionMaterial,
              items: ConstructionMaterial.values,
              itemLabel: (v) => v.label,
              onChanged: (v) =>
                  onChanged(env.copyWith(constructionMaterial: v)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Floor Area (m²)',
                    value: env.floorAreaM2,
                    min: 10,
                    max: 100000,
                    onChanged: (v) => onChanged(env.copyWith(floorAreaM2: v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumberField(
                    label: 'Ceiling Height (m)',
                    value: env.ceilingHeightM,
                    min: 1.5,
                    max: 20,
                    onChanged: (v) =>
                        onChanged(env.copyWith(ceilingHeightM: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _NumberField(
              label: 'Number of Floors',
              value: env.numberOfFloors.toDouble(),
              min: 1,
              max: 100,
              isInt: true,
              onChanged: (v) =>
                  onChanged(env.copyWith(numberOfFloors: v.round())),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FormSection(
          title: 'Users & Applications',
          children: [
            _NumberField(
              label: 'Concurrent Users (per floor)',
              value: env.concurrentUsers.toDouble(),
              min: 1,
              max: 10000,
              isInt: true,
              onChanged: (v) =>
                  onChanged(env.copyWith(concurrentUsers: v.round())),
            ),
            const SizedBox(height: 10),
            _NumberField(
              label: 'Target Throughput per User (Mbps)',
              value: env.targetPerUserMbps,
              min: 0.5,
              max: 1000,
              onChanged: (v) => onChanged(env.copyWith(targetPerUserMbps: v)),
            ),
            const SizedBox(height: 10),
            Text(
              'Application Types',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: ApplicationType.values.map((a) {
                final selected = env.applicationTypes.contains(a);
                return FilterChip(
                  label: Text(a.label, style: const TextStyle(fontSize: 11)),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (on) {
                    final newSet = Set<ApplicationType>.from(
                      env.applicationTypes,
                    );
                    if (on) {
                      newSet.add(a);
                    } else {
                      newSet.remove(a);
                    }
                    onChanged(env.copyWith(applicationTypes: newSet));
                  },
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _FormSection(
          title: 'Wi-Fi Parameters',
          children: [
            _DropdownField<WifiStandard>(
              label: 'Wi-Fi Standard',
              value: env.wifiStandard,
              items: WifiStandard.values,
              itemLabel: (v) => v.label,
              onChanged: (v) => onChanged(env.copyWith(wifiStandard: v)),
            ),
            const SizedBox(height: 10),
            _DropdownField<WiFiBand>(
              label: 'Primary Band',
              value: env.preferredBand,
              items: WiFiBand.values,
              itemLabel: (v) => v.label,
              onChanged: (v) => onChanged(env.copyWith(preferredBand: v)),
            ),
            const SizedBox(height: 10),
            _DropdownField<int>(
              label: 'Channel Width (MHz)',
              value: env.channelWidthMhz,
              items: const [20, 40, 80, 160],
              itemLabel: (v) => '$v MHz',
              onChanged: (v) => onChanged(env.copyWith(channelWidthMhz: v)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: 'Max TX Power (dBm)',
                    value: env.maxTxPowerDbm,
                    min: 5,
                    max: 30,
                    onChanged: (v) => onChanged(env.copyWith(maxTxPowerDbm: v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DropdownField<int>(
                    label: 'Client Spatial Streams',
                    value: env.clientSpatialStreams,
                    items: const [1, 2, 3],
                    itemLabel: (v) => '$v×$v MIMO',
                    onChanged: (v) =>
                        onChanged(env.copyWith(clientSpatialStreams: v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Results view
// ============================================================================

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.analysis, required this.env});

  final RfEngineeringAnalysis analysis;
  final SurveyEnvironment env;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionCard(
          icon: Icons.cell_tower_outlined,
          title: '1. RF Coverage Model',
          color: Colors.blue,
          child: _CoverageSection(r: analysis.coverage),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.graphic_eq_outlined,
          title: '2. SNR Calculation',
          color: Colors.teal,
          child: _SnrSection(r: analysis.snr),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.speed_outlined,
          title: '3. PHY Data Rate Estimation',
          color: Colors.purple,
          child: _PhyRateSection(r: analysis.phyRate),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.people_outlined,
          title: '4. Capacity Model',
          color: Colors.orange,
          child: _CapacitySection(r: analysis.capacity),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.router_outlined,
          title: '5. AP Count Estimation',
          color: Colors.green,
          child: _ApCountSection(r: analysis.apCount),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          icon: Icons.lightbulb_outline,
          title: '6. Design Recommendations',
          color: Colors.amber,
          child: _RecommendationsSection(recs: analysis.recommendations),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ============================================================================
// Section: Coverage Model
// ============================================================================

class _CoverageSection extends StatelessWidget {
  const _CoverageSection({required this.r});
  final RfCoverageResult r;

  @override
  Widget build(BuildContext context) {
    final diamM = r.cellRadiusM * 2;
    // sqft conversion
    final areaFt2 = r.cellAreaM2 * 10.7639;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormulaBox(
          formula:
              'Pr(d) = Pt + G − [FSPL(1 m) + 10 · n · log₁₀(d/1 m)] − Wall Losses',
        ),
        const SizedBox(height: 12),
        _MetricsGrid(
          metrics: [
            _Metric(
              'Path-loss exponent (n)',
              r.pathLossExponent.toStringAsFixed(2),
              hint: 'Indoor log-distance model',
            ),
            _Metric('Band frequency', '${r.freqMhz.toStringAsFixed(0)} MHz'),
            _Metric(
              'FSPL at d₀ = 1 m',
              '${r.fsplAt1mDb.toStringAsFixed(1)} dB',
            ),
            _Metric('TX power', '${r.txPowerDbm.toStringAsFixed(0)} dBm'),
            _Metric(
              'Antenna gain',
              '${r.antennaGainDbi.toStringAsFixed(1)} dBi',
            ),
            _Metric(
              'Wall loss / wall',
              '${r.wallLossDbPerWall.toStringAsFixed(0)} dB',
              hint:
                  '${r.wallsAssumed} walls → ${r.totalWallLossDb.toStringAsFixed(0)} dB total',
            ),
            _Metric(
              'RSSI design target',
              '${r.rssiTargetDbm.toStringAsFixed(0)} dBm',
            ),
            _Metric(
              'RSSI at cell edge',
              '${r.rssiAtCellEdgeDbm.toStringAsFixed(1)} dBm',
              status: r.meetsTarget ? 'ok' : 'warn',
            ),
            _Metric(
              'Cell radius',
              '${r.cellRadiusM.toStringAsFixed(1)} m',
              hint: '${diamM.toStringAsFixed(1)} m diameter',
            ),
            _Metric(
              'Single-AP coverage area',
              '${r.cellAreaM2.toStringAsFixed(0)} m²',
              hint: '${areaFt2.toStringAsFixed(0)} ft²',
            ),
          ],
        ),
        if (!r.meetsTarget)
          _AlertChip(
            'RSSI at cell edge (${r.rssiAtCellEdgeDbm.toStringAsFixed(1)} dBm) is below the design target (${r.rssiTargetDbm.toStringAsFixed(0)} dBm).',
            isWarning: true,
          ),
      ],
    );
  }
}

// ============================================================================
// Section: SNR
// ============================================================================

class _SnrSection extends StatelessWidget {
  const _SnrSection({required this.r});
  final SnrResult r;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormulaBox(
          formula:
              'Noise Floor = kTB (${r.channelWidthMhz} MHz) + NF margin  '
              '=  ${r.thermalNoiseDbm.toStringAsFixed(1)} + ${r.noiseMarginDb.toStringAsFixed(0)} '
              '=  ${r.noiseFloorDbm.toStringAsFixed(1)} dBm',
        ),
        const SizedBox(height: 12),
        _MetricsGrid(
          metrics: [
            _Metric('Channel width', '${r.channelWidthMhz} MHz'),
            _Metric(
              'Thermal noise floor',
              '${r.thermalNoiseDbm.toStringAsFixed(1)} dBm',
            ),
            _Metric(
              'NF + interference margin',
              '${r.noiseMarginDb.toStringAsFixed(0)} dB',
            ),
            _Metric(
              'Effective noise floor',
              '${r.noiseFloorDbm.toStringAsFixed(1)} dBm',
            ),
            _Metric(
              'SNR at cell edge',
              '${r.snrAtCellEdgeDb.toStringAsFixed(1)} dB',
              status: r.snrAtCellEdgeDb < 10
                  ? 'critical'
                  : r.snrAtCellEdgeDb < 20
                  ? 'warn'
                  : 'ok',
            ),
            _Metric(
              'SNR near AP (3 m)',
              '${r.snrAtCellCentreDb.toStringAsFixed(1)} dB',
              status: 'ok',
            ),
            _Metric('Expected MCS range', r.expectedMcsRange),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Section: PHY Rate
// ============================================================================

class _PhyRateSection extends StatelessWidget {
  const _PhyRateSection({required this.r});
  final PhyRateResult r;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormulaBox(
          formula:
              'Real throughput = PHY rate × ${r.spatialStreams} SS × ${(r.protocolEfficiency * 100).toStringAsFixed(0)}% efficiency',
        ),
        const SizedBox(height: 12),
        _MetricsGrid(
          metrics: [
            _Metric('Spatial streams', '${r.spatialStreams} SS'),
            _Metric('Channel width', '${r.channelWidthMhz} MHz'),
            _Metric('MCS at cell edge', 'MCS ${r.mcsAtEdge}'),
            _Metric('MCS near AP', 'MCS ${r.mcsAtCentre}'),
            _Metric(
              'PHY rate at edge',
              '${r.phyRateAtEdgeMbps.toStringAsFixed(1)} Mbps',
            ),
            _Metric(
              'PHY rate near AP',
              '${r.phyRateAtCentreMbps.toStringAsFixed(1)} Mbps',
            ),
            _Metric(
              'Real throughput at edge',
              '${r.realThroughputAtEdgeMbps.toStringAsFixed(1)} Mbps',
              hint:
                  '= PHY × ${r.spatialStreams} SS × ${(r.protocolEfficiency * 100).toStringAsFixed(0)}%',
            ),
            _Metric(
              'Real throughput near AP',
              '${r.realThroughputAtCentreMbps.toStringAsFixed(1)} Mbps',
              hint:
                  '= PHY × ${r.spatialStreams} SS × ${(r.protocolEfficiency * 100).toStringAsFixed(0)}%',
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Section: Capacity
// ============================================================================

class _CapacitySection extends StatelessWidget {
  const _CapacitySection({required this.r});
  final CapacityResult r;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormulaBox(
          formula:
              'Per-user Mbps = AP throughput / concurrent users  '
              '=  ${r.apRealThroughputMbps.toStringAsFixed(1)} / ${r.concurrentUsersPerAp.toStringAsFixed(0)} users',
        ),
        const SizedBox(height: 12),
        _MetricsGrid(
          metrics: [
            _Metric(
              'AP real throughput',
              '${r.apRealThroughputMbps.toStringAsFixed(1)} Mbps',
              hint: 'Cell-edge conservative estimate',
            ),
            _Metric('Max users per AP', r.maxUsersPerApByThroughput.toString()),
            _Metric(
              'Per-user target',
              '${r.targetPerUserMbps.toStringAsFixed(1)} Mbps',
            ),
            _Metric(
              'Actual per-user at max load',
              '${r.perUserMbpsAtMaxLoad.toStringAsFixed(1)} Mbps',
              status: r.meetsTarget ? 'ok' : 'warn',
            ),
          ],
        ),
        if (!r.meetsTarget)
          _AlertChip(
            'Per-user throughput (${r.perUserMbpsAtMaxLoad.toStringAsFixed(1)} Mbps) is below target (${r.targetPerUserMbps.toStringAsFixed(1)} Mbps). Add more APs.',
            isWarning: true,
          ),
        if (r.meetsTarget)
          _AlertChip(
            'AP capacity supports ${r.maxUsersPerApByThroughput} users at ${r.targetPerUserMbps.toStringAsFixed(1)} Mbps each.',
            isWarning: false,
          ),
      ],
    );
  }
}

// ============================================================================
// Section: AP Count
// ============================================================================

class _ApCountSection extends StatelessWidget {
  const _ApCountSection({required this.r});
  final ApCountResult r;

  @override
  Widget build(BuildContext context) {
    final isCapacityLimited = r.limitingFactor == 'capacity';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormulaBox(
          formula:
              'By coverage: ⌈${r.apCountByCoverage} APs⌉ = ⌈Floor area / Cell area⌉\n'
              'By capacity: ⌈${r.apCountByCapacity} APs⌉ = ⌈Users / Max users per AP⌉',
        ),
        const SizedBox(height: 12),
        _MetricsGrid(
          metrics: [
            _Metric(
              'APs by coverage',
              '${r.apCountByCoverage} per floor',
              status: !isCapacityLimited ? 'highlight' : null,
            ),
            _Metric(
              'APs by capacity',
              '${r.apCountByCapacity} per floor',
              status: isCapacityLimited ? 'highlight' : null,
            ),
            _Metric(
              'Recommended per floor',
              '${r.recommendedApCount}',
              hint: 'Dominated by ${r.limitingFactor}',
              status: 'highlight',
            ),
            _Metric('Total floors', '${r.totalFloors}'),
            _Metric('Total APs', '${r.totalApCount}', status: 'highlight'),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Section: Recommendations
// ============================================================================

class _RecommendationsSection extends StatelessWidget {
  const _RecommendationsSection({required this.recs});
  final List<DesignRecommendation> recs;

  Color _severityColor(String s, BuildContext context) => switch (s) {
    'critical' => Colors.red.shade600,
    'warning' => Colors.orange.shade700,
    _ => Theme.of(context).colorScheme.primary,
  };

  IconData _severityIcon(String s) => switch (s) {
    'critical' => Icons.error_outline,
    'warning' => Icons.warning_amber_outlined,
    _ => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    if (recs.isEmpty) {
      return const Text('No recommendations — design looks good!');
    }
    return Column(
      children: recs.map((rec) {
        final color = _severityColor(rec.severity, context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
              color: color.withValues(alpha: 0.05),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_severityIcon(rec.severity), color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text(
                              rec.category,
                              style: TextStyle(fontSize: 10, color: color),
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: color.withValues(alpha: 0.12),
                            side: BorderSide.none,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rec.title,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rec.detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// Empty state
// ============================================================================

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onAnalyze});
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 72,
            color: cs.primary.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'Configure parameters and run the analysis',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The report will cover coverage model, SNR, PHY rates,\ncapacity, AP count, and design recommendations.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAnalyze,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Run Analysis'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Re-usable sub-widgets
// ============================================================================

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use
      value: value,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      items: items
          .map(
            (v) => DropdownMenuItem<T>(
              value: v,
              child: Text(itemLabel(v), style: const TextStyle(fontSize: 13)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = double.infinity,
    this.isInt = false,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final bool isInt;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _format(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    // Only reset the displayed text when the field doesn't have focus
    // (e.g. a dropdown elsewhere changed a derived value).
    if (!_focusNode.hasFocus && old.value != widget.value) {
      _ctrl.text = _format(widget.value);
    }
  }

  String _format(double v) =>
      widget.isInt ? v.round().toString() : v.toString();

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String s) {
    final parsed = double.tryParse(s);
    if (parsed != null) {
      final clamped = parsed.clamp(widget.min, widget.max);
      widget.onChanged(clamped);
      _ctrl.text = _format(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
      style: const TextStyle(fontSize: 13),
      onFieldSubmitted: _submit,
      onEditingComplete: () => _submit(_ctrl.text),
    );
  }
}

// ---- Section card wrapper ----

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

// ---- Formula display box ----

class _FormulaBox extends StatelessWidget {
  const _FormulaBox({required this.formula});
  final String formula;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        formula,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}

// ---- Metrics grid ----

class _Metric {
  const _Metric(this.label, this.value, {this.hint, this.status});
  final String label;
  final String value;
  final String? hint;

  /// null, 'ok', 'warn', 'critical', 'highlight'
  final String? status;
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metrics.map((m) {
        Color valueColor = cs.onSurface;
        if (m.status == 'ok') valueColor = Colors.green.shade600;
        if (m.status == 'warn') valueColor = Colors.orange.shade700;
        if (m.status == 'critical') valueColor = Colors.red.shade600;
        if (m.status == 'highlight') valueColor = cs.primary;

        return Container(
          constraints: const BoxConstraints(minWidth: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.label,
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                m.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
              if (m.hint != null)
                Text(
                  m.hint!,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ---- Alert chip ----

class _AlertChip extends StatelessWidget {
  const _AlertChip(this.text, {required this.isWarning});
  final String text;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? Colors.orange.shade700 : Colors.green.shade600;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(
            isWarning
                ? Icons.warning_amber_outlined
                : Icons.check_circle_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}
