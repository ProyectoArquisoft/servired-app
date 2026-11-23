import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:servired_app/core/location/location_picker_screen.dart';
import 'package:servired_app/core/location/location_service.dart';
import 'package:servired_app/core/media/photo_service.dart';
import 'package:servired_app/core/router/routes.dart';
import 'package:servired_app/features/reports/data/reports_repository.dart';
import 'package:servired_app/features/reports/domain/report_models.dart';
import 'package:servired_app/features/reports/presentation/outage_draft_controller.dart';
import 'package:servired_app/l10n/app_localizations.dart';
import 'package:servired_app/shared/widgets/service_style.dart';

/// RF1: reportar un corte en 3 pasos (servicio → foto y ubicación → enviar).
class NewOutageScreen extends ConsumerWidget {
  const NewOutageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(outageDraftProvider);
    final controller = ref.read(outageDraftProvider.notifier);

    if (draft.result case final reporte?) {
      return _SentView(reporte: reporte);
    }

    return PopScope(
      // El botón "atrás" retrocede un paso antes de salir del flujo.
      canPop: draft.step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !draft.submitting) controller.goToStep(draft.step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.homeReportOutage),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(l10n.stepOf(draft.step)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LinearProgressIndicator(value: draft.step / 3),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: switch (draft.step) {
            1 => const _ServiceStep(),
            2 => const _PhotoLocationStep(),
            _ => const _ReviewStep(),
          },
        ),
      ),
    );
  }
}

// ── Paso 1 ────────────────────────────────────────────────────────────────

class _ServiceStep extends ConsumerWidget {
  const _ServiceStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final services = ref.watch(servicesProvider);
    final selected = ref.watch(outageDraftProvider.select((d) => d.servicio));

    return services.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorRetry(
        message: l10n.servicesLoadError,
        onRetry: () => ref.invalidate(servicesProvider),
      ),
      data: (list) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.step1Title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          for (final servicio in list)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: selected?.idServicio == servicio.idServicio
                    ? BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      )
                    : BorderSide.none,
              ),
              child: ListTile(
                minTileHeight: 72,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: ServiceAvatar(servicio.tipo),
                title: Text(
                  servicio.tipo.label(l10n),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Text(servicio.descripcion),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ref
                    .read(outageDraftProvider.notifier)
                    .selectService(servicio),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Paso 2 ────────────────────────────────────────────────────────────────

class _PhotoLocationStep extends ConsumerWidget {
  const _PhotoLocationStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(outageDraftProvider);
    final controller = ref.read(outageDraftProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.step2Title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const _LocationCard(),
              const SizedBox(height: 12),
              const _PhotoCard(),
              const SizedBox(height: 12),
              Text(
                l10n.severityTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (severidad, label) in [
                    (Severidad.baja, l10n.severityLow),
                    (Severidad.media, l10n.severityMedium),
                    (Severidad.alta, l10n.severityHigh),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: draft.severidad == severidad,
                      onSelected: (_) => controller.toggleSeverity(severidad),
                    ),
                ],
              ),
            ],
          ),
        ),
        _BottomBar(
          onBack: () => controller.goToStep(1),
          primaryLabel: l10n.continueButton,
          onPrimary: draft.canContinueFromStep2
              ? () => controller.goToStep(3)
              : null,
        ),
      ],
    );
  }
}

class _LocationCard extends ConsumerWidget {
  const _LocationCard();

