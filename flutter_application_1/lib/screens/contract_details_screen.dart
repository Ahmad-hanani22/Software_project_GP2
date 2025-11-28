import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/api_service.dart';

// ألوان الثيم الخاصة بك
const Color kPrimaryColor = Color(0xFF2E7D32);
const Color kSurfaceColor = Color(0xFFF9F9F9);

class ContractDetailsScreen extends StatefulWidget {
  final String contractId;

  const ContractDetailsScreen({super.key, required this.contractId});

  @override
  State<ContractDetailsScreen> createState() => _ContractDetailsScreenState();
}

class _ContractDetailsScreenState extends State<ContractDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _contract;
  String? _currentUserRole;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchContractDetails();
  }

  Future<void> _fetchContractDetails() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserRole =
        prefs.getString('role'); // جلب دور المستخدم (landlord/tenant)

    final (ok, data) = await ApiService.getContractById(widget
        .contractId); // تأكد أن هذه الدالة موجودة في ApiService وتقوم بـ GET /contracts/:id

    // ملاحظة: إذا لم تكن getContractById موجودة، استخدم getAllContracts وقم بالفلترة، أو أنشئها في الـ API.
    // لنفترض أنك أنشأت getContractById كما هو متوقع في الباك إند.

    if (mounted) {
      setState(() {
        if (ok) _contract = data;
        _isLoading = false;
      });
    }
  }

  // دالة التعامل مع الموافقة أو الرفض
  Future<void> _handleStatusUpdate(String newStatus) async {
    setState(() => _isUpdating = true);

    final (ok, msg) =
        await ApiService.updateContractStatus(widget.contractId, newStatus);

    if (mounted) {
      setState(() => _isUpdating = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Contract marked as $newStatus"),
          backgroundColor: newStatus == 'active' ? Colors.green : Colors.red,
        ));
        // إعادة تحميل البيانات لتحديث الواجهة
        _fetchContractDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $msg"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_contract == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Contract Details")),
        body: const Center(child: Text("Contract not found")),
      );
    }

    final c = _contract!;
    // استخراج البيانات بأمان (حسب هيكلة الباك إند)
    final tenantName =
        c['tenantId'] is Map ? c['tenantId']['name'] : 'Unknown Tenant';
    final landlordName =
        c['landlordId'] is Map ? c['landlordId']['name'] : 'Unknown Owner';
    final propertyTitle =
        c['propertyId'] is Map ? c['propertyId']['title'] : 'Property';
    final price = c['rentAmount'] ?? 0;
    final status = c['status'] ?? 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Contract Request"),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقة الحالة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusColor(status)),
              ),
              child: Column(
                children: [
                  Icon(_getStatusIcon(status),
                      color: _getStatusColor(status), size: 40),
                  const SizedBox(height: 8),
                  Text(
                    status.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // تفاصيل العقار
            _buildSectionHeader("Property Info"),
            _buildInfoTile(Icons.home, "Property", propertyTitle),
            _buildInfoTile(
                Icons.attach_money, "Rent Amount", "\$$price / month"),

            const SizedBox(height: 20),

            // تفاصيل الأطراف
            _buildSectionHeader("Parties Involved"),
            _buildInfoTile(Icons.person, "Tenant (Requester)", tenantName),
            _buildInfoTile(
                Icons.admin_panel_settings, "Landlord (Owner)", landlordName),

            const SizedBox(height: 40),

            // ✅✅ الجزء الأهم: أزرار التحكم للمالك فقط ✅✅
            if (status == 'pending' && _currentUserRole == 'landlord')
              _isUpdating
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _handleStatusUpdate('rejected'),
                            icon: const Icon(Icons.close),
                            label: const Text("Reject"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade100,
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _handleStatusUpdate('active'),
                            icon: const Icon(Icons.check),
                            label: const Text("Approve"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

            // رسالة إذا كان العقد فعالاً
            if (status == 'active')
              const Center(
                child: Text(
                  "This contract is officially active.",
                  style: TextStyle(
                      color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),

            // رسالة للمستأجر إذا كان الطلب قيد الانتظار
            if (status == 'pending' && _currentUserRole == 'tenant')
              const Center(
                child: Text(
                  "Waiting for landlord approval...",
                  style: TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper Widgets
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: kSurfaceColor, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          )
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.verified;
      case 'pending':
        return Icons.hourglass_empty;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }
}
