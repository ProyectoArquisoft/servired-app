import 'package:flutter_riverpod/flutter_riverpod.dart';

class FraudHistoryItem {
  const FraudHistoryItem({
    required this.id,
    required this.reportId,
    required this.service,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.createdAt,
    this.status = 'Pendiente de envío',
  });

  final String id;
  final int reportId;
  final String service;
  final double latitude;
  final double longitude;
  final String description;
  final DateTime createdAt;
  final String status;

  FraudHistoryItem copyWith({
    String? id,
    int? reportId,
    String? service,
    double? latitude,
    double? longitude,
    String? description,
    DateTime? createdAt,
    String? status,
  }) {
    return FraudHistoryItem(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      service: service ?? this.service,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

class FraudHistoryState {
  const FraudHistoryState({
    this.items = const [],
    this.selectedService = 'Todos',
    this.searchQuery = '',
  });

  final List<FraudHistoryItem> items;
  final String selectedService;
  final String searchQuery;

  List<FraudHistoryItem> get filteredItems {
    return items.where((item) {
      final matchesService =
          selectedService == 'Todos' || item.service == selectedService;
      final q = searchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          item.description.toLowerCase().contains(q) ||
          item.reportId.toString().contains(q) ||
          item.service.toLowerCase().contains(q) ||
          item.status.toLowerCase().contains(q);
      return matchesService && matchesQuery;
    }).toList();
  }

  FraudHistoryState copyWith({
    List<FraudHistoryItem>? items,
    String? selectedService,
    String? searchQuery,
  }) {
    return FraudHistoryState(
      items: items ?? this.items,
      selectedService: selectedService ?? this.selectedService,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class FraudHistoryNotifier extends Notifier<FraudHistoryState> {
  @override
  FraudHistoryState build() => const FraudHistoryState();

  void addRecord(FraudHistoryItem item) {
    state = state.copyWith(items: [item, ...state.items]);
  }

  void updateStatus(String id, String status) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(status: status);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
  }

  void setServiceFilter(String service) {
    state = state.copyWith(selectedService: service);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearAll() {
    state = const FraudHistoryState();
  }
}

final fraudHistoryProvider =
NotifierProvider<FraudHistoryNotifier, FraudHistoryState>(
  FraudHistoryNotifier.new,
);