/// Configuración leída de `--dart-define-from-file=config/dev.json`.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Nombre de las variables que faltan; vacío si todo está configurado.
  static List<String> get missing => [
    if (apiBaseUrl.isEmpty) 'API_BASE_URL',
    if (supabaseUrl.isEmpty || supabaseUrl.contains('<')) 'SUPABASE_URL',
    if (supabaseAnonKey.isEmpty || supabaseAnonKey.contains('<'))
      'SUPABASE_ANON_KEY',
  ];
}
