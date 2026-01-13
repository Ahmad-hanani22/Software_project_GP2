import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

// --- Color Palette ---
const Color _primaryGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFF5F5F5);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class AdminMaintenanceComplaintsScreen extends StatefulWidget {
  const AdminMaintenanceComplaintsScreen({super.key});

  @override
  State<AdminMaintenanceComplaintsScreen> createState() =>
      _AdminMaintenanceComplaintsScreenState();
}

class _AdminMaintenanceComplaintsScreenState
    extends State<AdminMaintenanceComplaintsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('Maintenance & Complaints'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
                icon: Icon(Icons.build_circle_outlined, color: Colors.white),
                text: 'Maintenance and Complaints'),
          ],
        ),
      ),
      body: const MaintenanceManagementTab(),
    );
  }
}

// ===================================================================
// =================== MAINTENANCE MANAGEMENT TAB ====================
// ===================================================================
class MaintenanceManagementTab extends StatefulWidget {
  const MaintenanceManagementTab({super.key});

  @override
  State<MaintenanceManagementTab> createState() =>
      _MaintenanceManagementTabState();
}

class _MaintenanceManagementTabState extends State<MaintenanceManagementTab> {
  bool _isLoading = true;
  List<dynamic> _requests = [];
  List<dynamic> _filteredRequests = [];
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_filterRequests);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRequests() {
    setState(() {
      String searchQuery = _searchController.text.toLowerCase();
      _filteredRequests = _requests.where((request) {
        // Filter by status
        bool statusMatch = _selectedStatusFilter == null ||
            (request['status'] ?? 'pending') == _selectedStatusFilter;

        if (!statusMatch) return false;

        // Filter by search query (apartment name or tenant name)
        if (searchQuery.isEmpty) return true;

        final property = request['propertyId'] ?? {};
        final tenant = request['tenantId'] ?? {};
        final propertyName = (property['title'] ?? '').toString().toLowerCase();
        final tenantName = (tenant['name'] ?? '').toString().toLowerCase();

        return propertyName.contains(searchQuery) ||
            tenantName.contains(searchQuery);
      }).toList();
    });
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllMaintenance();

    if (mounted) {
      setState(() {
        if (ok) {
          _requests = data as List<dynamic>;
          _filteredRequests = _requests;
        } else {
          _errorMessage = data.toString();
          _filteredRequests = [];
        }
        _isLoading = false;
      });
      _filterRequests();
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    final (ok, message) = await ApiService.updateMaintenance(id, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? _primaryGreen : Colors.red,
      ));
      if (ok) _fetchData();
    }
  }

  Future<void> _deleteMaintenance(String id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clean Request"),
        content: const Text(
            "Are you sure you want to delete this maintenance request?"),
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
      final (ok, msg) = await ApiService.deleteMaintenance(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? "Request deleted" : msg),
          backgroundColor: ok ? _primaryGreen : Colors.red,
        ));
        if (ok) _fetchData();
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: const Text('All'),
              value: null,
              groupValue: _selectedStatusFilter,
              onChanged: (value) {
                setState(() {
                  _selectedStatusFilter = value;
                });
                Navigator.pop(context);
                _filterRequests();
              },
            ),
            RadioListTile<String>(
              title: const Text('Pending'),
              value: 'pending',
              groupValue: _selectedStatusFilter,
              onChanged: (value) {
                setState(() {
                  _selectedStatusFilter = value;
                });
                Navigator.pop(context);
                _filterRequests();
              },
            ),
            RadioListTile<String>(
              title: const Text('In Progress'),
              value: 'in_progress',
              groupValue: _selectedStatusFilter,
              onChanged: (value) {
                setState(() {
                  _selectedStatusFilter = value;
                });
                Navigator.pop(context);
                _filterRequests();
              },
            ),
            RadioListTile<String>(
              title: const Text('Resolved'),
              value: 'resolved',
              groupValue: _selectedStatusFilter,
              onChanged: (value) {
                setState(() {
                  _selectedStatusFilter = value;
                });
                Navigator.pop(context);
                _filterRequests();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatusFilter = null;
              });
              Navigator.pop(context);
              _filterRequests();
            },
            child: const Text('Clear Filter'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Center(
          child: CircularProgressIndicator(color: _primaryGreen));
    if (_errorMessage != null)
      return Center(
          child:
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by apartment name or tenant name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterRequests();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: _selectedStatusFilter != null
                      ? _primaryGreen
                      : Colors.grey,
                ),
                onPressed: _showFilterDialog,
                tooltip: 'Filter by Status',
                style: IconButton.styleFrom(
                  backgroundColor: _selectedStatusFilter != null
                      ? _primaryGreen.withOpacity(0.1)
                      : Colors.grey[100],
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        // Results
        Expanded(
          child: _filteredRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _requests.isEmpty
                            ? Icons.build_outlined
                            : Icons.search_off,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _requests.isEmpty
                            ? 'No Maintenance Requests'
                            : 'No results found',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary),
                      ),
                      Text(
                        _requests.isEmpty
                            ? 'Active requests will appear here.'
                            : 'Try adjusting your search or filter.',
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      return _MaintenanceCard(
                        request: _filteredRequests[index],
                        onUpdateStatus: _updateStatus,
                        onDelete: _deleteMaintenance,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Function(String id, String newStatus) onUpdateStatus;
  final Function(String id) onDelete;

  const _MaintenanceCard({
    required this.request,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tenant = request['tenantId'] ?? {};
    final property = request['propertyId'] ?? {};
    final status = request['status'] ?? 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                Expanded(
                  child: Text(property['title'] ?? 'N/A Property',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _primaryGreen)),
                ),
                // زر الحذف والحالة (محدث)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => onDelete(request['_id']),
                    ),
                    const SizedBox(width: 8),
                    _statusButton(status, isMaintenance: true),
                  ],
                ),
              ],
            ),
            Text(property['address'] ?? 'No address',
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const Divider(height: 20),
            Text(request['description'] ?? 'No description provided.',
                style: const TextStyle(fontSize: 15, color: _textPrimary)),
            const Divider(height: 20),
            _buildInfoRow(
                Icons.person_outline, "Requester:", tenant['name'] ?? 'N/A'),
            _buildInfoRow(
                Icons.phone_outlined, "Contact:", tenant['phone'] ?? 'N/A'),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) =>
                        onUpdateStatus(request['_id'], value),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                          value: 'pending', child: Text('Mark as Pending')),
                      const PopupMenuItem(
                          value: 'in_progress',
                          child: Text('Mark as In Progress')),
                      const PopupMenuItem(
                          value: 'resolved', child: Text('Mark as Resolved')),
                    ],
                    child: const Chip(
                        label: Text('Update Status'),
                        avatar: Icon(Icons.edit, size: 16)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}


// --- Common Helper Widgets ---
// ✅ تصميم الحالة كزر واضح مع ألوان صلبة
Widget _statusButton(String status, {required bool isMaintenance}) {
  Color bg;
  List<String> statuses = isMaintenance
      ? ['pending', 'in_progress', 'resolved']
      : ['open', 'in_review', 'closed'];

  if (status == statuses[0]) {
    // Pending / Open
    bg = Colors.orange; // برتقالي صلب
  } else if (status == statuses[1]) {
    // In Progress / In Review
    bg = Colors.blue; // أزرق صلب
  } else {
    // Resolved / Closed
    bg = Colors.green; // أخضر صلب
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8), // حواف أقل استدارة كالأزرار
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ],
    ),
    child: Text(
      status.replaceAll('_', ' ').toUpperCase(),
      style: const TextStyle(
        color: Colors.white, // نص أبيض دائماً
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
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
