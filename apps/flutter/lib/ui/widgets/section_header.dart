import 'package:flutter/material.dart';

import '../theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 16, bottom: 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.woodLight,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
