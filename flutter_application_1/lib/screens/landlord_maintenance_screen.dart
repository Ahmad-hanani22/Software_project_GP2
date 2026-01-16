import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Theme Colors ---
const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);
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
  List<dynamic> _properties = [];
  String? _landlordId;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    final (ok, msg) = await ApiService.updateMaintenance(id, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: _accentGreen));
      if (ok) _fetchPropertiesAndRequests();
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
          : _requests.isEmpty
              ? Center(
                  child: Text('No maintenance requests found.',
                      style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final r = _requests[index];
                    final tenant = r['tenantId'] ?? {};
                    final status = r['status'] ?? 'pending';
                    final isResolved = status == 'resolved';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                      r['propertyId']?['title'] ??
                                          'Unknown Property',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textPrimary)),
                                ),
                                Chip(
                                  label: Text(status.toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10)),
                                  backgroundColor:
                                      isResolved ? _accentGreen : Colors.orange,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Issue: ${r['description']}',
                                style: const TextStyle(
                                    fontSize: 15, color: _textPrimary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('Tenant: ${tenant['name'] ?? 'N/A'}',
                                    style: TextStyle(color: Colors.grey[700])),
                              ],
                            ),
                            if (r['technicianName'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.engineering_outlined,
                                        size: 16, color: _accentGreen),
                                    const SizedBox(width: 4),
                                    Text('Tech: ${r['technicianName']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _accentGreen)),
                                  ],
                                ),
                              ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _assignTechnician(r['_id']),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: _primaryBeige,
                                      side: const BorderSide(
                                          color: _primaryBeige)),
                                  child: const Text('Assign Tech'),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  onSelected: (val) =>
                                      _updateStatus(r['_id'], val),
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                        value: 'in_progress',
                                        child: Text('In Progress')),
                                    const PopupMenuItem(
                                        value: 'resolved',
                                        child: Text('Resolved')),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _accentGreen,
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    child: const Text('Update Status',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
