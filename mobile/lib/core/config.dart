/// App-wide configuration. The only environment knob for now is the API base URL.
///
/// Defaults to the Android emulator's alias for the host machine (`10.0.2.2`),
/// which maps to `localhost:4000` where the Phoenix server runs in dev. Override
/// at build time with `--dart-define=FLEETMS_BASE_URL=https://api.example.com`.
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'FLEETMS_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000',
  );

  /// All JSON:API routes live under this prefix.
  static const String apiPrefix = '/api/v1';

  /// The JSON:API media type the backend speaks.
  static const String mediaType = 'application/vnd.api+json';
}
