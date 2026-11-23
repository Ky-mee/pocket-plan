import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime configuration loaded from compile-time `--dart-define` first,
/// falling back to `.env` for local development.
class AppConfig {
  static const String _defineProxyUrl = String.fromEnvironment(
    'GEMINI_PROXY_URL',
  );

  static String get geminiProxyUrl {
    if (_defineProxyUrl.isNotEmpty) return _defineProxyUrl;
    try {
      return dotenv.env['GEMINI_PROXY_URL'] ?? '';
    } catch (_) {
      return '';
    }
  }
}
