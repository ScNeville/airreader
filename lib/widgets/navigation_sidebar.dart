import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:airreader/blocs/survey_bloc.dart';
import 'package:airreader/blocs/ui_bloc.dart';
import 'package:airreader/services/project_service.dart';

class NavigationSidebar extends StatelessWidget {
  const NavigationSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UIBloc>().state;
    final surveyName = context.select((SurveyBloc b) => b.state.survey.name);

    return Container(
      width: 220,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.wifi,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AirReader [WIP]',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  surveyName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                const _ProjectControls(),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          // Navigation items
          _NavItem(
            icon: Icons.map_outlined,
            label: 'Floor Plan',
            section: NavSection.floorPlan,
            selected: ui.selectedSection == NavSection.floorPlan,
          ),
          _NavItem(
            icon: Icons.router_outlined,
            label: 'Access Points',
            section: NavSection.accessPoints,
            selected: ui.selectedSection == NavSection.accessPoints,
          ),
          _NavItem(
            icon: Icons.devices_outlined,
            label: 'Client Devices',
            section: NavSection.clients,
            selected: ui.selectedSection == NavSection.clients,
          ),
          _NavItem(
            icon: Icons.layers_outlined,
            label: 'Zones',
            section: NavSection.zones,
            selected: ui.selectedSection == NavSection.zones,
          ),
          _NavItem(
            icon: Icons.thermostat_outlined,
            label: 'Heat Map',
            section: NavSection.heatMap,
            selected: ui.selectedSection == NavSection.heatMap,
          ),
          _NavItem(
            icon: Icons.speed_outlined,
            label: 'Performance',
            section: NavSection.performance,
            selected: ui.selectedSection == NavSection.performance,
          ),
          _NavItem(
            icon: Icons.analytics_outlined,
            label: 'RF Analysis',
            section: NavSection.rfEngineering,
            selected: ui.selectedSection == NavSection.rfEngineering,
          ),
          const Spacer(),
          const Divider(height: 1),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            section: NavSection.settings,
            selected: ui.selectedSection == NavSection.settings,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.section,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final NavSection section;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => context.read<UIBloc>().add(UINavSectionSelected(section)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.85),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Project controls – New / Open / Save
// ---------------------------------------------------------------------------

class _ProjectControls extends StatelessWidget {
  const _ProjectControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FileButton(
          icon: Icons.add_circle_outline,
          tooltip: 'New survey',
          onTap: () => _newSurvey(context),
        ),
        const SizedBox(width: 4),
        _FileButton(
          icon: Icons.folder_open_outlined,
          tooltip: 'Open project',
          onTap: () => _openSurvey(context),
        ),
        const SizedBox(width: 4),
        _FileButton(
          icon: Icons.save_outlined,
          tooltip: 'Save project',
          onTap: () => _saveSurvey(context),
        ),
      ],
    );
  }

  Future<void> _newSurvey(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Survey'),
        content: const Text(
          'Start a new survey? Any unsaved changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New Survey'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<SurveyBloc>().add(const SurveyNewStarted());
      context.read<UIBloc>().add(const UISavePathChanged(null));
    }
  }

  Future<void> _openSurvey(BuildContext context) async {
    final result = await ProjectService.open();
    if (result == null || !context.mounted) return;

    context.read<SurveyBloc>().add(SurveyLoaded(result.survey));
    context.read<UIBloc>().add(UISavePathChanged(result.path));
  }

  Future<void> _saveSurvey(BuildContext context) async {
    final survey = context.read<SurveyBloc>().state.survey;
    final currentPath = context.read<UIBloc>().state.currentFilePath;

    String? path;
    if (currentPath != null) {
      await ProjectService.save(survey, currentPath);
      path = currentPath;
    } else {
      path = await ProjectService.saveAs(survey);
    }

    if (path != null && context.mounted) {
      context.read<UIBloc>().add(UISavePathChanged(path));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _FileButton extends StatelessWidget {
  const _FileButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
