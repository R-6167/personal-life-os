import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/security_service.dart';
import 'theme.dart';
import 'widgets/glass.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await SecurityService.instance.verifyPin(_ctrl.text.trim());
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'Incorrect PIN';
        _busy = false;
        _ctrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, color: AppTheme.amber, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'Personal Life OS',
                        style: TextStyle(
                          color: AppTheme.silver,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter PIN to unlock offline data',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.5), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _ctrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 12,
                        autofocus: true,
                        style: const TextStyle(color: AppTheme.silver, letterSpacing: 6),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          counterText: '',
                          labelText: 'PIN',
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(_busy ? '…' : 'Unlock'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Data never leaves this device',
                        style: TextStyle(color: AppTheme.silver.withValues(alpha: 0.35), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
