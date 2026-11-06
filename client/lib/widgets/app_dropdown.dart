import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/svg_icons.dart';

/// Item definition for [AppDropdown].
class AppDropdownItem<T> {
  final T value;
  final String label;
  final Widget? child;
  final bool enabled;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.child,
    this.enabled = true,
  });
}

/// Enterprise desktop & multiplatform dropdown component.
///
/// Unlike Flutter's default DropdownButton which modal-centers over the trigger,
/// [AppDropdown] strictly drops DOWN below the anchor field with an elegant
/// offset, constant 1.0px border, themed surface background, bounded scroll height,
/// and clear hover states.
class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final double maxHeight;
  final double? width;
  final bool isDense;
  final bool isExpanded;
  final Widget? prefixIcon;
  final EdgeInsetsGeometry? contentPadding;

  const AppDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.maxHeight = 280,
    this.width,
    this.isDense = true,
    this.isExpanded = true,
    this.prefixIcon,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find the currently selected item definition
    final selectedItem = items.cast<AppDropdownItem<T>?>().firstWhere(
          (it) => it?.value == value,
          orElse: () => null,
        );

    Widget displayText;
    if (selectedItem != null) {
      if (selectedItem.child != null) {
        displayText = selectedItem.child!;
      } else {
        displayText = Text(
          selectedItem.label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        );
      }
    } else {
      displayText = Text(
        hint ?? 'Select an option...',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = width ?? (isExpanded ? constraints.maxWidth : null);

        return PopupMenuButton<T>(
          tooltip: '',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          elevation: 4,
          constraints: effectiveWidth != null
              ? BoxConstraints(
                  minWidth: effectiveWidth,
                  maxWidth: effectiveWidth,
                  maxHeight: maxHeight,
                )
              : BoxConstraints(maxHeight: maxHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          onSelected: (T val) => onChanged(val),
          itemBuilder: (BuildContext context) {
            return items.map((item) {
              final isSelected = item.value == value;
              return PopupMenuItem<T>(
                value: item.value,
                enabled: item.enabled,
                height: isDense ? 36 : 42,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? AppColors.wineRedDark.withValues(alpha: 0.3)
                            : AppColors.wineRedSubtle)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: item.child ??
                            Text(
                              item.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : AppColors.wineRed)
                                    : (isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary),
                              ),
                            ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        AppSvgIcon(
                          svgString: AppSvgIcon.check,
                          size: 13,
                          color: isDark ? AppColors.wineRedLight : AppColors.wineRed,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList();
          },
          child: Container(
            height: isDense ? 40 : 46,
            width: effectiveWidth,
            padding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (prefixIcon != null) ...[
                  prefixIcon!,
                  const SizedBox(width: 8),
                ],
                Expanded(child: displayText),
                const SizedBox(width: 8),
                AppSvgIcon(
                  svgString: AppSvgIcon.chevronDown,
                  size: 14,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
