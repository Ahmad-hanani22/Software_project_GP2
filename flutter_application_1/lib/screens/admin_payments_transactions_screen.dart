// lib/screens/admin_payments_transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

enum PaymentStatusFilter { all, pending, paid, failed }

const Color _primaryGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFF5F5F5);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class AdminPaymentsTransactionsScreen extends StatefulWidget {
  const AdminPaymentsTransactionsScreen({super.key});

  @override
  State<AdminPaymentsTransactionsScreen> createState() =>
      _AdminPaymentsTransactionsScreenState();
}

class _AdminPaymentsTransactionsScreenState
    extends State<AdminPaymentsTransactionsScreen> {
  bool _isLoading = true;
  List<dynamic> _allPayments = [];
  List<dynamic> _filteredPayments = [];
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  PaymentStatusFilter _statusFilter = PaymentStatusFilter.all;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (ok, data) = await ApiService.getAllPayments();
    if (mounted) {
      setState(() {
        if (ok) {
          _allPayments = data as List<dynamic>;
          _applyFilters();
        } else {
          _errorMessage = data.toString();
        }
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<dynamic> tempPayments = List.from(_allPayments);

    if (_statusFilter != PaymentStatusFilter.all) {
      final statusString = _statusFilter.toString().split('.').last;
      tempPayments =
          tempPayments.where((p) => p['status'] == statusString).toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempPayments = tempPayments.where((p) {
        final contract = p['contractId'] as Map<String, dynamic>? ?? {};
        final tenantName =
            contract['tenantId']?['name']?.toString().toLowerCase() ?? '';
        final propertyTitle =
            contract['propertyId']?['title']?.toString().toLowerCase() ?? '';

        return tenantName.contains(query) || propertyTitle.contains(query);
      }).toList();
    }

    setState(() {
      _filteredPayments = tempPayments;
    });
  }

  Future<void> _updatePaymentStatus(String paymentId, String newStatus) async {
    final (ok, message) = await ApiService.updatePayment(paymentId, newStatus);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? _primaryGreen : Colors.red,
      ));
      if (ok) {
        _fetchPayments();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('Payments & Transactions'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayments,
            tooltip: 'Refresh Payments',
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            searchController: _searchController,
            currentFilter: _statusFilter,
            onFilterChanged: (newFilter) {
              if (newFilter != null) {
                setState(() {
                  _statusFilter = newFilter;
                  _applyFilters();
                });
              }
            },
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _primaryGreen));
    }
    if (_errorMessage != null) {
      return Center(
          child: Text('Error: $_errorMessage',
              style: const TextStyle(color: Colors.red)));
    }
    if (_filteredPayments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Payments Found',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('Payments will appear here once they are submitted.',
                style: TextStyle(color: _textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPayments,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _filteredPayments.length,
        itemBuilder: (context, index) {
          return _PaymentCard(
            payment: _filteredPayments[index],
            onUpdateStatus: _updatePaymentStatus,
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final PaymentStatusFilter currentFilter;
  final ValueChanged<PaymentStatusFilter?> onFilterChanged;

  const _FilterBar(
      {required this.searchController,
      required this.currentFilter,
      required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search by tenant or property...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<PaymentStatusFilter>(
              value: currentFilter,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: PaymentStatusFilter.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.toString().split('.').last.toUpperCase()),
                );
              }).toList(),
              onChanged: onFilterChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final Function(String paymentId, String newStatus) onUpdateStatus;

  const _PaymentCard({required this.payment, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final contractData = payment['contractId'] as Map<String, dynamic>? ?? {};
    final tenantData = contractData['tenantId'] as Map<String, dynamic>? ?? {};
    final propertyData =
        contractData['propertyId'] as Map<String, dynamic>? ?? {};

    final String status = payment['status'] ?? 'pending';
    final double amount = (payment['amount'] as num? ?? 0).toDouble();
    final String method = payment['method'] ?? 'N/A';
    final DateTime date =
        DateTime.parse(payment['date'] ?? DateTime.now().toIso8601String());

    final currencyFormat =
        NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 2);
    final dateFormat = DateFormat('d MMM, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(currencyFormat.format(amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: _primaryGreen)),
                _buildStatusChip(status),
              ],
            ),
            const Divider(height: 20),
            _buildInfoRow(
                Icons.person_outline, 'Tenant:', tenantData['name'] ?? 'N/A'),
            _buildInfoRow(Icons.home_outlined, 'Property:',
                propertyData['title'] ?? 'N/A'),
            const Divider(height: 20, thickness: 0.5),
            _buildInfoRow(Icons.credit_card, 'Method:', method.toUpperCase()),
            _buildInfoRow(Icons.date_range, 'Date:', dateFormat.format(date)),
            _buildInfoRow(Icons.vpn_key, 'Payment ID:', payment['_id']),
            if (status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Approve'),
                      onPressed: () => onUpdateStatus(payment['_id'], 'paid'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.highlight_off, size: 16),
                      label: const Text('Fail'),
                      onPressed: () => onUpdateStatus(payment['_id'], 'failed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    Color textColor;

    switch (status) {
      case 'paid':
        chipColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'failed':
        chipColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case 'pending':
      default:
        chipColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
    }
    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: chipColor,
      labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _textSecondary)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: _textPrimary))),
        ],
      ),
    );
  }
}
