/// Result of one AI turn (local or remote).
class AiReply {
  AiReply({
    required this.text,
    required this.source,
    this.model,
    this.usedSituation = false,
    this.error,
  });

  final String text;
  final AiSource source;
  final String? model;
  final bool usedSituation;
  final String? error;

  bool get ok => error == null && text.isNotEmpty;
}

enum AiSource { local, remote, hybrid }

enum AiMode {
  /// Personal Context + rule engine only (default, offline).
  localOnly,
  /// Try remote with situation prompt; fall back to local on failure.
  remoteWithFallback,
  /// Remote only (fails closed to a short error if unreachable).
  remoteOnly,
}

class AiSettings {
  AiSettings({
    this.mode = AiMode.localOnly,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.systemPreamble =
        'You are the offline Personal Life OS assistant. Use only the provided personal context. Be concise, practical, and honest. Never invent calendar events or balances.',
  });

  final AiMode mode;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String systemPreamble;

  bool get remoteConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  AiSettings copyWith({
    AiMode? mode,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? systemPreamble,
  }) {
    return AiSettings(
      mode: mode ?? this.mode,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      systemPreamble: systemPreamble ?? this.systemPreamble,
    );
  }

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'systemPreamble': systemPreamble,
      };

  static AiSettings fromJson(Map<String, Object?> m) {
    final modeName = '${m['mode'] ?? 'localOnly'}';
    final mode = AiMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => AiMode.localOnly,
    );
    return AiSettings(
      mode: mode,
      baseUrl: '${m['baseUrl'] ?? ''}',
      apiKey: '${m['apiKey'] ?? ''}',
      model: '${m['model'] ?? 'gpt-4o-mini'}',
      systemPreamble: '${m['systemPreamble'] ?? AiSettings().systemPreamble}',
    );
  }
}
