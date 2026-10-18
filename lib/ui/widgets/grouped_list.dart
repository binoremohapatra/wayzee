import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GroupedList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const GroupedList({
    super.key,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class GroupedListItem extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool showDivider;

  const GroupedListItem({
    super.key,
    required this.child,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      onTap: onTap != null ? () {} : null,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              child: child,
            ),
            if (showDivider)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.line,
                indent: 24,
                endIndent: 24,
              ),
          ],
        ),
      ),
    );
  }
}
