import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fraud/domain/fraud_history_notifier.dart';

class MyReportsScreen extends ConsumerStatefulWidget {
  const MyReportsScreen({super.key, this.onRetrySend});

  /// Conecta aquí tu llamada real a la API cuando quieras reenviar un reporte pendiente.
  /// Debe devolver `true` si el envío fue exitoso o `false` si falló.
  final Future<bool> Function(FraudHistoryItem item)? onRetrySend;

  @override
  ConsumerState<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends ConsumerState<MyReportsScreen> {
  String _selectedStatus = 'Todos';
  final Set<String> _retryingIds = {};

  static const _statusFilters = ['Todos', 'Pendiente de envío', 'Enviado'];

  static const _serviceFilters = [
    'Todos',
    'Energía',
    'Agua',
    'Gas',
    'Internet',
  ];

  Future<void> _handleRetry(FraudHistoryItem item) async {
    if (_retryingIds.contains(item.id)) return;

    setState(() => _retryingIds.add(item.id));
    final notifier = ref.read(fraudHistoryProvider.notifier);

    try {
      final sentOk = widget.onRetrySend != null
          ? await widget.onRetrySend!(item)
          : false;

      if (!mounted) return;

      if (sentOk) {
        notifier.updateStatus(item.id, 'Enviado');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reporte #${item.reportId} enviado correctamente.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo enviar el reporte #${item.reportId}. Sigue pendiente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _retryingIds.remove(item.id));
      }
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(fraudHistoryProvider);
    final notifier = ref.read(fraudHistoryProvider.notifier);

    final services = <String>{
      ..._serviceFilters,
      for (final item in historyState.items) item.service,
    }.toList();

    final visibleItems = historyState.filteredItems.where((item) {
      if (_selectedStatus == 'Todos') return true;
      return item.status.toLowerCase() == _selectedStatus.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reportes'),
        actions: [
          if (historyState.items.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar historial',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => notifier.clearAll(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: notifier.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Buscar por ID, servicio, descripción o estado...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          // Filtro por estado
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final status = _statusFilters[index];
                final selected = _selectedStatus == status;
                return ChoiceChip(
                  label: Text(status),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedStatus = status),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Filtro por servicio usando FraudHistoryState.selectedService
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: services.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final service = services[index];
                final selected = historyState.selectedService == service;
                return FilterChip(
                  label: Text(service),
                  selected: selected,
                  onSelected: (_) => notifier.setServiceFilter(service),
                );
              },
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: visibleItems.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay reportes para mostrar con los filtros actuales.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final isPending =
                          item.status.toLowerCase() == 'pendiente de envío';
                      final isRetrying = _retryingIds.contains(item.id);

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Reporte #${item.reportId} · ${item.service}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Chip(
                                    label: Text(item.status),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(item.description),
                              const SizedBox(height: 8),
                              Text(
                                'Fecha: ${_formatDate(item.createdAt)} · '
                                '(${item.latitude.toStringAsFixed(4)}, '
                                '${item.longitude.toStringAsFixed(4)})',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (isPending) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.tonalIcon(
                                    onPressed: isRetrying
                                        ? null
                                        : () => _handleRetry(item),
                                    icon: isRetrying
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.refresh, size: 18),
                                    label: Text(
                                      isRetrying
                                          ? 'Enviando...'
                                          : 'Reintentar envío',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
