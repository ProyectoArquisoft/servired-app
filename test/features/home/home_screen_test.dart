import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servired_app/app.dart';
import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {bool signedIn = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: signedIn),
          ),
          apiClientProvider.overrideWithValue(
            fakeDio(
              FakeAdapter(
                (_) => const FakeResponse(200, {
                  'items': <Object>[],
                  'page': 0,
                  'size': 50,
                  'total': 0,
                }),
              ),
            ),
          ),
        ],
        child: const ServiRedApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el inicio muestra las dos acciones principales', (tester) async {
    await pumpApp(tester);

    expect(find.text('Reportar un corte'), findsOneWidget);
    expect(find.text('Ya volvió el servicio'), findsOneWidget);
    expect(find.text('Denunciar conexión fraudulenta'), findsOneWidget);
  });

  testWidgets('los botones principales cumplen el área táctil mínima', (
    tester,
  ) async {
    await pumpApp(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('soporta texto agrandado ×2 sin desbordes', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Reportar un corte'), findsOneWidget);
  });

  testWidgets('navega a una sección y vuelve', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Mis reportes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Buscar por ID, servicio, descripción o estado...'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute(); // botón "atrás" de Android
    await tester.pumpAndSettle();
    expect(find.text('¿Qué pasó con tu servicio?'), findsOneWidget);
  });

  testWidgets('sin sesión, reportar pide ingresar y luego continúa', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Ya volvió el servicio'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa a tu cuenta'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ciudadano@ejemplo.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secreta123',
    );
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    // Vuelve a la sección que el ciudadano quería abrir.
    expect(find.text('Ingresa a tu cuenta'), findsNothing);
    expect(find.text('No tienes cortes abiertos.'), findsOneWidget);
  });
}
