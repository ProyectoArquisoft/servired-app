import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:servired_app/core/location/location_service.dart';
import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/features/reports/data/reports_repository.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';
import 'package:servired_app/l10n/app_localizations.dart';
import 'package:servired_app/shared/widgets/service_style.dart';

/// Radio máximo para confirmar un restablecimiento (contrato: 500 m).
const validationRadiusMeters = 500.0;

/// Aviso de restablecimiento cercano al ciudadano.
class NearbyReport {
  const NearbyReport(this.reporte, this.meters);

  final Reporte reporte;
  final double meters;
}

/// Resultado de buscar avisos cerca: la posición y los reportes, o el motivo
/// por el que no se pudo ubicar al ciudadano.
class NearbyReports {
  const NearbyReports({this.origin, this.failure, this.items = const []});

  final LatLng? origin;
  final LocationFailure? failure;
  final List<NearbyReport> items;
}

final nearbyReportsProvider = FutureProvider.autoDispose<NearbyReports>((
  ref,
) async {
  final location = await ref.watch(locationServiceProvider).current();
  final origin = location.point;
  if (origin == null) return NearbyReports(failure: location.failure);

  // ~0.0065° ≈ 720 m: cubre el radio de 500 m; el filtro exacto es abajo.
  const delta = 0.0065;
  final list = await ref
      .watch(reportsRepositoryProvider)
      .listByBbox(
        minLng: origin.longitude - delta,
        minLat: origin.latitude - delta,
        maxLng: origin.longitude + delta,
        maxLat: origin.latitude + delta,
        estado: EstadoReporte.restablecimientoReportado,
      );

  const distance = Distance();
  final items =
      [
        for (final reporte in list)
          // Quien reportó no puede confirmar su propio aviso (409).
          if (reporte.esMio != true)
            NearbyReport(
              reporte,
              distance.as(
                LengthUnit.Meter,
                origin,
                LatLng(reporte.lat, reporte.lng),
              ),
            ),
      ].where((n) => n.meters <= validationRadiusMeters).toList()
        ..sort((a, b) => a.meters.compareTo(b.meters));
  return NearbyReports(origin: origin, items: items);
});

/// RF3: el ciudadano confirma, desde su ubicación, que el servicio volvió.
class ValidationScreen extends ConsumerStatefulWidget {
  const ValidationScreen({super.key});

  @override
  ConsumerState<ValidationScreen> createState() => _ValidationScreenState();
}

class _ValidationScreenState extends ConsumerState<ValidationScreen> {
  /// Una llave por reporte, reutilizada si el ciudadano reintenta.
  final _keys = <int, String>{};
  int? _sendingId;

  Future<void> _confirm(NearbyReport nearby, LatLng origin) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = nearby.reporte.idReporte;
    setState(() => _sendingId = id);
    try {
      final result = await ref
          .read(reportsRepositoryProvider)
          .validate(
            id,
            lat: origin.latitude,
            lng: origin.longitude,
            idempotencyKey: _keys.putIfAbsent(id, newIdempotencyKey),
          );
      _keys.remove(id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.estadoReporte == EstadoReporte.restablecido
                ? l10n.validateRestored
                : l10n.validateProgress(
                    result.totalValidaciones,
                    result.validacionesRequeridas,
                  ),
          ),
        ),
      );
      ref.invalidate(nearbyReportsProvider);
    } on ApiException catch (e) {
      final message = switch (e.status) {
        409 => l10n.validateConflict,
        422 => l10n.validateTooFar,
        _ => e.message,
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
      if (e.status == 409) ref.invalidate(nearbyReportsProvider);
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nearby = ref.watch(nearbyReportsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeValidate)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(nearbyReportsProvider.future),
        child: nearby.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(
            icon: Icons.cloud_off,
            text: error is ApiException ? error.message : l10n.mapLoadError,
            action: FilledButton(
              onPressed: () => ref.invalidate(nearbyReportsProvider),
              child: Text(l10n.retry),
            ),
          ),
          data: (data) {
            final origin = data.origin;
            if (origin == null) {
              final blocked = data.failure == LocationFailure.deniedForever;
              return _Message(
                icon: Icons.location_off_outlined,
                text: blocked
                    ? l10n.validateLocationBlocked
                    : l10n.validateNeedLocation,
                action: blocked
                    ? null
                    : FilledButton(
                        onPressed: () => ref.invalidate(nearbyReportsProvider),
                        child: Text(l10n.validateAllow),
                      ),
              );
            }
            if (data.items.isEmpty) {
              return _Message(
                icon: Icons.inbox_outlined,
                text: l10n.validateEmpty,
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.validateHint),
                const SizedBox(height: 12),
                for (final item in data.items)
                  _NearbyTile(
                    item: item,
                    sending: _sendingId == item.reporte.idReporte,
                    onConfirm: _sendingId == null
                        ? () => _confirm(item, origin)
                        : null,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NearbyTile extends StatelessWidget {
  const _NearbyTile({
    required this.item,
    required this.sending,
    required this.onConfirm,
  });

  final NearbyReport item;
  final bool sending;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reporte = item.reporte;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ServiceAvatar(reporte.tipoServicio),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reporte.tipoServicio.label(l10n),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(l10n.reportCodeLabel(reporte.codigoTrazabilidad)),
                      Text(l10n.validateDistance(item.meters.round())),
                      Text(l10n.reportValidations(reporte.totalValidaciones)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onConfirm,
                child: sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.validateConfirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action),
        ],
      ],
    );
  }
}
