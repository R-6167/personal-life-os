import 'package:flutter/material.dart';

import '../services/intelligence_assistant.dart';
import 'theme.dart';
import 'widgets/glass.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _assistant = IntelligenceAssistant();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Msg>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _busy = true);
    final text = await _assistant.reply('situation');
    setState(() {
      _messages.add(_Msg(role: 'assistant', text: text));
      _busy = false;
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _busy = true;
    });
    final reply = await _assistant.reply(text);
    setState(() {
      _messages.add(_Msg(role: 'assistant', text: reply));
      _busy = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
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
              Text('Personal Context · Offline',
                  style: TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _messages.length + (_busy ? 1 : 0),
                itemBuilder: (context, i) {
                  if (_busy && i == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
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
                          child: Text(
                            m.text,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              height: 1.35,
                            ),
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
                    'Spend',
                    'Help'
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(chip),
                        onPressed: () => _send(chip.toLowerCase()),
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
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText:
                            'situation · focus · plan · remember · why…',
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
  _Msg({required this.role, required this.text});
  final String role;
  final String text;
}
