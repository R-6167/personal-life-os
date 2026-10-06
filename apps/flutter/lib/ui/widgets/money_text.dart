import 'package:flutter/material.dart';

import '../../services/security_service.dart';
import '../../services/user_prefs.dart';
import '../theme.dart';

/// Active currency code from the local user profile (falls back via UserPrefs).
String activeCurrency() => UserPrefs.instance.currency;

/// Formats minor units; masks when Settings → Hide balances is on.
String formatMoneyMinor(Object? minor, {String? currency}) {
  final cur = currency ?? activeCurrency();
  if (SecurityService.instance.hideBalances) return '$cur ···';
  final m = (minor as int?) ?? 0;
  return '$cur ${(m / 100).toStringAsFixed(2)}';
}

String formatMoneyMajor(double major, {String? currency}) {
  final cur = currency ?? activeCurrency();
  if (SecurityService.instance.hideBalances) return '$cur ···';
  return '$cur ${major.toStringAsFixed(2)}';
}

class MoneyText extends StatelessWidget {
  /// Convenience for call sites that used MoneyText.formatMinor.
  static String formatMinor(Object? minor, {String? currency}) =>
      formatMoneyMinor(minor, currency: currency);

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
