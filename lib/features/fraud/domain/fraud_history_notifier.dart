import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  factory FraudHistoryItem.fromJson(Map<String, dynamic> json) =>
      FraudHistoryItem(
        id: json['id'] as String,
        reportId: (json['reportId'] as num).toInt(),
        service: json['service'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        description: json['description'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: json['status'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportId': reportId,
    'service': service,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
  };

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
      final matchesQuery =
          q.isEmpty ||
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

/// Historial de denuncias de este teléfono. Se guarda en el dispositivo
/// (nunca se envía) para que sobreviva al cierre de la app. Solo contiene lo
/// que el ciudadano escribió, sin ningún identificador suyo.
class FraudHistoryNotifier extends Notifier<FraudHistoryState> {
  static const _storageKey = 'fraud_history_v1';

  @override
  FraudHistoryState build() {
    _load();
    return const FraudHistoryState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || !ref.mounted) return;
      final saved = (jsonDecode(raw) as List<dynamic>)
          .map((e) => FraudHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      // Lo que se agregó mientras cargaba va primero y no se duplica.
      final known = state.items.map((i) => i.id).toSet();
      state = state.copyWith(
        items: [...state.items, ...saved.where((i) => !known.contains(i.id))],
      );
    } on Exception {
      // Sin almacenamiento local: el historial queda solo en memoria.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode(state.items.map((i) => i.toJson()).toList()),
      );
    } on Exception {
      // Sin almacenamiento local: el historial queda solo en memoria.
    }
  }

  void addRecord(FraudHistoryItem item) {
    state = state.copyWith(items: [item, ...state.items]);
    _save();
  }

  void updateStatus(String id, String status) {
    final updated = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(status: status);
      }
      return item;
    }).toList();
    state = state.copyWith(items: updated);
    _save();
  }

  void setServiceFilter(String service) {
    state = state.copyWith(selectedService: service);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearAll() {
    state = const FraudHistoryState();
    _save();
  }
}

final fraudHistoryProvider =
    NotifierProvider<FraudHistoryNotifier, FraudHistoryState>(
      FraudHistoryNotifier.new,
    );
