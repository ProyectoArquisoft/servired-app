import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(apiClientProvider)),
);

/// Catálogo de servicios (`GET /api/servicios`).
final servicesProvider = FutureProvider<List<Servicio>>(
  (ref) => ref.watch(reportsRepositoryProvider).listServices(),
);

/// Reportes del usuario que siguen abiertos (`ACTIVO` o `EN_ATENCION`).
final openReportsProvider = FutureProvider.autoDispose<List<Reporte>>((
  ref,
) async {
  final mine = await ref.watch(reportsRepositoryProvider).listMine();
  return mine.where((r) => r.estado.isOpen).toList();
});

class ReportsRepository {
  ReportsRepository(this._dio);

  final Dio _dio;

  Future<List<Servicio>> listServices() => _call(() async {
    final response = await _dio.get<List<dynamic>>('/api/servicios');
    return response.data!
        .map((e) => Servicio.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  /// RF1. `idempotencyKey` se genera una vez por reporte y se reutiliza en
  /// los reintentos para que el backend no lo duplique.
  Future<Reporte> createOutage(
    NuevoReporte reporte, {
    required String idempotencyKey,
  }) => _call(() async {
    final form = FormData.fromMap({
      'idServicio': reporte.idServicio,
      'tipoEvento': 'CORTE',
      'lat': reporte.lat,
      'lng': reporte.lng,
      if (reporte.descripcion case final d? when d.trim().isNotEmpty)
        'descripcion': d.trim(),
      if (reporte.severidad case final s?) 'severidad': s.api,
      if (reporte.evidenciaPath case final path?)
        'evidencia': await MultipartFile.fromFile(
          path,
          filename: 'evidencia.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/reportes',
      data: form,
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Reporte.fromJson(response.data!);
  });

  /// Reportes creados por el usuario de la sesión (`mios=true`).
  Future<List<Reporte>> listMine({int size = 50}) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/reportes',
      queryParameters: {'mios': true, 'page': 0, 'size': size},
    );
    return (response.data!['items'] as List<dynamic>)
        .map((e) => Reporte.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  /// RF2. Marca el reporte como `RESTABLECIMIENTO_REPORTADO`.
  Future<Reporte> notifyRestoration(
    int idReporte, {
    required String idempotencyKey,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/reportes/$idReporte/restablecimiento',
      data: <String, dynamic>{},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return Reporte.fromJson(response.data!);
  });

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
