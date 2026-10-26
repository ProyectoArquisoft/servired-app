import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servired_app/app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ServiRedApp()));
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

    await tester.tap(find.text('Reportar un corte'));
    await tester.pumpAndSettle();
    expect(
      find.text('Muy pronto vas a poder usar esta sección.'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute(); // botón "atrás" de Android
    await tester.pumpAndSettle();
    expect(find.text('¿Qué pasó con tu servicio?'), findsOneWidget);
  });
}
