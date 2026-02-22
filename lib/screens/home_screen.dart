import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/blocs/ui_bloc.dart';
import 'package:airreader/screens/access_points_screen.dart';
import 'package:airreader/screens/clients_screen.dart';
import 'package:airreader/screens/floor_plan_screen.dart';
import 'package:airreader/screens/heat_map_screen.dart';
import 'package:airreader/screens/performance_screen.dart';
import 'package:airreader/screens/rf_engineering_screen.dart';
import 'package:airreader/screens/zones_screen.dart';
import 'package:airreader/widgets/navigation_sidebar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedSection = context.select(
      (UIBloc b) => b.state.selectedSection,
    );

    return Scaffold(
      body: Row(
        children: [
          const NavigationSidebar(),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _TopBar(section: selectedSection),
                const Divider(height: 1),
                Expanded(child: _SectionBody(section: selectedSection)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.section});
  final NavSection section;

  @override
  Widget build(BuildContext context) {
    final surveyName = context.select((SurveyBloc b) => b.state.survey.name);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Text(
            _sectionTitle(section),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _ProjectNameButton(surveyName: surveyName),
          const SizedBox(width: 16),
          // Theme toggle
          BlocBuilder<UIBloc, UIState>(
            buildWhen: (prev, curr) => prev.darkMode != curr.darkMode,
            builder: (context, ui) {
              return IconButton(
                icon: Icon(ui.darkMode ? Icons.light_mode : Icons.dark_mode),
                iconSize: 18,
                tooltip: ui.darkMode
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
                onPressed: () =>
                    context.read<UIBloc>().add(UIThemeDarkSet(!ui.darkMode)),
              );
            },
          ),
        ],
      ),
    );
  }

  String _sectionTitle(NavSection section) {
    return switch (section) {
      NavSection.floorPlan => 'Floor Plan',
      NavSection.accessPoints => 'Access Points',
      NavSection.clients => 'Client Devices',
      NavSection.zones => 'Environment Zones',
      NavSection.heatMap => 'Heat Map',
      NavSection.performance => 'Network Performance',
      NavSection.rfEngineering => 'RF Engineering Analysis',
      NavSection.settings => 'Settings',
    };
  }
}

// ---------------------------------------------------------------------------
// Editable project name button
// ---------------------------------------------------------------------------

class _ProjectNameButton extends StatelessWidget {
  const _ProjectNameButton({required this.surveyName});
  final String surveyName;

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: surveyName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Project name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName != null && newName.isNotEmpty && context.mounted) {
      context.read<SurveyBloc>().add(SurveyRenamed(newName));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Rename project',
      child: InkWell(
        onTap: () => _rename(context),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                surveyName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.edit_outlined,
                size: 13,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section body placeholders
// ---------------------------------------------------------------------------

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});
  final NavSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      NavSection.floorPlan => const FloorPlanScreen(),
      NavSection.accessPoints => const AccessPointsScreen(),
      NavSection.clients => const ClientsScreen(),
      NavSection.zones => const ZonesScreen(),
      NavSection.heatMap => const HeatMapScreen(),
      NavSection.performance => const PerformanceScreen(),
      NavSection.rfEngineering => const RfEngineeringScreen(),
      NavSection.settings => const _PlaceholderView(
        icon: Icons.settings_outlined,
        title: 'Settings',
        subtitle: 'Application preferences and project settings.',
      ),
    };
  }
}

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
