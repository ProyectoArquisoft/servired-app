import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'package:servired_app/core/location/location_service.dart';
import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/features/reports/data/reports_repository.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';
import 'package:servired_app/l10n/app_localizations.dart';
import 'package:servired_app/shared/widgets/service_style.dart';

/// RF6 (solo lectura): reportes del área visible del mapa. Consulta por
/// `bbox` con un pequeño retraso para no pedir datos en cada gesto.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _bogota = LatLng(4.6097, -74.0817);
  static const _debounce = Duration(milliseconds: 600);

  final _controller = MapController();
  Timer? _timer;
  LatLng _center = _bogota;
  bool _ready = false;
  bool _loading = false;
  String? _error;
  List<Reporte> _reports = const [];
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _resolveCenter();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Centra el mapa en el ciudadano solo si ya dio permiso; si no, en Bogotá.
  Future<void> _resolveCenter() async {
    try {
      final location = ref.read(locationServiceProvider);
      if (await location.hasPermission()) {
        final result = await location.current();
        if (result.point case final point?) _center = point;
      }
    } on Exception {
      // Sin ubicación: se usa el centro por defecto.
    }
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _goToMe() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    if (result.point case final point?) {
      _controller.move(point, 15);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.mapLocationUnavailable)),
      );
    }
  }

  void _scheduleLoad() {
    _timer?.cancel();
    _timer = Timer(_debounce, _load);
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context);
    final bounds = _controller.camera.visibleBounds;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(reportsRepositoryProvider)
          .listByBbox(
            minLng: bounds.west.clamp(-180.0, 180.0).toDouble(),
            minLat: bounds.south.clamp(-90.0, 90.0).toDouble(),
            maxLng: bounds.east.clamp(-180.0, 180.0).toDouble(),
            maxLat: bounds.north.clamp(-90.0, 90.0).toDouble(),
          );
      if (!mounted || request != _request) return;
      setState(() => _reports = list);
    } on ApiException catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = e.message);
    } on Exception {
      if (!mounted || request != _request) return;
      setState(() => _error = l10n.mapLoadError);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _showDetail(Reporte reporte) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ReportDetailSheet(reporte: reporte),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeMap)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToMe,
        icon: const Icon(Icons.my_location),
        label: Text(l10n.mapMyLocation),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 14,
                    minZoom: 5,
                    maxZoom: 18,
                    onMapReady: _load,
                    onPositionChanged: (_, _) => _scheduleLoad(),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.servired.mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final reporte in _reports)
                          Marker(
                            point: LatLng(reporte.lat, reporte.lng),
                            width: 48,
                            height: 48,
                            child: GestureDetector(
                              onTap: () => _showDetail(reporte),
                              child: Center(
                                child: ServiceAvatar(
                                  reporte.tipoServicio,
                                  radius: 18,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                if (_loading)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(),
                  ),
                if (_error case final message?)
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_off),
                        title: Text(message),
                        trailing: TextButton(
                          onPressed: _load,
                          child: Text(l10n.retry),
                        ),
                      ),
                    ),
                  ),
                if (!_loading && _error == null && _reports.isEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 88,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          l10n.mapEmpty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Hoja con el resumen del reporte y, al cargar el detalle, su descripción y
/// su evidencia (URL firmada que entrega el backend).
class _ReportDetailSheet extends ConsumerWidget {
  const _ReportDetailSheet({required this.reporte});

  final Reporte reporte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final detail = ref.watch(reportDetailProvider(reporte.idReporte));
    final date = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(reporte.fechaCreacion.toLocal());

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ServiceAvatar(reporte.tipoServicio),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reporte.tipoServicio.label(l10n),
                    style: textTheme.titleLarge,
                  ),
                ),
                EstadoChip(reporte.estado),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.reportCodeLabel(reporte.codigoTrazabilidad)),
            Text(l10n.reportedOn(date)),
            if (reporte.municipio case final municipio?)
              Text(
                [
                  municipio,
                  if (reporte.departamento case final d?) d,
                ].join(', '),
              ),
            Text(l10n.reportValidations(reporte.totalValidaciones)),
            const SizedBox(height: 12),
            detail.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                error is ApiException ? error.message : l10n.mapDetailLoadError,
              ),
              data: (full) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (full.descripcion case final text?
                      when text.trim().isNotEmpty) ...[
                    Text(text),
                    const SizedBox(height: 12),
                  ],
                  if (full.evidenciaUrl case final url?) ...[
                    Text(l10n.reportEvidence, style: textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
