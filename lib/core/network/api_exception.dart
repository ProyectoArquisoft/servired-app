import 'package:dio/dio.dart';

/// Error de la API ya traducido a un mensaje para el ciudadano.
class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.retryable = false});

  /// Texto en español listo para mostrar.
  final String message;

  /// Código HTTP; `null` si no hubo respuesta (sin red, timeout).
  final int? status;

  /// `true` para 5xx, 408, 429, timeouts y falta de red: vale la pena
  /// reintentar con la misma `Idempotency-Key`.
  final bool retryable;

  bool get isNetwork => status == null;

  /// Mapea un error de dio, incluido el cuerpo `application/problem+json`.
  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) {
      final message = switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'El servidor tardó demasiado en responder. Intenta de nuevo.',
        _ => 'No hay conexión a internet. Revisa tu señal e intenta de nuevo.',
      };
      return ApiException(message, retryable: true);
    }

    final detail = _problemDetail(e.response?.data);
    final retryable = status >= 500 || status == 408 || status == 429;
    final message = switch (status) {
      400 => detail ?? 'Algunos datos no son válidos. Revísalos.',
      401 => 'Tu sesión venció. Vuelve a iniciar sesión.',
      403 => 'Tu cuenta no tiene permiso para hacer esto.',
      404 => 'No encontramos lo que buscas. Puede que ya no exista.',
      409 => detail ?? 'Esta acción ya se hizo o ya no es posible.',
      413 => 'La foto es muy pesada. Toma otra o envía sin foto.',
      422 => detail ?? 'No se pudo procesar la solicitud.',
      429 => 'Hiciste muchas solicitudes seguidas. Espera un momento.',
      _ when status >= 500 =>
        'El servicio tiene un problema temporal. Intenta más tarde.',
      _ => detail ?? 'Ocurrió un error inesperado ($status).',
    };
    return ApiException(message, status: status, retryable: retryable);
  }

  /// `detail` del problem+json, más el primer error de campo si lo hay.
  static String? _problemDetail(Object? data) {
    if (data is! Map) return null;
    final detail = data['detail'] ?? data['title'];
    final errores = data['errores'];
    if (errores is List && errores.isNotEmpty && errores.first is Map) {
      final first = errores.first as Map;
      final campo = '${first['campo'] ?? ''}: ${first['mensaje'] ?? ''}';
      return detail == null ? campo : '$detail ($campo)';
    }
    return detail?.toString();
  }

  @override
  String toString() => 'ApiException($status): $message';
}
