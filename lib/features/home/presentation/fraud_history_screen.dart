import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:servired_app/features/fraud/domain/fraud_history_notifier.dart';

class FraudHistoryScreen extends ConsumerWidget {
  const FraudHistoryScreen({super.key});

  static const List<String> _services = [
    'Todos',
    'Energía',
    'Gas',
    'Acueducto',
    'Alcantarillado',
    'Aseo',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fraudHistoryProvider);
    final notifier = ref.read(fraudHistoryProvider.notifier);
    final items = state.filteredItems;
    final formatter = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de denuncias'),
        actions: [
          if (state.items.isNotEmpty)
            IconButton(
              tooltip: 'Limpiar historial',
              onPressed: notifier.clearAll,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por reporte o descripción',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: notifier.setSearchQuery,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _services.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final service = _services[index];
                final selected = state.selectedService == service;
                return ChoiceChip(
                  label: Text(service),
                  selected: selected,
                  onSelected: (_) => notifier.setServiceFilter(service),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(
              child: Text('No hay denuncias registradas con este filtro.'),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    title: Text(
                      'Reporte #${item.reportId} · ${item.service}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(item.description),
                        const SizedBox(height: 4),
                        Text(
                          'Coords: ${item.latitude}, ${item.longitude} · ${formatter.format(item.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: Chip(label: Text(item.status)),
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