import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

// --- Theme Colors ---
const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);
const Color _textSecondary = Color(0xFF757575);
const Color _cardColor = Colors.white;

class LandlordMaintenanceScreen extends StatefulWidget {
  const LandlordMaintenanceScreen({super.key});

  @override
  State<LandlordMaintenanceScreen> createState() =>
      _LandlordMaintenanceScreenState();
}

class _LandlordMaintenanceScreenState extends State<LandlordMaintenanceScreen> {
  bool _isLoading = true;
  List<dynamic> _requests = [];
  List<dynamic> _filteredRequests = [];
  List<dynamic> _properties = [];
  String? _landlordId;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter;
  String? _selectedPriorityFilter;
  String? _selectedTypeFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterRequests);
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
      await _fetchPropertiesAndRequests();
    }
  }

  Future<void> _fetchPropertiesAndRequests() async {
    setState(() => _isLoading = true);
    
    // Fetch landlord's properties first
    final (okProps, propsData) = await ApiService.getPropertiesByOwner(_landlordId!);
    
    if (okProps && propsData is List) {
      _properties = propsData;
      final propertyIds = _properties.map((p) => p['_id']).toSet();
      
      // Fetch all maintenance requests
      final (ok, data) = await ApiService.getAllMaintenance();
      
      if (mounted) {
        setState(() {
          if (ok && data is List) {
            // Filter maintenance requests to only include those for landlord's properties
            _requests = data.where((request) {
              final propertyId = request['propertyId'];
              if (propertyId is Map) {
                return propertyIds.contains(propertyId['_id']);
              } else if (propertyId is String) {
                return propertyIds.contains(propertyId);
              }
              return false;
            }).toList();
          }
          _isLoading = false;
        });
        _filterRequests();
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

        // Filter by type
        bool typeMatch = _selectedTypeFilter == null ||
            (request['type'] ?? 'maintenance') == _selectedTypeFilter;

        if (!statusMatch || !priorityMatch || !typeMatch) return false;

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

  Future<void> _updateStatus(String id, String status) async {
    final (ok, msg) = await ApiService.updateMaintenance(id, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: _accentGreen));
      if (ok) _fetchPropertiesAndRequests();
    }
  }

  Future<void> _updateRequest(String id, Map<String, dynamic> updates) async {
    // Update status if provided
    if (updates.containsKey('status')) {
      await _updateStatus(id, updates['status']);
    }
    // Other updates can be added here when API supports them
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
          backgroundColor: ok ? _accentGreen : Colors.red,
        ));
        if (ok) _fetchPropertiesAndRequests();
      }
    }
  }

  Future<void> _assignTechnician(String id) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Technician'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(
                labelText: 'Technician Name',
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _accentGreen)))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen, foregroundColor: Colors.white),
              child: const Text('Assign')),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final (ok, msg) = await ApiService.assignTechnician(id, name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: _accentGreen));
        if (ok) _fetchPropertiesAndRequests();
      }
    }
  }

  void _showFilterDialog() {
    String? tempStatusFilter = _selectedStatusFilter;
    String? tempPriorityFilter = _selectedPriorityFilter;
    String? tempTypeFilter = _selectedTypeFilter;

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
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempStatusFilter == null) const SizedBox(width: 8),
                      const Text('All'),
                    ],
                  ),
                  value: null,
                  groupValue: tempStatusFilter,
                  activeColor: _accentGreen,
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
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempStatusFilter == 'pending') const SizedBox(width: 8),
                      const Text('Pending'),
                    ],
                  ),
                  value: 'pending',
                  groupValue: tempStatusFilter,
                  activeColor: _accentGreen,
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
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempStatusFilter == 'in_progress') const SizedBox(width: 8),
                      const Text('In Progress'),
                    ],
                  ),
                  value: 'in_progress',
                  groupValue: tempStatusFilter,
                  activeColor: _accentGreen,
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
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempStatusFilter == 'resolved') const SizedBox(width: 8),
                      const Text('Resolved'),
                    ],
                  ),
                  value: 'resolved',
                  groupValue: tempStatusFilter,
                  activeColor: _accentGreen,
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
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempPriorityFilter == null) const SizedBox(width: 8),
                      const Text('All'),
                    ],
                  ),
                  value: null,
                  groupValue: tempPriorityFilter,
                  activeColor: _accentGreen,
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
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempPriorityFilter == 'low') const SizedBox(width: 8),
                      const Text('Low'),
                    ],
                  ),
                  value: 'low',
                  groupValue: tempPriorityFilter,
                  activeColor: _accentGreen,
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
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempPriorityFilter == 'medium') const SizedBox(width: 8),
                      const Text('Medium'),
                    ],
                  ),
                  value: 'medium',
                  groupValue: tempPriorityFilter,
                  activeColor: _accentGreen,
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
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempPriorityFilter == 'high') const SizedBox(width: 8),
                      const Text('High'),
                    ],
                  ),
                  value: 'high',
                  groupValue: tempPriorityFilter,
                  activeColor: _accentGreen,
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
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempPriorityFilter == 'urgent') const SizedBox(width: 8),
                      const Text('Urgent'),
                    ],
                  ),
                  value: 'urgent',
                  groupValue: tempPriorityFilter,
                  activeColor: _accentGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempPriorityFilter = value;
                    });
                  },
                ),
                const Divider(),
                const Text('Type:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                RadioListTile<String?>(
                  title: Row(
                    children: [
                      if (tempTypeFilter == null)
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempTypeFilter == null) const SizedBox(width: 8),
                      const Text('All'),
                    ],
                  ),
                  value: null,
                  groupValue: tempTypeFilter,
                  activeColor: _accentGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempTypeFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      if (tempTypeFilter == 'maintenance')
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempTypeFilter == 'maintenance') const SizedBox(width: 8),
                      const Text('Maintenance'),
                    ],
                  ),
                  value: 'maintenance',
                  groupValue: tempTypeFilter,
                  activeColor: _accentGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempTypeFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      if (tempTypeFilter == 'complaint')
                        const Icon(Icons.check, size: 18, color: _accentGreen),
                      if (tempTypeFilter == 'complaint') const SizedBox(width: 8),
                      const Text('Complaint'),
                    ],
                  ),
                  value: 'complaint',
                  groupValue: tempTypeFilter,
                  activeColor: _accentGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempTypeFilter = value;
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
                  tempTypeFilter = null;
                });
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatusFilter = tempStatusFilter;
                  _selectedPriorityFilter = tempPriorityFilter;
                  _selectedTypeFilter = tempTypeFilter;
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
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('Maintenance Requests',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryBeige,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : Column(
              children: [
                // Search and Filter Bar
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardColor,
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
                                  _selectedPriorityFilter != null ||
                                  _selectedTypeFilter != null
                              ? _accentGreen
                              : Colors.grey,
                        ),
                        onPressed: _showFilterDialog,
                        tooltip: 'Filter Options',
                        style: IconButton.styleFrom(
                          backgroundColor: _selectedStatusFilter != null ||
                                  _selectedPriorityFilter != null ||
                                  _selectedTypeFilter != null
                              ? _accentGreen.withOpacity(0.1)
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
                                    ? 'No maintenance requests found'
                                    : 'No results found',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _requests.isEmpty
                                    ? 'Requests for your properties will appear here.'
                                    : 'Try adjusting your search or filter.',
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchPropertiesAndRequests,
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
            ),
    );
  }
}

