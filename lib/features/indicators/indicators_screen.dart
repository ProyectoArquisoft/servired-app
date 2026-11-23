import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/core/router/routes.dart';
import 'package:servired_app/features/reports/data/reports_repository.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';

/// Resumen calculado a partir de los reportes del ciudadano.
class IndicatorSummary {
  const IndicatorSummary({
    required this.totalReports,
    required this.openReports,
    required this.restoredReports,
    required this.byService,
    required this.updatedAt,
  });

  final int totalReports;

  /// Cortes que siguen vigentes (`ACTIVO` o `EN_ATENCION`).
  final int openReports;

  /// Cortes con restablecimiento reportado, restablecidos o cerrados.
  final int restoredReports;
  final Map<String, int> byService;
  final DateTime updatedAt;

  factory IndicatorSummary.fromReports(List<Reporte> reports) {
    var open = 0;
    final countsByService = <String, int>{};
    for (final r in reports) {
      if (r.estado.isOpen) open++;
      final name = _serviceName(r.tipoServicio);
      countsByService[name] = (countsByService[name] ?? 0) + 1;
    }
    return IndicatorSummary(
      totalReports: reports.length,
      openReports: open,
      restoredReports: reports.length - open,
      byService: countsByService,
      updatedAt: DateTime.now(),
    );
  }
}

String _serviceName(TipoServicio tipo) => switch (tipo) {
  TipoServicio.energia => 'Energía',
  TipoServicio.gas => 'Gas',
  TipoServicio.acueducto => 'Acueducto',
  TipoServicio.alcantarillado => 'Alcantarillado',
  TipoServicio.aseo => 'Aseo',
  TipoServicio.desconocido => 'Otro',
};

class IndicatorsScreen extends ConsumerWidget {
  const IndicatorsScreen({super.key});

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Indicadores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar indicadores',
            onPressed: reports.isLoading
                ? null
                : () => ref.invalidate(myReportsProvider),
            icon: reports.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myReportsProvider.future),
        child: reports.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                error is ApiException
                    ? error.message
                    : 'No pudimos calcular los indicadores.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(myReportsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
          data: (list) => _content(context, IndicatorSummary.fromReports(list)),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, IndicatorSummary summary) {
    final sortedServices = summary.byService.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final restoredRatio = summary.totalReports == 0
        ? 0.0
        : summary.restoredReports / summary.totalReports;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total reportes',
                value: '${summary.totalReports}',
                icon: Icons.assignment_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'Abiertos',
                value: '${summary.openReports}',
                icon: Icons.schedule_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                title: 'Restablecidos',
                value: '${summary.restoredReports}',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tasa de restablecimiento',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('${(restoredRatio * 100).toStringAsFixed(0)}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: restoredRatio),
                const SizedBox(height: 8),
                Text(
                  'Actualizado a las ${_formatTime(summary.updatedAt)} '
                  '(fuente: tus reportes)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Reportes por servicio',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (sortedServices.isEmpty)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Aún no has reportado cortes para calcular métricas por servicio.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => context.go(Routes.newOutage),
                    child: const Text('Reportar un corte'),
                  ),
                ],
              ),
            ),
          )
        else
          ...sortedServices.map((entry) {
            final share = summary.totalReports == 0
                ? 0.0
                : entry.value / summary.totalReports;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text('${entry.value}'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: share),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
