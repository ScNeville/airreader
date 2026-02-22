import 'package:flutter/material.dart';

import 'package:airreader/models/wall.dart';

/// Grid picker for selecting a wall material.
class MaterialPickerWidget extends StatelessWidget {
  const MaterialPickerWidget({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final WallMaterial selected;
  final ValueChanged<WallMaterial> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: WallMaterial.values.map((m) {
        final isSelected = m == selected;
        return _MaterialChip(
          material: m,
          isSelected: isSelected,
          onTap: () => onSelected(m),
        );
      }).toList(),
    );
  }
}

class _MaterialChip extends StatelessWidget {
  const _MaterialChip({
    required this.material,
    required this.isSelected,
    required this.onTap,
  });

  final WallMaterial material;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final def = material.definition;
    final colorScheme = Theme.of(context).colorScheme;
    final matColor = Color(def.color.toARGB32());

    return Tooltip(
      message: '${def.description}\n'
          '2.4 GHz: ${def.loss24GhzDb} dB  •  '
          '5 GHz: ${def.loss5GhzDb} dB  •  '
          '6 GHz: ${def.loss6GhzDb} dB',
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? matColor.withValues(alpha: 0.25)
                : colorScheme.surface,
            border: Border.all(
              color: isSelected ? matColor : colorScheme.outline.withValues(alpha: 0.35),
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
              const SizedBox(width: 6),
              Text(
                def.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.75),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
