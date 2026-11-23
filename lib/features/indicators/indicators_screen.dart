import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:servired_app/core/router/routes.dart';
import 'package:servired_app/features/fraud/domain/fraud_history_notifier.dart';

class IndicatorSummary {
  const IndicatorSummary({
    required this.totalReports,
    required this.pendingReports,
    required this.sentReports,
    required this.byService,
    required this.updatedAt,
  });

  final int totalReports;
  final int pendingReports;
  final int sentReports;
  final Map<String, int> byService;
  final DateTime updatedAt;

  factory IndicatorSummary.fromHistory(List<FraudHistoryItem> items) {
    int pending = 0;
    int sent = 0;
    final countsByService = <String, int>{};

    for (final item in items) {
      if (item.status.toLowerCase() == 'enviado') {
        sent++;
      } else {
        pending++;
      }
      countsByService[item.service] = (countsByService[item.service] ?? 0) + 1;
    }

    return IndicatorSummary(
      totalReports: items.length,
      pendingReports: pending,
      sentReports: sent,
      byService: countsByService,
      updatedAt: DateTime.now(),
    );
  }
}

class IndicatorsScreen extends ConsumerStatefulWidget {
  const IndicatorsScreen({super.key, this.onRefreshExternal});

  /// Gancho opcional para consultar métricas desde la API cuando el backend esté listo.
  final Future<void> Function()? onRefreshExternal;

  @override
  ConsumerState<IndicatorsScreen> createState() => _IndicatorsScreenState();
}

class _IndicatorsScreenState extends ConsumerState<IndicatorsScreen> {
  bool _isRefreshing = false;
  DateTime _lastRefresh = DateTime.now();

  Future<void> _refreshIndicators() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      if (widget.onRefreshExternal != null) {
        await widget.onRefreshExternal!();
      }
      if (!mounted) return;
      setState(() => _lastRefresh = DateTime.now());
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(fraudHistoryProvider);
    final summary = IndicatorSummary.fromHistory(historyState.items);
    final sortedServices = summary.byService.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sentRatio = summary.totalReports == 0
        ? 0.0
        : summary.sentReports / summary.totalReports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Indicadores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar indicadores',
            onPressed: _isRefreshing ? null : _refreshIndicators,
            icon: _isRefreshing
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
        onRefresh: _refreshIndicators,
        child: ListView(
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
                    title: 'Pendientes',
                    value: '${summary.pendingReports}',
                    icon: Icons.schedule_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    title: 'Enviados',
                    value: '${summary.sentReports}',
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
                          'Tasa de envío completado',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text('${(sentRatio * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: sentRatio),
                    const SizedBox(height: 8),
                    Text(
                      'Actualizado a las ${_formatTime(_lastRefresh)} (fuente: historial local)',
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
                        'Aún no hay registros en el historial para calcular métricas por servicio.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => context.go(Routes.fraud),
                        child: const Text('Registrar denuncia'),
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
        ),
      ),
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
