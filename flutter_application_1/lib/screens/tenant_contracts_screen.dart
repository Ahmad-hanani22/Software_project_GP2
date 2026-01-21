import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/utils/tenant_theme.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contract_details_screen.dart';
import 'chat_screen.dart';

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
    if (lowerStatus == 'active' || lowerStatus == 'rented' || lowerStatus == 'expiring_soon') return 'نشط';
    if (lowerStatus == 'pending') return 'قيد الانتظار';
    return 'منتهي';
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
        title: 'عقودي',
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
                        hintText: 'بحث باسم العقار أو العنوان...',
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: ['All', 'Active', 'Pending', 'Ended'].map((f) {
                      final sel = _filter == f;
                      final ar = {'All':'الكل','Active':'نشط','Pending':'قيد الانتظار','Ended':'منتهي'}[f] ?? f;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: FilterChip(
                          label: Text(ar),
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
                        ? _buildContractsEmptyState('لا توجد عقود حتى الآن.')
                        : _filteredContracts.isEmpty
                            ? _buildContractsEmptyState('لا توجد نتائج تطابق الفلتر.')
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
                                final statusAr = _statusLabel(lowerStatus);
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
                                              Text("#$idShort", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              Row(
                                                children: [
                                                  if (isActive && daysLeft != null && daysLeft <= 30 && daysLeft >= 0)
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 8),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                                                        child: Text('ينتهي خلال $daysLeft يوم', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                                      ),
                                                    ),
                                                  Text(statusAr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
                                                        Text(property['title'] ?? 'عقار',
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
                                                              if (beds != null) _miniChip(Icons.bed, '$beds غرفة'),
                                                              if (area != null) _miniChip(Icons.square_foot, '${area} م²'),
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
                                                        Text("المالك", style: TextStyle(fontSize: 10, color: TenantTheme.textHint)),
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
                                                    label: const Text("محادثة"),
                                                    onPressed: () {
                                                      final lid = landlord['_id'] ?? landlord['id'] ?? '';
                                                      if (lid.toString().isEmpty) return;
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: lid.toString(), receiverName: landlord['name'] ?? 'المالك')));
                                                    },
                                                  ),
                                                ],
                                              ),
                                              const Divider(height: 24),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _infoItem('بداية العقد', startStr),
                                                  _infoItem('نهاية العقد', endStr),
                                                  if (months != null) _infoItem('المدة', '${months} شهر'),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _infoItem('الإيجار الشهري', '\$${rent.toStringAsFixed(0)}', isPrice: true),
                                                  if (hasDep) _infoItem('الوديعة', '\$${(dep ?? 0).toStringAsFixed(0)}', isPrice: true),
                                                  if (months != null && months > 0) _infoItem('إجمالي العقد', '\$${(rent * months).toStringAsFixed(0)}', isPrice: true),
                                                ],
                                              ),
                                              if (hasDep)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 8),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.lightbulb_outline, size: 14, color: TenantTheme.accent),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text('الوديعة تُسترد عند إنهاء العقد وتسليم الوحدة بحالة جيدة. احتفظ بنسخة من العقد.',
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
                                                      child: ElevatedButton.icon(
                                                        onPressed: () => _showAddDepositDialog(c),
                                                        icon: const Icon(Icons.security, size: 18),
                                                        label: const Text('إضافة وديعة'),
                                                        style: ElevatedButton.styleFrom(backgroundColor: TenantTheme.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TenantTheme.radiusMd))),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: OutlinedButton(
                                                        onPressed: () => _requestTermination(contractId),
                                                        style: OutlinedButton.styleFrom(foregroundColor: TenantTheme.error, side: const BorderSide(color: TenantTheme.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TenantTheme.radiusMd))),
                                                        child: const Text('طلب إنهاء العقد'),
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
