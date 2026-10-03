import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass.dart';

/// Visual “one system” chain: Goal → Project → Milestone → Task → Schedule → Done.
class LifeChainBanner extends StatelessWidget {
  const LifeChainBanner({
    super.key,
    required this.steps,
    this.subtitle,
  });

  final List<String> steps;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            steps.join('  →  '),
            style: const TextStyle(
              color: AppTheme.amber,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({
    super.key,
    required this.items,
  });

  final List<({String label, int at})> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No activity yet — complete or schedule work to build history.',
        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35)),
      );
    }
    return Column(
      children: items.map((e) {
        final d = DateTime.fromMillisecondsSinceEpoch(e.at);
        final stamp =
            '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: AppTheme.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(e.label, style: const TextStyle(color: AppTheme.silver, fontSize: 13)),
                ),
                Text(stamp, style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

String humanEvent(String eventType) {
  return eventType.replaceAll('_', ' ').toLowerCase();
}
