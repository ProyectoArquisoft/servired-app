import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:servired_app/core/network/api_client.dart';
import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/core/router/routes.dart';
import 'package:servired_app/features/reports/data/reports_repository.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';
import 'package:servired_app/l10n/app_localizations.dart';
import 'package:servired_app/shared/widgets/service_style.dart';

/// RF2: el ciudadano elige uno de sus cortes abiertos y avisa que volvió el
/// servicio. Luego la comunidad lo valida (RF3).
class RestorationScreen extends ConsumerStatefulWidget {
  const RestorationScreen({super.key});

  @override
  ConsumerState<RestorationScreen> createState() => _RestorationScreenState();
}

class _RestorationScreenState extends ConsumerState<RestorationScreen> {
  /// Una llave por reporte, reutilizada si el ciudadano reintenta.
  final _keys = <int, String>{};
  int? _sendingId;

  Future<void> _confirm(Reporte reporte) async {
    final l10n = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restorationConfirmTitle),
        content: Text(
          l10n.restorationConfirmBody(
            reporte.tipoServicio.label(l10n),
            reporte.codigoTrazabilidad,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.restorationConfirm),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sendingId = reporte.idReporte);
    try {
      await ref
          .read(reportsRepositoryProvider)
          .notifyRestoration(
            reporte.idReporte,
            idempotencyKey: _keys.putIfAbsent(
              reporte.idReporte,
              newIdempotencyKey,
            ),
          );
      _keys.remove(reporte.idReporte);
      messenger.showSnackBar(SnackBar(content: Text(l10n.restorationDone)));
      ref.invalidate(openReportsProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      // 409: ya se había reportado; la lista se actualiza para reflejarlo.
      if (e.status == 409) ref.invalidate(openReportsProvider);
    } finally {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reports = ref.watch(openReportsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeReportRestoration)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(openReportsProvider.future),
        child: reports.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Message(
            icon: Icons.cloud_off,
            text: error is ApiException
                ? error.message
                : l10n.restorationLoadError,
            action: FilledButton(
              onPressed: () => ref.invalidate(openReportsProvider),
              child: Text(l10n.retry),
            ),
          ),
          data: (list) => list.isEmpty
              ? _Message(
                  icon: Icons.inbox_outlined,
                  text: l10n.restorationEmpty,
                  action: FilledButton.icon(
                    icon: const Icon(Icons.power_off_outlined),
                    label: Text(l10n.homeReportOutage),
                    onPressed: () => context.pushReplacement(Routes.newOutage),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(l10n.restorationHint),
                    const SizedBox(height: 12),
                    for (final reporte in list)
                      _ReportTile(
                        reporte: reporte,
                        sending: _sendingId == reporte.idReporte,
                        onTap: _sendingId == null
                            ? () => _confirm(reporte)
                            : null,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.reporte,
    required this.sending,
    required this.onTap,
  });

  final Reporte reporte;
  final bool sending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Los símbolos de fecha en español los carga flutter_localizations.
    final fecha = DateFormat.yMMMd(
      Localizations.localeOf(context).languageCode,
    ).add_jm().format(reporte.fechaCreacion.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ServiceAvatar(reporte.tipoServicio),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reporte.tipoServicio.label(l10n),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(reporte.codigoTrazabilidad),
                    Text(
                      l10n.reportedOn(fecha),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    EstadoChip(reporte.estado),
                  ],
                ),
              ),
              if (sending)
                const SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                const Icon(Icons.check_circle_outline, size: 32),
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
    // ListView para que el "jalar para actualizar" funcione también aquí.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 56),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    );
  }
}
