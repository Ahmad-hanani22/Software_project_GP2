import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TenantPaymentsScreen extends StatefulWidget {
  const TenantPaymentsScreen({super.key});

  @override
  State<TenantPaymentsScreen> createState() => _TenantPaymentsScreenState();
}

class _TenantPaymentsScreenState extends State<TenantPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _allPayments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null) {
      final (ok, data) = await ApiService.getUserPayments(userId);
      if (mounted) {
        setState(() {
          if (ok) _allPayments = data as List<dynamic>;
          _isLoading = false;
        });
      }
    }
  }

  // ✅ دالة جديدة لرفع الوصل
  Future<void> _uploadReceipt(String paymentId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    // إظهار لودينج
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Uploading receipt...")));

    try {
      // 1. رفع الصورة
      final (imgOk, imgUrl) = await ApiService.uploadImage(image);

      if (imgOk && imgUrl != null) {
        // 2. تحديث الدفعة برابط الصورة
        // ملاحظة: سنستخدم updatePayment ونرسل لها receiptUrl إذا كان الباك إند يدعم ذلك
        // حالياً سنغير الحالة إلى "paid" كإثبات، ولكن الأصح هو وجود حالة "review"
        // سأفترض هنا أننا نغير الحالة لـ paid ونعتبر الصورة وصلت (تحتاج تعديل بسيط في الباك إند لاستقبال الصورة)

        final (updateOk, msg) =
            await ApiService.updatePayment(paymentId, 'paid');
        // 💡 فكرة تطويرية: أضف حقل receiptUrl في نموذج Payment في الباك إند

        if (mounted) {
          if (updateOk) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Receipt Uploaded! Payment marked as paid."),
                backgroundColor: Colors.green));
            _fetchPayments();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), backgroundColor: Colors.red));
          }
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Failed to upload image"),
              backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // تصفية القوائم
    final pending =
        _allPayments.where((p) => p['status'] == 'pending').toList();
    final history =
        _allPayments.where((p) => p['status'] != 'pending').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              ).createShader(bounds),
              child: const Icon(Icons.home_work_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 8),
            const Text("SHAQATI",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5)),
            const SizedBox(width: 8),
          ],
        ),
        title: const Text("My Payments"),
        backgroundColor: const Color(0xFF1976D2),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Due",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "(${pending.length})",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Tab(
              child: Text(
                "Paid History",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1976D2)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(pending, true),
                _buildList(history, false),
              ],
            ),
    );
  }

  Widget _buildList(List<dynamic> list, bool isPending) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isPending ? Icons.check_circle_outline : Icons.history,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 15),
            Text(isPending ? "No due payments!" : "No payment history",
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        final amount = p['amount'];
        final date = DateTime.parse(p['date']);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPending
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.attach_money,
                          color: isPending ? Colors.red : Colors.green,
                          size: 28),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Rent Payment",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                              "Payment Date: ${DateFormat('dd MMM yyyy').format(date)}",
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text("\$$amount",
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 20)),
                  ],
                ),
                if (isPending) ...[
                  const Divider(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadReceipt(p['_id']),
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Upload Receipt / Pay"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  )
                ] else if (p['receiptUrl'] != null) ...[
                  // إذا كان هناك صورة وصل
                  // يمكن إضافة زر لعرض الوصل هنا مستقبلاً
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
