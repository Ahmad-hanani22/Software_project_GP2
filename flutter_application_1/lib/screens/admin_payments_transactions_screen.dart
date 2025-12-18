// lib/screens/admin_payments_transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

enum PaymentStatusFilter { all, pending, paid, failed }

enum SortOption { newest, oldest, highest, lowest }

enum MethodFilter { all, online, cash, bank }

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

  // For Notifications
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  final TextEditingController _searchController = TextEditingController();
  PaymentStatusFilter _statusFilter = PaymentStatusFilter.all;
  SortOption _sortOption = SortOption.newest;
  MethodFilter _methodFilter = MethodFilter.all;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
    _fetchNotifications();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =============================
  // FETCH PAYMENTS
  // =============================
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

  // =============================
  // FETCH NOTIFICATIONS
  // =============================
  Future<void> _fetchNotifications() async {
    final (ok, data) = await ApiService.getAllNotifications();
    if (mounted && ok) {
      setState(() {
        _notifications = data as List<dynamic>;
        _unreadCount = _notifications.where((n) => n['isRead'] == false).length;
      });
    }
  }

  // =============================
  // APPLY FILTERS & SORT
  // =============================
  void _applyFilters() {
    List<dynamic> temp = List.from(_allPayments);

    if (_statusFilter != PaymentStatusFilter.all) {
      temp = temp.where((p) => p['status'] == _statusFilter.name).toList();
    }

    if (_methodFilter != MethodFilter.all) {
      temp = temp
          .where((p) =>
              p['method']?.toLowerCase() == _methodFilter.name.toLowerCase())
          .toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      temp = temp.where((p) {
        final c = p['contractId'] ?? {};
        final tenant = c['tenantId']?['name']?.toLowerCase() ?? '';
        final property = c['propertyId']?['title']?.toLowerCase() ?? '';
        return tenant.contains(query) || property.contains(query);
      }).toList();
    }

    switch (_sortOption) {
      case SortOption.newest:
        temp.sort((a, b) => b['date'].compareTo(a['date']));
        break;
      case SortOption.oldest:
        temp.sort((a, b) => a['date'].compareTo(b['date']));
        break;
      case SortOption.highest:
        temp.sort((a, b) => (b['amount'] ?? 0).compareTo(a['amount'] ?? 0));
        break;
      case SortOption.lowest:
        temp.sort((a, b) => (a['amount'] ?? 0).compareTo(b['amount'] ?? 0));
        break;
    }

    setState(() => _filteredPayments = temp);
  }

  // =============================
  // UPDATE PAYMENT STATUS
  // =============================
  Future<void> _updatePaymentStatus(String paymentId, String newStatus) async {
    final (ok, msg) = await ApiService.updatePayment(paymentId, newStatus);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg), backgroundColor: ok ? _primaryGreen : Colors.red),
    );

    if (ok) _fetchPayments();
  }

  // =============================
  // DELETE PAYMENT (NEW)
  // =============================
  Future<void> _deletePayment(String paymentId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Transaction"),
        content:
            const Text("Are you sure you want to remove this payment record?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // يجب أن تكون هذه الدالة موجودة في ApiService
      final (ok, msg) = await ApiService.deletePayment(paymentId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok ? "Payment deleted" : msg),
            backgroundColor: ok ? _primaryGreen : Colors.red),
      );

      if (ok) {
        _fetchPayments();
      }
    }
  }

  // =============================
  // NOTIFICATIONS DIALOG
  // =============================
  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notifications"),
        content: SizedBox(
          width: 400,
          height: 300,
          child: _notifications.isEmpty
              ? const Center(child: Text("No notifications yet."))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    final bool isRead = n['isRead'] ?? false;

                    return ListTile(
                      leading: Icon(
                        Icons.notifications,
                        color: isRead ? Colors.grey : _primaryGreen,
                      ),
                      title: Text(n['message'] ?? '',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold)),
                      trailing: isRead
                          ? null
                          : const Icon(Icons.circle,
                              color: Colors.red, size: 10),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  // =============================
  // UI
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text("Payments & Transactions"),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort),
              onSelected: (v) {
                setState(() => _sortOption = v);
                _applyFilters();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: SortOption.newest, child: Text("Newest")),
                PopupMenuItem(value: SortOption.oldest, child: Text("Oldest")),
                PopupMenuItem(
                    value: SortOption.highest, child: Text("Highest Amount")),
                PopupMenuItem(
                    value: SortOption.lowest, child: Text("Lowest Amount")),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: PopupMenuButton<MethodFilter>(
              icon: const Icon(Icons.filter_alt),
              onSelected: (v) {
                setState(() => _methodFilter = v);
                _applyFilters();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: MethodFilter.all, child: Text("All Methods")),
                PopupMenuItem(
                    value: MethodFilter.online, child: Text("Online")),
                PopupMenuItem(value: MethodFilter.cash, child: Text("Cash")),
                PopupMenuItem(
                    value: MethodFilter.bank, child: Text("Bank Transfer")),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: _showStatsDialog,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _showNotificationsDialog,
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _fetchPayments();
                _fetchNotifications();
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            searchController: _searchController,
            currentFilter: _statusFilter,
            onFilterChanged: (f) {
              setState(() => _statusFilter = f!);
              _applyFilters();
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
          child: Text("Error: $_errorMessage",
              style: const TextStyle(color: Colors.red)));
    }
    if (_filteredPayments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment_outlined, size: 80, color: Colors.grey),
            Text("No Payments Found",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("Payments will appear once submitted."),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPayments,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredPayments.length,
        itemBuilder: (_, i) => _PaymentCard(
          payment: _filteredPayments[i],
          onUpdateStatus: _updatePaymentStatus,
          onDelete: _deletePayment, // Pass delete function
        ),
      ),
    );
  }

  void _showStatsDialog() {
    final paid = _allPayments.where((p) => p['status'] == 'paid').length;
    final pending = _allPayments.where((p) => p['status'] == 'pending').length;
    final failed = _allPayments.where((p) => p['status'] == 'failed').length;

    final totalRevenue = _allPayments
        .where((p) => p['status'] == 'paid')
        .fold(0.0, (sum, p) => sum + (p['amount'] ?? 0));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Statistics"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.attach_money),
              title:
                  Text("Total Revenue: \$${totalRevenue.toStringAsFixed(2)}"),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: Text("Paid: $paid"),
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: Text("Pending: $pending"),
            ),
            ListTile(
              leading: const Icon(Icons.error),
              title: Text("Failed: $failed"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final PaymentStatusFilter currentFilter;
  final ValueChanged<PaymentStatusFilter?> onFilterChanged;

  const _FilterBar({
    required this.searchController,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search by tenant or property...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                labelText: "Status",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: PaymentStatusFilter.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s.name.toUpperCase()),
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
  final Function(String id, String status) onUpdateStatus;
  final Function(String id) onDelete; // Delete function

  const _PaymentCard(
      {required this.payment,
      required this.onUpdateStatus,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final contract = payment['contractId'] ?? {};
    final tenant = contract['tenantId'] ?? {};
    final property = contract['propertyId'] ?? {};

    final status = payment['status'];
    final amount = (payment['amount'] ?? 0).toDouble();
    final method = payment['method'] ?? "N/A";
    final date = DateTime.parse(payment['date']);

    final dateFmt = DateFormat('d MMM, yyyy');
    final currency = NumberFormat.simpleCurrency();

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currency.format(amount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryGreen,
                  ),
                ),
                // زر الحذف والحالة
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => onDelete(payment['_id']),
                    ),
                    _statusChip(status),
                  ],
                )
              ],
            ),

            const Divider(height: 20),

            _row(Icons.person, "Tenant:", tenant['name'] ?? "N/A"),
            _row(Icons.home, "Property:", property['title'] ?? "N/A"),

            const Divider(height: 20),

            _row(Icons.credit_card, "Method:", method.toUpperCase()),
            _row(Icons.date_range, "Date:", dateFmt.format(date)),
            _row(Icons.vpn_key, "Payment ID:", payment['_id']),

            if (status == "pending")
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => onUpdateStatus(payment['_id'], "paid"),
                      icon: const Icon(Icons.check),
                      label: const Text("Approve"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => onUpdateStatus(payment['_id'], "failed"),
                      icon: const Icon(Icons.close),
                      label: const Text("Fail"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: _textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ تعديل الألوان لتكون بيضاء وواضحة
  Widget _statusChip(String status) {
    late Color bg;
    late Color fg = Colors.white; // النص دائماً أبيض

    switch (status) {
      case "paid":
        bg = Colors.green;
        break;
      case "failed":
        bg = Colors.red;
        break;
      default:
        bg = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
