import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servired_app/app.dart';
import 'package:servired_app/core/location/location_service.dart';
import 'package:servired_app/core/media/photo_service.dart';
import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/features/auth/data/auth_repository.dart';

import '../../helpers/fakes.dart';

const _services = [
  (1, 'ENERGIA', 'Energía', 'Energía eléctrica'),
  (2, 'GAS', 'Gas', 'Gas natural / gas licuado'),
  (3, 'ACUEDUCTO', 'Acueducto', 'Acueducto (agua potable)'),
  (4, 'ALCANTARILLADO', 'Alcantarillado', 'Alcantarillado'),
  (5, 'ASEO', 'Aseo', 'Recolección de basuras y residuos'),
];

void main() {
  late File photo;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  setUpAll(() {
    // JPEG mínimo: al fake le basta con que el archivo exista.
    photo = File('${Directory.systemTemp.path}/servired_test_evidencia.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
  });

  Future<FakeAdapter> openFlow(WidgetTester tester) async {
    final api = FakeAdapter(
      (options) => switch ((options.method, options.path)) {
        ('GET', '/api/servicios') => FakeResponse(200, [
          for (final s in _services)
            {'idServicio': s.$1, 'tipo': s.$2, 'descripcion': s.$4},
        ]),
        ('POST', '/api/reportes') => FakeResponse(201, reporteJson()),
        _ => const FakeResponse(404),
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(signedIn: true),
          ),
          apiClientProvider.overrideWithValue(fakeDio(api)),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          photoServiceProvider.overrideWithValue(
            FakePhotoService(path: photo.path),
          ),
        ],
        child: const ServiRedApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reportar un corte'));
    await tester.pumpAndSettle();
    return api;
  }

  for (final (id, _, label, _) in _services) {
    testWidgets('envía el reporte de $label con foto de la galería', (
      tester,
    ) async {
      final api = await openFlow(tester);

      // `.first`: el buscador repite el tile si título y subtítulo coinciden.
      await tester.tap(find.widgetWithText(ListTile, label).first);
      await tester.pumpAndSettle();
      expect(find.text('Paso 2 de 3'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Galería'), 200);
      await tester.tap(find.text('Galería'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar reporte'));
      // Leer la foto del disco es E/S real: hay que dejar correr el reloj real.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(find.text('¡Recibimos tu reporte!'), findsOneWidget);

      final post = api.requests.singleWhere((r) => r.method == 'POST');
      final form = post.data as FormData;
      expect(Map.fromEntries(form.fields)['idServicio'], '$id');
      expect(form.files.map((f) => f.key), ['evidencia']);
    });
  }
}
