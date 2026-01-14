// lib/screens/admin_payments_transactions_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

enum PaymentStatusFilter { all, pending, paid, failed }

enum SortOption { newest, oldest, highest, lowest }

enum MethodFilter { all, online, cash, bank, visa }

enum ViewMode { cards, table }

const Color _primaryGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFF5F5F5);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class AdminPaymentsTransactionsScreen extends StatefulWidget {
  const AdminPaymentsTransactionsScreen({super.key});

  @override
  State<AdminPaymentsTransactionsScreen> createState() =>
      _AdminPaymentsTransactionsScreenState();
}

class _AdminPaymentsTransactionsScreenState
    extends State<AdminPaymentsTransactionsScreen> {
  bool _isLoading = true;
  List<dynamic> _allPayments = [];
  List<dynamic> _filteredPayments = [];
  List<dynamic> _displayedPayments = [];
  String? _errorMessage;

  // For Notifications
  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  // Filters
  final TextEditingController _searchController = TextEditingController();
  PaymentStatusFilter _statusFilter = PaymentStatusFilter.all;
  SortOption _sortOption = SortOption.newest;
  MethodFilter _methodFilter = MethodFilter.all;
  ViewMode _viewMode = ViewMode.cards;

  // Date Range Filter
  DateTime? _startDate;
  DateTime? _endDate;

  // Amount Range Filter
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  // Property & Tenant Filters
  List<dynamic> _allProperties = [];
  List<dynamic> _allTenants = [];
  String? _selectedPropertyId;
  String? _selectedTenantId;

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 20;
  int get _totalPages => (_filteredPayments.length / _itemsPerPage).ceil();

  // Saved Filters
  List<Map<String, dynamic>> _savedFilters = [];

  @override
  void initState() {
    super.initState();
    _loadSavedFilters();
    _fetchData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFiltersJson = prefs.getString('payment_filters');
    if (savedFiltersJson != null) {
      setState(() {
        _savedFilters = List<Map<String, dynamic>>.from(
            (jsonDecode(savedFiltersJson) as List)
                .map((e) => e as Map<String, dynamic>));
      });
    }
  }

  Future<void> _saveCurrentFilters() async {
    final filters = {
      'statusFilter': _statusFilter.name,
      'methodFilter': _methodFilter.name,
      'sortOption': _sortOption.name,
      'startDate': _startDate?.toIso8601String(),
      'endDate': _endDate?.toIso8601String(),
      'minAmount': _minAmountController.text,
      'maxAmount': _maxAmountController.text,
      'propertyId': _selectedPropertyId,
      'tenantId': _selectedTenantId,
      'name': 'Filter ${DateFormat('MM/dd HH:mm').format(DateTime.now())}',
    };
    _savedFilters.add(filters);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payment_filters', jsonEncode(_savedFilters));
    setState(() {});
  }

  Future<void> _loadFilter(Map<String, dynamic> filter) async {
    setState(() {
      _statusFilter = PaymentStatusFilter.values.firstWhere(
          (e) => e.name == filter['statusFilter'],
          orElse: () => PaymentStatusFilter.all);
      _methodFilter = MethodFilter.values.firstWhere(
          (e) => e.name == filter['methodFilter'],
          orElse: () => MethodFilter.all);
      _sortOption = SortOption.values.firstWhere(
          (e) => e.name == filter['sortOption'],
          orElse: () => SortOption.newest);
      _startDate = filter['startDate'] != null
          ? DateTime.parse(filter['startDate'])
          : null;
      _endDate =
          filter['endDate'] != null ? DateTime.parse(filter['endDate']) : null;
      _minAmountController.text = filter['minAmount'] ?? '';
      _maxAmountController.text = filter['maxAmount'] ?? '';
      _selectedPropertyId = filter['propertyId'];
      _selectedTenantId = filter['tenantId'];
    });
    _applyFilters();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.wait([
      _fetchPayments(),
      _fetchProperties(),
      _fetchNotifications(),
    ]);
  }

  Future<void> _fetchPayments() async {
    final (ok, data) = await ApiService.getAllPayments();
    if (mounted) {
      setState(() {
        if (ok) {
          _allPayments = data as List<dynamic>;
          // Extract unique tenants
          final tenantSet = <String, dynamic>{};
          for (var payment in _allPayments) {
            final tenant = payment['contractId']?['tenantId'];
            if (tenant != null && tenant['_id'] != null) {
              tenantSet[tenant['_id']] = tenant;
            }
          }
          _allTenants = tenantSet.values.toList();
          _applyFilters();
        } else {
          _errorMessage = data.toString();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProperties() async {
    final (ok, data) = await ApiService.getAllProperties();
    if (mounted && ok) {
      setState(() {
        _allProperties = data as List<dynamic>;
      });
    }
  }

  Future<void> _fetchNotifications() async {
    final (ok, data) = await ApiService.getAllNotifications();
    if (mounted && ok) {
      setState(() {
        _notifications = data as List<dynamic>;
        _unreadCount = _notifications.where((n) => n['isRead'] == false).length;
      });
    }
  }

  void _applyFilters() {
    List<dynamic> temp = List.from(_allPayments);

    // Status Filter
    if (_statusFilter != PaymentStatusFilter.all) {
      temp = temp.where((p) => p['status'] == _statusFilter.name).toList();
    }

    // Method Filter
    if (_methodFilter != MethodFilter.all) {
      temp = temp
          .where((p) =>
              p['method']?.toLowerCase() == _methodFilter.name.toLowerCase())
          .toList();
    }

    // Date Range Filter
    if (_startDate != null) {
      temp = temp.where((p) {
        final date = DateTime.parse(p['date']);
        return date.isAfter(_startDate!.subtract(const Duration(days: 1)));
      }).toList();
    }
    if (_endDate != null) {
      temp = temp.where((p) {
        final date = DateTime.parse(p['date']);
        return date.isBefore(_endDate!.add(const Duration(days: 1)));
      }).toList();
    }

    // Amount Range Filter
    if (_minAmountController.text.isNotEmpty) {
      final min = double.tryParse(_minAmountController.text);
      if (min != null) {
        temp = temp.where((p) => (p['amount'] ?? 0) >= min).toList();
      }
    }
    if (_maxAmountController.text.isNotEmpty) {
      final max = double.tryParse(_maxAmountController.text);
      if (max != null) {
        temp = temp.where((p) => (p['amount'] ?? 0) <= max).toList();
      }
    }

    // Property Filter
    if (_selectedPropertyId != null) {
      temp = temp.where((p) {
        return p['contractId']?['propertyId']?['_id'] == _selectedPropertyId;
      }).toList();
    }

    // Tenant Filter
    if (_selectedTenantId != null) {
      temp = temp.where((p) {
        return p['contractId']?['tenantId']?['_id'] == _selectedTenantId;
      }).toList();
    }

    // Search Filter
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      temp = temp.where((p) {
        final c = p['contractId'] ?? {};
        final tenant = c['tenantId']?['name']?.toLowerCase() ?? '';
        final property = c['propertyId']?['title']?.toLowerCase() ?? '';
        final paymentId = p['_id']?.toLowerCase() ?? '';
        return tenant.contains(query) ||
            property.contains(query) ||
            paymentId.contains(query);
      }).toList();
    }

    // Sort
    switch (_sortOption) {
      case SortOption.newest:
        temp.sort((a, b) =>
            DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
        break;
      case SortOption.oldest:
        temp.sort((a, b) =>
            DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
        break;
      case SortOption.highest:
        temp.sort((a, b) => (b['amount'] ?? 0).compareTo(a['amount'] ?? 0));
        break;
      case SortOption.lowest:
        temp.sort((a, b) => (a['amount'] ?? 0).compareTo(b['amount'] ?? 0));
        break;
    }

    setState(() {
      _filteredPayments = temp;
      _currentPage = 1;
      _updateDisplayedPayments();
    });
  }

  void _updateDisplayedPayments() {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    _displayedPayments = _filteredPayments.sublist(
        start, end > _filteredPayments.length ? _filteredPayments.length : end);
  }

  Map<String, dynamic> _getSummaryStats() {
    final paid = _filteredPayments.where((p) => p['status'] == 'paid').length;
    final pending =
        _filteredPayments.where((p) => p['status'] == 'pending').length;
    final failed =
        _filteredPayments.where((p) => p['status'] == 'failed').length;

    final totalRevenue = _filteredPayments
        .where((p) => p['status'] == 'paid')
        .fold(0.0, (sum, p) => sum + (p['amount'] ?? 0));

    final averageAmount = _filteredPayments.isNotEmpty
        ? _filteredPayments.fold(0.0, (sum, p) => sum + (p['amount'] ?? 0)) /
            _filteredPayments.length
        : 0.0;

    return {
      'total': _filteredPayments.length,
      'paid': paid,
      'pending': pending,
      'failed': failed,
      'totalRevenue': totalRevenue,
      'averageAmount': averageAmount,
    };
  }

  Future<void> _updatePaymentStatus(String paymentId, String newStatus) async {
    final (ok, msg) = await ApiService.updatePayment(paymentId, newStatus);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg), backgroundColor: ok ? _primaryGreen : Colors.red),
    );

    if (ok) _fetchPayments();
  }

  Future<void> _deletePayment(String paymentId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Transaction"),
        content:
            const Text("Are you sure you want to remove this payment record?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final (ok, msg) = await ApiService.deletePayment(paymentId);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ok ? "Payment deleted" : msg),
            backgroundColor: ok ? _primaryGreen : Colors.red),
      );

      if (ok) {
        _fetchPayments();
      }
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notifications"),
        content: SizedBox(
          width: 400,
          height: 300,
          child: _notifications.isEmpty
              ? const Center(child: Text("No notifications yet."))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    final bool isRead = n['isRead'] ?? false;

                    return ListTile(
                      leading: Icon(
                        Icons.notifications,
                        color: isRead ? Colors.grey : _primaryGreen,
                      ),
                      title: Text(n['message'] ?? '',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold)),
                      trailing: isRead
                          ? null
                          : const Icon(Icons.circle,
                              color: Colors.red, size: 10),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Advanced Filters"),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date Range
                  ListTile(
                    title: const Text("Date Range"),
                    subtitle: Text(_startDate == null && _endDate == null
                        ? "No date range selected"
                        : "${_startDate != null ? DateFormat('MMM d, yyyy').format(_startDate!) : 'Start'} - ${_endDate != null ? DateFormat('MMM d, yyyy').format(_endDate!) : 'End'}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (range != null) {
                              setDialogState(() {
                                _startDate = range.start;
                                _endDate = range.end;
                              });
                            }
                          },
                        ),
                        if (_startDate != null || _endDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setDialogState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Amount Range
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minAmountController,
                          decoration: const InputDecoration(
                            labelText: "Min Amount",
                            prefixText: "\$",
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _maxAmountController,
                          decoration: const InputDecoration(
                            labelText: "Max Amount",
                            prefixText: "\$",
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Property Filter
                  DropdownButtonFormField<String>(
                    value: _selectedPropertyId,
                    decoration: const InputDecoration(
                      labelText: "Property",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text("All Properties")),
                      ..._allProperties.map((p) => DropdownMenuItem(
                            value: p['_id'],
                            child: Text(p['title'] ?? 'Unknown'),
                          )),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedPropertyId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Tenant Filter
                  DropdownButtonFormField<String>(
                    value: _selectedTenantId,
                    decoration: const InputDecoration(
                      labelText: "Tenant",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text("All Tenants")),
                      ..._allTenants.map((t) => DropdownMenuItem(
                            value: t['_id'],
                            child: Text(t['name'] ?? 'Unknown'),
                          )),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedTenantId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Saved Filters
                  if (_savedFilters.isNotEmpty) ...[
                    const Divider(),
                    const Text("Saved Filters:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._savedFilters.map((filter) => ListTile(
                          title: Text(filter['name'] ?? 'Unnamed Filter'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () {
                                  _loadFilter(filter);
                                  Navigator.pop(context);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  setDialogState(() {
                                    _savedFilters.remove(filter);
                                  });
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setString('payment_filters',
                                      jsonEncode(_savedFilters));
                                },
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _minAmountController.clear();
                _maxAmountController.clear();
                _startDate = null;
                _endDate = null;
                _selectedPropertyId = null;
                _selectedTenantId = null;
                setDialogState(() {});
              },
              child: const Text("Clear All"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveCurrentFilters();
                if (context.mounted) Navigator.pop(context);
                _applyFilters();
              },
              child: const Text("Save Filter"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              child: const Text("Apply"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToCSV() async {
    try {
      final List<List<dynamic>> rows = [];
      rows.add([
        'Payment ID',
        'Date',
        'Amount',
        'Method',
        'Status',
        'Tenant',
        'Property',
        'Receipt Number'
      ]);

      for (var payment in _filteredPayments) {
        final contract = payment['contractId'] ?? {};
        final tenant = contract['tenantId'] ?? {};
        final property = contract['propertyId'] ?? {};
        rows.add([
          payment['_id'] ?? '',
          DateFormat('yyyy-MM-dd').format(DateTime.parse(payment['date'])),
          payment['amount'] ?? 0,
          payment['method'] ?? '',
          payment['status'] ?? '',
          tenant['name'] ?? '',
          property['title'] ?? '',
          payment['receipt']?['receiptNumber'] ?? '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csv);

      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Storage permission denied")));
          return;
        }

        final directory = Directory('/storage/emulated/0/Download');
        final file = File(
            '${directory.path}/payments_${DateTime.now().millisecondsSinceEpoch}.csv');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Exported to ${file.path}")));
      } else {
        // For other platforms, save to documents
        final directory = await getApplicationDocumentsDirectory();
        final file = File(
            '${directory.path}/payments_${DateTime.now().millisecondsSinceEpoch}.csv');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Exported to ${file.path}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Export failed: $e")));
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'SHAQATI - Payments Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated: ${dateFormat.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Total Payments: ${_filteredPayments.length}',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Date',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Amount',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Method',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Status',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('Tenant',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ..._filteredPayments.map((payment) {
                    final contract = payment['contractId'] ?? {};
                    final tenant = contract['tenantId'] ?? {};
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(DateFormat('yyyy-MM-dd')
                                .format(DateTime.parse(payment['date'])))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('\$${payment['amount'] ?? 0}')),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(payment['method'] ?? '')),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(payment['status'] ?? '')),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(tenant['name'] ?? '')),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("PDF Export failed: $e")));
    }
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Export Data"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text("Export as CSV"),
              subtitle: const Text("Excel compatible format"),
              onTap: () {
                Navigator.pop(context);
                _exportToCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("Export as PDF"),
              subtitle: const Text("Printable document"),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChartsDialog() {
    final stats = _getSummaryStats();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Payment Analytics"),
        content: SizedBox(
          width: 400,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Status Pie Chart
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: stats['paid'].toDouble(),
                          color: Colors.green,
                          title: 'Paid\n${stats['paid']}',
                          radius: 60,
                        ),
                        PieChartSectionData(
                          value: stats['pending'].toDouble(),
                          color: Colors.orange,
                          title: 'Pending\n${stats['pending']}',
                          radius: 60,
                        ),
                        PieChartSectionData(
                          value: stats['failed'].toDouble(),
                          color: Colors.red,
                          title: 'Failed\n${stats['failed']}',
                          radius: 60,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Monthly Revenue Bar Chart
                SizedBox(
                  height: 200,
                  child: _buildMonthlyRevenueChart(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  Widget _buildMonthlyRevenueChart() {
    final monthlyData = <String, double>{};
    for (var payment in _filteredPayments.where((p) => p['status'] == 'paid')) {
      final date = DateTime.parse(payment['date']);
      final key = DateFormat('MMM yyyy').format(date);
      monthlyData[key] = (monthlyData[key] ?? 0) + (payment['amount'] ?? 0);
    }

    final sortedKeys = monthlyData.keys.toList()..sort();
    if (sortedKeys.isEmpty) {
      return const Center(child: Text("No data available"));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: monthlyData.values.reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < sortedKeys.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      sortedKeys[index],
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('\$${value.toInt()}');
              },
              reservedSize: 50,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        barGroups: sortedKeys.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: monthlyData[entry.value]!,
                color: _primaryGreen,
                width: 20,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getSummaryStats();

    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text("Payments & Transactions"),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          const SizedBox(width: 8),
          // View Mode Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: IconButton(
              icon: Icon(_viewMode == ViewMode.table
                  ? Icons.view_module
                  : Icons.table_chart),
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == ViewMode.table
                      ? ViewMode.cards
                      : ViewMode.table;
                });
              },
              tooltip: _viewMode == ViewMode.table ? "Card View" : "Table View",
            ),
          ),
          // Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: IconButton(
              icon: const Icon(Icons.filter_alt),
              onPressed: _showFilterDialog,
              tooltip: "Advanced Filters",
            ),
          ),
          // Sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort),
              onSelected: (v) {
                setState(() => _sortOption = v);
                _applyFilters();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: SortOption.newest, child: Text("Newest")),
                PopupMenuItem(value: SortOption.oldest, child: Text("Oldest")),
                PopupMenuItem(
                    value: SortOption.highest, child: Text("Highest Amount")),
                PopupMenuItem(
                    value: SortOption.lowest, child: Text("Lowest Amount")),
              ],
            ),
          ),
          // Charts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: _showChartsDialog,
            ),
          ),
          // Export
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: const Icon(Icons.download),
              onPressed: _showExportDialog,
            ),
          ),
          // Notifications
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _showNotificationsDialog,
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _fetchPayments();
                _fetchNotifications();
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          _buildSummaryCards(stats),
          // Filter Bar
          _FilterBar(
            searchController: _searchController,
            currentFilter: _statusFilter,
            methodFilter: _methodFilter,
            onFilterChanged: (f) {
              setState(() => _statusFilter = f!);
              _applyFilters();
            },
            onMethodChanged: (m) {
              setState(() => _methodFilter = m!);
              _applyFilters();
            },
          ),
          // Content
          Expanded(child: _buildContent()),
          // Pagination
          if (_totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: "Total Payments",
              value: stats['total'].toString(),
              icon: Icons.payment,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              title: "Total Revenue",
              value: "\$${stats['totalRevenue'].toStringAsFixed(0)}",
              icon: Icons.attach_money,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              title: "Paid",
              value: stats['paid'].toString(),
              icon: Icons.check_circle,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              title: "Pending",
              value: stats['pending'].toString(),
              icon: Icons.hourglass_empty,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                      _updateDisplayedPayments();
                    });
                  }
                : null,
          ),
          Text(
            "Page $_currentPage of $_totalPages",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                      _updateDisplayedPayments();
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _primaryGreen));
    }
    if (_errorMessage != null) {
      return Center(
          child: Text("Error: $_errorMessage",
              style: const TextStyle(color: Colors.red)));
    }
    if (_filteredPayments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment_outlined, size: 80, color: Colors.grey),
            Text("No Payments Found",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("Payments will appear once submitted."),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPayments,
      child:
          _viewMode == ViewMode.table ? _buildTableView() : _buildCardsView(),
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Date")),
            DataColumn(label: Text("Amount")),
            DataColumn(label: Text("Method")),
            DataColumn(label: Text("Status")),
            DataColumn(label: Text("Tenant")),
            DataColumn(label: Text("Property")),
            DataColumn(label: Text("Actions")),
          ],
          rows: _displayedPayments.map((payment) {
            final contract = payment['contractId'] ?? {};
            final tenant = contract['tenantId'] ?? {};
            final property = contract['propertyId'] ?? {};
            final date = DateTime.parse(payment['date']);
            final amount = (payment['amount'] ?? 0).toDouble();

            return DataRow(
              cells: [
                DataCell(Text(DateFormat('MMM d, yyyy').format(date))),
                DataCell(Text("\$${amount.toStringAsFixed(2)}")),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getPaymentMethodIcon(payment['method'] ?? ''),
                    const SizedBox(width: 8),
                    Text((payment['method'] ?? '').toUpperCase()),
                  ],
                )),
                DataCell(_statusChip(payment['status'] ?? '')),
                DataCell(Text(tenant['name'] ?? 'N/A')),
                DataCell(Text(property['title'] ?? 'N/A')),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () => _showPaymentDetails(payment),
                    ),
                    if (payment['status'] == 'pending')
                      IconButton(
                        icon: const Icon(Icons.check,
                            size: 20, color: Colors.green),
                        onPressed: () =>
                            _updatePaymentStatus(payment['_id'], 'paid'),
                      ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCardsView() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _displayedPayments.length,
      itemBuilder: (_, i) => _PaymentCard(
        payment: _displayedPayments[i],
        onUpdateStatus: _updatePaymentStatus,
        onDelete: _deletePayment,
        onViewDetails: _showPaymentDetails,
      ),
    );
  }

  void _showPaymentDetails(dynamic payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentDetailsSheet(payment: payment),
    );
  }

  Widget _statusChip(String status) {
    late Color bg;
    late Color fg = Colors.white;

    switch (status) {
      case "paid":
        bg = Colors.green;
        break;
      case "failed":
        bg = Colors.red;
        break;
      default:
        bg = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Icon(Icons.money, size: 16, color: Colors.green);
      case 'bank':
        return const Icon(Icons.account_balance, size: 16, color: Colors.blue);
      case 'online':
      case 'visa':
      case 'test_visa':
        return const Icon(Icons.credit_card, size: 16, color: Colors.purple);
      default:
        return const Icon(Icons.payment, size: 16);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final PaymentStatusFilter currentFilter;
  final MethodFilter methodFilter;
  final ValueChanged<PaymentStatusFilter?> onFilterChanged;
  final ValueChanged<MethodFilter?> onMethodChanged;

  const _FilterBar({
    required this.searchController,
    required this.currentFilter,
    required this.methodFilter,
    required this.onFilterChanged,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search by tenant, property, or payment ID...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<PaymentStatusFilter>(
              value: currentFilter,
              decoration: const InputDecoration(
                labelText: "Status",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: PaymentStatusFilter.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s.name.toUpperCase()),
                );
              }).toList(),
              onChanged: onFilterChanged,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<MethodFilter>(
              value: methodFilter,
              decoration: const InputDecoration(
                labelText: "Method",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: MethodFilter.values.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text(m.name.toUpperCase()),
                );
              }).toList(),
              onChanged: onMethodChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final Function(String id, String status) onUpdateStatus;
  final Function(String id) onDelete;
  final Function(Map<String, dynamic>) onViewDetails;

  const _PaymentCard({
    required this.payment,
    required this.onUpdateStatus,
    required this.onDelete,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final contract = payment['contractId'] ?? {};
    final tenant = contract['tenantId'] ?? {};
    final property = contract['propertyId'] ?? {};

    final status = payment['status'];
    final amount = (payment['amount'] ?? 0).toDouble();
    final method = payment['method'] ?? "N/A";
    final date = DateTime.parse(payment['date']);

    final dateFmt = DateFormat('d MMM, yyyy');
    final currency = NumberFormat.simpleCurrency();
    final isLargePayment = amount >= 5000;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => onViewDetails(payment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _getPaymentMethodIcon(method),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currency.format(amount),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _primaryGreen,
                            ),
                          ),
                        ),
                        if (isLargePayment)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "LARGE",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.copy, size: 18),
                                SizedBox(width: 8),
                                Text("Copy ID"),
                              ],
                            ),
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: payment['_id']));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Payment ID copied")),
                              );
                            },
                          ),
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.share, size: 18),
                                SizedBox(width: 8),
                                Text("Share"),
                              ],
                            ),
                            onTap: () async {
                              final uri = Uri.parse(
                                  'mailto:?subject=Payment Details&body=Payment ID: ${payment['_id']}');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                          PopupMenuItem(
                            child: const Row(
                              children: [
                                Icon(Icons.print, size: 18),
                                SizedBox(width: 8),
                                Text("Print"),
                              ],
                            ),
                            onTap: () {
                              // Implement print functionality
                            },
                          ),
                          if (payment['receiptUrl'] != null)
                            PopupMenuItem(
                              child: const Row(
                                children: [
                                  Icon(Icons.receipt, size: 18),
                                  SizedBox(width: 8),
                                  Text("View Receipt"),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Scaffold(
                                      appBar:
                                          AppBar(title: const Text("Receipt")),
                                      body: PhotoView(
                                        imageProvider:
                                            CachedNetworkImageProvider(
                                          payment['receiptUrl'],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => onDelete(payment['_id']),
                      ),
                      _statusChip(status),
                    ],
                  )
                ],
              ),

              const Divider(height: 20),

              _row(Icons.person, "Tenant:", tenant['name'] ?? "N/A"),
              _row(Icons.home, "Property:", property['title'] ?? "N/A"),

              const Divider(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _getPaymentMethodIcon(method),
                    const SizedBox(width: 6),
                    const Text(
                      "Method:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        method.toUpperCase(),
                        textAlign: TextAlign.end,
                        style: const TextStyle(color: _textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              _row(Icons.date_range, "Date:", dateFmt.format(date)),
              _row(Icons.vpn_key, "Payment ID:",
                  payment['_id'].toString().substring(0, 8) + "..."),

              if (payment['receipt']?['receiptNumber'] != null)
                _row(Icons.receipt_long, "Receipt #:",
                    payment['receipt']['receiptNumber']),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => onViewDetails(payment),
                    icon: const Icon(Icons.visibility),
                    label: const Text("View Details"),
                  ),
                  if (status == "pending") ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => onUpdateStatus(payment['_id'], "paid"),
                      icon: const Icon(Icons.check),
                      label: const Text("Approve"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => onUpdateStatus(payment['_id'], "failed"),
                      icon: const Icon(Icons.close),
                      label: const Text("Fail"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(dynamic icon, String label, String value) {
    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(icon, size: 16, color: Colors.grey.shade600);
    } else if (icon is Widget) {
      iconWidget = icon;
    } else {
      iconWidget = const Icon(Icons.info, size: 16, color: Colors.grey);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: _textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    late Color bg;
    late Color fg = Colors.white;

    switch (status) {
      case "paid":
        bg = Colors.green;
        break;
      case "failed":
        bg = Colors.red;
        break;
      default:
        bg = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _getPaymentMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return const Icon(Icons.money, size: 16, color: Colors.green);
      case 'bank':
        return const Icon(Icons.account_balance, size: 16, color: Colors.blue);
      case 'online':
      case 'visa':
      case 'test_visa':
        return const Icon(Icons.credit_card, size: 16, color: Colors.purple);
      default:
        return const Icon(Icons.payment, size: 16);
    }
  }
}

class _PaymentDetailsSheet extends StatelessWidget {
  final dynamic payment;

  const _PaymentDetailsSheet({required this.payment});

  @override
  Widget build(BuildContext context) {
    final contract = payment['contractId'] ?? {};
    final tenant = contract['tenantId'] ?? {};
    final property = contract['propertyId'] ?? {};
    final date = DateTime.parse(payment['date']);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Payment Details",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          _detailRow("Payment ID", payment['_id']),
          _detailRow(
              "Amount", "\$${(payment['amount'] ?? 0).toStringAsFixed(2)}"),
          _detailRow("Method", (payment['method'] ?? '').toUpperCase()),
          _detailRow("Status", payment['status']?.toUpperCase() ?? ''),
          _detailRow("Date", DateFormat('MMMM d, yyyy').format(date)),
          _detailRow("Time", DateFormat('hh:mm a').format(date)),
          if (payment['receipt']?['receiptNumber'] != null)
            _detailRow("Receipt Number", payment['receipt']['receiptNumber']),
          const SizedBox(height: 16),
          const Text("Tenant Information",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          _detailRow("Name", tenant['name'] ?? 'N/A'),
          _detailRow("Email", tenant['email'] ?? 'N/A'),
          const SizedBox(height: 16),
          const Text("Property Information",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          _detailRow("Property", property['title'] ?? 'N/A'),
          if (payment['receiptUrl'] != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text("Receipt")),
                        body: PhotoView(
                          imageProvider: CachedNetworkImageProvider(
                            payment['receiptUrl'],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt),
                label: const Text("View Receipt"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: _textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
