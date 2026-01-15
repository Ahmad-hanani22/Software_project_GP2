import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

// --- Color Palette ---
const Color _primaryGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFF5F5F5);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class AdminMaintenanceComplaintsScreen extends StatefulWidget {
  final String? propertyId;
  
  const AdminMaintenanceComplaintsScreen({super.key, this.propertyId});

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
        title: Text(widget.propertyId != null 
            ? 'Property Maintenance' 
            : 'Maintenance & Complaints'),
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
                text: 'Maintenance'),
            Tab(
                icon: Icon(Icons.bar_chart, color: Colors.white),
                text: 'Charts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MaintenanceManagementTab(propertyId: widget.propertyId),
          MaintenanceChartsTab(propertyId: widget.propertyId),
        ],
      ),
    );
  }
}

// ===================================================================
// =================== MAINTENANCE MANAGEMENT TAB ====================
// ===================================================================
class MaintenanceManagementTab extends StatefulWidget {
  final String? propertyId;
  
  const MaintenanceManagementTab({super.key, this.propertyId});

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
  String? _selectedPriorityFilter;
  Timer? _refreshTimer;

  // Statistics
  int _totalRequests = 0;
  int _pendingRequests = 0;
  int _inProgressRequests = 0;
  int _resolvedRequests = 0;
  double _totalCost = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_filterRequests);
    // Real-time refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _calculateStatistics() {
    _totalRequests = _requests.length;
    _pendingRequests = _requests.where((r) => r['status'] == 'pending').length;
    _inProgressRequests =
        _requests.where((r) => r['status'] == 'in_progress').length;
    _resolvedRequests =
        _requests.where((r) => r['status'] == 'resolved').length;
    _totalCost = _requests.fold(0.0, (sum, r) {
      final cost = r['cost'] ?? 0.0;
      return sum + (cost is num ? cost.toDouble() : 0.0);
    });
  }

  void _filterRequests() {
    setState(() {
      String searchQuery = _searchController.text.toLowerCase();
      _filteredRequests = _requests.where((request) {
        // Filter by status
        bool statusMatch = _selectedStatusFilter == null ||
            (request['status'] ?? 'pending') == _selectedStatusFilter;

        // Filter by priority
        bool priorityMatch = _selectedPriorityFilter == null ||
            (request['priority'] ?? 'medium') == _selectedPriorityFilter;

        if (!statusMatch || !priorityMatch) return false;

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
    final (ok, data) = await ApiService.getAllMaintenance();

    if (mounted) {
      setState(() {
        if (ok) {
          List<dynamic> allRequests = data as List<dynamic>;
          // Filter by propertyId if provided
          if (widget.propertyId != null) {
            _requests = allRequests.where((request) {
              final propertyId = request['propertyId'];
              if (propertyId is Map) {
                return propertyId['_id'] == widget.propertyId;
              } else if (propertyId is String) {
                return propertyId == widget.propertyId;
              }
              return false;
            }).toList();
          } else {
            _requests = allRequests;
          }
          _calculateStatistics();
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

  Future<void> _updateRequest(String id, Map<String, dynamic> updates) async {
    // This would need to be added to ApiService
    // For now, we'll use updateMaintenance for status updates
    if (updates.containsKey('status')) {
      await _updateStatus(id, updates['status']);
    }
  }

  Future<void> _deleteMaintenance(String id) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Request"),
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
    String? tempStatusFilter = _selectedStatusFilter;
    String? tempPriorityFilter = _selectedPriorityFilter;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Filter Options'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Status:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String?>(
                  title: Row(
                    children: [
                      if (tempStatusFilter == null)
                        const Icon(Icons.check, size: 18, color: _primaryGreen),
                      if (tempStatusFilter == null) const SizedBox(width: 8),
                      const Text('All'),
                    ],
                  ),
                  value: null,
                  groupValue: tempStatusFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempStatusFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      if (tempStatusFilter == 'pending')
                        const Icon(Icons.check, size: 18, color: _primaryGreen),
                      if (tempStatusFilter == 'pending') const SizedBox(width: 8),
                      const Text('Pending'),
                    ],
                  ),
                  value: 'pending',
                  groupValue: tempStatusFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempStatusFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      if (tempStatusFilter == 'in_progress')
                        const Icon(Icons.check, size: 18, color: _primaryGreen),
                      if (tempStatusFilter == 'in_progress') const SizedBox(width: 8),
                      const Text('In Progress'),
                    ],
                  ),
                  value: 'in_progress',
                  groupValue: tempStatusFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempStatusFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      if (tempStatusFilter == 'resolved')
                        const Icon(Icons.check, size: 18, color: _primaryGreen),
                      if (tempStatusFilter == 'resolved') const SizedBox(width: 8),
                      const Text('Resolved'),
                    ],
                  ),
                  value: 'resolved',
                  groupValue: tempStatusFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempStatusFilter = value;
                    });
                  },
                ),
                const Divider(),
                const Text('Priority:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String?>(
                  title: Row(
                    children: [
                      if (tempPriorityFilter == null)
                        const Icon(Icons.check, size: 18, color: _primaryGreen),
                      if (tempPriorityFilter == null) const SizedBox(width: 8),
                      const Text('All'),
                    ],
                  ),
                  value: null,
                  groupValue: tempPriorityFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempPriorityFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      if (tempPriorityFilter == 'low')
                        const Icon(Icons.check, size: 18, color: _primaryGreen),
                      if (tempPriorityFilter == 'low') const SizedBox(width: 8),
                      const Text('Low'),
                    ],
                  ),
                  value: 'low',
                  groupValue: tempPriorityFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempPriorityFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      if (tempPriorityFilter == 'medium')
                        const Icon(Icons.check, size: 18, color: _primaryGreen),
                      if (tempPriorityFilter == 'medium') const SizedBox(width: 8),
                      const Text('Medium'),
                    ],
                  ),
                  value: 'medium',
                  groupValue: tempPriorityFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempPriorityFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      if (tempPriorityFilter == 'high')
                        const Icon(Icons.check, size: 18, color: _primaryGreen),
                      if (tempPriorityFilter == 'high') const SizedBox(width: 8),
                      const Text('High'),
                    ],
                  ),
                  value: 'high',
                  groupValue: tempPriorityFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempPriorityFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      if (tempPriorityFilter == 'urgent')
                        const Icon(Icons.check, size: 18, color: _primaryGreen),
                      if (tempPriorityFilter == 'urgent') const SizedBox(width: 8),
                      const Text('Urgent'),
                    ],
                  ),
                  value: 'urgent',
                  groupValue: tempPriorityFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempPriorityFilter = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setModalState(() {
                  tempStatusFilter = null;
                  tempPriorityFilter = null;
                });
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatusFilter = tempStatusFilter;
                  _selectedPriorityFilter = tempPriorityFilter;
                });
                Navigator.pop(context);
                _filterRequests();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
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
        // Summary Dashboard
        _buildSummaryDashboard(),
        // Search and Filter Bar
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
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
                  color: _selectedStatusFilter != null ||
                          _selectedPriorityFilter != null
                      ? _primaryGreen
                      : Colors.grey,
                ),
                onPressed: _showFilterDialog,
                tooltip: 'Filter Options',
                style: IconButton.styleFrom(
                  backgroundColor: _selectedStatusFilter != null ||
                          _selectedPriorityFilter != null
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
              ? SingleChildScrollView(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _requests.isEmpty
                                  ? 'Active requests will appear here.'
                                  : 'Try adjusting your search or filter.',
                              style: const TextStyle(color: _textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: SizedBox.expand(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      itemCount: _filteredRequests.length,
                      itemBuilder: (context, index) {
                        return _MaintenanceCard(
                          request: _filteredRequests[index],
                          onUpdateStatus: _updateStatus,
                          onUpdateRequest: _updateRequest,
                          onDelete: _deleteMaintenance,
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryDashboard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              _totalRequests.toString(),
              Icons.list_alt,
              _primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Pending',
              _pendingRequests.toString(),
              Icons.access_time,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'In Progress',
              _inProgressRequests.toString(),
              Icons.build,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Resolved',
              _resolvedRequests.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              'Total Cost',
              '\$${_totalCost.toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final Function(String id, String newStatus) onUpdateStatus;
  final Function(String id, Map<String, dynamic> updates) onUpdateRequest;
  final Function(String id) onDelete;

  const _MaintenanceCard({
    required this.request,
    required this.onUpdateStatus,
    required this.onUpdateRequest,
    required this.onDelete,
  });

  @override
  State<_MaintenanceCard> createState() => _MaintenanceCardState();
}

class _MaintenanceCardState extends State<_MaintenanceCard> {
  @override
  Widget build(BuildContext context) {
    final tenant = widget.request['tenantId'] ?? {};
    final property = widget.request['propertyId'] ?? {};
    final status = widget.request['status'] ?? 'pending';
    final priority = widget.request['priority'] ?? 'medium';
    final images = widget.request['images'] is List
        ? List<String>.from(widget.request['images'] ?? [])
        : <String>[];
    final technician = widget.request['technician'] ?? '';
    final cost = widget.request['cost'] ?? 0.0;
    final createdAt = widget.request['createdAt'];

    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailsDialog(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Priority and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          property['title'] ?? 'N/A Property',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: _primaryGreen),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          property['address'] ?? 'No address',
                          style: const TextStyle(
                              color: _textSecondary, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildPriorityBadge(priority),
                      const SizedBox(width: 12),
                      _statusButton(status),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Description
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: Text(
                  widget.request['description'] ?? 'No description provided.',
                  style: const TextStyle(fontSize: 16, color: _textPrimary, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),
              // Images Gallery (if available)
              if (images.isNotEmpty) ...[
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length > 3 ? 3 : images.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => _showImageGallery(images, index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: images[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey[200],
                                child: const Icon(Icons.error),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (images.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+${images.length - 3} more images',
                      style: const TextStyle(
                        fontSize: 14,
                        color: _primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
              // Info Rows
              _buildInfoRow(
                  Icons.person_outline, "Requester:", tenant['name'] ?? 'N/A'),
              const SizedBox(height: 12),
              _buildInfoRow(
                  Icons.phone_outlined, "Contact:", tenant['phone'] ?? 'N/A'),
              if (technician.toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoRow(Icons.person_pin, "Technician:", technician),
              ],
              if (cost > 0) ...[
                const SizedBox(height: 12),
                _buildInfoRow(Icons.attach_money, "Cost:",
                    '\$${cost.toStringAsFixed(2)}'),
              ],
              // Timeline
              if (createdAt != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 18, color: _textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      'Created: ${_formatDate(createdAt)}',
                      style:
                          const TextStyle(fontSize: 14, color: _textSecondary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                    onPressed: () => widget.onDelete(widget.request['_id']),
                    tooltip: 'Delete',
                    padding: const EdgeInsets.all(12),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showUpdateDialog(),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Update', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    String label;
    IconData icon;

    switch (priority.toLowerCase()) {
      case 'urgent':
        color = Colors.red;
        label = 'Urgent';
        icon = Icons.priority_high;
        break;
      case 'high':
        color = Colors.orange;
        label = 'High';
        icon = Icons.arrow_upward;
        break;
      case 'low':
        color = Colors.blue;
        label = 'Low';
        icon = Icons.arrow_downward;
        break;
      default:
        color = Colors.grey;
        label = 'Medium';
        icon = Icons.remove;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusButton(String status) {
    Color bg;
    if (status == 'pending') {
      bg = Colors.orange;
    } else if (status == 'in_progress') {
      bg = Colors.blue;
    } else {
      bg = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _primaryGreen),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: _textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: _textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is String) {
        return DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(date));
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showImageGallery(List<String> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageGallery(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _showDetailsDialog() {
    final tenant = widget.request['tenantId'] ?? {};
    final property = widget.request['propertyId'] ?? {};
    final status = widget.request['status'] ?? 'pending';
    final priority = widget.request['priority'] ?? 'medium';
    final images = widget.request['images'] is List
        ? List<String>.from(widget.request['images'] ?? [])
        : <String>[];
    final technician = widget.request['technician'] ?? '';
    final cost = widget.request['cost'] ?? 0.0;
    final notes = widget.request['notes'] is List
        ? List<Map<String, dynamic>>.from(widget.request['notes'] ?? [])
        : <Map<String, dynamic>>[];
    final createdAt = widget.request['createdAt'];
    final updatedAt = widget.request['updatedAt'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _primaryGreen,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Request Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Property & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  property['title'] ?? 'N/A',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  property['address'] ?? 'No address',
                                  style: const TextStyle(
                                    color: _textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              _buildPriorityBadge(priority),
                              const SizedBox(height: 8),
                              _statusButton(status),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.request['description'] ?? 'No description',
                        style: const TextStyle(fontSize: 14),
                      ),
                      // Images
                      if (images.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Images',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showImageGallery(images, index);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: images[index],
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      // Timeline
                      if (createdAt != null || updatedAt != null) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Timeline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (createdAt != null)
                          _buildTimelineItem(
                            'Created',
                            _formatDate(createdAt),
                            Icons.add_circle,
                            Colors.green,
                          ),
                        if (updatedAt != null)
                          _buildTimelineItem(
                            'Last Updated',
                            _formatDate(updatedAt),
                            Icons.update,
                            Colors.blue,
                          ),
                      ],
                      // Info
                      const SizedBox(height: 16),
                      const Text(
                        'Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.person_outline, "Requester:",
                          tenant['name'] ?? 'N/A'),
                      _buildInfoRow(Icons.phone_outlined, "Contact:",
                          tenant['phone'] ?? 'N/A'),
                      if (technician.toString().isNotEmpty)
                        _buildInfoRow(
                            Icons.person_pin, "Technician:", technician),
                      if (cost > 0)
                        _buildInfoRow(Icons.attach_money, "Cost:",
                            '\$${cost.toStringAsFixed(2)}'),
                      // Notes/Comments
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Notes & Comments',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...notes.map((note) => _buildNoteCard(note)),
                      ],
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showUpdateDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Update'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
      String title, String date, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                note['author'] ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                note['date'] != null ? _formatDate(note['date']) : '',
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            note['text'] ?? '',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog() {
    final TextEditingController technicianController =
        TextEditingController(text: widget.request['technician'] ?? '');
    final TextEditingController costController =
        TextEditingController(text: widget.request['cost']?.toString() ?? '');
    final TextEditingController noteController = TextEditingController();
    String selectedPriority = widget.request['priority'] ?? 'medium';
    String selectedStatus = widget.request['status'] ?? 'pending';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Request'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status
                const Text('Status:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('In Progress')),
                    DropdownMenuItem(
                        value: 'resolved', child: Text('Resolved')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStatus = value ?? 'pending';
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Priority
                const Text('Priority:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedPriority = value ?? 'medium';
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Technician
                TextField(
                  controller: technicianController,
                  decoration: const InputDecoration(
                    labelText: 'Technician',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_pin),
                  ),
                ),
                const SizedBox(height: 16),
                // Cost
                TextField(
                  controller: costController,
                  decoration: const InputDecoration(
                    labelText: 'Cost',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                // Note
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Add Note/Comment',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Update status
                await widget.onUpdateStatus(
                    widget.request['_id'], selectedStatus);
                // Update other fields (would need API support)
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request updated successfully'),
                      backgroundColor: _primaryGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// =================== MAINTENANCE CHARTS TAB ====================
// ===================================================================
class MaintenanceChartsTab extends StatefulWidget {
  final String? propertyId;
  
  const MaintenanceChartsTab({super.key, this.propertyId});

  @override
  State<MaintenanceChartsTab> createState() => _MaintenanceChartsTabState();
}

class _MaintenanceChartsTabState extends State<MaintenanceChartsTab> {
  bool _isLoading = true;
  List<dynamic> _requests = [];
  String? _errorMessage;

  // Statistics
  int _totalRequests = 0;
  int _pendingRequests = 0;
  int _inProgressRequests = 0;
  int _resolvedRequests = 0;
  double _totalCost = 0.0;

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
        _isLoading = false;
        if (ok) {
          List<dynamic> allRequests = data is List ? data : [];
          // Filter by propertyId if provided
          if (widget.propertyId != null) {
            _requests = allRequests.where((request) {
              final propertyId = request['propertyId'];
              if (propertyId is Map) {
                return propertyId['_id'] == widget.propertyId;
              } else if (propertyId is String) {
                return propertyId == widget.propertyId;
              }
              return false;
            }).toList();
          } else {
            _requests = allRequests;
          }
          _calculateStats();
        } else {
          _errorMessage = data.toString();
        }
      });
    }
  }

  void _calculateStats() {
    _totalRequests = _requests.length;
    _pendingRequests = _requests.where((r) => r['status'] == 'pending').length;
    _inProgressRequests =
        _requests.where((r) => r['status'] == 'in_progress').length;
    _resolvedRequests = _requests.where((r) => r['status'] == 'resolved').length;
    _totalCost = _requests.fold<double>(
        0.0, (sum, r) => sum + ((r['cost'] ?? 0) as num).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No data available for charts',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Chart
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Requests by Status',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sections: _buildStatusPieChart(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusLegend(),
              ],
            ),
          ),
          // Priority Chart
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Requests by Priority',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      barGroups: _buildPriorityBarChart(),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cost Chart
          if (_totalCost > 0)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Cost',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    NumberFormat.currency(symbol: '\$').format(_totalCost),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildStatusPieChart() {
    final colors = [
      Colors.orange, // Pending
      Colors.blue, // In Progress
      Colors.green, // Resolved
    ];
    final values = [
      _pendingRequests.toDouble(),
      _inProgressRequests.toDouble(),
      _resolvedRequests.toDouble(),
    ];
    final total = values.fold<double>(0, (sum, val) => sum + val);

    return values.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      final percentage = total > 0 ? (value / total * 100) : 0;
      return PieChartSectionData(
        value: value,
        title: '${percentage.toStringAsFixed(1)}%',
        color: colors[index % colors.length],
        radius: 70,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildStatusLegend() {
    final colors = [Colors.orange, Colors.blue, Colors.green];
    final labels = ['Pending', 'In Progress', 'Resolved'];
    final values = [_pendingRequests, _inProgressRequests, _resolvedRequests];

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: values.asMap().entries.map((entry) {
        final index = entry.key;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${labels[index]}: ${values[index]}',
              style: const TextStyle(fontSize: 16, color: _textPrimary),
            ),
          ],
        );
      }).toList(),
    );
  }

  List<BarChartGroupData> _buildPriorityBarChart() {
    final priorityCounts = <String, int>{};
    for (var request in _requests) {
      final priority = request['priority'] ?? 'medium';
      priorityCounts[priority] = (priorityCounts[priority] ?? 0) + 1;
    }

    final colors = [
      Colors.green, // Low
      Colors.orange, // Medium
      Colors.red, // High
    ];
    final priorities = ['low', 'medium', 'high'];
    int index = 0;

    return priorityCounts.entries.map((entry) {
      final priorityIndex = priorities.indexOf(entry.key);
      final color = priorityIndex >= 0 && priorityIndex < colors.length
          ? colors[priorityIndex]
          : Colors.grey;
      return BarChartGroupData(
        x: index++,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: color,
            width: 20,
          ),
        ],
      );
    }).toList();
  }
}

class _FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageGallery> createState() =>
      _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<_FullScreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.images[index]),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
        itemCount: widget.images.length,
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
          ),
        ),
        pageController: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
