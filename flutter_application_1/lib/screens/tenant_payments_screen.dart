import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TenantPaymentsScreen extends StatefulWidget {
  final String? contractIdFilter;

  const TenantPaymentsScreen({super.key, this.contractIdFilter});

  @override
  State<TenantPaymentsScreen> createState() => _TenantPaymentsScreenState();
}

class _TenantPaymentsScreenState extends State<TenantPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _allPayments = [];

  // Filters & sorting
  String _statusFilter = 'All'; // All | Paid | Pending | Overdue
  String _sortOption = 'Newest'; // Newest | Oldest | Amount

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
    // Optional filter by contract
    List<dynamic> filtered = _allPayments;
    if (widget.contractIdFilter != null) {
      filtered = _allPayments.where((p) {
        final cid = p['contractId'];
        final cidStr = cid is Map ? cid['_id']?.toString() : cid?.toString();
        return cidStr == widget.contractIdFilter;
      }).toList();
    }

    // Aggregate stats for summary
    double totalPaid = 0;
    double totalDue = 0;
    DateTime? nextDueDate;

    final now = DateTime.now();

    for (final p in filtered) {
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      final status = (p['status'] ?? '').toString().toLowerCase();
      if (status == 'paid') {
        totalPaid += amount;
      } else if (status == 'pending') {
        totalDue += amount;
        try {
          final d = DateTime.parse(p['date']);
          if (nextDueDate == null || d.isBefore(nextDueDate!)) {
            nextDueDate = d;
          }
        } catch (_) {}
      }
    }

    // Split lists by status
    List<dynamic> pending =
        filtered.where((p) => (p['status'] ?? '') == 'pending').toList();
    List<dynamic> history =
        filtered.where((p) => (p['status'] ?? '') != 'pending').toList();

    // Apply filter
    List<dynamic> applyFilter(List<dynamic> list) {
      switch (_statusFilter) {
        case 'Paid':
          return list.where((p) => (p['status'] ?? '') == 'paid').toList();
        case 'Pending':
          return list.where((p) => (p['status'] ?? '') == 'pending').toList();
        case 'Overdue':
          return list.where((p) {
            try {
              final status = (p['status'] ?? '').toString().toLowerCase();
              if (status != 'pending') return false;
              final d = DateTime.parse(p['date']);
              return d.isBefore(now);
            } catch (_) {
              return false;
            }
          }).toList();
        default:
          return list;
      }
    }

    pending = applyFilter(pending);
    history = applyFilter(history);

    // Apply sort
    int compareDatesDesc(a, b) =>
        DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));
    int compareDatesAsc(a, b) =>
        DateTime.parse(a['date']).compareTo(DateTime.parse(b['date']));
    int compareAmount(a, b) =>
        ((b['amount'] as num?) ?? 0).compareTo((a['amount'] as num?) ?? 0);

    void sortList(List list) {
      try {
        if (_sortOption == 'Newest') {
          list.sort(compareDatesDesc);
        } else if (_sortOption == 'Oldest') {
          list.sort(compareDatesAsc);
        } else if (_sortOption == 'Amount') {
          list.sort(compareAmount);
        }
      } catch (_) {}
    }

    sortList(pending);
    sortList(history);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
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
          : Column(
              children: [
                // Smart summary bar
                _buildSummaryBar(
                  totalPaid: totalPaid,
                  totalDue: totalDue,
                  nextDueDate: nextDueDate,
                  paymentsCount: filtered.length,
                ),
                // Filters row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Wrap(
                          spacing: 6,
                          children: ['All', 'Paid', 'Pending', 'Overdue']
                              .map(
                                (f) => ChoiceChip(
                                  label: Text(f),
                                  selected: _statusFilter == f,
                                  onSelected: (v) {
                                    if (!v) return;
                                    setState(() => _statusFilter = f);
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _sortOption,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                                value: 'Newest', child: Text('Newest')),
                            DropdownMenuItem(
                                value: 'Oldest', child: Text('Oldest')),
                            DropdownMenuItem(
                                value: 'Amount', child: Text('Amount')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _sortOption = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(pending, true, nextDueDate),
                      _buildList(history, false, nextDueDate),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBar({
    required double totalPaid,
    required double totalDue,
    required DateTime? nextDueDate,
    required int paymentsCount,
  }) {
    String nextLabel = nextDueDate != null
        ? DateFormat('dd MMM yyyy').format(nextDueDate)
        : '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 220,
              child: _summaryChip(
                icon: Icons.check_circle,
                label: 'Total paid',
                value: '\$${totalPaid.toStringAsFixed(0)}',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 220,
              child: _summaryChip(
                icon: Icons.pending_actions,
                label: 'Total due',
                value: '\$${totalDue.toStringAsFixed(0)}',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 220,
              child: _summaryChip(
                icon: Icons.event,
                label: 'Next due',
                value: nextLabel,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 220,
              child: _summaryChip(
                icon: Icons.list_alt,
                label: 'Payments',
                value: paymentsCount.toString(),
                color: Colors.indigo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      List<dynamic> list, bool isPending, DateTime? globalNextDueDate) {
    if (list.isEmpty) {
      if (isPending) {
        final nextText = globalNextDueDate != null
            ? DateFormat('dd MMM yyyy').format(globalNextDueDate)
            : '—';
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 72, color: Colors.green),
              const SizedBox(height: 12),
              const Text(
                "You're all caught up!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "Next payment due on $nextText",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(1),
                icon: const Icon(Icons.history),
                label: const Text('View paid history'),
              ),
            ],
          ),
        );
      } else {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 15),
              Text("No payment history",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            ],
          ),
        );
      }
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];
        final amount = p['amount'];
        final date = DateTime.parse(p['date']);

        final now = DateTime.now();
        final daysDiff = date.difference(now).inDays;
        final bool isOverdue = daysDiff < 0;

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
                          Text(
                            "Rent payment",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPending
                                ? "Due on ${DateFormat('dd MMM yyyy').format(date)}"
                                : "Paid on ${DateFormat('dd MMM yyyy').format(date)}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (isPending) ...[
                            const SizedBox(height: 2),
                            Text(
                              isOverdue
                                  ? "Overdue by ${daysDiff.abs()} day(s)"
                                  : "Due in $daysDiff day(s)",
                              style: TextStyle(
                                color: isOverdue
                                    ? Colors.red
                                    : (daysDiff <= 3
                                        ? Colors.orange
                                        : Colors.green),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "\$$amount",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPending
                                ? (isOverdue
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1))
                                : Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isPending
                                ? (isOverdue ? "Overdue" : "Pending")
                                : "Paid",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPending
                                  ? (isOverdue ? Colors.red : Colors.orange)
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isPending) ...[
                  const Divider(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadReceipt(p['_id']),
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Upload receipt / Pay"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  )
                ] else if (p['receiptUrl'] != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        // TODO: implement open receipt viewer
                      },
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('View receipt'),
                    ),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
