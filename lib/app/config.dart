/// Configuração do app lida de `--dart-define` (nunca segredos no git).
///
/// Exemplo (a chave vem do `supabase start`):
/// `flutter run -d windows --dart-define=SUPABASE_URL=http://127.0.0.1:54321
///  --dart-define=SUPABASE_ANON_KEY=CHAVE_ANON_LOCAL`
class Config {
  const Config._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54321',
  );

  /// Sem padrão: informe a chave anon local via `--dart-define`.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const String osrmBaseUrl = String.fromEnvironment(
    'OSRM_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const String nominatimBaseUrl = String.fromEnvironment(
    'NOMINATIM_BASE_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );

  static const String tileUrl = String.fromEnvironment(
    'TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const String _cidadeDemoLat = String.fromEnvironment(
    'CIDADE_DEMO_LAT',
    defaultValue: '-23.5505',
  );

  static const String _cidadeDemoLng = String.fromEnvironment(
    'CIDADE_DEMO_LNG',
    defaultValue: '-46.6333',
  );

  /// Latitude inicial do mapa (padrão: São Paulo).
  static double get cidadeDemoLat =>
      double.tryParse(_cidadeDemoLat) ?? -23.5505;

  /// Longitude inicial do mapa (padrão: São Paulo).
  static double get cidadeDemoLng =>
      double.tryParse(_cidadeDemoLng) ?? -46.6333;

  /// Verdadeiro quando há chave anon para conectar ao Supabase.
  static bool get supabaseConfigurado =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
