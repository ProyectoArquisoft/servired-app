import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:servired_app/features/fraud/fraud_models.dart';

const String _kFraudApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

final fraudRepositoryProvider = Provider<FraudRepository>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _kFraudApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  return FraudRepository(dio);
});

class FraudRepository {
  FraudRepository(this._dio);

  final Dio _dio;

  Future<FraudReportResponse> submitAnonymousFraud(
      FraudReportRequest request,
      ) async {
    try {
      final response = await _dio.post(
        '/api/fraudes',
        data: request.toJson(),
        options: Options(
          headers: <String, dynamic>{
            'Idempotency-Key': _generateUuidV4(),
          },
        ),
      );

      final Map<String, dynamic> data =
          _asStringKeyMap(response.data) ?? <String, dynamic>{};
      return FraudReportResponse.fromJson(data);
    } on DioException catch (e) {
      final responseMap = _asStringKeyMap(e.response?.data);
      final serverMessage =
      (responseMap?['detail'] ?? responseMap?['title'])?.toString();
      throw Exception(
        serverMessage ?? 'No se pudo enviar la denuncia anónima.',
      );
    }
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is Map) {
      return value.map<String, dynamic>(
            (key, val) => MapEntry(key.toString(), val),
      );
    }
    return null;
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}