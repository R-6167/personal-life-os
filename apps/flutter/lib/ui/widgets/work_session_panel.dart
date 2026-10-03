import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/work_session_service.dart';
import '../theme.dart';
import 'glass.dart';

/// Live work loop controls: Start → Pause/Resume → Complete (+ history insight).
class WorkSessionPanel extends StatefulWidget {
  const WorkSessionPanel({
    super.key,
    required this.taskId,
    this.plannedMinutes,
    this.onChanged,
  });

  final String taskId;
  final int? plannedMinutes;
  final VoidCallback? onChanged;

  @override
  State<WorkSessionPanel> createState() => _WorkSessionPanelState();
}

class _WorkSessionPanelState extends State<WorkSessionPanel> {
  final _svc = WorkSessionService();
  WorkSession? _session;
  List<WorkSession> _history = [];
  EstimateInsight? _insight;
  Timer? _tick;
  int _displayMs = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final active = await _svc.activeSession(taskId: widget.taskId);
    final hist = await _svc.historyForTask(widget.taskId);
    final insight = await _svc.insightForTask(widget.taskId);
    if (!mounted) return;
    setState(() {
      _session = active;
      _history = hist;
      _insight = insight;
      _displayMs = active?.elapsedMs() ?? 0;
    });
    _tick?.cancel();
    if (active?.status == 'RUNNING') {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _session == null) return;
        setState(() => _displayMs = _session!.elapsedMs());
      });
    }
  }

  String _fmt(int ms) {
    final s = (ms / 1000).floor();
    final m = s ~/ 60;
    final r = s % 60;
    final h = m ~/ 60;
    final mm = m % 60;
    if (h > 0) {
      return '${h}h ${mm.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  Future<void> _start() async {
    await _svc.start(
      taskId: widget.taskId,
      plannedMinutes: widget.plannedMinutes,
    );
    HapticFeedback.mediumImpact();
    await _refresh();
    widget.onChanged?.call();
  }

  Future<void> _pause() async {
    final s = _session;
    if (s == null) return;
    await _svc.pause(s.id);
    await _refresh();
  }

  Future<void> _resume() async {
    final s = _session;
    if (s == null) return;
    await _svc.resume(s.id);
    await _refresh();
  }

  Future<void> _complete({required bool completeTask}) async {
    final s = _session;
    if (s == null) return;
    final done = await _svc.complete(s.id, completeTask: completeTask);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Worked ${done.actualMinutes}m'
            '${done.plannedMinutes != null ? ' (planned ${done.plannedMinutes}m)' : ''}',
          ),
        ),
      );
    }
    HapticFeedback.heavyImpact();
    await _refresh();
    widget.onChanged?.call();
  }

  Future<void> _cancel() async {
    final s = _session;
    if (s == null) return;
    await _svc.cancel(s.id);
    await _refresh();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final insight = _insight;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppTheme.amber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Work session',
                style: TextStyle(
                  color: AppTheme.amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (s != null)
                Text(
                  s.status,
                  style: TextStyle(
                    color: AppTheme.silver.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (s == null) ...[
            Text(
              'Start when you begin. Pause if interrupted. Complete to record actual time.',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start work'),
            ),
          ] else ...[
            Text(
              _fmt(_displayMs),
              style: const TextStyle(
                color: AppTheme.silver,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            if (s.plannedMinutes != null)
              Text(
                'Planned ${s.plannedMinutes}m',
                style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.45), fontSize: 12),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.status == 'RUNNING')
                  OutlinedButton.icon(
                    onPressed: _pause,
                    icon: const Icon(Icons.pause, size: 18),
                    label: const Text('Pause'),
                  ),
                if (s.status == 'PAUSED')
                  FilledButton.icon(
                    onPressed: _resume,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume'),
                  ),
                FilledButton.icon(
                  onPressed: () => _complete(completeTask: false),
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('End session'),
                ),
                OutlinedButton(
                  onPressed: () => _complete(completeTask: true),
                  child: const Text('End + complete task'),
                ),
                TextButton(
                  onPressed: _cancel,
                  child: Text('Discard',
                      style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5))),
                ),
              ],
            ),
          ],
          if (insight != null && insight.sampleCount > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Personal estimate',
              style: TextStyle(
                color: AppTheme.woodLight,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              insight.summary,
              style: const TextStyle(color: AppTheme.silver, fontSize: 13),
            ),
            Text(
              'Based on ${insight.sampleCount} completed session${insight.sampleCount == 1 ? '' : 's'}',
              style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'History',
              style: TextStyle(
                color: AppTheme.woodLight,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            ..._history.take(5).map((h) {
              final planned = h.plannedMinutes;
              final actual = h.actualMinutes;
              final delta = planned == null ? null : actual - planned;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${actual}m actual'
                  '${planned != null ? ' · planned ${planned}m' : ''}'
                  '${delta != null ? (delta > 0 ? ' · +${delta}m' : delta < 0 ? ' · ${delta}m' : ' · on target') : ''}'
                  '${h.interruptCount > 0 ? ' · ${h.interruptCount} pause(s)' : ''}',
                  style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.55), fontSize: 12),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
