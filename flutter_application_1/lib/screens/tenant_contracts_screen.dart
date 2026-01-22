import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/utils/tenant_theme.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contract_details_screen.dart';
import 'chat_screen.dart';
import 'tenant_payments_screen.dart';

class TenantContractsScreen extends StatefulWidget {
  const TenantContractsScreen({super.key});

  @override
  State<TenantContractsScreen> createState() => _TenantContractsScreenState();
}

class _TenantContractsScreenState extends State<TenantContractsScreen> {
  bool _isLoading = true;
  List<dynamic> _contracts = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _terminationReasonController =
      TextEditingController();
  String _filter = 'All'; // All | Active | Pending | Ended

  // Payments + stats
  List<dynamic> _userPayments = [];
  int _totalContracts = 0;
  int _activeContracts = 0;
  int _pendingContracts = 0;
  int _endedContracts = 0;
  int _pendingPaymentsCount = 0;
  double _totalMonthlyRent = 0;
  DateTime? _nextGlobalPaymentDate;
  int? _nextGlobalPaymentDays;
  String? _nextGlobalPaymentCycle; // daily / weekly / monthly / yearly ...

  // Per-contract payment info
  final Map<String, Map<String, dynamic>> _contractPaymentInfo = {};

  @override
  void initState() {
    super.initState();
    _fetchContracts();
  }

