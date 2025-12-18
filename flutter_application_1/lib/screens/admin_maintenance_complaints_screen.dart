import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.build_circle_outlined), text: 'Maintenance'),
            Tab(icon: Icon(Icons.report_problem_outlined), text: 'Complaints'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MaintenanceManagementTab(),
          ComplaintsManagementTab(),
        ],
      ),
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllMaintenance();

    if (mounted) {
      setState(() {
        if (ok) {
          _requests = data as List<dynamic>;
        } else {
          _errorMessage = data.toString();
        }
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Center(
          child: CircularProgressIndicator(color: _primaryGreen));
    if (_errorMessage != null)
      return Center(
          child:
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Maintenance Requests',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            Text('Active requests will appear here.',
                style: TextStyle(color: _textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          return _MaintenanceCard(
            request: _requests[index],
            onUpdateStatus: _updateStatus,
            onDelete: _deleteMaintenance,
          );
        },
      ),
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

// ===================================================================
// =================== COMPLAINTS MANAGEMENT TAB =====================
// ===================================================================
class ComplaintsManagementTab extends StatefulWidget {
  const ComplaintsManagementTab({super.key});

  @override
  State<ComplaintsManagementTab> createState() =>
      _ComplaintsManagementTabState();
}

class _ComplaintsManagementTabState extends State<ComplaintsManagementTab> {
  bool _isLoading = true;
  List<dynamic> _complaints = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final (ok, data) = await ApiService.getAllComplaints();

    if (mounted) {
      setState(() {
        if (ok) {
          _complaints = data as List<dynamic>;
        } else {
          _errorMessage = data.toString();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    final (ok, message) = await ApiService.updateComplaintStatus(id, newStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? _primaryGreen : Colors.red,
      ));
      if (ok) _fetchData();
    }
  }

  Future<void> _deleteComplaint(String id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clean Complaint"),
        content: const Text("Are you sure you want to delete this complaint?"),
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
      final (ok, msg) = await ApiService.deleteComplaint(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok ? "Complaint deleted" : msg),
          backgroundColor: ok ? _primaryGreen : Colors.red,
        ));
        if (ok) _fetchData();
      }
    }
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
    if (_complaints.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.report_problem_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Complaints Found',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            Text('Complaints will appear here.',
                style: TextStyle(color: _textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _complaints.length,
        itemBuilder: (context, index) {
          return _ComplaintCard(
            complaint: _complaints[index],
            onUpdateStatus: _updateStatus,
            onDelete: _deleteComplaint,
          );
        },
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final Function(String id, String newStatus) onUpdateStatus;
  final Function(String id) onDelete;

  const _ComplaintCard({
    required this.complaint,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final user = complaint['userId'] ?? {};
    final againstUser = complaint['againstUserId'];
    final status = (complaint['status'] ?? 'open').toString();
    final category = (complaint['category'] ?? 'N/A').toString();
    final adminDecision = complaint['adminDecision']?.toString();
    final attachments = (complaint['attachments'] as List?) ?? [];
    final date = DateTime.parse(complaint['createdAt']);

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
                  child: Text(
                      'Complaint #${complaint['_id'].substring(0, 7)}...',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: _primaryGreen)),
                ),
                // زر الحذف والحالة
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => onDelete(complaint['_id']),
                    ),
                    const SizedBox(width: 8),
                    _statusButton(status, isMaintenance: false),
                  ],
                ),
              ],
            ),
            Text(DateFormat('d MMM, yyyy').format(date),
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const Divider(height: 20),
            Text(complaint['description'] ?? 'No description.',
                style: const TextStyle(fontSize: 15, color: _textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.category, size: 16, color: _textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Category: ${category.toUpperCase()}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _textSecondary),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildInfoRow(Icons.person_outline, 'From:', user['name'] ?? 'N/A'),
            if (againstUser != null)
              _buildInfoRow(Icons.person_pin_outlined, 'Against:',
                  againstUser['name'] ?? 'N/A'),
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Attachments:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: _textPrimary)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: attachments.map<Widget>((att) {
                  final map = att as Map<String, dynamic>;
                  final name = map['name']?.toString() ?? 'File';
                  return Chip(
                    avatar: const Icon(Icons.attachment, size: 16),
                    label: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ],
            if (adminDecision != null && adminDecision.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Admin Decision:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: _textPrimary)),
              const SizedBox(height: 4),
              Text(
                adminDecision,
                style: const TextStyle(color: _textSecondary, fontSize: 13),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final statusController =
                          TextEditingController(text: status);
                      final decisionController =
                          TextEditingController(text: adminDecision ?? '');

                      final result = await showDialog<Map<String, String>>(
                          context: context,
                          builder: (ctx) {
                            return AlertDialog(
                              title: const Text('Update Complaint'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value: status,
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'open', child: Text('Open')),
                                        DropdownMenuItem(
                                            value: 'in_progress',
                                            child: Text('In Progress')),
                                        DropdownMenuItem(
                                            value: 'resolved',
                                            child: Text('Resolved')),
                                        DropdownMenuItem(
                                            value: 'closed',
                                            child: Text('Closed')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          statusController.text = val;
                                        }
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Status',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: decisionController,
                                      maxLines: 4,
                                      decoration: const InputDecoration(
                                        labelText: 'Admin Decision (optional)',
                                        border: OutlineInputBorder(),
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
                                    Navigator.pop<Map<String, String>>(ctx, {
                                      'status': statusController.text,
                                      'adminDecision': decisionController.text,
                                    });
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            );
                          });

                      if (result != null && result['status'] != null) {
                        onUpdateStatus(
                          complaint['_id'],
                          result['status']!,
                        );
                      }
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Update & Decide'),
                  )
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
