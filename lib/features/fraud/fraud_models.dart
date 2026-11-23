class FraudReportRequest {
  const FraudReportRequest({
    required this.idReporte,
    required this.idServicio,
    required this.descripcion,
    required this.lat,
    required this.lng,
  });

  final int idReporte;
  final int idServicio;
  final String descripcion;
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {
    'idReporte': idReporte,
    'idServicio': idServicio,
    'descripcion': descripcion.trim(),
    'lat': lat,
    'lng': lng,
  };
}

class FraudReportResponse {
  const FraudReportResponse({required this.estado, this.motivo});

  final String estado;
  final String? motivo;

  factory FraudReportResponse.fromJson(Map<String, dynamic> json) {
    return FraudReportResponse(
      estado: (json['estado'] ?? 'PENDIENTE_REVISION').toString(),
      motivo: json['motivo']?.toString(),
    );
  }
}
