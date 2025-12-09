import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Theme Colors ---
const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _cardColor = Colors.white;

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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: _accentGreen));
      if (ok) _fetchPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('Payments Received',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryBeige,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : _payments.isEmpty
              ? const Center(
                  child: Text('No payments found.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _payments.length,
                  itemBuilder: (context, index) {
                    final p = _payments[index];
                    final isPaid = p['status'] == 'paid';

                    return Card(
                      color: _cardColor,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: _accentGreen.withOpacity(0.1),
                          child: const Icon(Icons.monetization_on,
                              color: _accentGreen, size: 30),
                        ),
                        title: Text('\$${p['amount']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Status: ${p['status'].toString().toUpperCase()}',
                                  style: TextStyle(
                                      color:
                                          isPaid ? _accentGreen : Colors.orange,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                  DateFormat.yMMMd()
                                      .format(DateTime.parse(p['date'])),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        trailing: p['status'] == 'pending'
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: "Approve",
                                    icon: const Icon(Icons.check_circle,
                                        color: _accentGreen, size: 32),
                                    onPressed: () =>
                                        _updateStatus(p['_id'], 'paid'),
                                  ),
                                  IconButton(
                                    tooltip: "Reject",
                                    icon: const Icon(Icons.cancel,
                                        color: Colors.red, size: 32),
                                    onPressed: () =>
                                        _updateStatus(p['_id'], 'failed'),
                                  ),
                                ],
                              )
                            : Icon(
                                isPaid
                                    ? Icons.check_circle_outline
                                    : Icons.error_outline,
                                color: isPaid ? _accentGreen : Colors.red,
                                size: 32,
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}
