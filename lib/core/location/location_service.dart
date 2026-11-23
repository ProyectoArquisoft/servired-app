import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Por qué no se pudo obtener la ubicación.
enum LocationFailure { serviceDisabled, denied, deniedForever, unavailable }

/// Resultado de pedir la ubicación: un punto o el motivo del fallo.
class LocationResult {
  const LocationResult.found(LatLng this.point) : failure = null;
  const LocationResult.failed(LocationFailure this.failure) : point = null;

  final LatLng? point;
  final LocationFailure? failure;
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

abstract interface class LocationService {
  /// `true` si ya hay permiso; así la app no muestra la explicación previa.
  Future<bool> hasPermission();

  /// Pide permiso (si hace falta) y devuelve la posición actual.
  Future<LocationResult> current();
}

class GeolocatorLocationService implements LocationService {
  /// Una posición conocida más reciente que esto se usa sin esperar al GPS,
  /// para confirmar el reporte en menos de 3 s.
  static const _maxLastKnownAge = Duration(minutes: 2);

  @override
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<LocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failed(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        return const LocationResult.failed(LocationFailure.denied);
      case LocationPermission.deniedForever:
        return const LocationResult.failed(LocationFailure.deniedForever);
      case LocationPermission.always:
      case LocationPermission.whileInUse:
      case LocationPermission.unableToDetermine:
        break;
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp) < _maxLastKnownAge) {
        return LocationResult.found(LatLng(last.latitude, last.longitude));
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult.found(
        LatLng(position.latitude, position.longitude),
      );
    } on Exception {
      return const LocationResult.failed(LocationFailure.unavailable);
    }
  }
}
