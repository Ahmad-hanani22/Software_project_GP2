import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/landlord_dashboard_screen.dart';
import 'package:flutter_application_1/screens/tenant_dashboard_screen.dart';
import 'deposits_management_screen.dart';
import 'invoices_screen.dart';
import 'expenses_management_screen.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

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
  List<dynamic> _payments = [];
  bool _isLoadingPayments = false;
  bool _showPayments = false;
  List<dynamic> _attachments = [];
  bool _showAttachments = false;
  bool _isUploadingAttachment = false;

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
        if (ok) {
          _contract = data;
        }
        _isLoading = false;
      });
      // ✅ جلب الدفعات والمرفقات بعد تحميل العقد مباشرة (خارج setState)
      if (ok) {
        await _loadPayments();
        await _loadAttachments();
      }
    }
  }

  Future<void> _loadPayments() async {
    if (!mounted) return;
    setState(() => _isLoadingPayments = true);
    try {
      final (ok, data) =
          await ApiService.getPaymentsByContract(widget.contractId);
      if (mounted) {
        setState(() {
          _isLoadingPayments = false;
          if (ok) {
            // ✅ معالجة مختلفة لأشكال البيانات
            if (data is List) {
              _payments = data;
            } else if (data is Map) {
              // إذا كانت البيانات في كائن، جرب استخراج القائمة
              if (data['payments'] is List) {
                _payments = data['payments'];
              } else if (data['data'] is List) {
                _payments = data['data'];
              } else {
                _payments = [];
              }
            } else {
              _payments = [];
            }
            // ✅ طباعة للتصحيح (يمكن حذفها لاحقاً)
            print('✅ Loaded ${_payments.length} payments for contract ${widget.contractId}');
          } else {
            _payments = [];
            print('❌ Error loading payments: $data');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPayments = false;
          _payments = [];
        });
        print('❌ Exception loading payments: $e');
      }
    }
  }

  // دالة التعامل مع الموافقة أو الرفض (من قبل المالك)
  Future<void> _handleStatusUpdate(String newStatus) async {
    setState(() => _isUpdating = true);

    final (ok, msg) =
        await ApiService.updateContractStatus(widget.contractId, newStatus);

    if (mounted) {
      setState(() => _isUpdating = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Contract marked as $newStatus"),
          backgroundColor: newStatus == 'active' || newStatus == 'rented' ? Colors.green : Colors.red,
        ));
        // ✅ إعادة تحميل البيانات لتحديث الواجهة
        await _fetchContractDetails();
        // ✅ إعادة تحميل الدفعات بشكل صريح بعد تحديث حالة العقد
        // هذا مهم لأن الدفعة الأولية قد تُنشأ تلقائياً عند التفعيل
        if (newStatus == 'active' || newStatus == 'rented') {
          // انتظار بسيط للتأكد من أن الدفعة تم إنشاؤها في الباك إند
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadPayments();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $msg"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ✍️ توقيع العقد إلكترونيًا للطرف الحالي (مالك/مستأجر)
  Future<void> _signThisContract() async {
    setState(() => _isUpdating = true);
    final (ok, msg) = await ApiService.signContract(widget.contractId);
    if (!mounted) return;
    setState(() => _isUpdating = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? "Contract signed successfully" : "Error: $msg"),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));

    if (ok) _fetchContractDetails();
  }

  // 🔁 تجديد العقد (للمالك فقط)
  Future<void> _renewThisContract() async {
    final c = _contract;
    if (c == null) return;

    final currentEnd =
        c['endDate'] != null ? DateTime.parse(c['endDate']) : DateTime.now();

    final pickedEnd = await showDatePicker(
      context: context,
      initialDate: currentEnd.add(const Duration(days: 365)),
      firstDate: currentEnd,
      lastDate: DateTime(currentEnd.year + 5),
    );

    if (pickedEnd == null) return;

    setState(() => _isUpdating = true);
    final (ok, msg) = await ApiService.renewContract(widget.contractId,
        newEndDate: pickedEnd);
    if (!mounted) return;
    setState(() => _isUpdating = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? "Contract renewed successfully" : "Error: $msg"),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));

    if (ok) _fetchContractDetails();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_contract == null) {
      return Scaffold(
        appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            // ✅ التحقق من إمكانية الرجوع
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // إذا لم يكن هناك صفحة سابقة، الانتقال إلى Dashboard حسب الدور
              final prefs = await SharedPreferences.getInstance();
              final role = prefs.getString('role');
              if (!mounted) return;
              if (role == 'landlord') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LandlordDashboardScreen(),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TenantDashboardScreen(),
                  ),
                );
              }
            }
          },
        ),
        title: const Text("Contract Details"),
      ),
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
    // ✅ استخراج نوع العقار وعمليته (rent/sale)
    final propertyType = c['propertyId'] is Map 
        ? (c['propertyId']['type'] ?? 'Apartment').toString().toUpperCase()
        : 'Apartment';
    final propertyOperation = c['propertyId'] is Map
        ? (c['propertyId']['operation'] ?? 'rent').toString()
        : 'rent';
    final propertyCity = c['propertyId'] is Map
        ? (c['propertyId']['city'] ?? '')
        : '';
    final propertyCountry = c['propertyId'] is Map
        ? (c['propertyId']['country'] ?? '')
        : '';
    // دعم Unit إذا كان موجود
    final unitInfo = c['unitId'] is Map
        ? '${c['unitId']['unitNumber'] ?? 'N/A'} (الطابق ${c['unitId']['floor'] ?? 'N/A'})'
        : null;
    final price = c['rentAmount'] ?? 0;
    final status = (c['status'] ?? 'pending').toString();

    final signatures = (c['signatures'] ?? {}) as Map<String, dynamic>;
    final landlordSigned = signatures['landlord'] is Map &&
        signatures['landlord']['signed'] == true;
    final tenantSigned =
        signatures['tenant'] is Map && signatures['tenant']['signed'] == true;

    final bool isLandlord = _currentUserRole == 'landlord';
    final bool isTenant = _currentUserRole == 'tenant';
    final bool currentUserSigned =
        isLandlord ? landlordSigned : (isTenant ? tenantSigned : false);
    final bool canSign = (isLandlord || isTenant) && !currentUserSigned;

    final lowerStatus = status.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            // ✅ التحقق من إمكانية الرجوع
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              // إذا لم يكن هناك صفحة سابقة، الانتقال إلى Dashboard حسب الدور
              final prefs = await SharedPreferences.getInstance();
              final role = prefs.getString('role');
              if (!mounted) return;
              if (role == 'landlord') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LandlordDashboardScreen(),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TenantDashboardScreen(),
                  ),
                );
              }
            }
          },
        ),
        title: const Text("Contract Request"),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 360;
          final horizontalPadding = isSmallScreen ? 12.0 : 20.0;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
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
            // ✅ نوع العقار وعمليته (Apartment / Rent)
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(Icons.home, "Type", propertyType),
                ),
                Expanded(
                  child: _buildInfoTile(
                    Icons.category, 
                    "Operation", 
                    propertyOperation.toUpperCase()
                  ),
                ),
              ],
            ),
            // ✅ الموقع (المدينة والبلد)
            if (propertyCity.isNotEmpty || propertyCountry.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final locationParts = <String>[];
                  if (propertyCity.isNotEmpty) locationParts.add(propertyCity);
                  if (propertyCountry.isNotEmpty) locationParts.add(propertyCountry);
                  final location = locationParts.join(', ');
                  return _buildInfoTile(
                    Icons.location_on, 
                    "Location", 
                    location.isEmpty ? 'N/A' : location,
                  );
                },
              ),
            ],
            _buildInfoTile(Icons.home, "Property Title", propertyTitle),
            if (unitInfo != null)
              _buildInfoTile(Icons.home_work, "Unit", unitInfo),
            _buildInfoTile(
                Icons.attach_money, 
                propertyOperation == 'sale' ? "Sale Price" : "Rent Amount", 
                "\$$price ${propertyOperation == 'sale' ? '' : '/ month'}"),

            const SizedBox(height: 20),

            // تفاصيل الأطراف
            _buildSectionHeader("Parties Involved"),
            _buildInfoTile(Icons.person, "Tenant (Requester)", tenantName),
            _buildInfoTile(
                Icons.admin_panel_settings, "Landlord (Owner)", landlordName),

            const SizedBox(height: 40),

            // ✅ أزرار التحكم للمالك عندما يكون العقد في حالة pending
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

            const SizedBox(height: 20),

            // ✍️ زر التوقيع الإلكتروني للطرف الحالي (إن لم يوقّع بعد)
            if (canSign)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _signThisContract,
                  icon: const Icon(Icons.edit_document),
                  label:
                      Text(isLandlord ? "Sign as Landlord" : "Sign as Tenant"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // 📄 أزرار التأمينات والمصروفات والفواتير (للعقود النشطة)
            if (status == 'active' || status == 'rented')
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => DepositsManagementScreen(
                                  contractId: widget.contractId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.security),
                          label: const Text("Deposits"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            side: const BorderSide(color: kPrimaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final propertyId = c['propertyId'] is Map
                                ? c['propertyId']['_id']?.toString()
                                : null;
                            final unitId = c['unitId'] is Map
                                ? c['unitId']['_id']?.toString()
                                : null;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => ExpensesManagementScreen(
                                  contractId: widget.contractId,
                                  propertyId: propertyId,
                                  unitId: unitId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.receipt_long),
                          label: const Text("Expenses"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            side: const BorderSide(color: kPrimaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => InvoicesScreen(
                              contractId: widget.contractId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt),
                      label: const Text("Invoices"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: const BorderSide(color: kPrimaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // 💳 Payment Receipts Section - عرض الدفعات لجميع العقود
            if (_contract != null) ...[
              const SizedBox(height: 20),
              InkWell(
                onTap: () {
                  setState(() {
                    _showPayments = !_showPayments;
                    // ✅ إعادة تحميل الدفعات عند فتح القسم لأول مرة
                    if (!_showPayments) {
                      _loadPayments();
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                color: kPrimaryColor, size: 24),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Payment Receipts${_payments.isNotEmpty ? ' (${_payments.length})' : ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_showPayments)
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: _loadPayments,
                              tooltip: 'Refresh payments',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          Icon(
                            _showPayments
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: kPrimaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_showPayments) ...[
                const SizedBox(height: 12),
                if (_isLoadingPayments)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // Payment Progress
                  Builder(
                    builder: (context) {
                      final c = _contract!;
                      final rentAmount = ((c['rentAmount'] ?? 0) as num).toDouble();
                      final startDate = c['startDate'] != null 
                          ? DateTime.parse(c['startDate']) 
                          : null;
                      final endDate = c['endDate'] != null 
                          ? DateTime.parse(c['endDate']) 
                          : null;
                      
                      // حساب عدد الدفعات المتوقعة
                      int expectedPayments = 0;
                      if (startDate != null && endDate != null && rentAmount > 0) {
                        final months = (endDate.difference(startDate).inDays / 30).ceil();
                        expectedPayments = months > 0 ? months : 1;
                      }
                      
                      // حساب الدفعات المدفوعة والمتبقية
                      final paidPayments = _payments.where((p) => 
                        (p['status'] ?? '').toString().toLowerCase() == 'paid'
                      ).toList();
                      final totalPaid = paidPayments.fold<double>(
                        0.0, 
                        (sum, p) => sum + ((p['amount'] ?? 0) as num).toDouble()
                      );
                      final totalExpected = rentAmount * expectedPayments;
                      final remainingAmount = totalExpected - totalPaid;
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    'Paid ${paidPayments.length} of $expectedPayments payments',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 1,
                                  child: Text(
                                    'Remaining: \$${remainingAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: expectedPayments > 0
                                  ? paidPayments.length / expectedPayments
                                  : 0,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  kPrimaryColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Payments List
                  if (_payments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Icon(Icons.payment, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No payments yet',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _payments.map((payment) => _buildPaymentItem(payment)).toList(),
                    ),
                ],
              ],
            ],

            // 📎 Attachments Section
            if (_contract != null) ...[
              const SizedBox(height: 20),
              _buildAttachmentsSection(),
            ],

            // 🔁 زر التجديد للمالك عندما يكون العقد فعالاً أو يوشك على الانتهاء أو منتهي
            if (isLandlord &&
                (lowerStatus == 'active' ||
                    lowerStatus == 'expiring_soon' ||
                    lowerStatus == 'expired'))
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isUpdating ? null : _renewThisContract,
                  icon: const Icon(Icons.autorenew),
                  label: const Text("Renew Contract"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimaryColor,
                    side: const BorderSide(color: kPrimaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
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
          );
        },
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

  Widget _buildPaymentItem(Map<String, dynamic> payment) {
    final status = payment['status'] ?? 'pending';
    final amount = ((payment['amount'] ?? 0) as num).toDouble();
    final date =
        payment['date'] != null ? DateTime.parse(payment['date']) : null;
    final receipt = payment['receipt'];
    final hasReceipt = receipt != null && receipt['receiptNumber'] != null;
    final method = payment['method'] ?? 'N/A';

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.pending;
    String statusText = 'Pending';

    if (status == 'paid') {
      statusColor = kPrimaryColor;
      statusIcon = Icons.check_circle;
      statusText = 'Paid';
    } else if (status == 'failed') {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = 'Failed';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (date != null)
                            Text(
                              DateFormat('dd MMM, yyyy').format(date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.payment, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Method: $method',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasReceipt) ...[
                const SizedBox(width: 12),
                Icon(Icons.receipt, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Receipt: ${receipt['receiptNumber']}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ✅ تحميل المرفقات من العقد
  Future<void> _loadAttachments() async {
    if (_contract != null) {
      final contractAttachments = _contract!['attachments'] ?? [];
      setState(() {
        _attachments = contractAttachments is List ? contractAttachments : [];
      });
    }
  }

  // ✅ رفع مرفق جديد
  Future<void> _uploadAttachment() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    setState(() => _isUploadingAttachment = true);

    try {
      final (ok, imageUrl) = await ApiService.uploadImage(file);

      if (!mounted) return;

      if (ok && imageUrl != null) {
        // ✅ تحديث العقد لإضافة المرفق الجديد
        final (updateOk, _) = await ApiService.updateContract(
          widget.contractId,
          {
            'attachments': [
              ..._attachments.map((a) => a is Map ? a : {'url': a, 'name': file.name}).toList(),
              {'url': imageUrl, 'name': file.name, 'uploadedAt': DateTime.now().toIso8601String()}
            ]
          },
        );

        if (updateOk) {
          // إعادة تحميل بيانات العقد
          await _fetchContractDetails();
          await _loadAttachments();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Attachment uploaded successfully"),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Failed to save attachment"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Failed to upload file"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
    }
  }

  // ✅ بناء قسم المرفقات
  Widget _buildAttachmentsSection() {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _showAttachments = !_showAttachments;
              if (_showAttachments && _attachments.isEmpty) {
                _loadAttachments();
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, color: Colors.teal, size: 24),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Attachments${_attachments.isNotEmpty ? ' (${_attachments.length})' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _showAttachments ? Icons.expand_less : Icons.expand_more,
                  color: Colors.teal,
                ),
              ],
            ),
          ),
        ),
        if (_showAttachments) ...[
          const SizedBox(height: 12),
          if (_isUploadingAttachment)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_attachments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.attach_file, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'No attachments',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: _attachments.map((attachment) => _buildAttachmentItem(attachment)).toList(),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploadingAttachment ? null : _uploadAttachment,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload Attachment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ✅ بناء عنصر مرفق
  Widget _buildAttachmentItem(dynamic attachment) {
    String url = '';
    String name = '';
    String? uploadedAt;

    if (attachment is Map) {
      url = attachment['url']?.toString() ?? '';
      name = attachment['name']?.toString() ?? 'Unknown';
      if (attachment['uploadedAt'] != null) {
        uploadedAt = attachment['uploadedAt'].toString();
      }
    } else if (attachment is String) {
      url = attachment;
      name = url.split('/').last;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file, color: Colors.teal, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (uploadedAt != null)
                  Text(
                    DateFormat('yyyy-MM-dd').format(DateTime.parse(uploadedAt)),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, color: Colors.teal),
            tooltip: 'Open',
            onPressed: () {
              if (url.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening: $url'),
                  ),
                );
                // TODO: يمكن إضافة فتح الملف في المتصفح أو تطبيق خارجي
              }
            },
          ),
        ],
      ),
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
      case 'draft':
        return Colors.blueGrey;
      case 'expiring_soon':
        return Colors.blue;
      case 'expired':
        return Colors.black54;
      case 'terminated':
        return Colors.black;
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
      case 'draft':
        return Icons.description;
      case 'expiring_soon':
        return Icons.alarm;
      case 'expired':
        return Icons.event_busy;
      case 'terminated':
        return Icons.gavel;
      default:
        return Icons.info;
    }
  }
}
