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
  final TextEditingController _terminationReasonController =
      TextEditingController();

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

  @override
  void dispose() {
    _terminationReasonController.dispose();
    super.dispose();
  }

  // ✅ إضافة وديعة للعقد
  void _showAddDepositDialog(dynamic contract) {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final contractId = contract['_id'].toString();
    final property = contract['propertyId'] ?? {};
    final propertyTitle = property['title'] ?? 'Property';

    // Calculate suggested amount: depositAmount from contract, or rentAmount as fallback
    final suggestedAmount =
        contract['depositAmount'] ?? contract['rentAmount'] ?? 0.0;
    if (suggestedAmount > 0) {
      amountController.text = suggestedAmount.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Deposit',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.home, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            propertyTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Show suggested amount if available
                  if (contract['depositAmount'] != null ||
                      contract['rentAmount'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              contract['depositAmount'] != null
                                  ? 'Suggested amount from contract: \$${contract['depositAmount']}'
                                  : 'Suggested amount (1 month rent): \$${contract['rentAmount'] ?? 0}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Deposit Amount *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      hintText: '0.00',
                      helperText:
                          'Enter the deposit amount (suggested amount is pre-filled)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter deposit amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) return;

                      Navigator.of(ctx).pop();

                      // Show loading
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (loadingCtx) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                      );

                      final (ok, message) = await ApiService.addDeposit({
                        'contractId': contractId,
                        'amount': amount,
                      });

                      if (mounted) {
                        Navigator.of(context).pop(); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor:
                                ok ? const Color(0xFF2E7D32) : Colors.red,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        if (ok) {
                          _fetchContracts();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create Deposit',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ طلب إنهاء العقد (باستخدام المسار الجديد)
  Future<void> _requestTermination(String contractId) async {
    _terminationReasonController.clear();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Request Contract Termination"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "Are you sure you want to request contract termination? This will notify the landlord."),
            const SizedBox(height: 12),
            TextField(
              controller: _terminationReasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Reason (optional)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
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

    final reason = _terminationReasonController.text.trim();

    final (ok, msg) = await ApiService.requestContractTermination(
      contractId,
      reason: reason.isEmpty ? null : reason,
    );

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
                    final status = (c['status'] ?? 'pending').toString();
                    final lowerStatus = status.toLowerCase();
                    final bool isActive = lowerStatus == 'active' ||
                        lowerStatus == 'rented' ||
                        lowerStatus == 'expiring_soon';

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
                              color: isActive ? Colors.green : Colors.grey,
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
                                // Only show deposit button for active contracts (not pending)
                                if (lowerStatus == 'active' &&
                                    lowerStatus != 'terminated' &&
                                    lowerStatus != 'expired') ...[
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              _showAddDepositDialog(c),
                                          icon: const Icon(Icons.security,
                                              size: 18),
                                          label: const Text("Add Deposit"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF2E7D32),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _requestTermination(c['_id']),
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                  color: Colors.red),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8))),
                                          child: const Text("Terminate"),
                                        ),
                                      ),
                                    ],
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
