import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servired_app/app.dart';
import 'package:servired_app/core/location/location_service.dart';
import 'package:servired_app/core/media/photo_service.dart';
import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAdapter api;
  late FakeLocationService location;

  /// Abre la app con sesión iniciada y entra a "Reportar un corte".
  Future<void> openFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: true),
          ),
          apiClientProvider.overrideWithValue(fakeDio(api)),
          locationServiceProvider.overrideWithValue(location),
          photoServiceProvider.overrideWithValue(FakePhotoService()),
        ],
        child: const ServiRedApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reportar un corte'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    location = FakeLocationService();
    api = FakeAdapter(
      (options) => switch ((options.method, options.path)) {
        ('GET', '/api/servicios') => const FakeResponse(200, servicesJson),
        ('POST', '/api/reportes') => FakeResponse(201, reporteJson()),
        _ => const FakeResponse(404),
      },
    );
  });

  testWidgets('reporta un corte en 3 pasos y muestra el código', (
    tester,
  ) async {
    await openFlow(tester);

    // Paso 1: tipo de servicio.
    expect(find.text('Paso 1 de 3'), findsOneWidget);
    await tester.tap(find.text('Energía'));
    await tester.pumpAndSettle();

    // Paso 2: con permiso, la ubicación se toma sola.
    expect(find.text('Paso 2 de 3'), findsOneWidget);
    expect(find.text('Ubicación lista'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Grave'), 200);
    await tester.tap(find.text('Grave'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    // Paso 3: descripción opcional y enviar.
    expect(find.text('Paso 3 de 3'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Sin luz en la cuadra');
    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();

    expect(find.text('¡Recibimos tu reporte!'), findsOneWidget);
    expect(find.text('SR-2026-000124'), findsOneWidget);

    final post = api.requests.singleWhere((r) => r.method == 'POST');
    expect(post.headers['Idempotency-Key'], isNotEmpty);
  });

  testWidgets('sin permiso de ubicación explica y ofrece el mapa', (
    tester,
  ) async {
    location
      ..permission = false
      ..result = const LocationResult.failed(LocationFailure.denied);
    await openFlow(tester);

    await tester.tap(find.text('Energía'));
    await tester.pumpAndSettle();

    // Antes del diálogo del sistema: explicación + opción manual.
    expect(find.textContaining('Usaremos tu ubicación'), findsOneWidget);
    expect(find.text('Elegir en el mapa'), findsOneWidget);
    expect(_continueButton(tester).onPressed, isNull);

    await tester.tap(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No diste permiso'), findsOneWidget);
    expect(find.text('Elegir en el mapa'), findsOneWidget);
  });

  testWidgets('si falla el envío, reintenta con la misma llave', (
    tester,
  ) async {
    var attempts = 0;
    api = FakeAdapter(
      (options) => switch ((options.method, options.path)) {
        ('GET', '/api/servicios') => const FakeResponse(200, servicesJson),
        ('POST', '/api/reportes') when ++attempts == 1 => const FakeResponse(
          503,
          {'title': 'Error interno', 'status': 503},
        ),
        ('POST', '/api/reportes') => FakeResponse(201, reporteJson()),
        _ => const FakeResponse(404),
      },
    );
    await openFlow(tester);
    await tester.tap(find.text('Energía'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();
    expect(find.textContaining('problema temporal'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('SR-2026-000124'), findsOneWidget);

    final keys = api.requests
        .where((r) => r.method == 'POST')
        .map((r) => r.headers['Idempotency-Key'])
        .toList();
    expect(keys, hasLength(2));
    expect(keys.first, keys.last);
  });

  testWidgets('el botón atrás retrocede un paso', (tester) async {
    await openFlow(tester);
    await tester.tap(find.text('Energía'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 2 de 3'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 3'), findsOneWidget);
  });
}

FilledButton _continueButton(WidgetTester tester) =>
    tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Continuar'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
