import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servired_app/app.dart';
import 'package:servired_app/core/location/location_service.dart';
import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  Future<void> openValidation(WidgetTester tester, FakeAdapter api) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: true),
          ),
          apiClientProvider.overrideWithValue(fakeDio(api)),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
        ],
        child: const ServiRedApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar servicio cercano'));
    await tester.tap(find.text('Confirmar servicio cercano'));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> aviso({bool esMio = false}) => {
    ...reporteJson(estado: 'RESTABLECIMIENTO_REPORTADO'),
    'esMio': esMio,
  };

  testWidgets('lista el aviso cercano y confirma el restablecimiento', (
    tester,
  ) async {
    final api = FakeAdapter(
      (options) => switch ((options.method, options.path)) {
        ('GET', '/api/reportes') => FakeResponse(200, {
          'items': [aviso()],
          'page': 0,
          'size': 100,
          'total': 1,
        }),
        ('POST', '/api/reportes/1024/validaciones') => const FakeResponse(
          201,
          {
            'idValidacion': 77,
            'idReporte': 1024,
            'fecha': '2026-10-26T16:40:00Z',
            'totalValidaciones': 1,
            'validacionesRequeridas': 3,
            'estadoReporte': 'RESTABLECIMIENTO_REPORTADO',
          },
        ),
        _ => const FakeResponse(404),
      },
    );
    await openValidation(tester, api);

    expect(find.text('Sí, ya volvió'), findsOneWidget);
    await tester.tap(find.text('Sí, ya volvió'));
    await tester.pumpAndSettle();

    final post = api.requests.firstWhere((r) => r.method == 'POST');
    expect(post.data, {'lat': 4.6097, 'lng': -74.0817});
    expect(post.headers['Idempotency-Key'], isNotEmpty);
    expect(find.text('Confirmación registrada (1 de 3).'), findsOneWidget);
  });

  testWidgets('no ofrece confirmar un aviso propio', (tester) async {
    final api = FakeAdapter(
      (_) => FakeResponse(200, {
        'items': [aviso(esMio: true)],
        'page': 0,
        'size': 100,
        'total': 1,
      }),
    );
    await openValidation(tester, api);

    expect(find.text('Sí, ya volvió'), findsNothing);
    expect(
      find.text('No hay restablecimientos por confirmar cerca de ti.'),
      findsOneWidget,
    );
  });
}
