import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LandlordContractsScreen extends StatefulWidget {
  const LandlordContractsScreen({super.key});

  @override
  State<LandlordContractsScreen> createState() =>
      _LandlordContractsScreenState();
}

class _LandlordContractsScreenState extends State<LandlordContractsScreen> {
  bool _isLoading = true;
  List<dynamic> _contracts = [];
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
      _fetchContracts();
    }
  }

  Future<void> _fetchContracts() async {
    final (ok, data) = await ApiService.getUserContracts(_landlordId!);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (ok) _contracts = data as List<dynamic>;
      });
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    final (ok, msg) = await ApiService.updateContract(id, {'status': status});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (ok) _fetchContracts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('My Contracts'),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contracts.isEmpty
              ? const Center(child: Text('No contracts found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contracts.length,
                  itemBuilder: (context, index) {
                    final c = _contracts[index];
                    final tenant = c['tenantId'] ?? {};
                    final property = c['propertyId'] ?? {};
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
                                Text(property['title'] ?? 'N/A',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Chip(
                                  label: Text(
                                      (c['status'] ?? '')
                                          .toString()
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10)),
                                  backgroundColor: c['status'] == 'active'
                                      ? Colors.green
                                      : Colors.grey,
                                )
                              ],
                            ),
                            const Divider(),
                            Text('Tenant: ${tenant['name']}'),
                            Text('Rent: \$${c['rentAmount']}'),
                            Text(
                                'Period: ${DateFormat.yMd().format(DateTime.parse(c['startDate']))} - ${DateFormat.yMd().format(DateTime.parse(c['endDate']))}'),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<String>(
                                onSelected: (val) =>
                                    _updateStatus(c['_id'], val),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                      value: 'active',
                                      child: Text('Mark Active')),
                                  const PopupMenuItem(
                                      value: 'expired',
                                      child: Text('Mark Expired')),
                                  const PopupMenuItem(
                                      value: 'terminated',
                                      child: Text('Terminate')),
                                ],
                                child: const Chip(
                                    avatar: Icon(Icons.edit, size: 16),
                                    label: Text('Update Status')),
                              ),
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
