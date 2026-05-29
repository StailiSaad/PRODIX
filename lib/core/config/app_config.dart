class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.backendApiUrl,
    required this.aiGatewayUrl,
    required this.huggingFaceToken,
  });

  const AppConfig.fromEnvironment()
      : supabaseUrl = const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://edlxuaoldmdabteiqjfa.supabase.co',
        ),
        supabaseAnonKey = const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkbHh1YW9sZG1kYWJ0ZWlxamZhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc4ODk1NDgsImV4cCI6MjA5MzQ2NTU0OH0.Bcj54K16xMYz1Gkncyo7kcQkHQkfrJm_3aQA4ae0u90',
        ),
        backendApiUrl = const String.fromEnvironment(
          'BACKEND_API_URL',
          defaultValue: '',
        ),
        aiGatewayUrl = const String.fromEnvironment(
          'AI_GATEWAY_URL',
          defaultValue: '',
        ),
        huggingFaceToken = const String.fromEnvironment(
          'HUGGING_FACE_TOKEN',
          defaultValue: '',
        );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String backendApiUrl;
  final String aiGatewayUrl;
  final String huggingFaceToken;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  bool get hasBackendApi => backendApiUrl.isNotEmpty;
  bool get hasAiGateway => aiGatewayUrl.isNotEmpty && huggingFaceToken.isNotEmpty;

  /// Warns in debug mode if any config is missing.
  void debugCheck() {
    assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL not set — pass via --dart-define');
    assert(supabaseAnonKey.isNotEmpty,
        'SUPABASE_ANON_KEY not set — pass via --dart-define');
  }
}
