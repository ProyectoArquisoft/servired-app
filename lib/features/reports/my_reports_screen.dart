import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/features/map/map_screen.dart';
import 'package:servired_app/features/reports/data/reports_repository.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';
import 'package:servired_app/l10n/app_localizations.dart';
import 'package:servired_app/shared/widgets/service_style.dart';

/// Reportes de corte creados por el ciudadano (`GET /api/reportes?mios=true`).
/// El historial de denuncias de fraude vive aparte, en su propia pantalla.
class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reports = ref.watch(myReportsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeMyReports)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myReportsProvider.future),
        child: reports.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(
            icon: Icons.cloud_off,
            text: error is ApiException
                ? error.message
                : l10n.myReportsLoadError,
            action: FilledButton(
              onPressed: () => ref.invalidate(myReportsProvider),
              child: Text(l10n.retry),
            ),
          ),
          data: (list) => list.isEmpty
              ? _Message(icon: Icons.inbox_outlined, text: l10n.myReportsEmpty)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _ReportTile(list[index]),
                ),
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.reporte);

  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(reporte.fechaCreacion.toLocal());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showReportDetail(context, reporte),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
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
                    Text(l10n.reportedOn(date)),
                    const SizedBox(height: 4),
                    EstadoChip(reporte.estado),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
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
