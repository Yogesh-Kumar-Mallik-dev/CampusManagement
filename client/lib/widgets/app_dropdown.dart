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

/// Internal wrapper to handle nullable [T] values cleanly without Flutter's
/// PopupMenuButton mistaking a selected null value for a cancellation dismissal.
class _DropdownItemWrapper<T> {
  final T value;
  const _DropdownItemWrapper(this.value);
}

/// Enterprise desktop & multiplatform dropdown component.
///
/// Unlike Flutter's default DropdownButton which modal-centers over the trigger,
/// [AppDropdown] strictly drops DOWN below the anchor field with an elegant
/// offset, constant 1.0px border, themed surface background, bounded scroll height,
/// and clear hover states.
class AppDropdown<T> extends StatefulWidget {
  final String? labelText;
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
    this.labelText,
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
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  final GlobalKey<PopupMenuButtonState<_DropdownItemWrapper<T>>> _popupKey =
      GlobalKey<PopupMenuButtonState<_DropdownItemWrapper<T>>>();
  bool _isHovered = false;

  void _openMenu() {
    _popupKey.currentState?.showButtonMenu();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find the currently selected item definition
    final selectedItem = widget.items.cast<AppDropdownItem<T>?>().firstWhere(
          (it) => it?.value == widget.value,
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
        widget.hint ?? 'Select an option...',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      );
    }

    final dropdownWidget = LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = widget.width ?? (widget.isExpanded ? constraints.maxWidth : null);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: PopupMenuButton<_DropdownItemWrapper<T>>(
            key: _popupKey,
            tooltip: '',
            position: PopupMenuPosition.under,
            offset: const Offset(0, 4),
            elevation: 4,
            constraints: effectiveWidth != null
                ? BoxConstraints(
                    minWidth: effectiveWidth,
                    maxWidth: effectiveWidth,
                    maxHeight: widget.maxHeight,
                  )
                : BoxConstraints(maxHeight: widget.maxHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            onSelected: (_DropdownItemWrapper<T> wrapper) => widget.onChanged(wrapper.value),
            itemBuilder: (BuildContext context) {
              return widget.items.map((item) {
                final isSelected = item.value == widget.value;
                return PopupMenuItem<_DropdownItemWrapper<T>>(
                  value: _DropdownItemWrapper<T>(item.value),
                  enabled: item.enabled,
                  height: widget.isDense ? 36 : 42,
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
                                  color: !item.enabled
                                      ? (isDark
                                          ? AppColors.darkTextMuted.withValues(alpha: 0.5)
                                          : AppColors.lightTextMuted.withValues(alpha: 0.5))
                                      : isSelected
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
              height: widget.isDense ? 40 : 46,
              width: effectiveWidth,
              padding: widget.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isHovered
                      ? (isDark ? AppColors.wineRedDark : AppColors.wineRedLight)
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  if (widget.prefixIcon != null) ...[
                    widget.prefixIcon!,
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
          ),
        );
      },
    );

    if (widget.labelText == null) {
      return dropdownWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openMenu,
          child: Text(
            widget.labelText!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        dropdownWidget,
      ],
    );
  }
}
