import '../services/error_log_service.dart';

/// Run [fn] without failing the parent; log and return [fallback].
Future<T> softFuture<T>(
  Future<T> Function() fn,
  T fallback, {
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

/// Like Future.wait but each future is isolated — one failure does not drop others.
Future<List<T>> softWaitAll<T>(List<Future<T> Function()> factories, T fallback) {
  return Future.wait(
    factories.map((f) => softFuture(f, fallback)),
  );
}
