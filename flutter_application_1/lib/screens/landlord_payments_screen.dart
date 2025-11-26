import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LandlordPaymentsScreen extends StatefulWidget {
  const LandlordPaymentsScreen({super.key});

  @override
  State<LandlordPaymentsScreen> createState() => _LandlordPaymentsScreenState();
}

class _LandlordPaymentsScreenState extends State<LandlordPaymentsScreen> {
  bool _isLoading = true;
  List<dynamic> _payments = [];
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
      _fetchPayments();
    }
  }

  Future<void> _fetchPayments() async {
    final (ok, data) = await ApiService.getUserPayments(_landlordId!);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (ok) _payments = data as List<dynamic>;
      });
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    final (ok, msg) = await ApiService.updatePayment(id, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (ok) _fetchPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Payments Received'),
          backgroundColor: const Color(0xFF1976D2),
          foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
              ? const Center(child: Text('No payments found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _payments.length,
                  itemBuilder: (context, index) {
                    final p = _payments[index];
                    final contract = p['contractId'] ?? {};
                    final tenantName = contract['tenantId']?['name'] ??
                        'N/A'; // Depends on backend population

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.monetization_on,
                            color: Colors.green, size: 40),
                        title: Text('\$${p['amount']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Status: ${p['status'].toString().toUpperCase()}'),
                            Text(
                                'Date: ${DateFormat.yMMMd().format(DateTime.parse(p['date']))}'),
                          ],
                        ),
                        trailing: p['status'] == 'pending'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.green),
                                    onPressed: () =>
                                        _updateStatus(p['_id'], 'paid'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _updateStatus(p['_id'], 'failed'),
                                  ),
                                ],
                              )
                            : Icon(
                                p['status'] == 'paid'
                                    ? Icons.check
                                    : Icons.error,
                                color: p['status'] == 'paid'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
