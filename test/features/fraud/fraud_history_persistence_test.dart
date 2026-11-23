import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:servired_app/features/fraud/domain/fraud_history_notifier.dart';

void main() {
  test('el historial de denuncias sobrevive al cierre de la app', () async {
    SharedPreferences.setMockInitialValues({});

    final first = ProviderContainer();
    first
        .read(fraudHistoryProvider.notifier)
        .addRecord(
          FraudHistoryItem(
            id: '1',
            reportId: 7,
            service: 'Energía',
            latitude: 4.7,
            longitude: -74.0,
            description: 'Conexión ilegal en el poste',
            createdAt: DateTime.utc(2026, 11, 23, 20),
            status: 'Enviada',
          ),
        );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    first.dispose();

    // Como al abrir la app otra vez: un contenedor nuevo carga lo guardado.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(fraudHistoryProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final items = second.read(fraudHistoryProvider).items;
    expect(items, hasLength(1));
    expect(items.single.reportId, 7);
    expect(items.single.status, 'Enviada');
  });
}
