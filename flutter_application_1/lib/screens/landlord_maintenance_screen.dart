import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Fetch properties first, then requests for each property
  Future<void> _fetchPropertiesAndRequests() async {
    setState(() => _isLoading = true);
    final (ok, props) = await ApiService.getPropertiesByOwner(_landlordId!);

    if (ok) {
      _properties = props as List<dynamic>;
      List<dynamic> allRequests = [];

      for (var prop in _properties) {
        final (reqOk, reqData) =
            await ApiService.getMaintenanceByProperty(prop['_id']);
        if (reqOk) {
          allRequests.addAll(reqData as List<dynamic>);
        }
      }

      if (mounted) {
        setState(() {
          _requests = allRequests;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    final (ok, msg) = await ApiService.updateMaintenance(id, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            decoration: const InputDecoration(labelText: 'Technician Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Assign')),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final (ok, msg) = await ApiService.assignTechnician(id, name);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
        if (ok) _fetchPropertiesAndRequests();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Maintenance Requests'),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(child: Text('No maintenance requests found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final r = _requests[index];
                    final tenant = r['tenantId'] ?? {};
                    final status = r['status'] ?? 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    r['propertyId']?['title'] ??
                                        'Unknown Property',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                Chip(
                                    label: Text(status.toUpperCase()),
                                    backgroundColor: status == 'resolved'
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100)
                              ],
                            ),
                            Text('Issue: ${r['description']}'),
                            Text('Tenant: ${tenant['name'] ?? 'N/A'}'),
                            if (r['technicianName'] != null)
                              Text('Technician: ${r['technicianName']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue)),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                    onPressed: () =>
                                        _assignTechnician(r['_id']),
                                    child: const Text('Assign Tech')),
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
                                  child: const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text('Update Status',
                                          style:
                                              TextStyle(color: Colors.blue))),
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
