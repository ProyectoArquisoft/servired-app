import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/features/auth/data/auth_repository.dart';
import 'package:servired_app/features/reports/data/reports_repository.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';

import '../../helpers/fakes.dart';

Reporte _local({int idServicio = 4, DateTime? fecha}) => Reporte(
  idReporte: -1,
  codigoTrazabilidad: 'SR-2026-000999',
  idServicio: idServicio,
  tipoServicio: TipoServicio.alcantarillado,
  estado: EstadoReporte.activo,
  lat: 4.7,
  lng: -74.1,
  fechaCreacion: fecha ?? DateTime.now().toUtc(),
  totalValidaciones: 0,
  esMio: true,
);

ProviderContainer _container(FakeAdapter adapter) => ProviderContainer(
  overrides: [
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(signedIn: true),
    ),
    apiClientProvider.overrideWithValue(fakeDio(adapter)),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('el reporte nuevo aparece aunque el backend no lo devuelva', () async {
    final adapter = FakeAdapter(
      (_) => FakeResponse(200, {
        'items': [reporteJson()],
      }),
    );
    final container = _container(adapter);
    addTearDown(container.dispose);

    await container.read(localReportsStoreProvider).add(_local());
    final list = await container.read(myReportsProvider.future);

    expect(list, hasLength(2));
    expect(list.first.tipoServicio, TipoServicio.alcantarillado);
  });

  test('si el backend ya lo devuelve no se duplica', () async {
    final now = DateTime.now().toUtc();
    final adapter = FakeAdapter(
      (_) => FakeResponse(200, {
        'items': [
          {
            ...reporteJson(id: 7),
            'idServicio': 4,
            'tipoServicio': 'ALCANTARILLADO',
            'lat': 4.7,
            'lng': -74.1,
            'fechaCreacion': now.toIso8601String(),
          },
        ],
      }),
    );
    final container = _container(adapter);
    addTearDown(container.dispose);

    await container.read(localReportsStoreProvider).add(_local(fecha: now));
    final list = await container.read(myReportsProvider.future);

    expect(list.single.idReporte, 7);
  });

  test('sin red igual muestra los reportes locales', () async {
    final adapter = FakeAdapter((_) => const FakeResponse(503));
    final container = _container(adapter);
    addTearDown(container.dispose);

    await container.read(localReportsStoreProvider).add(_local());
    final list = await container.read(myReportsProvider.future);

    expect(list.single.idReporte, -1);
  });
}
