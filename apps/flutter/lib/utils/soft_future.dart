import '../services/error_log_service.dart';

/// Run [fn] without failing the parent; log and return [fallback].
///
/// Uses a nullable return so call sites can pass `null` for void-style work
/// without fighting `Future<void>` vs `Future<Null>`.
Future<T?> softFuture<T>(
  Future<T> Function() fn, {
  T? fallback,
  String label = 'softFuture',
}) async {
  try {
    return await fn();
  } catch (e, st) {
    await ErrorLogService.instance.log(
      message: '$label: $e',
      stack: st.toString(),
      level: 'SOFT',
    );
    return fallback;
  }
}

/// Fire-and-forget style: swallow errors, log them.
Future<void> softRun(
  Future<void> Function() fn, {
  String label = 'softRun',
}) async {
  try {
    await fn();
  } catch (e, st) {
    await ErrorLogService.instance.log(
      message: '$label: $e',
      stack: st.toString(),
      level: 'SOFT',
    );
  }
}
