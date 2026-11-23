import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servired_app/core/network/api_exception.dart';

DioException _http(int status, [Object? data]) {
  final options = RequestOptions(path: '/x');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: data),
  );
}

void main() {
  group('ApiException.fromDio', () {
    test('sin red: reintentable y sin código', () {
      final e = ApiException.fromDio(
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/x'),
          reason: 'offline',
        ),
      );
      expect(e.isNetwork, isTrue);
      expect(e.retryable, isTrue);
      expect(e.message, contains('conexión'));
    });

    test('timeout: reintentable', () {
      final e = ApiException.fromDio(
        DioException.receiveTimeout(
          timeout: const Duration(seconds: 20),
          requestOptions: RequestOptions(path: '/x'),
        ),
      );
      expect(e.retryable, isTrue);
      expect(e.message, contains('tardó'));
    });

    test('5xx, 408 y 429 se reintentan; los demás 4xx no', () {
      for (final status in [500, 502, 503, 408, 429]) {
        expect(
          ApiException.fromDio(_http(status)).retryable,
          isTrue,
          reason: '$status',
        );
      }
      for (final status in [400, 401, 403, 404, 409, 413, 422]) {
        expect(
          ApiException.fromDio(_http(status)).retryable,
          isFalse,
          reason: '$status',
        );
      }
    });

    test('409 usa el detail del problem+json', () {
      final e = ApiException.fromDio(
        _http(409, {
          'type': 'https://servired.example/problemas/conflicto',
          'title': 'Conflicto',
          'status': 409,
          'detail': 'El usuario ya validó este restablecimiento.',
        }),
      );
      expect(e.status, 409);
      expect(e.message, 'El usuario ya validó este restablecimiento.');
    });

    test('400 incluye el primer error de campo', () {
      final e = ApiException.fromDio(
        _http(400, {
          'title': 'Solicitud inválida',
          'status': 400,
          'detail': 'Uno o más campos no son válidos.',
          'errores': [
            {'campo': 'lat', 'mensaje': 'debe estar entre -90 y 90'},
          ],
        }),
      );
      expect(e.message, contains('lat: debe estar entre -90 y 90'));
    });

    test('401 y 500 tienen mensajes propios en español', () {
      expect(ApiException.fromDio(_http(401)).message, contains('sesión'));
      expect(ApiException.fromDio(_http(500)).message, contains('temporal'));
    });
  });
}
