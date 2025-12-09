import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Theme Colors ---
const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);
const Color _cardColor = Colors.white;

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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: _accentGreen));
      if (ok) _fetchContracts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('My Contracts',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryBeige,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : _contracts.isEmpty
              ? Center(
                  child: Text('No contracts found.',
                      style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contracts.length,
                  itemBuilder: (context, index) {
                    final c = _contracts[index];
                    final tenant = c['tenantId'] ?? {};
                    final property = c['propertyId'] ?? {};
                    final isActive = c['status'] == 'active';

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
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(property['title'] ?? 'N/A',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: _textPrimary)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? _accentGreen.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isActive
                                            ? _accentGreen
                                            : Colors.grey),
                                  ),
                                  child: Text(
                                    (c['status'] ?? '')
                                        .toString()
                                        .toUpperCase(),
                                    style: TextStyle(
                                        color: isActive
                                            ? _accentGreen
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                )
                              ],
                            ),
                            const Divider(height: 24),
                            _buildInfoRow(Icons.person, 'Tenant',
                                tenant['name'] ?? 'Unknown'),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.attach_money, 'Rent',
                                '\$${c['rentAmount']}'),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.date_range, 'Period',
                                '${DateFormat.yMd().format(DateTime.parse(c['startDate']))} - ${DateFormat.yMd().format(DateTime.parse(c['endDate']))}'),
                            const SizedBox(height: 16),
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
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _primaryBeige,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Update Status',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                      SizedBox(width: 8),
                                      Icon(Icons.edit,
                                          color: Colors.white, size: 16),
                                    ],
                                  ),
                                ),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600])),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: _textPrimary)),
      ],
    );
  }
}
