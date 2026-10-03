import 'package:flutter/material.dart';

import '../../domain/enums.dart';
import '../../services/security_service.dart';
import '../theme.dart';

/// Formats minor units; masks when Settings → Hide balances is on.
String formatMoneyMinor(Object? minor, {String? currency}) {
  final cur = currency ?? Defaults.currency;
  if (SecurityService.instance.hideBalances) return '$cur ···';
  final m = (minor as int?) ?? 0;
  return '$cur ${(m / 100).toStringAsFixed(2)}';
}

String formatMoneyMajor(double major, {String? currency}) {
  final cur = currency ?? Defaults.currency;
  if (SecurityService.instance.hideBalances) return '$cur ···';
  return '$cur ${major.toStringAsFixed(2)}';
}

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.minor, {
    super.key,
    this.style,
    this.currency,
  });

  final Object? minor;
  final TextStyle? style;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatMoneyMinor(minor, currency: currency),
      style: style ?? const TextStyle(color: AppTheme.amber),
    );
  }
}
