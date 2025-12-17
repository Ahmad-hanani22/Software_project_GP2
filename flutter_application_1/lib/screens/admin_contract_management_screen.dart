import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:intl/intl.dart';
import 'contract_pdf_preview_screen.dart';

// الألوان المستخدمة
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

  Future<void> _approveContract(String id) async {
    final (ok, msg) = await ApiService.updateContract(id, {'status': 'active'});
    if (ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contract Approved & Property Rented ✅"), backgroundColor: _primaryGreen),
        );
        _fetchContracts();
      }
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectContract(String id) async {
    final (ok, msg) =
        await ApiService.updateContract(id, {'status': 'rejected'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? "Contract Rejected ❌" : msg),
          backgroundColor: ok ? Colors.orange : Colors.red,
        ),
      );
      if (ok) _fetchContracts();
    }
  }

  // ✅ الدالة الجديدة لتغيير الحالة
  Future<void> _showChangeStatusDialog(String contractId, String currentStatus) async {
    String? selectedStatus = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Change Contract Status'),
          children: <Widget>[
            _buildStatusOption(context, 'draft', 'DRAFT', Colors.blueGrey),
            _buildStatusOption(context, 'pending', 'PENDING', Colors.orange),
            _buildStatusOption(context, 'active', 'ACTIVE', Colors.green),
            _buildStatusOption(context, 'expiring_soon', 'EXPIRING SOON', Colors.blue),
            _buildStatusOption(context, 'expired', 'EXPIRED', Colors.grey),
            _buildStatusOption(context, 'terminated', 'TERMINATED', Colors.black),
            // للحفاظ على التوافق مع الحالات القديمة إن وجدت
            _buildStatusOption(context, 'rented', 'RENTED (legacy)', _primaryGreen),
            _buildStatusOption(context, 'rejected', 'REJECTED', Colors.red),
          ],
        );
      },
    );

    if (selectedStatus != null && selectedStatus != currentStatus) {
      // إرسال التحديث للسيرفر
      final (ok, msg) = await ApiService.updateContract(contractId, {'status': selectedStatus});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? "Status updated to ${selectedStatus.toUpperCase()}" : "Error: $msg"),
            backgroundColor: ok ? _primaryGreen : Colors.red,
          ),
        );
        if (ok) _fetchContracts(); // تحديث القائمة
      }
    }
  }

  Widget _buildStatusOption(BuildContext context, String value, String label, Color color) {
    return SimpleDialogOption(
      onPressed: () { Navigator.pop(context, value); },
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 14),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showStatistics() {
    int active = _allContracts.where((c) => c['status'] == 'active' || c['status'] == 'rented').length;
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
                    return _buildContractCard(_filteredContracts[index]);
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

  Widget _buildContractCard(Map<String, dynamic> contract) {
    final property = contract['propertyId'] ?? {};
    final tenant = contract['tenantId'] ?? {};
    final landlord = contract['landlordId'] ?? {};
    final status = (contract['status'] ?? 'pending').toString().toLowerCase(); // Lowercase for comparison
    final rent = contract['rentAmount'] ?? 0;
    final startDate = DateTime.parse(contract['startDate']);
    final endDate = DateTime.parse(contract['endDate']);
    final durationDays = endDate.difference(startDate).inDays;
    final remainingDays = endDate.difference(DateTime.now()).inDays;
    final bool isPending = status == 'pending';
    // التعامل مع active و rented كحالة نشطة
    final bool isActive = status == 'rented' || status == 'active'; 

    Color statusColor = Colors.grey;
    if (isActive) statusColor = _primaryGreen;
    if (isPending) statusColor = Colors.orange;
    if (status == 'rejected') statusColor = Colors.red;
    if (status == 'expired' || status == 'terminated') statusColor = Colors.black54;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ID: ${contract['_id']}",
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const Icon(Icons.qr_code_2, size: 28, color: _textDark),
                  ],
                ),
                const Divider(),
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
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        color: _primaryGreen, size: 20),
                    Text("\$$rent / Month",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _primaryGreen)),
                  ],
                ),
                const Divider(height: 24),
                _personRow(
                    Icons.person, "Tenant", tenant['name'], tenant['email']),
                const SizedBox(height: 12),
                _personRow(Icons.business_center, "Landlord", landlord['name'],
                    landlord['email']),
                const Divider(height: 24),
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
                const SizedBox(height: 20),
                if (isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveContract(contract['_id']),
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
                          onPressed: () => _rejectContract(contract['_id']),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Maintenance screen (TODO).")));
                      }),
                      // ✅ زر تعديل الحالة
                      _actionButton(Icons.edit, "Status", Colors.grey, () {
                        _showChangeStatusDialog(contract['_id'], status);
                      }),
                      _actionButton(Icons.chat, "Chat", _primaryGreen, () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Chat feature (TODO).")));
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
}