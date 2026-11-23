import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:servired_app/core/config/app_config.dart';
import 'package:servired_app/features/auth/data/auth_repository.dart';

/// Cliente HTTP autenticado hacia el gateway.
///
/// **No usarlo para `/api/fraudes`**: esa ruta debe ir sin `Authorization`.
final apiClientProvider = Provider<Dio>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  dio.interceptors.add(AuthInterceptor(auth.accessToken));
  return dio;
});

/// Añade `Authorization: Bearer <JWT>` si hay sesión. Nunca registra el token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._token);

  final Future<String?> Function() _token;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _token();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}

/// UUID v4 aleatorio para `Idempotency-Key`. Se genera una vez por acción del
/// usuario y se reutiliza en cada reintento de esa misma acción.
String newIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
