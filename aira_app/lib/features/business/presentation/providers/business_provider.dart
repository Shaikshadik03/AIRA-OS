import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aira_app/core/services/api_service.dart';

// ──────────────────── Models ────────────────────

class BusinessClient {
  final String id;
  final String name;
  final String? company;
  final String? email;
  final String? phone;
  final String? notes;
  final String status; // lead, active, inactive

  const BusinessClient({
    required this.id,
    required this.name,
    this.company,
    this.email,
    this.phone,
    this.notes,
    required this.status,
  });

  factory BusinessClient.fromJson(Map<String, dynamic> json) {
    return BusinessClient(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      company: json['company'],
      email: json['email'],
      phone: json['phone'],
      notes: json['notes'],
      status: json['status'] ?? 'lead',
    );
  }
}

class InvoiceResult {
  final String invoiceNumber;
  final double subtotal;
  final double tax;
  final double total;
  final String html;

  const InvoiceResult({
    required this.invoiceNumber,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.html,
  });

  factory InvoiceResult.fromJson(Map<String, dynamic> json) {
    return InvoiceResult(
      invoiceNumber: json['invoice_number'] ?? '',
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      tax: (json['tax'] ?? 0.0).toDouble(),
      total: (json['total'] ?? 0.0).toDouble(),
      html: json['html'] ?? '',
    );
  }
}

// ──────────────────── State ────────────────────

class BusinessState {
  final List<BusinessClient> clients;
  final InvoiceResult? generatedInvoice;
  final bool isLoading;
  final String? error;

  const BusinessState({
    this.clients = const [],
    this.generatedInvoice,
    this.isLoading = false,
    this.error,
  });

  BusinessState copyWith({
    List<BusinessClient>? clients,
    InvoiceResult? generatedInvoice,
    bool? isLoading,
    String? error,
  }) {
    return BusinessState(
      clients: clients ?? this.clients,
      generatedInvoice: generatedInvoice,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ──────────────────── Notifier ────────────────────

class BusinessNotifier extends StateNotifier<BusinessState> {
  final ApiService _api = ApiService();

  BusinessNotifier() : super(const BusinessState());

  Future<void> loadClients() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.listClients();
      final list = data.map((json) => BusinessClient.fromJson(json)).toList();
      state = state.copyWith(clients: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addClient(Map<String, dynamic> clientData) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.createClient(clientData);
      final newClient = BusinessClient.fromJson(res);
      state = state.copyWith(
        clients: [...state.clients, newClient],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to add client: $e');
    }
  }

  Future<void> deleteClient(String id) async {
    final previousClients = state.clients;
    state = state.copyWith(
      clients: state.clients.where((c) => c.id != id).toList(),
    );
    try {
      await _api.deleteClient(id);
    } catch (e) {
      state = state.copyWith(clients: previousClients, error: e.toString());
    }
  }

  Future<void> createInvoice(Map<String, dynamic> invoiceData) async {
    state = state.copyWith(isLoading: true, error: null, generatedInvoice: null);
    try {
      final res = await _api.generateInvoice(invoiceData);
      final invoice = InvoiceResult.fromJson(res);
      state = state.copyWith(generatedInvoice: invoice, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to compile invoice: $e');
    }
  }

  void clearInvoice() {
    state = state.copyWith(generatedInvoice: null);
  }
}

// ──────────────────── Provider ────────────────────

final businessProvider = StateNotifierProvider<BusinessNotifier, BusinessState>((ref) {
  return BusinessNotifier();
});
