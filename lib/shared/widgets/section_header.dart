import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailingLabel,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.mainText,
                ),
          ),
        ),
        if (trailingLabel != null && onTrailingTap != null)
          TextButton(
            onPressed: onTrailingTap,
            child: Text(
              trailingLabel!,
              style: const TextStyle(
                color: AppColors.primaryForestGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
