/// Stub when llama_flutter_android is unavailable.
dynamic createLlamaController() {
  throw UnsupportedError(
    'On-device GGUF requires Android/iOS with llama_flutter_android',
  );
}
