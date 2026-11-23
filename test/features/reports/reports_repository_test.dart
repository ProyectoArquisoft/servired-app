import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/features/reports/data/reports_repository.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';

import '../../helpers/fakes.dart';

void main() {
  test('listServices lee el catálogo', () async {
    final adapter = FakeAdapter((_) => const FakeResponse(200, servicesJson));
    final services = await ReportsRepository(fakeDio(adapter)).listServices();

    expect(adapter.requests.single.path, '/api/servicios');
    expect(services.map((s) => s.tipo), [
      TipoServicio.energia,
      TipoServicio.acueducto,
    ]);
  });

  test('createOutage envía multipart con Idempotency-Key', () async {
    final adapter = FakeAdapter((_) => FakeResponse(201, reporteJson()));
    final reporte = await ReportsRepository(fakeDio(adapter)).createOutage(
      const NuevoReporte(
        idServicio: 1,
        lat: 4.6,
        lng: -74.08,
        descripcion: '  Sin luz en la cuadra  ',
        severidad: Severidad.alta,
      ),
      idempotencyKey: 'llave-1',
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/reportes');
    expect(request.headers['Idempotency-Key'], 'llave-1');
    final fields = Map.fromEntries((request.data as FormData).fields);
    expect(fields, {
      'idServicio': '1',
      'tipoEvento': 'CORTE',
      'lat': '4.6',
      'lng': '-74.08',
      'descripcion': 'Sin luz en la cuadra',
      'severidad': 'ALTA',
    });
    expect(reporte.codigoTrazabilidad, 'SR-2026-000124');
  });

  test('createOutage omite descripción vacía y severidad nula', () async {
    final adapter = FakeAdapter((_) => FakeResponse(201, reporteJson()));
    await ReportsRepository(fakeDio(adapter)).createOutage(
      const NuevoReporte(
        idServicio: 1,
        lat: 4.6,
        lng: -74.08,
        descripcion: ' ',
      ),
      idempotencyKey: 'llave-2',
    );

    final names = (adapter.requests.single.data as FormData).fields.map(
      (f) => f.key,
    );
    expect(names, isNot(contains('descripcion')));
    expect(names, isNot(contains('severidad')));
  });

  test('listMine pide solo los del usuario', () async {
    final adapter = FakeAdapter(
      (_) => FakeResponse(200, {
        'items': [reporteJson()],
        'page': 0,
        'size': 50,
        'total': 1,
      }),
    );
    final mine = await ReportsRepository(fakeDio(adapter)).listMine();

    expect(adapter.requests.single.queryParameters['mios'], true);
    expect(mine.single.estado, EstadoReporte.activo);
  });

  test('notifyRestoration llama a la ruta del reporte con su llave', () async {
    final adapter = FakeAdapter(
      (_) =>
          FakeResponse(200, reporteJson(estado: 'RESTABLECIMIENTO_REPORTADO')),
    );
    final reporte = await ReportsRepository(
      fakeDio(adapter),
    ).notifyRestoration(1024, idempotencyKey: 'llave-3');

    final request = adapter.requests.single;
    expect(request.path, '/api/reportes/1024/restablecimiento');
    expect(request.headers['Idempotency-Key'], 'llave-3');
    expect(reporte.estado, EstadoReporte.restablecimientoReportado);
  });

  test('un 409 llega como ApiException con el detail', () async {
    final adapter = FakeAdapter(
      (_) => const FakeResponse(409, {
        'title': 'Conflicto',
        'status': 409,
        'detail': 'El reporte ya tiene un restablecimiento reportado.',
      }),
    );

    expect(
      () => ReportsRepository(
        fakeDio(adapter),
      ).notifyRestoration(1, idempotencyKey: 'k'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.retryable, 'retryable', false)
            .having((e) => e.message, 'message', contains('ya tiene')),
      ),
    );
  });

  test('sin red llega como ApiException reintentable', () async {
    final adapter = FakeAdapter(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      ),
    );

    expect(
      () => ReportsRepository(fakeDio(adapter)).listServices(),
      throwsA(
        isA<ApiException>().having((e) => e.retryable, 'retryable', true),
      ),
    );
  });

  group('AuthInterceptor', () {
    test('añade el Bearer si hay sesión', () async {
      final adapter = FakeAdapter((_) => const FakeResponse(200, servicesJson));
      final dio = fakeDio(adapter)
        ..interceptors.add(AuthInterceptor(() async => 'jwt-123'));
      await dio.get<Object>('/api/servicios');

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer jwt-123',
      );
    });

    test('no añade nada sin sesión', () async {
      final adapter = FakeAdapter((_) => const FakeResponse(200, servicesJson));
      final dio = fakeDio(adapter)
        ..interceptors.add(AuthInterceptor(() async => null));
      await dio.get<Object>('/api/servicios');

      expect(adapter.requests.single.headers, isNot(contains('Authorization')));
    });
  });

  test('newIdempotencyKey genera UUID v4 distintos', () {
    final a = newIdempotencyKey();
    final b = newIdempotencyKey();
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(a, matches(uuidV4));
    expect(a, isNot(b));
  });
}
