import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:servired_app/core/location/location_service.dart';
import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/features/reports/data/reports_repository.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';

enum LocationStatus { needsPermission, searching, found, manual, failed }

/// Borrador del reporte de corte mientras el ciudadano avanza por los 3 pasos.
class OutageDraft {
  const OutageDraft({
    required this.idempotencyKey,
    this.step = 1,
    this.servicio,
    this.point,
    this.locationStatus = LocationStatus.needsPermission,
    this.locationFailure,
    this.photoPath,
    this.severidad,
    this.descripcion = '',
    this.submitting = false,
    this.error,
    this.result,
  });

  /// Una por borrador: si el envío falla y se reintenta, el backend no duplica.
  final String idempotencyKey;
  final int step;
  final Servicio? servicio;
  final LatLng? point;
  final LocationStatus locationStatus;
  final LocationFailure? locationFailure;
  final String? photoPath;
  final Severidad? severidad;
  final String descripcion;
  final bool submitting;
  final ApiException? error;
  final Reporte? result;

  bool get canContinueFromStep2 => point != null;

  OutageDraft copyWith({
    int? step,
    Servicio? servicio,
    LatLng? point,
    LocationStatus? locationStatus,
    Object? locationFailure = _keep,
    Object? photoPath = _keep,
    Object? severidad = _keep,
    String? descripcion,
    bool? submitting,
    Object? error = _keep,
    Reporte? result,
  }) {
    return OutageDraft(
      idempotencyKey: idempotencyKey,
      step: step ?? this.step,
      servicio: servicio ?? this.servicio,
      point: point ?? this.point,
      locationStatus: locationStatus ?? this.locationStatus,
      locationFailure: locationFailure == _keep
          ? this.locationFailure
          : locationFailure as LocationFailure?,
      photoPath: photoPath == _keep ? this.photoPath : photoPath as String?,
      severidad: severidad == _keep ? this.severidad : severidad as Severidad?,
      descripcion: descripcion ?? this.descripcion,
      submitting: submitting ?? this.submitting,
      error: error == _keep ? this.error : error as ApiException?,
      result: result ?? this.result,
    );
  }
}

const _keep = Object();

final outageDraftProvider =
    NotifierProvider.autoDispose<OutageDraftController, OutageDraft>(
      OutageDraftController.new,
    );

class OutageDraftController extends Notifier<OutageDraft> {
  @override
  OutageDraft build() => OutageDraft(idempotencyKey: newIdempotencyKey());

  LocationService get _location => ref.read(locationServiceProvider);

  /// Paso 1 → 2. Si ya hay permiso, la ubicación se busca sola.
  Future<void> selectService(Servicio servicio) async {
    state = state.copyWith(servicio: servicio, step: 2);
    if (state.point == null && await _location.hasPermission()) {
      await locate();
    }
  }

  /// Pide la ubicación actual (y el permiso, si hace falta).
  Future<void> locate() async {
    state = state.copyWith(
      locationStatus: LocationStatus.searching,
      locationFailure: null,
    );
    final result = await _location.current();
    if (!ref.mounted) return;
    state = result.point != null
        ? state.copyWith(
            point: result.point,
            locationStatus: LocationStatus.found,
          )
        : state.copyWith(
            locationStatus: LocationStatus.failed,
            locationFailure: result.failure,
          );
  }

  void setManualLocation(LatLng point) {
    state = state.copyWith(
      point: point,
      locationStatus: LocationStatus.manual,
      locationFailure: null,
    );
  }

  void setPhoto(String? path) => state = state.copyWith(photoPath: path);

  /// Tocar la severidad ya elegida la quita (es opcional).
  void toggleSeverity(Severidad severidad) => state = state.copyWith(
    severidad: state.severidad == severidad ? null : severidad,
  );

  void setDescription(String text) => state = state.copyWith(descripcion: text);

  void goToStep(int step) => state = state.copyWith(step: step, error: null);

  Future<void> submit() async {
    final servicio = state.servicio;
    final point = state.point;
    if (servicio == null || point == null || state.submitting) return;

    state = state.copyWith(submitting: true, error: null);
    try {
      final reporte = await ref
          .read(reportsRepositoryProvider)
          .createOutage(
            NuevoReporte(
              idServicio: servicio.idServicio,
              lat: point.latitude,
              lng: point.longitude,
              descripcion: state.descripcion,
              severidad: state.severidad,
              evidenciaPath: state.photoPath,
            ),
            idempotencyKey: state.idempotencyKey,
          );
      // Respaldo local: "Mis reportes" lo muestra aunque el backend tarde.
      await ref
          .read(localReportsStoreProvider)
          .add(
            Reporte(
              idReporte: -DateTime.now().millisecondsSinceEpoch,
              codigoTrazabilidad: reporte.codigoTrazabilidad,
              idServicio: servicio.idServicio,
              tipoServicio: servicio.tipo,
              estado: EstadoReporte.activo,
              lat: point.latitude,
              lng: point.longitude,
              fechaCreacion: DateTime.now().toUtc(),
              totalValidaciones: 0,
              severidad: state.severidad,
              descripcion: state.descripcion.trim().isEmpty
                  ? null
                  : state.descripcion.trim(),
              evidenciaUrl: state.photoPath,
              esMio: true,
            ),
          );
      if (!ref.mounted) return;
      state = state.copyWith(submitting: false, result: reporte);
      // Que "Mis reportes" y los cortes abiertos muestren el reporte nuevo.
      ref
        ..invalidate(myReportsProvider)
        ..invalidate(openReportsProvider);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(submitting: false, error: e);
    }
  }
}
