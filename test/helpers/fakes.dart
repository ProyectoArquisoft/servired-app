import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'package:servired_app/core/location/location_service.dart';
import 'package:servired_app/core/media/photo_service.dart';
import 'package:servired_app/features/auth/data/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this._signedIn = false});

  bool _signedIn;
  final _changes = StreamController<bool>.broadcast();

  @override
  bool get isSignedIn => _signedIn;

  @override
  String? get email => _signedIn ? 'ciudadano@ejemplo.com' : null;

  @override
  Stream<bool> authChanges() => _changes.stream;

  @override
  Future<String?> accessToken() async => _signedIn ? 'jwt-de-prueba' : null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _signedIn = true;
    _changes.add(true);
  }

  @override
  Future<bool> signUp({required String email, required String password}) async {
    await signIn(email: email, password: password);
    return true;
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    _changes.add(false);
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService({this.permission = true, this.result});

  bool permission;
  LocationResult? result;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<LocationResult> current() async =>
      result ?? const LocationResult.found(LatLng(4.6097, -74.0817));
}

class FakePhotoService implements PhotoService {
  @override
  Future<String?> pick({required bool fromCamera}) async => null;
}

/// Respuesta simulada del servidor.
class FakeResponse {
  const FakeResponse(this.status, [this.body, this.contentType]);

  final int status;
  final Object? body;
  final String? contentType;
}

/// Adaptador de dio que responde sin red y guarda las peticiones recibidas.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  /// Devuelve la respuesta, o lanza un [DioException] para simular sin red.
  final FakeResponse Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = handler(options);
    final body = response.body;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [
          response.contentType ??
              (response.status >= 400
                  ? 'application/problem+json'
                  : Headers.jsonContentType),
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter;

/// Cuerpos de ejemplo tomados de `servired-public.yaml`.
const servicesJson = [
  {'idServicio': 1, 'tipo': 'ENERGIA', 'descripcion': 'Energía eléctrica'},
  {
    'idServicio': 3,
    'tipo': 'ACUEDUCTO',
    'descripcion': 'Acueducto (agua potable)',
  },
];

Map<String, dynamic> reporteJson({
  int id = 1024,
  String estado = 'ACTIVO',
  String codigo = 'SR-2026-000124',
}) => {
  'idReporte': id,
  'codigoTrazabilidad': codigo,
  'idServicio': 1,
  'tipoServicio': 'ENERGIA',
  'tipoEvento': 'CORTE',
  'estado': estado,
  'severidad': 'ALTA',
  'departamento': 'Cundinamarca',
  'municipio': 'Bogotá D.C.',
  'lat': 4.6097,
  'lng': -74.0817,
  'fechaCreacion': '2026-10-26T13:05:00Z',
  'fechaResolucion': null,
  'totalValidaciones': 0,
};
