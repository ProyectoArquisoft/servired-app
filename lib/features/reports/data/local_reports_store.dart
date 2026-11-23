import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:servired_app/features/reports/domain/report_models.dart';

/// Reportes creados en este dispositivo por el usuario de la sesión.
///
/// Garantiza que "Mis reportes" muestre al instante lo que el ciudadano acaba
/// de enviar, aunque el backend aún no devuelva el reporte en `mios=true`
/// (mock sin estado, red caída o lista con retraso). Cuando el backend sí lo
/// devuelve, la copia local se descarta (ver [Reporte.sameAs]).
class LocalReportsStore {
  LocalReportsStore(String? owner)
    : _key = 'local_reports_v1:${owner ?? 'anon'}';

  final String _key;

  Future<List<Reporte>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Reporte.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> add(Reporte reporte) async {
    try {
      final current = await load();
      final prefs = await SharedPreferences.getInstance();
      final next = [reporte, ...current].take(100).toList();
      await prefs.setString(
        _key,
        jsonEncode(next.map((r) => r.toJson()).toList()),
      );
    } on Object {
      // Es solo un respaldo local: si falla, el envío al backend ya se hizo.
    }
  }

  Future<Reporte?> find(int idReporte) async =>
      (await load()).where((r) => r.idReporte == idReporte).firstOrNull;
}
