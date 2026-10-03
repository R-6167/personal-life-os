import 'package:flutter/material.dart';

import '../theme.dart';

/// Small chip reminding the user everything is local.
class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, this.compact = true});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.wood.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.woodLight.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: compact ? 12 : 16,
            color: AppTheme.silver,
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            compact ? 'Offline' : 'Fully offline',
            style: TextStyle(
              color: AppTheme.silver,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
