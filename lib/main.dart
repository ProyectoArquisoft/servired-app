import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:servired_app/app.dart';
import 'package:servired_app/core/config/app_config.dart';
import 'package:servired_app/features/auth/data/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.missing.isNotEmpty) {
    runApp(ConfigErrorApp(missing: AppConfig.missing));
    return;
  }

  // Solo Auth: la app nunca usa la BD ni el Storage de Supabase.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      // Sin reintentos automáticos de Riverpod: evita peticiones repetidas
      // (bajo consumo de datos); el usuario reintenta con un botón.
      retry: (retryCount, error) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(
          SupabaseAuthRepository(Supabase.instance.client.auth),
        ),
      ],
      child: const ServiRedApp(),
    ),
  );
}
