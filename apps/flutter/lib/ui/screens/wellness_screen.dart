import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/health_repository.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  final _repo = HealthRepository(AppDatabase.instance);
  Map<String, Object?>? _today;
  Map<String, Object?> _week = {};
  List<Map<String, Object?>> _recent = [];
  int _mood = 3;
  int _energy = 3;
  int _stress = 3;
  double _sleep = 7;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = await _repo.todayCheckin();
    final week = await _repo.weeklySummary();
    final recent = await _repo.recentCheckins();
    if (!mounted) return;
    setState(() {
      _today = today;
      _week = week;
      _recent = recent;
      if (today != null) {
        _mood = (today['mood'] as int?) ?? 3;
        _energy = (today['energy'] as int?) ?? 3;
        _stress = (today['stress'] as int?) ?? 3;
        _sleep = (today['sleep_hours'] as num?)?.toDouble() ?? 7;
      }
      _loading = false;
    });
  }

  Future<void> _saveCheckin() async {
    await _repo.saveCheckin(
      mood: _mood,
      energy: _energy,
      stress: _stress,
      sleepHours: _sleep,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wellness check-in saved')),
      );
    }
    await _load();
  }

  Future<void> _logMetric(String type, String label, String unit) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.metal,
        title: Text(label, style: const TextStyle(color: AppTheme.silver)),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppTheme.silver),
          decoration: InputDecoration(labelText: unit),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log')),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(c.text.trim());
    if (v == null) return;
    await _repo.logMetric(type: type, value: v, unit: unit);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Health & wellness')),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.amber))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _today == null ? 'Today’s check-in' : 'Update today’s check-in',
                          style: const TextStyle(
                              color: AppTheme.silver, fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        _slider('Mood', _mood, (v) => setState(() => _mood = v)),
                        _slider('Energy', _energy, (v) => setState(() => _energy = v)),
                        _slider('Stress', _stress, (v) => setState(() => _stress = v)),
                        Text('Sleep (hours): ${_sleep.toStringAsFixed(1)}',
                            style: const TextStyle(color: AppTheme.silver)),
                        Slider(
                          value: _sleep,
                          min: 0,
                          max: 12,
                          divisions: 24,
                          activeColor: AppTheme.amber,
                          onChanged: (v) => setState(() => _sleep = v),
                        ),
                        FilledButton(onPressed: _saveCheckin, child: const Text('Save check-in')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('This week',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Check-in days: ${_week['checkin_days'] ?? 0}',
                            style: const TextStyle(color: AppTheme.silver)),
                        Text(
                          'Avg mood: ${_fmt(_week['avg_mood'])} · energy: ${_fmt(_week['avg_energy'])}',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7)),
                        ),
                        Text(
                          'Avg sleep: ${_fmt(_week['avg_sleep'])}h · exercise: ${(_week['exercise_minutes_week'] as num?)?.toStringAsFixed(0) ?? '0'} min',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Log metrics',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _logMetric('WEIGHT', 'Weight', 'kg'),
                        child: const Text('Weight'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _logMetric('STEPS', 'Steps', 'steps'),
                        child: const Text('Steps'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _logMetric('EXERCISE_MINUTES', 'Exercise', 'min'),
                        child: const Text('Exercise'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _logMetric('WATER_ML', 'Water', 'ml'),
                        child: const Text('Water'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Recent check-ins',
                      style: TextStyle(color: AppTheme.woodLight, fontWeight: FontWeight.w600)),
                  if (_recent.isEmpty)
                    Text('No history yet',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4)))
                  else
                    ..._recent.map((c) {
                      final d = DateTime.fromMillisecondsSinceEpoch(c['day'] as int);
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: AppTheme.silver),
                        ),
                        subtitle: Text(
                          'Mood ${c['mood'] ?? '—'} · Energy ${c['energy'] ?? '—'} · Sleep ${c['sleep_hours'] ?? '—'}h',
                          style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
                        ),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _slider(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value / 5', style: const TextStyle(color: AppTheme.silver)),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: AppTheme.amber,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  String _fmt(Object? v) {
    if (v == null) return '—';
    if (v is num) return v.toStringAsFixed(1);
    return '$v';
  }
}
