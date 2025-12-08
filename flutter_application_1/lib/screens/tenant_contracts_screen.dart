import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TenantContractsScreen extends StatefulWidget {
  const TenantContractsScreen({super.key});

  @override
  State<TenantContractsScreen> createState() => _TenantContractsScreenState();
}

class _TenantContractsScreenState extends State<TenantContractsScreen> {
  bool _isLoading = true;
  List<dynamic> _contracts = [];

  @override
  void initState() {
    super.initState();
    _fetchContracts();
  }

  Future<void> _fetchContracts() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null) {
      final (ok, data) = await ApiService.getUserContracts(userId);
      if (mounted) {
        setState(() {
          if (ok) _contracts = data as List<dynamic>;
          _isLoading = false;
        });
      }
    }
  }

  // ✅ طلب إنهاء العقد
  Future<void> _requestTermination(String contractId) async {
    // إظهار تأكيد
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("End Contract?"),
        content: const Text(
            "Are you sure you want to request contract termination? This will notify the landlord."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text("Confirm", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    // استدعاء API (تغيير الحالة إلى terminated أو pending_termination)
    // سنستخدم "terminated" مباشرة للتبسيط أو يمكنك إضافة حالة جديدة في الباك إند
    final (ok, msg) =
        await ApiService.updateContractStatus(contractId, 'terminated');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? "Contract termination requested!" : msg),
        backgroundColor: ok ? Colors.orange : Colors.red,
      ));
      if (ok) _fetchContracts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
          title: const Text("My Contracts"),
          backgroundColor: const Color(0xFF00695C),
          elevation: 0),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00695C)))
          : _contracts.isEmpty
              ? const Center(
                  child: Text("No contracts found.",
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contracts.length,
                  itemBuilder: (context, index) {
                    final c = _contracts[index];
                    final property = c['propertyId'] ?? {};
                    final landlord = c['landlordId'] ?? {};
                    final status = c['status'] ?? 'pending';
                   final bool isRented = status == 'rented' || status == 'active';
                    Color statusColor = isRented ? Colors.green : Colors.orange;

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          // Header (Status)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isRented  ? Colors.green : Colors.grey,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    "Contract #${c['_id'].toString().substring(c['_id'].toString().length - 6)}",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                Text(status.toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Property Info
                                Text(property['title'] ?? "Unknown Property",
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87)),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                        child: Text(
                                            property['address'] ?? "No Address",
                                            style: const TextStyle(
                                                color: Colors.grey))),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Landlord Info
                                Row(
                                  children: [
                                    const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.blueGrey,
                                        child: Icon(Icons.person,
                                            size: 18, color: Colors.white)),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text("Landlord",
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey)),
                                        Text(landlord['name'] ?? "Unknown",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const Spacer(),
                                    // زر الاتصال (وهمي حالياً)
                                    IconButton(
                                      icon: const Icon(Icons.phone,
                                          color: Colors.green),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    "Contacting ${landlord['name']}...")));
                                      },
                                    )
                                  ],
                                ),
                                const Divider(height: 30),

                                // Dates & Rent
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _infoItem(
                                        "Start Date",
                                        DateFormat('yyyy-MM-dd').format(
                                            DateTime.parse(c['startDate']))),
                                    _infoItem(
                                        "End Date",
                                        DateFormat('yyyy-MM-dd').format(
                                            DateTime.parse(c['endDate']))),
                                    _infoItem("Rent", "\$${c['rentAmount']}",
                                        isPrice: true),
                                  ],
                                ),

                                // Actions
                                if (isRented ) ...[
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _requestTermination(c['_id']),
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                              color: Colors.red),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8))),
                                      child: const Text("Request Termination"),
                                    ),
                                  )
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _infoItem(String label, String value, {bool isPrice = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isPrice ? const Color(0xFF00695C) : Colors.black87)),
      ],
    );
  }
}
