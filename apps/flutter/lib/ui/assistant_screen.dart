import 'package:flutter/material.dart';

import '../services/ai/ai.dart';
import '../services/feedback_service.dart';
import '../services/ordin_operator.dart';
import 'theme.dart';
import 'widgets/glass.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _ai = AiOrchestrator();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  bool _busy = false;
  String? _streamBuffer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _ai.stopGeneration();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _busy = true);
    try {
      final reply = await _ai.reply('situation');
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(
          role: 'assistant',
          text: reply.text,
          source: reply.source.name,
        ));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_Msg(role: 'assistant', text: 'Could not load context: $e'));
        _busy = false;
      });
    }
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _busy = true;
      _streamBuffer = '';
      _messages.add(_Msg(role: 'assistant', text: '', streaming: true));
    });
    _scrollToEnd();

    try {
      final result = await _ai.reply(text);
      if (!mounted) return;
      setState(() {
        final i = _messages.length - 1;
        if (i >= 0 && _messages[i].streaming) {
          _messages[i] = _Msg(
            role: 'assistant',
            text: result.text,
            source: result.source.name,
            proposals: List<OrdinActionProposal>.from(result.proposals),
          );
        } else {
          _messages.add(_Msg(
            role: 'assistant',
            text: result.text,
            source: result.source.name,
            proposals: List<OrdinActionProposal>.from(result.proposals),
          ));
        }
        _busy = false;
        _streamBuffer = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final i = _messages.length - 1;
        if (i >= 0 && _messages[i].streaming) {
          _messages[i] = _Msg(role: 'assistant', text: 'Error: $e');
        }
        _busy = false;
        _streamBuffer = null;
      });
    }
    _scrollToEnd();
  }

  Future<void> _approve(int msgIndex, OrdinActionProposal proposal) async {
    FeedbackService.instance.success();
    setState(() => _busy = true);
    final op = OrdinOperator();
    final result = await op.execute(proposal);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (msgIndex >= 0 && msgIndex < _messages.length) {
        final m = _messages[msgIndex];
        _messages[msgIndex] = _Msg(
          role: m.role,
          text: m.text,
          source: m.source,
          proposals: m.proposals,
          resolved: true,
        );
      }
      _messages.add(_Msg(
        role: 'assistant',
        text: result.ok ? '✓ ${result.message}' : '✗ ${result.message}',
        source: 'local',
      ));
    });
    _scrollToEnd();
  }

  void _dismissProposal(int msgIndex) {
    if (msgIndex < 0 || msgIndex >= _messages.length) return;
    FeedbackService.instance.light();
    setState(() {
      final m = _messages[msgIndex];
      _messages[msgIndex] = _Msg(
        role: m.role,
        text: m.text,
        source: m.source,
        proposals: const [],
        resolved: true,
      );
      _messages.add(_Msg(
        role: 'assistant',
        text: 'Okay — no changes made.',
        source: 'local',
      ));
    });
    _scrollToEnd();
  }

  Future<void> _stop() async {
    await _ai.stopGeneration();
    if (!mounted) return;
    setState(() {
      _busy = false;
      final i = _messages.length - 1;
      if (i >= 0 && _messages[i].streaming) {
        final t = _messages[i].text.trim();
        _messages[i] = _Msg(
          role: 'assistant',
          text: t.isEmpty ? '(stopped)' : t,
          source: 'onDevice',
        );
      }
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Intelligence'),
              Text('Personal Context · action loop',
                  style: TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          actions: [
            if (_busy)
              IconButton(
                tooltip: 'Stop',
                onPressed: _stop,
                icon: const Icon(Icons.stop_circle_outlined),
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount:
                    _messages.length + (_busy && _streamBuffer == null ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_busy && _streamBuffer == null && i == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (i >= _messages.length) return const SizedBox.shrink();
                  final m = _messages[i];
                  final isUser = m.role == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.85),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (m.source != null && !isUser)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    m.streaming ? 'generating…' : m.source!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          AppTheme.amber.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              Text(
                                m.text.isEmpty && m.streaming ? '…' : m.text,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  height: 1.35,
                                ),
                              ),
                              if (m.proposals.isNotEmpty && !m.resolved) ...[
                                const SizedBox(height: 10),
                                for (final p in m.proposals)
                                  if (p.isActionable)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.seed.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppTheme.amber.withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.title,
                                                style: const TextStyle(
                                                    color: AppTheme.amber,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13)),
                                            const SizedBox(height: 4),
                                            Text(p.rationale,
                                                style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.7),
                                                    fontSize: 12,
                                                    height: 1.3)),
                                            const SizedBox(height: 4),
                                            Text(p.preview,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                FilledButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _approve(i, p),
                                                  child: const Text('Approve'),
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _dismissProposal(i),
                                                  child: const Text('Dismiss'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final chip in [
                    'Situation',
                    'Today',
                    'Plan',
                    'Insights',
                    'Overdue',
                    'Habits',
                    'Bills',
                    'Help'
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(chip),
                        onPressed:
                            _busy ? null : () => _send(chip.toLowerCase()),
                        backgroundColor: AppTheme.seed.withValues(alpha: 0.2),
                        side: BorderSide(
                            color: AppTheme.seed.withValues(alpha: 0.4)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_busy,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Try: complete “laundry” · add task buy milk',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _send(),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Msg {
  _Msg({
    required this.role,
    required this.text,
    this.streaming = false,
    this.source,
    this.proposals = const [],
    this.resolved = false,
  });
  final String role;
  final String text;
  final bool streaming;
  final String? source;
  final List<OrdinActionProposal> proposals;
  final bool resolved;
}
