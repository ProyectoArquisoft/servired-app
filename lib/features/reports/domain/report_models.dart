/// Modelos alineados con `servired-public.yaml` (v0.1.0).
library;

enum TipoServicio { energia, gas, acueducto, alcantarillado, aseo, desconocido }

TipoServicio _tipoFrom(Object? value) => switch (value) {
  'ENERGIA' => TipoServicio.energia,
  'GAS' => TipoServicio.gas,
  'ACUEDUCTO' => TipoServicio.acueducto,
  'ALCANTARILLADO' => TipoServicio.alcantarillado,
  'ASEO' => TipoServicio.aseo,
  _ => TipoServicio.desconocido,
};

enum Severidad {
  baja('BAJA'),
  media('MEDIA'),
  alta('ALTA');

  const Severidad(this.api);
  final String api;

  static Severidad? fromApi(Object? value) =>
      values.where((s) => s.api == value).firstOrNull;
}

enum EstadoReporte {
  activo('ACTIVO'),
  enAtencion('EN_ATENCION'),
  restablecimientoReportado('RESTABLECIMIENTO_REPORTADO'),
  restablecido('RESTABLECIDO'),
  cerrado('CERRADO');

  const EstadoReporte(this.api);
  final String api;

  /// El corte sigue vigente: se puede reportar que volvió el servicio.
  bool get isOpen => this == activo || this == enAtencion;

  static EstadoReporte fromApi(Object? value) =>
      values.firstWhere((e) => e.api == value, orElse: () => activo);
}

class Servicio {
  const Servicio({
    required this.idServicio,
    required this.tipo,
    required this.descripcion,
  });

  factory Servicio.fromJson(Map<String, dynamic> json) => Servicio(
    idServicio: (json['idServicio'] as num).toInt(),
    tipo: _tipoFrom(json['tipo']),
    descripcion: json['descripcion'] as String,
  );

  final int idServicio;
  final TipoServicio tipo;
  final String descripcion;
}

/// Datos que el ciudadano llena en el flujo de 3 pasos.
class NuevoReporte {
  const NuevoReporte({
    required this.idServicio,
    required this.lat,
    required this.lng,
    this.descripcion,
    this.severidad,
    this.evidenciaPath,
  });

  final int idServicio;
  final double lat;
  final double lng;
  final String? descripcion;
  final Severidad? severidad;

  /// Ruta local de la foto ya comprimida y sin EXIF.
  final String? evidenciaPath;
}

/// `Reporte` del contrato. Los campos del detalle son `null` en las listas
/// (`ReporteResumen`).
class Reporte {
  const Reporte({
    required this.idReporte,
    required this.codigoTrazabilidad,
    required this.idServicio,
    required this.tipoServicio,
    required this.estado,
    required this.lat,
    required this.lng,
    required this.fechaCreacion,
    required this.totalValidaciones,
    this.severidad,
    this.departamento,
    this.municipio,
    this.fechaResolucion,
    this.descripcion,
    this.evidenciaUrl,
    this.esMio,
  });

  factory Reporte.fromJson(Map<String, dynamic> json) => Reporte(
    idReporte: (json['idReporte'] as num).toInt(),
    codigoTrazabilidad: json['codigoTrazabilidad'] as String,
    idServicio: (json['idServicio'] as num).toInt(),
    tipoServicio: _tipoFrom(json['tipoServicio']),
    estado: EstadoReporte.fromApi(json['estado']),
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    fechaCreacion: DateTime.parse(json['fechaCreacion'] as String),
    totalValidaciones: (json['totalValidaciones'] as num?)?.toInt() ?? 0,
    severidad: Severidad.fromApi(json['severidad']),
    departamento: json['departamento'] as String?,
    municipio: json['municipio'] as String?,
    fechaResolucion: json['fechaResolucion'] == null
        ? null
        : DateTime.parse(json['fechaResolucion'] as String),
    descripcion: json['descripcion'] as String?,
    evidenciaUrl: json['evidenciaUrl'] as String?,
    esMio: json['esMio'] as bool?,
  );

  final int idReporte;
  final String codigoTrazabilidad;
  final int idServicio;
  final TipoServicio tipoServicio;
  final EstadoReporte estado;
  final double lat;
  final double lng;
  final DateTime fechaCreacion;
  final int totalValidaciones;
  final Severidad? severidad;
  final String? departamento;
  final String? municipio;
  final DateTime? fechaResolucion;
  final String? descripcion;
  final String? evidenciaUrl;
  final bool? esMio;
}

/// Respuesta de `POST /api/reportes/{id}/validaciones`.
class Validacion {
  const Validacion({
    required this.idReporte,
    required this.totalValidaciones,
    required this.validacionesRequeridas,
    required this.estadoReporte,
  });

  factory Validacion.fromJson(Map<String, dynamic> json) => Validacion(
    idReporte: (json['idReporte'] as num).toInt(),
    totalValidaciones: (json['totalValidaciones'] as num).toInt(),
    validacionesRequeridas: (json['validacionesRequeridas'] as num).toInt(),
    estadoReporte: EstadoReporte.fromApi(json['estadoReporte']),
  );

  final int idReporte;
  final int totalValidaciones;
  final int validacionesRequeridas;
  final EstadoReporte estadoReporte;
}