  Future<void> _fetchContracts() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null) {
      try {
        final results = await Future.wait([
          ApiService.getUserContracts(userId),
          ApiService.getUserPayments(userId),
        ]);

        final (conOk, conData) = results[0] as (bool, dynamic);
        final (payOk, payData) = results[1] as (bool, dynamic);

        if (mounted) {
          setState(() {
            if (conOk && conData is List) {
              _contracts = conData as List<dynamic>;
            }
            if (payOk && payData is List) {
              _userPayments = payData as List<dynamic>;
            }
            _computeStats();
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _computeStats() {
    _totalContracts = _contracts.length;
    _activeContracts = 0;
    _pendingContracts = 0;
    _endedContracts = 0;
    _totalMonthlyRent = 0;

    final now = DateTime.now();
    _contractPaymentInfo.clear();

    // Contract status stats + monthly rent
    for (final c in _contracts) {
      final status = (c['status'] ?? '').toString().toLowerCase();
      if (status == 'active' || status == 'rented' || status == 'expiring_soon') {
        _activeContracts++;
      } else if (status == 'pending') {
        _pendingContracts++;
      } else {
        _endedContracts++;
      }

      final rent = (c['rentAmount'] as num?)?.toDouble() ?? 0.0;
      if (status == 'active' || status == 'rented') {
        _totalMonthlyRent += rent;
      }
    }

    // Payments stats
    _pendingPaymentsCount =
        _userPayments.where((p) => p['status'] == 'pending').length;

    DateTime? earliestNext;
    String? earliestCycle;

    for (final contract in _contracts) {
      final contractId = contract['_id']?.toString() ?? '';
      if (contractId.isEmpty) continue;
      final cycle =
          (contract['paymentCycle'] ?? 'monthly').toString().toLowerCase();

      final paymentsForContract = _userPayments.where((p) {
        final cid = p['contractId'];
        final cidStr = cid is Map ? cid['_id']?.toString() : cid?.toString();
        return cidStr == contractId;
      }).toList();

      int total = paymentsForContract.length;
      int paid = 0;
      int pending = 0;
      double totalPaidAmount = 0;
      double remainingAmount = 0;
      DateTime? nextPendingDate;
      int? nextPendingDays;
      int overdueCount = 0;
      int overdueDaysSum = 0;

      for (final p in paymentsForContract) {
        final status = (p['status'] ?? '').toString().toLowerCase();
        final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
        if (status == 'paid') {
          paid++;
          totalPaidAmount += amount;
        }
        if (status == 'pending') {
          pending++;
          try {
            final d = DateTime.parse(p['date']);
            final days = d.difference(now).inDays;
            if (nextPendingDate == null ||
                d.isBefore(nextPendingDate!)) {
              nextPendingDate = d;
              nextPendingDays = days;
            }
            if (days < 0) {
              overdueCount++;
              overdueDaysSum += days.abs();
            }
          } catch (_) {}
        }
      }

      // Remaining contract value (approx rent * months - totalPaidAmount)
      final rent = (contract['rentAmount'] as num?)?.toDouble() ?? 0.0;
      int? months;
      try {
        final s =
            DateTime.tryParse((contract['startDate'] ?? '').toString());
        final e =
            DateTime.tryParse((contract['endDate'] ?? '').toString());
        if (s != null && e != null) {
          months = (e.difference(s).inDays / 30).round();
        }
      } catch (_) {}
      if (months != null && months > 0) {
        final totalContractValue = rent * months;
        remainingAmount = (totalContractValue - totalPaidAmount)
            .clamp(0, double.infinity);
      }

      final daysLeft = _daysRemaining(contract['endDate']) ?? 0;
      final double? avgDelay =
          overdueCount > 0 ? overdueDaysSum / overdueCount : null;

      _contractPaymentInfo[contractId] = {
        'total': total,
        'paid': paid,
        'pending': pending,
        'nextDate': nextPendingDate,
        'nextDays': nextPendingDays,
        'totalPaidAmount': totalPaidAmount,
        'remainingAmount': remainingAmount,
        'daysLeft': daysLeft,
        'overdueCount': overdueCount,
        'avgDelay': avgDelay,
      };

      if (nextPendingDate != null) {
        if (earliestNext == null || nextPendingDate.isBefore(earliestNext)) {
          earliestNext = nextPendingDate;
          earliestCycle = cycle;
        }
      }
    }

    _nextGlobalPaymentDate = earliestNext;
    _nextGlobalPaymentCycle = earliestCycle;
    if (earliestNext != null) {
      _nextGlobalPaymentDays = earliestNext.difference(now).inDays;
    } else {
      _nextGlobalPaymentDays = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _terminationReasonController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredContracts {
    var list = _contracts;
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) {
        final p = c['propertyId'] ?? {};
        final title = (p['title'] ?? '').toString().toLowerCase();
        final addr = (p['address'] ?? '').toString().toLowerCase();
        return title.contains(q) || addr.contains(q);
      }).toList();
    }
    final s = (c) => (c['status'] ?? '').toString().toLowerCase();
    switch (_filter) {
      case 'Active':
        list = list.where((c) =>
            s(c) == 'active' || s(c) == 'rented' || s(c) == 'expiring_soon').toList();
        break;
      case 'Pending':
        list = list.where((c) => s(c) == 'pending').toList();
        break;
      case 'Ended':
        list = list.where((c) =>
            s(c) == 'terminated' || s(c) == 'expired' || s(c) == 'ended').toList();
        break;
    }
    return list;
  }

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
          borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TenantTheme.cardBg,
            borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
            boxShadow: TenantTheme.cardShadow,
          ),
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
                      Text(
                        'إضافة وديعة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: TenantTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: TenantTheme.textHint),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TenantTheme.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.home, color: TenantTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            propertyTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: TenantTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (contract['depositAmount'] != null ||
                      contract['rentAmount'] != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TenantTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                        border: Border.all(color: TenantTheme.accent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: TenantTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              contract['depositAmount'] != null
                                  ? 'Suggested from contract: \$${contract['depositAmount']}'
                                  : 'Suggested (1 month rent): \$${contract['rentAmount'] ?? 0}',
                              style: TextStyle(
                                fontSize: 12,
                                color: TenantTheme.textPrimary,
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
                    decoration: InputDecoration(
                      labelText: 'مبلغ الوديعة *',
                      labelStyle: TextStyle(color: TenantTheme.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                        borderSide: const BorderSide(color: TenantTheme.primary),
                      ),
                      prefixIcon: Icon(Icons.attach_money, color: TenantTheme.primary),
                      hintText: '0.00',
                      helperText: 'أدخل مبلغ الوديعة (المقترح معبأ مسبقاً)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال مبلغ الوديعة';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'يرجى إدخال مبلغاً صالحاً';
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

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (loadingCtx) => Center(
                          child: CircularProgressIndicator(color: TenantTheme.primary),
                        ),
                      );

                      final (ok, message) = await ApiService.addDeposit({
                        'contractId': contractId,
                        'amount': amount,
                      });

                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: ok ? TenantTheme.success : TenantTheme.error,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        if (ok) _fetchContracts();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TenantTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Create Deposit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Future<void> _requestTermination(String contractId) async {
    _terminationReasonController.clear();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
        ),
        title: Text("طلب إنهاء العقد", style: TextStyle(color: TenantTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "هل أنت متأكد من طلب إنهاء العقد؟ سيتم إشعار المالك.",
              style: TextStyle(color: TenantTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _terminationReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "السبب (اختياري)",
                hintText: "اكتب سبب طلب إنهاء العقد (اختياري)",
                labelStyle: TextStyle(color: TenantTheme.textSecondary),
                hintStyle: TextStyle(color: TenantTheme.textHint),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                  borderSide: const BorderSide(color: TenantTheme.primary),
                ),
                filled: true,
                fillColor: TenantTheme.scaffoldBg,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("إلغاء", style: TextStyle(color: TenantTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TenantTheme.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
              ),
            ),
            child: const Text("تأكيد"),
          ),
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
        content: Text(ok ? 'Termination request sent!' : msg),
        backgroundColor: ok ? TenantTheme.warning : TenantTheme.error,
      ));
      if (ok) _fetchContracts();
    }
  }

  Color _statusColor(String lowerStatus) {
    if (lowerStatus == 'active' || lowerStatus == 'rented' || lowerStatus == 'expiring_soon') {
      return TenantTheme.success;
    }
    if (lowerStatus == 'pending') return TenantTheme.warning;
    return TenantTheme.textHint;
  }

  String _statusLabel(String lowerStatus) {
    if (lowerStatus == 'active' || lowerStatus == 'rented' || lowerStatus == 'expiring_soon') return 'Active';
    if (lowerStatus == 'pending') return 'Pending';
    return 'Ended';
  }

  String? _safeDate(dynamic d) {
    if (d == null) return null;
    try {
      final dt = DateTime.tryParse(d.toString());
      return dt != null ? DateFormat('yyyy-MM-dd').format(dt) : null;
    } catch (_) { return null; }
  }

  int? _daysRemaining(dynamic endDate) {
    if (endDate == null) return null;
    try {
      final end = DateTime.tryParse(endDate.toString());
      if (end == null) return null;
      return end.difference(DateTime.now()).inDays;
    } catch (_) { return null; }
  }

  Widget _buildContractsEmptyState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.description_outlined, size: 64, color: TenantTheme.textHint.withOpacity(0.5)),
        const SizedBox(height: 12),
        Text(message, style: TextStyle(fontSize: 16, color: TenantTheme.textHint), textAlign: TextAlign.center),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TenantTheme.scaffoldBg,
      appBar: TenantTheme.appBar(
        title: 'My contracts',
        onBack: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TenantTheme.primary))
          : RefreshIndicator(
              onRefresh: _fetchContracts,
              color: TenantTheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by property name or address...',
                        hintStyle: TextStyle(color: TenantTheme.textHint),
                        prefixIcon: Icon(Icons.search, color: TenantTheme.primary),
                        filled: true,
                        fillColor: TenantTheme.cardBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  if (_totalContracts > 0) ...[
                    const SizedBox(height: 4),
                    _buildTopStats(),
                  ],
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: ['All', 'Active', 'Pending', 'Ended'].map((f) {
                      final sel = _filter == f;
                      final label = f;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(label),
                          selected: sel,
                          onSelected: (v) => setState(() => _filter = f),
                          selectedColor: TenantTheme.primaryLight.withOpacity(0.4),
                          checkmarkColor: TenantTheme.primary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                    child: RefreshIndicator(
                    onRefresh: _fetchContracts,
                    color: TenantTheme.primary,
                    child: _contracts.isEmpty
                        ? _buildContractsEmptyState('No contracts yet.')
                        : _filteredContracts.isEmpty
                            ? _buildContractsEmptyState('No contracts match the current filters.')
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                itemCount: _filteredContracts.length,
                              itemBuilder: (context, index) {
                                final c = _filteredContracts[index];
                                final property = c['propertyId'] ?? {};
                                final landlord = c['landlordId'] ?? {};
                                final status = (c['status'] ?? 'pending').toString();
                                final lowerStatus = status.toLowerCase();
                                final isActive = lowerStatus == 'active' ||
                                    lowerStatus == 'rented' ||
                                    lowerStatus == 'expiring_soon';
                                final headerColor = _statusColor(lowerStatus);
                                final statusLabel = _statusLabel(lowerStatus);
                                final contractId = c['_id'].toString();
                                final idShort = contractId.length >= 6
                                    ? contractId.substring(contractId.length - 6)
                                    : contractId;

                                final img = property['images'] is List && (property['images'] as List).isNotEmpty
                                    ? (property['images'] as List).first?.toString()
                                    : property['image']?.toString();
                                final startStr = _safeDate(c['startDate']) ?? '—';
                                final endStr = _safeDate(c['endDate']) ?? '—';
                                final daysLeft = _daysRemaining(c['endDate']);
                                final rent = (c['rentAmount'] as num?)?.toDouble() ?? 0.0;
                                final dep = (c['depositAmount'] as num?)?.toDouble();
                                final hasDep = dep != null && dep > 0;
                                // مدة العقد بالأشهر تقريباً
                                int? months;
                                try {
                                  final s = DateTime.tryParse((c['startDate'] ?? '').toString());
                                  final e = DateTime.tryParse((c['endDate'] ?? '').toString());
                                  if (s != null && e != null) months = (e.difference(s).inDays / 30).round();
                                } catch (_) {}
                                final propType = property['type'] ?? property['propertyType'] ?? '';
                                final beds = property['bedrooms'] ?? property['rooms'];
                                final area = property['area'] ?? property['size'];
                                final landlordPhone = landlord['phone'] ?? landlord['mobile'] ?? '';
                                final landlordEmail = landlord['email'] ?? '';

                                final paymentInfo =
                                    _contractPaymentInfo[contractId] ?? {};
                                final int totalPayments =
                                    (paymentInfo['total'] as int?) ?? 0;
                                final int paidPayments =
                                    (paymentInfo['paid'] as int?) ?? 0;
                                final int pendingPaymentsForContract =
                                    (paymentInfo['pending'] as int?) ?? 0;
                                final DateTime? nextPaymentDate =
                                    paymentInfo['nextDate'] as DateTime?;
                                final int? nextPaymentDays =
                                    paymentInfo['nextDays'] as int?;
                                final double totalPaidAmount =
                                    (paymentInfo['totalPaidAmount'] as double?) ?? 0.0;
                                final double remainingAmount =
                                    (paymentInfo['remainingAmount'] as double?) ?? 0.0;
                                final int daysLeftForHealth =
                                    (paymentInfo['daysLeft'] as int?) ??
                                        (_daysRemaining(c['endDate']) ?? 0);
                                final int overdueCount =
                                    (paymentInfo['overdueCount'] as int?) ?? 0;
                                final double? avgDelay =
                                    paymentInfo['avgDelay'] as double?;

                                // Contract health badge
                                String healthLabel = 'Healthy';
                                Color healthColor = TenantTheme.success;
                                if (overdueCount == 0 &&
                                    (daysLeftForHealth <= 30 && daysLeftForHealth > 7)) {
                                  healthLabel = 'Attention';
                                  healthColor = TenantTheme.warning;
                                }
                                if (overdueCount >= 1 ||
                                    (daysLeftForHealth <= 7 && daysLeftForHealth >= 0)) {
                                  healthLabel =
                                      overdueCount >= 2 || daysLeftForHealth <= 7
                                          ? 'At risk'
                                          : 'Attention';
                                  healthColor = overdueCount >= 2
                                      ? TenantTheme.error
                                      : TenantTheme.warning;
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: TenantTheme.cardBg,
                                    borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
                                    boxShadow: TenantTheme.cardShadow,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => ContractDetailsScreen(contractId: contractId))),
                                    borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: headerColor,
                                            borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(TenantTheme.radiusLg)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Text("#$idShort", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(999),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 6,
                                                          height: 6,
                                                          decoration: BoxDecoration(
                                                            color: healthColor,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          healthLabel,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  if (isActive && daysLeft != null && daysLeft <= 30 && daysLeft >= 0)
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 8),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                                                        child: Text('Ends in $daysLeft day(s)', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                                      ),
                                                    ),
                                                  Text(statusLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                                                    child: img != null && img.isNotEmpty
                                                        ? Image.network(img, width: 88, height: 88, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholderIcon())
                                                        : _buildPlaceholderIcon(),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(property['title'] ?? 'Property',
                                                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: TenantTheme.textPrimary)),
                                                        if (propType.toString().isNotEmpty)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 2),
                                                            child: Text(propType.toString(), style: TextStyle(fontSize: 12, color: TenantTheme.primary, fontWeight: FontWeight.w500)),
                                                          ),
                                                        const SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            Icon(Icons.location_on, size: 14, color: TenantTheme.textHint),
                                                            const SizedBox(width: 4),
                                                            Expanded(child: Text(property['address'] ?? "—", style: TextStyle(fontSize: 13, color: TenantTheme.textHint))),
                                                          ],
                                                        ),
                                                        if (beds != null || area != null) ...[
                                                          const SizedBox(height: 4),
                                                          Wrap(
                                                            spacing: 10,
                                                            children: [
                                                              if (beds != null) _miniChip(Icons.bed, '$beds rooms'),
                                                              if (area != null) _miniChip(Icons.square_foot, '${area} m²'),
                                                            ],
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Row(
                                                children: [
                                                  CircleAvatar(radius: 18, backgroundColor: TenantTheme.primaryLight.withOpacity(0.3), child: Icon(Icons.person, size: 18, color: TenantTheme.primary)),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text("Landlord", style: TextStyle(fontSize: 10, color: TenantTheme.textHint)),
                                                        Text(landlord['name'] ?? "—", style: const TextStyle(fontWeight: FontWeight.w600)),
                                                        if (landlordPhone.toString().isNotEmpty || landlordEmail.toString().isNotEmpty)
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 2),
                                                            child: Text(
                                                              [if (landlordPhone.toString().isNotEmpty) landlordPhone, if (landlordEmail.toString().isNotEmpty) landlordEmail].join(' • '),
                                                              style: TextStyle(fontSize: 11, color: TenantTheme.textHint),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  TextButton.icon(
                                                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                                    label: const Text("Chat"),
                                                    onPressed: () {
                                                      final lid = landlord['_id'] ?? landlord['id'] ?? '';
                                                      if (lid.toString().isEmpty) return;
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: lid.toString(), receiverName: landlord['name'] ?? 'Landlord')));
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const Divider(height: 24),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _infoItem('Start date', startStr),
                                                  _infoItem('End date', endStr),
                                                  if (months != null) _infoItem('Duration', '${months} months'),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              if (totalPayments > 0) ...[
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    _infoItem(
                                                      'Payments',
                                                      '$paidPayments / $totalPayments paid',
                                                    ),
                                                    if (pendingPaymentsForContract > 0)
                                                      _infoItem(
                                                        'Pending',
                                                        '$pendingPaymentsForContract due',
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                LinearProgressIndicator(
                                                  value: totalPayments > 0
                                                      ? paidPayments / totalPayments
                                                      : 0,
                                                  backgroundColor: TenantTheme.scaffoldBg,
                                                  color: TenantTheme.success,
                                                  minHeight: 6,
                                                ),
                                                const SizedBox(height: 10),
                                              ],
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _infoItem('Monthly rent', '\$${rent.toStringAsFixed(0)}', isPrice: true),
                                                  if (hasDep) _infoItem('Deposit', '\$${(dep ?? 0).toStringAsFixed(0)}', isPrice: true),
                                                  if (months != null && months > 0) _infoItem('Total contract value', '\$${(rent * months).toStringAsFixed(0)}', isPrice: true),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _infoItem('Paid so far', '\$${totalPaidAmount.toStringAsFixed(0)}', isPrice: true),
                                                  _infoItem('Remaining', '\$${remainingAmount.toStringAsFixed(0)}', isPrice: true),
                                                ],
                                              ),
                                              if (avgDelay != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Average overdue days: ${avgDelay.toStringAsFixed(1)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: TenantTheme.textHint,
                                                  ),
                                                ),
                                              ],
                                              if (nextPaymentDays != null) ...[
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.schedule,
                                                      size: 16,
                                                      color: nextPaymentDays < 0
                                                          ? TenantTheme.error
                                                          : (nextPaymentDays <= 3
                                                              ? TenantTheme.warning
                                                              : TenantTheme.success),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Builder(
                                                        builder: (context) {
                                                          final cycle = (c['paymentCycle'] ?? 'monthly')
                                                              .toString()
                                                              .toLowerCase();
                                                          String text;
                                                          if (cycle == 'daily' && nextPaymentDate != null) {
                                                            final diff = nextPaymentDate.difference(DateTime.now());
                                                            final hours = diff.inHours;
                                                            if (hours < 0) {
                                                              text =
                                                                  'Next payment is overdue by ${hours.abs()} hour(s)';
                                                            } else {
                                                              text = 'Next payment in $hours hour(s)';
                                                            }
                                                          } else {
                                                            if (nextPaymentDays! < 0) {
                                                              text =
                                                                  'Next payment is overdue by ${nextPaymentDays.abs()} day(s)';
                                                            } else {
                                                              text = 'Next payment in $nextPaymentDays day(s)';
                                                            }
                                                            if (nextPaymentDate != null) {
                                                              text +=
                                                                  ' (${DateFormat('yyyy-MM-dd').format(nextPaymentDate)})';
                                                            }
                                                          }

                                                          final isOverdueDisplay = (cycle == 'daily' && nextPaymentDate != null
                                                                  ? nextPaymentDate
                                                                          .difference(DateTime.now())
                                                                          .inHours <
                                                                      0
                                                                  : nextPaymentDays! < 0);

                                                          return Text(
                                                            text,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: isOverdueDisplay
                                                                  ? TenantTheme.error
                                                                  : (nextPaymentDays! <= 3
                                                                      ? TenantTheme.warning
                                                                      : TenantTheme.textSecondary),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              if (hasDep)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.lightbulb_outline, size: 14, color: TenantTheme.accent),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text('The deposit is refunded when the contract ends and the unit is handed over in good condition. Keep a copy of the contract.',
                                                          style: TextStyle(fontSize: 11, color: TenantTheme.textHint)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (isActive) ...[
                                                const SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          Switch(
                                                            value: (c['autoPay']?['enabled'] ?? false) as bool,
                                                            onChanged: (v) async {
                                                              final (ok, msg) =
                                                                  await ApiService.updateContractAutoPay(
                                                                      contractId, v);
                                                              if (!mounted) return;
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(ok
                                                                      ? (v
                                                                          ? 'Auto pay enabled for this contract.'
                                                                          : 'Auto pay disabled for this contract.')
                                                                      : msg),
                                                                ),
                                                              );
                                                              if (ok) {
                                                                _fetchContracts();
                                                              }
                                                            },
                                                          ),
                                                          const SizedBox(width: 4),
                                                          const Expanded(
                                                            child: Text(
                                                              'Auto pay next installments',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed: () => _showAddDepositDialog(c),
                                                        icon: const Icon(Icons.security, size: 18),
                                                        label: const Text('Add deposit'),
                                                        style: ElevatedButton.styleFrom(backgroundColor: TenantTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TenantTheme.radiusMd))),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                        children: [
                                                          OutlinedButton(
                                                            onPressed: () => _requestTermination(contractId),
                                                            style: OutlinedButton.styleFrom(foregroundColor: TenantTheme.error, side: const BorderSide(color: TenantTheme.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TenantTheme.radiusMd))),
                                                            child: const Text('Request termination'),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          ElevatedButton(
                                                            onPressed: pendingPaymentsForContract > 0
                                                                ? () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder: (_) => TenantPaymentsScreen(
                                                                          contractIdFilter: contractId,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  }
                                                                : null,
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: TenantTheme.primary,
                                                              foregroundColor: Colors.white,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                                                              ),
                                                            ),
                                                            child: const Text('Pay next installment'),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                );
                              },
                            ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildTopStats() {
    final nextDays = _nextGlobalPaymentDays;
    String nextText = 'No upcoming payments';
    Color nextColor = TenantTheme.textHint;
    if (_nextGlobalPaymentDate != null) {
      final now = DateTime.now();
      final diff = _nextGlobalPaymentDate!.difference(now);
      final cycle = (_nextGlobalPaymentCycle ?? 'monthly').toLowerCase();

      if (cycle == 'daily') {
        final hours = diff.inHours;
        if (hours < 0) {
          nextText = 'Next payment is overdue by ${hours.abs()} hour(s)';
          nextColor = TenantTheme.error;
        } else {
          nextText = 'Next payment in $hours hour(s)';
          nextColor =
              hours <= 24 ? TenantTheme.warning : TenantTheme.success;
        }
      } else {
        if (nextDays != null) {
          if (nextDays < 0) {
            nextText = 'Next payment is overdue by ${nextDays.abs()} day(s)';
            nextColor = TenantTheme.error;
          } else {
            nextText = 'Next payment in $nextDays day(s)';
            nextColor =
                nextDays <= 3 ? TenantTheme.warning : TenantTheme.success;
          }
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: TenantTheme.cardBg,
          borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
          boxShadow: TenantTheme.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contracts overview',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: TenantTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _smallStatChip(
                        'Total',
                        _totalContracts.toString(),
                      ),
                      _smallStatChip(
                        'Active',
                        _activeContracts.toString(),
                      ),
                      _smallStatChip(
                        'Pending',
                        _pendingContracts.toString(),
                      ),
                      _smallStatChip(
                        'Ended',
                        _endedContracts.toString(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${_totalMonthlyRent.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: TenantTheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total monthly rent',
                  style: TextStyle(
                    fontSize: 11,
                    color: TenantTheme.textHint,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: nextColor,
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 130,
                      child: Text(
                        nextText,
                        style: TextStyle(
                          fontSize: 11,
                          color: nextColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: TenantTheme.scaffoldBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: TenantTheme.textHint,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: TenantTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(width: 88, height: 88, color: TenantTheme.scaffoldBg, child: Icon(Icons.home_work_rounded, size: 36, color: TenantTheme.textHint));
  }

  Widget _miniChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: TenantTheme.textHint),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: TenantTheme.textSecondary)),
      ],
    );
  }

  Widget _infoItem(String label, String value, {bool isPrice = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: TenantTheme.textHint, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isPrice ? TenantTheme.primary : TenantTheme.textPrimary)),
      ],
    );
  }
}
