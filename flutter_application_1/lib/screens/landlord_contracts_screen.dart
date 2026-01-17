import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/admin_maintenance_complaints_screen.dart';
import 'package:flutter_application_1/screens/invoices_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'payment_receipt_screen.dart';

// Used Colors
const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _bgWhite = Color(0xFFFAF9F6);
const Color _textDark = Color(0xFF263238);
const Color _textLight = Color(0xFF78909C);

class LandlordContractsScreen extends StatefulWidget {
  const LandlordContractsScreen({super.key});

  @override
  State<LandlordContractsScreen> createState() =>
      _LandlordContractsScreenState();
}

class _LandlordContractsScreenState extends State<LandlordContractsScreen> {
  bool _isLoading = true;
  List<dynamic> _allContracts = [];
  List<dynamic> _filteredContracts = [];
  final TextEditingController _searchController = TextEditingController();
  String? _landlordId;
  String _sortOption = 'Newest';

  @override
  void initState() {
    super.initState();
    _loadLandlordId();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLandlordId() async {
    final prefs = await SharedPreferences.getInstance();
    _landlordId = prefs.getString('userId');
    if (_landlordId != null) {
      _fetchContracts();
    }
  }

  Future<void> _fetchContracts() async {
    setState(() => _isLoading = true);
    
    // ✅ Fetch landlord's contracts using getUserContracts (not getAllContracts which is admin-only)
    // Backend already filters contracts where userId is either tenantId or landlordId
    final (ok, data) = await ApiService.getUserContracts(_landlordId!);
    if (mounted) {
      setState(() {
        if (ok && data is List) {
          // ✅ Backend returns all contracts where this user is tenant OR landlord
          // For landlord screen, we want to show all contracts (both as landlord and tenant if any)
          _allContracts = data;
          _applyFilterAndSort();
        } else {
          _allContracts = [];
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
      final id = c['_id'].toString();

      return (property['title'] ?? '').toLowerCase().contains(query) ||
          (tenant['name'] ?? '').toLowerCase().contains(query) ||
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
    final active = _allContracts.where((c) => c['status'] == 'active').length;
    final expired = _allContracts.where((c) => c['status'] == 'expired').length;
    final pending = _allContracts.where((c) => c['status'] == 'pending').length;
    final total = _allContracts.length;
    final totalRevenue = _allContracts.fold<double>(
        0, (sum, c) => sum + ((c['rentAmount'] ?? 0) as num).toDouble());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contract Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Contracts', total.toString(), Icons.description),
            _buildStatRow('Active', active.toString(), Icons.check_circle),
            _buildStatRow('Expired', expired.toString(), Icons.cancel),
            _buildStatRow('Pending', pending.toString(), Icons.pending),
            _buildStatRow('Total Revenue',
                NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0)
                    .format(totalRevenue),
                Icons.attach_money),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'))
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: _accentGreen),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search contracts...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilterAndSort();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgWhite,
      appBar: AppBar(
        backgroundColor: _primaryBeige,
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
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _accentGreen),
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

// Contract Card Widget (similar to admin version)
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
  bool _showFinancialSummary = false;

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
            backgroundColor: ok ? _accentGreen : Colors.red,
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

  int _calculateDaysUntilNextPayment() {
    final contract = widget.contract;
    final startDate = DateTime.parse(contract['startDate']);
    final endDate = DateTime.parse(contract['endDate']);
    final paymentCycle =
        (contract['paymentCycle'] ?? 'monthly').toString().toLowerCase();
    final now = DateTime.now();

    if (now.isBefore(startDate)) {
      return startDate.difference(now).inDays;
    }

    if (now.isAfter(endDate)) {
      return 0;
    }

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
        daysInCycle = 30;
    }

    while (nextPaymentDate.isBefore(now) ||
        nextPaymentDate.isAtSameMomentAs(now)) {
      nextPaymentDate = nextPaymentDate.add(Duration(days: daysInCycle));
      if (nextPaymentDate.isAfter(endDate)) {
        return 0;
      }
    }

    return nextPaymentDate.difference(now).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final contract = widget.contract;
    final property = contract['propertyId'] ?? {};
    final tenant = contract['tenantId'] ?? {};
    final landlord = contract['landlordId'] ?? {};
    final status = contract['status'] ?? 'unknown';
    final startDate = DateTime.parse(contract['startDate']);
    final endDate = DateTime.parse(contract['endDate']);
    final rentAmount = contract['rentAmount'] ?? 0;
    final daysUntilPayment = _calculateDaysUntilNextPayment();

    Color statusColor = Colors.grey;
    if (status == 'active') statusColor = Colors.green;
    if (status == 'pending') statusColor = Colors.orange;
    if (status == 'expired') statusColor = Colors.red;
    if (status == 'expiring_soon') statusColor = Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property['title'] ?? 'Unknown Property',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contract #${contract['_id'].toString().substring(0, 8)}',
                        style: const TextStyle(
                            fontSize: 12, color: _textLight),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // People Info
            _personRow(Icons.person, 'Tenant', tenant['name'], tenant['email']),
            const SizedBox(height: 12),
            _personRow(
                Icons.business, 'Landlord', landlord['name'], landlord['email']),
            const SizedBox(height: 16),
            // Dates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _dateInfo('Start Date', startDate),
                _dateInfo('End Date', endDate),
              ],
            ),
            const Divider(height: 24),
            // Financial Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monthly Rent',
                        style: TextStyle(fontSize: 11, color: _textLight)),
                    Text(
                      NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0)
                          .format(rentAmount),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _accentGreen),
                    ),
                  ],
                ),
                if (daysUntilPayment > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Next Payment',
                          style: TextStyle(fontSize: 11, color: _textLight)),
                      Text(
                        '$daysUntilPayment days',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(Icons.build, "Maintenance", Colors.orange, () {
                  final property = widget.contract['propertyId'] ?? {};
                  final propertyId = property is Map
                      ? property['_id']?.toString()
                      : property.toString();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminMaintenanceComplaintsScreen(
                        propertyId: propertyId,
                      ),
                    ),
                  );
                }),
                _actionButton(Icons.payment, "Payments", _accentGreen, () {
                  setState(() => _showPayments = !_showPayments);
                }),
                _actionButton(Icons.description, "Invoices", Colors.blue, () {
                  setState(() => _showInvoices = !_showInvoices);
                }),
                _actionButton(Icons.bar_chart, "Summary", Colors.purple, () {
                  setState(() => _showFinancialSummary = !_showFinancialSummary);
                }),
                _actionButton(Icons.edit, "Status", Colors.grey, () {
                  _showChangeStatusDialog(contract['_id'], status);
                }),
              ],
            ),
            // Expandable Sections
            if (_showPayments) ...[
              const Divider(height: 24),
              _buildPaymentsSection(),
            ],
            if (_showInvoices) ...[
              const Divider(height: 24),
              _buildInvoicesSection(),
            ],
            if (_showFinancialSummary) ...[
              const Divider(height: 24),
              _buildFinancialSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsSection() {
    if (_isLoadingPayments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_payments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No payments found', style: TextStyle(color: _textLight)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._payments.map((payment) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: payment['status'] == 'paid'
                  ? _accentGreen.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              child: Icon(
                payment['status'] == 'paid' ? Icons.check : Icons.pending,
                color: payment['status'] == 'paid' ? _accentGreen : Colors.orange,
              ),
            ),
            title: Text(
              NumberFormat.simpleCurrency(name: 'USD')
                  .format(payment['amount']),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${payment['status']} • ${DateFormat.yMMMd().format(DateTime.parse(payment['date']))}',
            ),
            trailing: payment['status'] == 'paid'
                ? IconButton(
                    icon: const Icon(Icons.receipt),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentReceiptScreen(
                            payment: payment,
                          ),
                        ),
                      );
                    },
                  )
                : null,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildInvoicesSection() {
    if (_isLoadingInvoices) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_invoices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No invoices found', style: TextStyle(color: _textLight)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Invoices',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._invoices.map((invoice) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.description, color: Colors.white),
            ),
            title: Text(
              invoice['invoiceNumber'] ?? 'Invoice',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              NumberFormat.simpleCurrency(name: 'USD')
                  .format(invoice['amount']),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.visibility),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoicesScreen(contractId: widget.contract['_id']),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFinancialSummary() {
    final totalPaid = _payments
        .where((p) => p['status'] == 'paid')
        .fold<double>(0, (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble());
    final totalPending = _payments
        .where((p) => p['status'] == 'pending')
        .fold<double>(0, (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble());
    final contract = widget.contract;
    final rentAmount = (contract['rentAmount'] ?? 0) as num;
    final startDate = DateTime.parse(contract['startDate']);
    final endDate = DateTime.parse(contract['endDate']);
    final months = ((endDate.difference(startDate).inDays) / 30).ceil();
    final expectedTotal = rentAmount * months;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Financial Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildSummaryRow('Total Expected', expectedTotal.toDouble(), Colors.blue),
        _buildSummaryRow('Total Paid', totalPaid, _accentGreen),
        _buildSummaryRow('Total Pending', totalPending, Colors.orange),
        _buildSummaryRow('Remaining', (expectedTotal - totalPaid).toDouble(), Colors.grey),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _textLight)),
          Text(
            NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0)
                .format(amount),
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