// ===================================================================
// =================== MAINTENANCE CARD WIDGET ====================
// ===================================================================
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
    final requestType = widget.request['type'] ?? 'maintenance';
    final images = widget.request['images'] is List
        ? List<String>.from(widget.request['images'] ?? [])
        : <String>[];
    final technician = widget.request['technician'] ?? widget.request['technicianName'] ?? '';
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
                              color: _accentGreen),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          _buildTypeBadge(requestType),
                          const SizedBox(width: 12),
                          _buildPriorityBadge(priority),
                          const SizedBox(width: 12),
                          _statusButton(status),
                        ],
                      ),
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
                        color: _accentGreen,
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
                      backgroundColor: _accentGreen,
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

  Widget _buildTypeBadge(String type) {
    Color color;
    String label;
    IconData icon;

    switch (type.toLowerCase()) {
      case 'complaint':
        color = Colors.orange;
        label = 'شكوى';
        icon = Icons.report_problem;
        break;
      default: // maintenance
        color = Colors.blue;
        label = 'صيانة';
        icon = Icons.build;
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
          Icon(icon, size: 22, color: _accentGreen),
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
    final requestType = widget.request['type'] ?? 'maintenance';
    final images = widget.request['images'] is List
        ? List<String>.from(widget.request['images'] ?? [])
        : <String>[];
    final technician = widget.request['technician'] ?? widget.request['technicianName'] ?? '';
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
                  color: _accentGreen,
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
                              _buildTypeBadge(requestType),
                              const SizedBox(height: 8),
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
                        backgroundColor: _accentGreen,
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
        TextEditingController(text: widget.request['technician'] ?? widget.request['technicianName'] ?? '');
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
                      backgroundColor: _accentGreen,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGreen,
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

class _FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageGallery> createState() => _FullScreenImageGalleryState();
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