  Future<void> _pickOnMap(BuildContext context, WidgetRef ref) async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerScreen(initial: ref.read(outageDraftProvider).point),
      ),
    );
    if (picked != null) {
      ref.read(outageDraftProvider.notifier).setManualLocation(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(outageDraftProvider);
    final controller = ref.read(outageDraftProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final (
      IconData icon,
      Color color,
      String text,
    ) = switch (draft.locationStatus) {
      LocationStatus.needsPermission => (
        Icons.my_location,
        scheme.primary,
        l10n.locationWhy,
      ),
      LocationStatus.searching => (
        Icons.gps_not_fixed,
        scheme.primary,
        l10n.locationSearching,
      ),
      LocationStatus.found => (
        Icons.check_circle,
        Colors.green.shade700,
        l10n.locationReady,
      ),
      LocationStatus.manual => (
        Icons.check_circle,
        Colors.green.shade700,
        l10n.locationManual,
      ),
      LocationStatus.failed => (
        Icons.location_off,
        scheme.error,
        switch (draft.locationFailure) {
          LocationFailure.denied => l10n.locationDenied,
          LocationFailure.deniedForever => l10n.locationDeniedForever,
          LocationFailure.serviceDisabled => l10n.locationServiceOff,
          _ => l10n.locationUnavailable,
        },
      ),
    };
    final hasPoint = draft.point != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.locationTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (draft.locationStatus == LocationStatus.searching)
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
              ],
            ),
            if (draft.point case final p?) ...[
              const SizedBox(height: 4),
              Text(
                '${p.latitude.toStringAsFixed(5)}, '
                '${p.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            if (!hasPoint && draft.locationStatus != LocationStatus.searching)
              FilledButton.icon(
                icon: const Icon(Icons.my_location),
                label: Text(l10n.locationUseMine),
                onPressed: controller.locate,
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: Text(
                hasPoint ? l10n.locationAdjust : l10n.locationPickOnMap,
              ),
              onPressed: () => _pickOnMap(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends ConsumerWidget {
  const _PhotoCard();

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref, {
    required bool fromCamera,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ref
          .read(photoServiceProvider)
          .pick(fromCamera: fromCamera);
      if (path != null) ref.read(outageDraftProvider.notifier).setPhoto(path);
    } on PlatformException catch (e) {
      final denied = e.code.contains('denied');
      messenger.showSnackBar(
        SnackBar(
          content: Text(denied ? l10n.photoPermission : l10n.photoError),
        ),
      );
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final photo = ref.watch(outageDraftProvider.select((d) => d.photoPath));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.photoOptional,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (photo != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(photo),
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 80,
                    child: Icon(Icons.image_outlined, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.photoRemove),
                onPressed: () =>
                    ref.read(outageDraftProvider.notifier).setPhoto(null),
              ),
            ] else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(l10n.photoTake),
                    onPressed: () => _pick(context, ref, fromCamera: true),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.photoGallery),
                    onPressed: () => _pick(context, ref, fromCamera: false),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Paso 3 ────────────────────────────────────────────────────────────────

class _ReviewStep extends ConsumerStatefulWidget {
  const _ReviewStep();

  @override
  ConsumerState<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<_ReviewStep> {
  late final _description = TextEditingController(
    text: ref.read(outageDraftProvider).descripcion,
  );

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = ref.watch(outageDraftProvider);
    final controller = ref.read(outageDraftProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.step3Title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _description,
                onChanged: controller.setDescription,
                enabled: !draft.submitting,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.descriptionLabel,
                  hintText: l10n.descriptionHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    if (draft.servicio case final s?)
                      ListTile(
                        leading: ServiceAvatar(s.tipo, radius: 18),
                        title: Text(l10n.summaryService),
                        subtitle: Text(s.tipo.label(l10n)),
                      ),
                    if (draft.point case final p?)
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(l10n.summaryLocation),
                        subtitle: Text(
                          '${p.latitude.toStringAsFixed(5)}, '
                          '${p.longitude.toStringAsFixed(5)}',
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.photo_outlined),
                      title: Text(l10n.summaryPhoto),
                      subtitle: Text(
                        draft.photoPath == null ? l10n.no : l10n.yes,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Junto al botón para que siempre se vea, sin desplazarse.
        if (draft.error case final error?)
          Semantics(
            liveRegion: true,
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  error.isNetwork ? Icons.wifi_off : Icons.error_outline,
                ),
                title: Text(error.message),
              ),
            ),
          ),
        _BottomBar(
          onBack: draft.submitting ? null : () => controller.goToStep(2),
          primaryLabel: draft.submitting
              ? l10n.sending
              : (draft.error != null ? l10n.retry : l10n.sendReport),
          primaryIcon: draft.submitting ? null : Icons.send,
          busy: draft.submitting,
          onPrimary: draft.submitting ? null : controller.submit,
        ),
      ],
    );
  }
}

// ── Confirmación ──────────────────────────────────────────────────────────

class _SentView extends StatelessWidget {
  const _SentView({required this.reporte});

  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeReportOutage),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.check_circle, size: 96, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              l10n.reportSentTitle,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(l10n.reportSentCode, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            SelectableText(
              reporte.codigoTrazabilidad,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reportSentHint,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.go(Routes.home),
              child: Text(l10n.goHome),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Comunes ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.busy = false,
  });

  final VoidCallback? onBack;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final IconData? primaryIcon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: onBack, child: Text(l10n.back)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onPrimary,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(primaryIcon ?? Icons.arrow_forward),
                label: Text(primaryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
