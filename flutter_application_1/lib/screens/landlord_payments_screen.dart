// lib/screens/landlord_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/landlord_dashboard_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

enum PaymentStatusFilter { all, pending, paid, failed }
enum MethodFilter { all, online, cash, bank, visa }

// --- Theme Colors ---
const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class LandlordPaymentsScreen extends StatefulWidget {
  const LandlordPaymentsScreen({super.key});

  @override
  State<LandlordPaymentsScreen> createState() => _LandlordPaymentsScreenState();
}

class _LandlordPaymentsScreenState extends State<LandlordPaymentsScreen> {
  bool _isLoading = true;
  List<dynamic> _allPayments = [];
  List<dynamic> _filteredPayments = [];
  String? _landlordId;
  String? _errorMessage;

  // Filters
  final TextEditingController _searchController = TextEditingController();
  PaymentStatusFilter _statusFilter = PaymentStatusFilter.all;
  MethodFilter _methodFilter = MethodFilter.all;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _landlordId = prefs.getString('userId');
    if (_landlordId != null) {
      _fetchPayments();
    }
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (ok, data) = await ApiService.getUserPayments(_landlordId!);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (ok) {
          // ✅ Filter payments where landlord is the owner (from contract.landlordId)
          // الباك إند الآن يقوم بـ populate كامل، لذلك يمكننا التصفية بشكل صحيح
          _allPayments = (data as List<dynamic>).where((payment) {
            final contract = payment['contractId'];
            if (contract == null) return false;
            
            final landlordId = contract['landlordId'];
            if (landlordId == null) return false;
            
            // Handle both populated object and ID string
            if (landlordId is Map) {
              return landlordId['_id'] == _landlordId || landlordId.toString() == _landlordId;
            }
            return landlordId == _landlordId || landlordId.toString() == _landlordId;
          }).toList();
          _applyFilters();
        } else {
          _errorMessage = data.toString();
        }
      });
    }
  }

  void _applyFilters() {
    List<dynamic> temp = List.from(_allPayments);

    // Status Filter
    if (_statusFilter != PaymentStatusFilter.all) {
      temp = temp.where((p) => p['status'] == _statusFilter.name).toList();
    }

    // Method Filter
    if (_methodFilter != MethodFilter.all) {
      temp = temp
          .where((p) =>
              p['method']?.toLowerCase() == _methodFilter.name.toLowerCase())
          .toList();
    }

    // Search Filter
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      temp = temp.where((p) {
        final c = p['contractId'] ?? {};
        final tenant = c['tenantId']?['name']?.toLowerCase() ?? '';
        final property = c['propertyId']?['title']?.toLowerCase() ?? '';
        final paymentId = p['_id']?.toLowerCase() ?? '';
        return tenant.contains(query) ||
            property.contains(query) ||
            paymentId.contains(query);
      }).toList();
    }

    // Sort by newest first
    temp.sort((a, b) =>
        DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    setState(() {
      _filteredPayments = temp;
    });
  }

  Map<String, dynamic> _getSummaryStats() {
    final paid = _filteredPayments.where((p) => p['status'] == 'paid').length;
    final pending =
        _filteredPayments.where((p) => p['status'] == 'pending').length;
    final failed =
        _filteredPayments.where((p) => p['status'] == 'failed').length;

    final totalRevenue = _filteredPayments
        .where((p) => p['status'] == 'paid')
        .fold(0.0, (sum, p) => sum + (p['amount'] ?? 0));

    return {
      'total': _filteredPayments.length,
      'paid': paid,
      'pending': pending,
      'failed': failed,
      'totalRevenue': totalRevenue,
    };
  }

  Future<void> _updateStatus(String id, String status) async {
    final (ok, msg) = await ApiService.updatePayment(id, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: ok ? _accentGreen : Colors.red,
        ),
      );
      if (ok) _fetchPayments();
    }
  }

  void _showPaymentDetails(dynamic payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentDetailsSheet(payment: payment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getSummaryStats();

    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 40),
          onPressed: () {
            // ✅ التحقق من إمكانية الرجوع (خاصة على الويب)
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // إذا لم يكن هناك صفحة سابقة، الانتقال إلى Dashboard
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const LandlordDashboardScreen(),
                ),
              );
            }
          },
          tooltip: 'Back',
        ),
        title: const Text(
          'Payments & Transactions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryBeige,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayments,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummaryCards(stats),
          // Filter Bar
          _FilterBar(
            searchController: _searchController,
            currentFilter: _statusFilter,
            methodFilter: _methodFilter,
            onFilterChanged: (f) {
              setState(() => _statusFilter = f!);
              _applyFilters();
            },
            onMethodChanged: (m) {
              setState(() => _methodFilter = m!);
              _applyFilters();
            },
          ),
          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        final spacing = isSmallScreen ? 8.0 : 12.0;
        final padding = isSmallScreen ? 12.0 : 16.0;
        
        // Format total revenue with K for thousands
        String revenueText;
        final revenue = stats['totalRevenue'] as double;
        if (revenue >= 1000) {
          revenueText = "\$${(revenue / 1000).toStringAsFixed(1)}K";
        } else {
          revenueText = "\$${revenue.toStringAsFixed(0)}";
        }
        
        return Container(
          padding: EdgeInsets.all(padding),
          color: Colors.white,
          child: isSmallScreen
              ? Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: "Total Payments",
                            value: stats['total'].toString(),
                            icon: Icons.payment,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: _SummaryCard(
                            title: "Total Revenue",
                            value: revenueText,
                            icon: Icons.attach_money,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: "Paid",
                            value: stats['paid'].toString(),
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: _SummaryCard(
                            title: "Pending",
                            value: stats['pending'].toString(),
                            icon: Icons.hourglass_empty,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: "Total Payments",
                        value: stats['total'].toString(),
                        icon: Icons.payment,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _SummaryCard(
                        title: "Total Revenue",
                        value: revenueText,
                        icon: Icons.attach_money,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _SummaryCard(
                        title: "Paid",
                        value: stats['paid'].toString(),
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _SummaryCard(
                        title: "Pending",
                        value: stats['pending'].toString(),
                        icon: Icons.hourglass_empty,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _accentGreen));
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
          onUpdateStatus: _updateStatus,
          onViewDetails: _showPaymentDetails,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 100;
        final valueFontSize = isSmallScreen ? 18.0 : 20.0;
        final titleFontSize = isSmallScreen ? 10.0 : 12.0;
        final iconSize = isSmallScreen ? 20.0 : 24.0;
        final padding = isSmallScreen ? 8.0 : 12.0;
        
        return Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: iconSize),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      color: _textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final PaymentStatusFilter currentFilter;
  final MethodFilter methodFilter;
  final ValueChanged<PaymentStatusFilter?> onFilterChanged;
  final ValueChanged<MethodFilter?> onMethodChanged;

  const _FilterBar({
    required this.searchController,
    required this.currentFilter,
    required this.methodFilter,
    required this.onFilterChanged,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        final spacing = isSmallScreen ? 8.0 : 12.0;
        final padding = isSmallScreen ? 8.0 : 12.0;
        
        return Container(
          padding: EdgeInsets.all(padding),
          color: Colors.white,
          child: isSmallScreen
              ? Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search by t...",
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<PaymentStatusFilter>(
                            value: currentFilter,
                            decoration: const InputDecoration(
                              labelText: "Status",
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 12),
                            items: PaymentStatusFilter.values.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s.name.toUpperCase(),
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: onFilterChanged,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: DropdownButtonFormField<MethodFilter>(
                            value: methodFilter,
                            decoration: const InputDecoration(
                              labelText: "Method",
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 12),
                            items: MethodFilter.values.map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m.name.toUpperCase(),
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: onMethodChanged,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: "Search by tenant, property, or payment ID...",
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    SizedBox(width: spacing),
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
                            child: Text(
                              s.name.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: onFilterChanged,
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<MethodFilter>(
                        value: methodFilter,
                        decoration: const InputDecoration(
                          labelText: "Method",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: MethodFilter.values.map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(
                              m.name.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: onMethodChanged,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final Function(String id, String status) onUpdateStatus;
  final Function(Map<String, dynamic>) onViewDetails;

  const _PaymentCard({
    required this.payment,
    required this.onUpdateStatus,
    required this.onViewDetails,
  });

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
      child: InkWell(
        onTap: () => onViewDetails(payment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _getPaymentMethodIcon(method),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currency.format(amount),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _accentGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(status),
                ],
              ),

              const Divider(height: 20),

              _row(Icons.person, "Tenant:", tenant['name'] ?? "N/A"),
              _row(Icons.home, "Property:", property['title'] ?? "N/A"),

              const Divider(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _getPaymentMethodIcon(method),
                    const SizedBox(width: 6),
                    const Text(
                      "Method:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        method.toUpperCase(),
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: _textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              _row(Icons.date_range, "Date:", dateFmt.format(date)),
              _row(Icons.vpn_key, "Payment ID:",
                  payment['_id'].toString().substring(0, 8) + "..."),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => onViewDetails(payment),
                    icon: const Icon(Icons.visibility),
                    label: const Text("View Details"),
                  ),
                  if (status == "pending") ...[
                    const SizedBox(width: 10),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(dynamic icon, String label, String value) {
    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(icon, size: 16, color: Colors.grey.shade600);
    } else if (icon is Widget) {
      iconWidget = icon;
    } else {
      iconWidget = const Icon(Icons.info, size: 16, color: Colors.grey);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _textSecondary,
            ),
          ),
          const SizedBox(width: 8),
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

  Widget _statusChip(String status) {
    late Color bg;
    late Color fg = Colors.white;

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

  Widget _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Icon(Icons.money, size: 16, color: Colors.green);
      case 'bank':
        return const Icon(Icons.account_balance, size: 16, color: Colors.blue);
      case 'online':
      case 'visa':
      case 'test_visa':
        return const Icon(Icons.credit_card, size: 16, color: Colors.purple);
      default:
        return const Icon(Icons.payment, size: 16);
    }
  }
}

class _PaymentDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> payment;

  const _PaymentDetailsSheet({required this.payment});

  @override
  Widget build(BuildContext context) {
    final contract = payment['contractId'] ?? {};
    final tenant = contract['tenantId'] ?? {};
    final property = contract['propertyId'] ?? {};

    final amount = (payment['amount'] ?? 0).toDouble();
    final method = payment['method'] ?? "N/A";
    final date = DateTime.parse(payment['date']);
    final status = payment['status'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Payment Details",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.payment, size: 64, color: _accentGreen),
                        const SizedBox(height: 16),
                        Text(
                          NumberFormat.simpleCurrency().format(amount),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: _accentGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: status == 'paid'
                                ? Colors.green
                                : status == 'failed'
                                    ? Colors.red
                                    : Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  // Details
                  _detailRow("Tenant:", tenant['name'] ?? "N/A"),
                  _detailRow("Property:", property['title'] ?? "N/A"),
                  _detailRow("Method:", method.toUpperCase()),
                  _detailRow("Date:", DateFormat('d MMM, yyyy').format(date)),
                  _detailRow("Payment ID:", payment['_id']),
                  if (payment['receiptUrl'] != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      "Receipt",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(title: const Text("Receipt")),
                              body: PhotoView(
                                imageProvider: CachedNetworkImageProvider(
                                  payment['receiptUrl'],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: payment['receiptUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => const Center(
                                child: Icon(Icons.error)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
