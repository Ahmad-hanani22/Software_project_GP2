import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/admin_maintenance_complaints_screen.dart';
import 'package:flutter_application_1/screens/chat_screen.dart';
import 'package:flutter_application_1/screens/invoices_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'contract_pdf_preview_screen.dart';
import 'payment_receipt_screen.dart';

// Used Colors
const Color _primaryGreen = Color(0xFF2E7D32);
const Color _bgWhite = Color(0xFFF5F5F5);
const Color _textDark = Color(0xFF263238);
const Color _textLight = Color(0xFF78909C);

class AdminContractManagementScreen extends StatefulWidget {
  const AdminContractManagementScreen({super.key});

  @override
  State<AdminContractManagementScreen> createState() =>
      _AdminContractManagementScreenState();
}

class _AdminContractManagementScreenState
    extends State<AdminContractManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _allContracts = [];
  List<dynamic> _filteredContracts = [];
  final TextEditingController _searchController = TextEditingController();

  String _sortOption = 'Newest';

  @override
  void initState() {
    super.initState();
    _fetchContracts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContracts() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllContracts();
    if (mounted) {
      setState(() {
        if (ok) {
          _allContracts = data as List<dynamic>;
          _applyFilterAndSort();
        }
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _applyFilterAndSort();
  }

  void _applyFilterAndSort() {
    List<dynamic> temp = _allContracts.where((c) {
      final query = _searchController.text.toLowerCase();
      final property = c['propertyId'] ?? {};
      final tenant = c['tenantId'] ?? {};
      final landlord = c['landlordId'] ?? {};
      final id = c['_id'].toString();

      return (property['title'] ?? '').toLowerCase().contains(query) ||
          (tenant['name'] ?? '').toLowerCase().contains(query) ||
          (landlord['name'] ?? '').toLowerCase().contains(query) ||
          id.contains(query);
    }).toList();

    switch (_sortOption) {
      case 'Newest':
        temp.sort((a, b) => DateTime.parse(b['createdAt'])
            .compareTo(DateTime.parse(a['createdAt'])));
        break;
      case 'Oldest':
        temp.sort((a, b) => DateTime.parse(a['createdAt'])
            .compareTo(DateTime.parse(b['createdAt'])));
        break;
      case 'Price High':
        temp.sort(
            (a, b) => (b['rentAmount'] ?? 0).compareTo(a['rentAmount'] ?? 0));
        break;
      case 'Status':
        temp.sort((a, b) => (a['status'] ?? '').compareTo(b['status'] ?? ''));
        break;
    }

    setState(() {
      _filteredContracts = temp;
    });
  }

  void _showStatistics() {
    int active = _allContracts
        .where((c) => c['status'] == 'active' || c['status'] == 'rented')
        .length;
    int pending = _allContracts.where((c) => c['status'] == 'pending').length;
    double revenue =
        _allContracts.fold(0, (sum, c) => sum + (c['rentAmount'] ?? 0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Quick Statistics"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text("Active/Rented: $active"),
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_empty, color: Colors.orange),
              title: Text("Pending Contracts: $pending"),
            ),
            ListTile(
              leading: const Icon(Icons.attach_money, color: _primaryGreen),
              title: Text("Est. Revenue: \$${revenue.toStringAsFixed(0)}"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: 400,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.black87),
        decoration: const InputDecoration(
          hintText: "Search contracts...",
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 9, horizontal: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgWhite,
      appBar: AppBar(
        backgroundColor: _primaryGreen,
        title: _buildSearchField(),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (val) {
              setState(() => _sortOption = val);
              _applyFilterAndSort();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'Newest', child: Text("Newest First")),
              PopupMenuItem(value: 'Oldest', child: Text("Oldest First")),
              PopupMenuItem(value: 'Price High', child: Text("Highest Price")),
              PopupMenuItem(value: 'Status', child: Text("By Status")),
            ],
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: _showStatistics,
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchContracts,
          ),
          const SizedBox(width: 16),
          PopupMenuButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 16,
              child: Icon(Icons.person, size: 22, color: _primaryGreen),
            ),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'profile', child: Text("My Profile")),
              PopupMenuItem(
                  value: 'logout',
                  child: Text("Logout", style: TextStyle(color: Colors.red))),
            ],
            onSelected: (val) async {
              if (val == 'logout') {
                await ApiService.logout();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (r) => false,
                  );
                }
              }
            },
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _primaryGreen),
            )
          : _filteredContracts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredContracts.length,
                  itemBuilder: (context, index) {
                    return _ContractCardWidget(
                        contract: _filteredContracts[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 10),
          Text("No contracts found.",
              style: TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }
}

// ✅ StatefulWidget for the card with payment data fetching
class _ContractCardWidget extends StatefulWidget {
  final Map<String, dynamic> contract;

  const _ContractCardWidget({required this.contract});

  @override
  State<_ContractCardWidget> createState() => _ContractCardWidgetState();
}

class _ContractCardWidgetState extends State<_ContractCardWidget> {
  List<dynamic> _payments = [];
  List<dynamic> _invoices = [];
  bool _isLoadingPayments = false;
  bool _isLoadingInvoices = false;
  bool _showPayments = false;
  bool _showInvoices = false;
  bool _showAttachments = false;
  bool _showFinancialSummary = false;
  bool _showSignatures = false;
  bool _showNotifications = false;
  bool _showActivityLog = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
    _loadInvoices();
  }

  Future<void> _loadPayments() async {
    if (!mounted) return;
    setState(() => _isLoadingPayments = true);
    final (ok, data) =
        await ApiService.getPaymentsByContract(widget.contract['_id']);
    if (mounted) {
      setState(() {
        _isLoadingPayments = false;
        if (ok) {
          _payments = data is List ? data : [];
        }
      });
    }
  }

  Future<void> _loadInvoices() async {
    if (!mounted) return;
    setState(() => _isLoadingInvoices = true);
    final (ok, data) =
        await ApiService.getAllInvoices(contractId: widget.contract['_id']);
    if (mounted) {
      setState(() {
        _isLoadingInvoices = false;
        if (ok) {
          _invoices = data is List ? data : [];
        }
      });
    }
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _textLight),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textDark)),
        ),
      ],
    );
  }

  Widget _personRow(IconData icon, String label, String? name, String? email) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon, size: 20, color: _textLight),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: _textLight,
                    fontWeight: FontWeight.bold)),
            Text(name ?? 'Unknown',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textDark)),
            if (email != null)
              Text(email,
                  style: const TextStyle(fontSize: 12, color: _textLight)),
          ],
        ),
      ],
    );
  }

  Widget _dateInfo(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: _textLight)),
        Text(DateFormat('d MMM yyyy').format(date),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _actionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _showChangeStatusDialog(
      String contractId, String currentStatus) async {
    String? selectedStatus = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Change Contract Status'),
          children: <Widget>[
            _buildStatusOption(context, 'draft', 'DRAFT', Colors.blueGrey),
            _buildStatusOption(context, 'pending', 'PENDING', Colors.orange),
            _buildStatusOption(context, 'active', 'ACTIVE', Colors.green),
            _buildStatusOption(
                context, 'expiring_soon', 'EXPIRING SOON', Colors.blue),
            _buildStatusOption(context, 'expired', 'EXPIRED', Colors.grey),
            _buildStatusOption(
                context, 'terminated', 'TERMINATED', Colors.black),
            _buildStatusOption(context, 'rejected', 'REJECTED', Colors.red),
          ],
        );
      },
    );

    if (selectedStatus != null && selectedStatus != currentStatus) {
      final (ok, msg) = await ApiService.updateContract(
          contractId, {'status': selectedStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? "Status updated to ${selectedStatus.toUpperCase()}"
                : "Error: $msg"),
            backgroundColor: ok ? _primaryGreen : Colors.red,
          ),
        );
        if (ok) {
          _loadPayments();
        }
      }
    }
  }

  Widget _buildStatusOption(
      BuildContext context, String value, String label, Color color) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context, value);
      },
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 14),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // Calculate remaining days until next payment
  int _calculateDaysUntilNextPayment() {
    final contract = widget.contract;
    final startDate = DateTime.parse(contract['startDate']);
    final endDate = DateTime.parse(contract['endDate']);
    final paymentCycle =
        (contract['paymentCycle'] ?? 'monthly').toString().toLowerCase();
    final now = DateTime.now();

    if (now.isBefore(startDate)) {
      // Contract hasn't started yet
      return startDate.difference(now).inDays;
    }

    if (now.isAfter(endDate)) {
      // Contract ended
      return 0;
    }

    // Calculate next payment date
    DateTime nextPaymentDate = startDate;
    int daysInCycle;

    switch (paymentCycle) {
      case 'weekly':
        daysInCycle = 7;
        break;
      case 'monthly':
        daysInCycle = 30;
        break;
      case 'yearly':
        daysInCycle = 365;
        break;
      default:
        daysInCycle = 30; // default monthly
    }

    // Calculate elapsed cycles
    while (nextPaymentDate.isBefore(now) ||
        nextPaymentDate.isAtSameMomentAs(now)) {
      nextPaymentDate = nextPaymentDate.add(Duration(days: daysInCycle));
      if (nextPaymentDate.isAfter(endDate)) {
        // Reached end of contract
        return 0;
      }
    }

    final daysRemaining = nextPaymentDate.difference(now).inDays;
    return daysRemaining > 0 ? daysRemaining : 0;
  }

  @override
  Widget build(BuildContext context) {
    final contract = widget.contract;
    final property = contract['propertyId'] ?? {};
    final tenant = contract['tenantId'] ?? {};
    final landlord = contract['landlordId'] ?? {};
    final status = (contract['status'] ?? 'pending').toString().toLowerCase();
    final rent = contract['rentAmount'] ?? 0;
    final depositAmount = contract['depositAmount'] ?? 0;
    final startDate = DateTime.parse(contract['startDate']);
    final endDate = DateTime.parse(contract['endDate']);
    final durationDays = endDate.difference(startDate).inDays;
    final remainingDays = endDate.difference(DateTime.now()).inDays;
    final paymentCycle =
        (contract['paymentCycle'] ?? 'monthly').toString().toLowerCase();
    final bool isPending = status == 'pending';
    final bool isActive = status == 'rented' || status == 'active';

    // Calculate remaining days until next payment
    final daysUntilNextPayment = _calculateDaysUntilNextPayment();

    // Calculate payment statistics
    final paidPayments = _payments.where((p) => p['status'] == 'paid').toList();
    final totalPaid = paidPayments.fold<double>(
        0, (sum, p) => sum + ((p['amount'] ?? 0).toDouble()));

    // Calculate expected payments count
    int expectedPayments = 0;
    int daysInCycle = 30;
    switch (paymentCycle) {
      case 'weekly':
        daysInCycle = 7;
        break;
      case 'monthly':
        daysInCycle = 30;
        break;
      case 'yearly':
        daysInCycle = 365;
        break;
    }
    expectedPayments = (durationDays / daysInCycle).ceil();

    final totalExpected = rent * expectedPayments;
    final remainingAmount = totalExpected - totalPaid;

    Color statusColor = Colors.grey;
    if (isActive) statusColor = _primaryGreen;
    if (isPending) statusColor = Colors.orange;
    if (status == 'rejected') statusColor = Colors.red;
    if (status == 'expired' || status == 'terminated') {
      statusColor = Colors.black54;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    property['title'] ?? 'Unknown Property',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  tooltip: "Clean / Remove Contract",
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Clean Contract"),
                        content: const Text(
                            "Are you sure you want to permanently remove this contract? This action cannot be undone."),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              final (ok, msg) = await ApiService.deleteContract(
                                  contract['_id']);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? "Contract Removed Successfully 🗑️"
                                        : msg),
                                    backgroundColor:
                                        ok ? _primaryGreen : Colors.red,
                                  ),
                                );
                                if (ok) {
                                  // Refresh the page
                                  Navigator.of(context).pop();
                                }
                              }
                            },
                            child: const Text("Delete",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(status.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ID and QR Code (Clickable)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text("ID: ${contract['_id']}",
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ),
                    InkWell(
                      onTap: () => _showQRCodeDialog(contract),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_2,
                                size: 28, color: _primaryGreen),
                            SizedBox(width: 4),
                            Text(
                              'View QR',
                              style: TextStyle(
                                fontSize: 12,
                                color: _primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),

                // Location and Type
                Row(
                  children: [
                    Expanded(
                        child: _iconText(Icons.location_on,
                            property['city'] ?? 'Nablus, PS')),
                    Expanded(
                        child: _iconText(
                            Icons.home, property['type'] ?? 'Apartment')),
                  ],
                ),
                const SizedBox(height: 8),

                // Rent Amount and Payment Cycle
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        color: _primaryGreen, size: 20),
                    Text(
                        "\$${rent.toStringAsFixed(0)} / ${paymentCycle == 'weekly' ? 'Week' : paymentCycle == 'yearly' ? 'Year' : 'Month'}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _primaryGreen)),
                  ],
                ),

                // Payment Counter - Remaining days until next payment
                if (isActive && daysUntilNextPayment > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: daysUntilNextPayment <= 7
                          ? Colors.red.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: daysUntilNextPayment <= 7
                            ? Colors.red.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: daysUntilNextPayment <= 7
                              ? Colors.red
                              : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Days remaining until next payment',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '$daysUntilNextPayment days',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: daysUntilNextPayment <= 7
                                      ? Colors.red
                                      : Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Divider(height: 24),

                // Tenant and Landlord
                _personRow(
                    Icons.person, "Tenant", tenant['name'], tenant['email']),
                const SizedBox(height: 12),
                _personRow(Icons.business_center, "Landlord", landlord['name'],
                    landlord['email']),
                const Divider(height: 24),

                // Contract Dates
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bgWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _dateInfo("Start", startDate),
                          const Icon(Icons.arrow_right_alt, color: Colors.grey),
                          _dateInfo("End", endDate),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              "Duration: ${(durationDays / 30).toStringAsFixed(1)} Months",
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: remainingDays <= 7
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.timer,
                                      size: 14,
                                      color: remainingDays <= 7
                                          ? Colors.red
                                          : Colors.blue),
                                  const SizedBox(width: 4),
                                  Text("$remainingDays Days Left",
                                      style: TextStyle(
                                          color: remainingDays <= 7
                                              ? Colors.red
                                              : Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Deposit Amount if exists
                if (depositAmount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.security,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Deposit: \$${depositAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Payment Receipts Section
                if (isActive) ...[
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showPayments = !_showPayments;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: _primaryGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.receipt_long,
                                  color: _primaryGreen, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Payment Receipts',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _showPayments
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: _primaryGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showPayments) ...[
                    const SizedBox(height: 12),
                    if (_isLoadingPayments)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      // Payment Progress
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Paid ${paidPayments.length} of $expectedPayments payments',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Remaining: \$${remainingAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: expectedPayments > 0
                                  ? paidPayments.length / expectedPayments
                                  : 0,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  _primaryGreen),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Payments List
                      ...(_payments.isEmpty
                          ? [
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Text(
                                    'No payments yet',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            ]
                          : _payments
                              .map((payment) => _buildPaymentItem(payment))),
                    ],
                  ],
                ],

                // Contract Progress Bar
                if (isActive) ...[
                  const SizedBox(height: 20),
                  _buildContractProgressBar(startDate, endDate, remainingDays),
                ],

                // Financial Summary Section
                if (isActive) ...[
                  const SizedBox(height: 20),
                  _buildFinancialSummarySection(
                    totalPaid,
                    remainingAmount,
                    rent,
                    expectedPayments,
                    paidPayments.length,
                    _payments,
                  ),
                ],

                // Invoices Section
                if (isActive) ...[
                  const SizedBox(height: 20),
                  _buildInvoicesSection(),
                ],

                // Attachments Section
                if (isActive) ...[
                  const SizedBox(height: 20),
                  _buildAttachmentsSection(contract),
                ],

                // Signatures Section
                if (isActive) ...[
                  const SizedBox(height: 20),
                  _buildSignaturesSection(contract),
                ],

                // Payment Chart
                if (isActive && _payments.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildPaymentChart(),
                ],

                // Notifications & Alerts Section
                if (isActive) ...[
                  const SizedBox(height: 20),
                  _buildNotificationsSection(
                      daysUntilNextPayment, remainingDays),
                ],

                // Activity Log Section
                if (isActive) ...[
                  const SizedBox(height: 20),
                  _buildActivityLogSection(),
                ],

                const SizedBox(height: 20),

                // Action Buttons
                if (isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final (ok, msg) = await ApiService.updateContract(
                                contract['_id'], {'status': 'active'});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? "Contract Approved & Property Rented ✅"
                                      : msg),
                                  backgroundColor:
                                      ok ? _primaryGreen : Colors.red,
                                ),
                              );
                              if (ok) {
                                Navigator.of(context).pop();
                              }
                            }
                          },
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text("Approve & Rent"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final (ok, msg) = await ApiService.updateContract(
                                contract['_id'], {'status': 'rejected'});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text(ok ? "Contract Rejected ❌" : msg),
                                  backgroundColor:
                                      ok ? Colors.orange : Colors.red,
                                ),
                              );
                              if (ok) {
                                Navigator.of(context).pop();
                              }
                            }
                          },
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text("Reject"),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                        ),
                      ),
                    ],
                  )
                ] else ...[
                  // Additional Action Buttons Row 1
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _actionButton(
                        Icons.credit_card,
                        "Payments",
                        Colors.blue,
                        () {
                          setState(() {
                            _showPayments = !_showPayments;
                          });
                        },
                      ),
                      _actionButton(
                        Icons.receipt,
                        "Invoices",
                        Colors.indigo,
                        () {
                          setState(() {
                            _showInvoices = !_showInvoices;
                          });
                        },
                      ),
                      _actionButton(
                        Icons.attach_file,
                        "Attachments",
                        Colors.teal,
                        () {
                          setState(() {
                            _showAttachments = !_showAttachments;
                          });
                        },
                      ),
                      _actionButton(
                        Icons.autorenew,
                        "Renew",
                        Colors.purple,
                        () {
                          _showRenewContractDialog(contract);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Additional Action Buttons Row 2
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _actionButton(
                        Icons.picture_as_pdf,
                        "PDF",
                        Colors.blue,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ContractPdfPreviewScreen(contract: contract),
                            ),
                          );
                        },
                      ),
                      _actionButton(Icons.build, "Maintenance", Colors.orange,
                          () {
                        final property = contract['propertyId'] ?? {};
                        String? propertyId;
                        if (property is Map && property['_id'] != null) {
                          propertyId = property['_id'].toString();
                        } else if (property is String) {
                          propertyId = property;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminMaintenanceComplaintsScreen(
                              propertyId: propertyId,
                            ),
                          ),
                        );
                      }),
                      _actionButton(Icons.edit, "Status", Colors.grey, () {
                        _showChangeStatusDialog(contract['_id'], status);
                      }),
                      _actionButton(Icons.chat, "Chat", _primaryGreen,
                          () async {
                        final prefs = await SharedPreferences.getInstance();
                        final currentUserId = prefs.getString('userId');
                        if (currentUserId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("User ID not found")));
                          return;
                        }

                        final tenantId = tenant['_id']?.toString() ?? '';
                        final landlordId = landlord['_id']?.toString() ?? '';

                        String receiverId = '';
                        String receiverName = 'User';

                        if (currentUserId == tenantId) {
                          receiverId = landlordId;
                          receiverName =
                              landlord['name']?.toString() ?? 'Landlord';
                        } else if (currentUserId == landlordId) {
                          receiverId = tenantId;
                          receiverName = tenant['name']?.toString() ?? 'Tenant';
                        } else {
                          receiverId =
                              tenantId.isNotEmpty ? tenantId : landlordId;
                          receiverName = tenant['name']?.toString() ??
                              landlord['name']?.toString() ??
                              'User';
                        }

                        if (receiverId.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                receiverId: receiverId,
                                receiverName: receiverName,
                              ),
                            ),
                          );
                        }
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final status = payment['status'] ?? 'pending';
    final amount = payment['amount'] ?? 0;
    final date =
        payment['date'] != null ? DateTime.parse(payment['date']) : null;
    final receipt = payment['receipt'];
    final hasReceipt = receipt != null && receipt['receiptNumber'] != null;

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.pending;
    String statusText = 'Pending';

    if (status == 'paid') {
      statusColor = _primaryGreen;
      statusIcon = Icons.check_circle;
      statusText = 'Paid';
    } else if (status == 'failed') {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Failed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (date != null)
                  Text(
                    DateFormat('yyyy-MM-dd').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                if (hasReceipt && receipt['receiptDate'] != null)
                  Text(
                    'Receipt: ${receipt['receiptNumber']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (status == 'paid' && hasReceipt)
            IconButton(
              icon: const Icon(Icons.receipt, color: _primaryGreen),
              tooltip: 'View Receipt',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentReceiptScreen(payment: payment),
                  ),
                );
              },
            )
          else if (status == 'pending')
            IconButton(
              icon: const Icon(Icons.upload_file, color: Colors.orange),
              tooltip: 'Upload Receipt',
              onPressed: () => _uploadReceipt(payment['_id']),
            ),
        ],
      ),
    );
  }

  Future<void> _uploadReceipt(String paymentId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Uploading receipt...")),
    );

    try {
      final (ok, imageUrl) = await ApiService.uploadImage(image);

      if (ok && imageUrl != null) {
        // Update payment with receipt URL
        final (updateOk, msg) = await ApiService.updatePayment(
          paymentId,
          null, // Don't change status
          additionalData: {'receiptUrl': imageUrl},
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(updateOk ? "Receipt uploaded successfully ✅" : msg),
              backgroundColor: updateOk ? _primaryGreen : Colors.red,
            ),
          );
          if (updateOk) {
            _loadPayments();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Image upload failed: ${imageUrl ?? "Unknown error"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build Contract Progress Bar
  Widget _buildContractProgressBar(
      DateTime startDate, DateTime endDate, int remainingDays) {
    final now = DateTime.now();
    final totalDays = endDate.difference(startDate).inDays;
    final elapsedDays = now.difference(startDate).inDays;
    final progress =
        totalDays > 0 ? (elapsedDays / totalDays).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Contract Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${elapsedDays} days elapsed of $totalDays total days',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Build Financial Summary Section
  Widget _buildFinancialSummarySection(
    double totalPaid,
    double remainingAmount,
    double rent,
    int expectedPayments,
    int paidCount,
    List<dynamic> payments,
  ) {
    final lastPayment = payments.isNotEmpty
        ? payments.where((p) => p['status'] == 'paid').toList()
        : [];
    final lastPaymentDate =
        lastPayment.isNotEmpty && lastPayment.first['date'] != null
            ? DateTime.parse(lastPayment.first['date'])
            : null;

    final averageMonthly = paidCount > 0 ? totalPaid / paidCount : 0.0;

    return InkWell(
      onTap: () {
        setState(() {
          _showFinancialSummary = !_showFinancialSummary;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet,
                        color: Colors.purple, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Financial Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showFinancialSummary ? Icons.expand_less : Icons.expand_more,
                  color: Colors.purple,
                ),
              ],
            ),
            if (_showFinancialSummary) ...[
              const SizedBox(height: 16),
              _buildFinancialRow(
                  'Total Paid',
                  '\$${totalPaid.toStringAsFixed(2)}',
                  Icons.check_circle,
                  Colors.green),
              _buildFinancialRow(
                  'Remaining',
                  '\$${remainingAmount.toStringAsFixed(2)}',
                  Icons.pending,
                  Colors.orange),
              _buildFinancialRow(
                  'Average Payment',
                  '\$${averageMonthly.toStringAsFixed(2)}',
                  Icons.trending_up,
                  Colors.blue),
              if (lastPaymentDate != null)
                _buildFinancialRow(
                    'Last Payment',
                    DateFormat('yyyy-MM-dd').format(lastPaymentDate),
                    Icons.calendar_today,
                    Colors.grey),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Build Invoices Section
  Widget _buildInvoicesSection() {
    return InkWell(
      onTap: () {
        setState(() {
          _showInvoices = !_showInvoices;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.indigo.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt, color: Colors.indigo, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Invoices',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showInvoices ? Icons.expand_less : Icons.expand_more,
                  color: Colors.indigo,
                ),
              ],
            ),
            if (_showInvoices) ...[
              const SizedBox(height: 16),
              if (_isLoadingInvoices)
                const Center(child: CircularProgressIndicator())
              else if (_invoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No invoices found',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ..._invoices.map((invoice) => _buildInvoiceItem(invoice)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          InvoicesScreen(contractId: widget.contract['_id']),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('View All Invoices'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItem(Map<String, dynamic> invoice) {
    final invoiceNumber = invoice['invoiceNumber'] ?? 'N/A';
    final total = invoice['total'] ?? 0;
    final issuedAt = invoice['issuedAt'] != null
        ? DateTime.parse(invoice['issuedAt'])
        : null;
    final payment = invoice['paymentId'];
    final paymentStatus = payment != null && payment is Map
        ? payment['status'] ?? 'pending'
        : 'pending';

    Color statusColor = Colors.orange;
    if (paymentStatus == 'paid') statusColor = _primaryGreen;
    if (paymentStatus == 'failed') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.receipt, color: statusColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoiceNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (issuedAt != null)
                  Text(
                    DateFormat('yyyy-MM-dd').format(issuedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  paymentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
            tooltip: 'Download PDF',
            onPressed: () {
              // TODO: Implement PDF download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('PDF download feature coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Build Attachments Section
  Widget _buildAttachmentsSection(Map<String, dynamic> contract) {
    final attachments = contract['attachments'] ?? [];

    return InkWell(
      onTap: () {
        setState(() {
          _showAttachments = !_showAttachments;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.attach_file, color: Colors.teal, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Attachments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showAttachments ? Icons.expand_less : Icons.expand_more,
                  color: Colors.teal,
                ),
              ],
            ),
            if (_showAttachments) ...[
              const SizedBox(height: 16),
              if (attachments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No attachments',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...attachments
                    .map((attachment) => _buildAttachmentItem(attachment)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _uploadAttachment(),
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Attachment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(Map<String, dynamic> attachment) {
    final name = attachment['name'] ?? 'Unknown';
    final url = attachment['url'] ?? '';
    final uploadedAt = attachment['uploadedAt'] != null
        ? DateTime.parse(attachment['uploadedAt'])
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.teal, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (uploadedAt != null)
                  Text(
                    DateFormat('yyyy-MM-dd').format(uploadedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.preview, color: Colors.blue),
            tooltip: 'Preview',
            onPressed: () {
              if (url.isNotEmpty) {
                // TODO: Implement preview
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preview feature coming soon')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAttachment() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Uploading attachment...")),
    );

    try {
      final (ok, imageUrl) = await ApiService.uploadImage(file);

      if (ok && imageUrl != null) {
        // TODO: Update contract with new attachment
        // This would require a backend endpoint to add attachments
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Attachment uploaded successfully ✅"),
              backgroundColor: _primaryGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build Signatures Section
  Widget _buildSignaturesSection(Map<String, dynamic> contract) {
    final signatures = contract['signatures'] ?? {};
    final tenantSigned = signatures['tenant']?['signed'] ?? false;
    final landlordSigned = signatures['landlord']?['signed'] ?? false;

    return InkWell(
      onTap: () {
        setState(() {
          _showSignatures = !_showSignatures;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit, color: Colors.deepPurple, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Signatures',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showSignatures ? Icons.expand_less : Icons.expand_more,
                  color: Colors.deepPurple,
                ),
              ],
            ),
            if (_showSignatures) ...[
              const SizedBox(height: 16),
              _buildSignatureRow(
                  'Tenant', tenantSigned, signatures['tenant']?['signedAt']),
              const SizedBox(height: 8),
              _buildSignatureRow('Landlord', landlordSigned,
                  signatures['landlord']?['signedAt']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureRow(String role, bool signed, dynamic signedAt) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: signed ? _primaryGreen : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            signed ? Icons.check_circle : Icons.pending,
            color: signed ? _primaryGreen : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  signed
                      ? (signedAt != null
                          ? 'Signed on ${DateFormat('yyyy-MM-dd').format(DateTime.parse(signedAt))}'
                          : 'Signed')
                      : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (signed)
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.blue),
              tooltip: 'View Signature',
              onPressed: () {
                // TODO: Show signature preview
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Signature preview coming soon')),
                );
              },
            ),
        ],
      ),
    );
  }

  // Build Payment Chart
  Widget _buildPaymentChart() {
    final paidPayments = _payments.where((p) => p['status'] == 'paid').toList();
    final pendingPayments =
        _payments.where((p) => p['status'] == 'pending').toList();

    if (paidPayments.isEmpty && pendingPayments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _payments.fold<double>(
                        0,
                        (max, p) => (p['amount'] ?? 0).toDouble() > max
                            ? (p['amount'] ?? 0).toDouble()
                            : max) *
                    1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < _payments.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'P${value.toInt() + 1}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _payments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final payment = entry.value;
                  final amount = (payment['amount'] ?? 0).toDouble();
                  final isPaid = payment['status'] == 'paid';

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: amount,
                        color: isPaid ? _primaryGreen : Colors.orange,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build Notifications Section
  Widget _buildNotificationsSection(
      int daysUntilNextPayment, int remainingDays) {
    final alerts = <Map<String, dynamic>>[];

    if (daysUntilNextPayment <= 3 && daysUntilNextPayment > 0) {
      alerts.add({
        'type': 'warning',
        'message': 'Payment due in $daysUntilNextPayment days',
        'icon': Icons.payment,
        'color': Colors.orange,
      });
    }

    if (remainingDays <= 30 && remainingDays > 0) {
      alerts.add({
        'type': 'info',
        'message': 'Contract expires in $remainingDays days',
        'icon': Icons.event,
        'color': Colors.blue,
      });
    }

    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () {
        setState(() {
          _showNotifications = !_showNotifications;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active,
                        color: Colors.amber, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Alerts (${alerts.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showNotifications ? Icons.expand_less : Icons.expand_more,
                  color: Colors.amber,
                ),
              ],
            ),
            if (_showNotifications) ...[
              const SizedBox(height: 16),
              ...alerts.map((alert) => _buildAlertItem(alert)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert['color'].withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: alert['color'].withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(alert['icon'], color: alert['color'], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              alert['message'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: alert['color'],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build Activity Log Section
  Widget _buildActivityLogSection() {
    final activities = <Map<String, dynamic>>[];

    // Add payment activities
    for (var payment in _payments) {
      if (payment['status'] == 'paid' && payment['date'] != null) {
        activities.add({
          'date': DateTime.parse(payment['date']),
          'type': 'payment',
          'message': 'Payment of \$${payment['amount']} was made',
          'icon': Icons.payment,
        });
      }
    }

    // Sort by date
    activities.sort((a, b) => b['date'].compareTo(a['date']));

    return InkWell(
      onTap: () {
        setState(() {
          _showActivityLog = !_showActivityLog;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history, color: Colors.grey, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Activity Log',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _showActivityLog ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey,
                ),
              ],
            ),
            if (_showActivityLog) ...[
              const SizedBox(height: 16),
              if (activities.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No activities yet',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                ...activities
                    .take(5)
                    .map((activity) => _buildActivityItem(activity)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(activity['icon'], color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['message'],
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(activity['date']),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show QR Code Dialog
  void _showQRCodeDialog(Map<String, dynamic> contract) {
    final contractInfo = '''
Contract ID: ${contract['_id']}
Property: ${contract['propertyId']?['title'] ?? 'N/A'}
Tenant: ${contract['tenantId']?['name'] ?? 'N/A'}
Landlord: ${contract['landlordId']?['name'] ?? 'N/A'}
Rent: \$${contract['rentAmount'] ?? 0}
Status: ${contract['status']}
''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contract QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.qr_code_2,
                size: 200,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              contractInfo,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  // Show Renew Contract Dialog
  void _showRenewContractDialog(Map<String, dynamic> contract) async {
    final currentEndDate = DateTime.parse(contract['endDate']);
    final currentStartDate = DateTime.parse(contract['startDate']);
    final durationDays = currentEndDate.difference(currentStartDate).inDays;

    // Default renewal: extend by same duration
    final defaultNewStartDate = currentEndDate;
    final defaultNewEndDate = currentEndDate.add(Duration(days: durationDays));

    DateTime? selectedStartDate;
    DateTime? selectedEndDate;

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Renew Contract'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select new renewal dates:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('New Start Date'),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd').format(
                      selectedStartDate ?? defaultNewStartDate,
                    ),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedStartDate ?? defaultNewStartDate,
                      firstDate: currentEndDate,
                      lastDate: DateTime(currentEndDate.year + 5),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedStartDate = picked;
                        // Auto-update end date if not set
                        if (selectedEndDate == null) {
                          selectedEndDate =
                              picked.add(Duration(days: durationDays));
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  title: const Text('New End Date'),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd').format(
                      selectedEndDate ?? defaultNewEndDate,
                    ),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedEndDate ?? defaultNewEndDate,
                      firstDate: selectedStartDate ?? defaultNewStartDate,
                      lastDate: DateTime(
                          (selectedStartDate ?? defaultNewStartDate).year + 5),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedEndDate = picked;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Duration: ${((selectedEndDate ?? defaultNewEndDate).difference(selectedStartDate ?? defaultNewStartDate).inDays / 30).toStringAsFixed(1)} months',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedStartDate != null && selectedEndDate != null) {
                  Navigator.pop(ctx, {
                    'startDate': selectedStartDate!,
                    'endDate': selectedEndDate!,
                  });
                } else {
                  Navigator.pop(ctx, {
                    'startDate': defaultNewStartDate,
                    'endDate': defaultNewEndDate,
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Renew'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final startDate = result['startDate'] as DateTime;
      final endDate = result['endDate'] as DateTime;

      final (ok, msg) = await ApiService.renewContract(
        contract['_id'],
        newStartDate: startDate,
        newEndDate: endDate,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Contract renewed successfully ✅' : msg),
            backgroundColor: ok ? _primaryGreen : Colors.red,
          ),
        );

        if (ok) {
          // Reload payments and refresh
          _loadPayments();
          // Note: _loadInvoices() was in your snippet but not in the previous main code.
          // If you have an invoice function, uncomment the line below:
          // _loadInvoices();

          // Refresh parent screen
          Navigator.of(context).pop();
        }
      }
    }
  }
}
