// lib/screens/admin_maintenance_complaints_screen.dart

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
          );
        },
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Function(String id, String newStatus) onUpdateStatus;

  const _MaintenanceCard({required this.request, required this.onUpdateStatus});

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
                            color: _primaryGreen))),
                _buildStatusChip(status, isMaintenance: true),
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
          );
        },
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final Function(String id, String newStatus) onUpdateStatus;

  const _ComplaintCard({required this.complaint, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final user = complaint['userId'] ?? {};
    final againstUser = complaint['againstUserId'];
    final status = complaint['status'] ?? 'open';
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
                Text('Complaint #${complaint['_id'].substring(0, 7)}...',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _primaryGreen)),
                _buildStatusChip(status, isMaintenance: false),
              ],
            ),
            Text(DateFormat('d MMM, yyyy').format(date),
                style: const TextStyle(color: _textSecondary, fontSize: 12)),
            const Divider(height: 20),
            Text(complaint['description'] ?? 'No description.',
                style: const TextStyle(fontSize: 15, color: _textPrimary)),
            const Divider(height: 20),
            _buildInfoRow(Icons.person_outline, 'From:', user['name'] ?? 'N/A'),
            if (againstUser != null)
              _buildInfoRow(Icons.person_pin_outlined, 'Against:',
                  againstUser['name'] ?? 'N/A'),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) =>
                        onUpdateStatus(complaint['_id'], value),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                          value: 'open', child: Text('Mark as Open')),
                      const PopupMenuItem(
                          value: 'in_review', child: Text('Mark as In Review')),
                      const PopupMenuItem(
                          value: 'closed', child: Text('Mark as Closed')),
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
Widget _buildStatusChip(String status, {required bool isMaintenance}) {
  Color chipColor, textColor;
  List<String> statuses = isMaintenance
      ? ['pending', 'in_progress', 'resolved']
      : ['open', 'in_review', 'closed'];

  if (status == statuses[0]) {
    // Pending / Open
    chipColor = Colors.orange.shade100;
    textColor = Colors.orange.shade800;
  } else if (status == statuses[1]) {
    // In Progress / In Review
    chipColor = Colors.blue.shade100;
    textColor = Colors.blue.shade800;
  } else {
    // Resolved / Closed
    chipColor = Colors.green.shade100;
    textColor = Colors.green.shade800;
  }

  return Chip(
    label: Text(status.replaceAll('_', ' ').toUpperCase()),
    backgroundColor: chipColor,
    labelStyle:
        TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
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
