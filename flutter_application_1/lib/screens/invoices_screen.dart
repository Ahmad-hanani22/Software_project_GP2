import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

/// Enhanced Invoices Screen
/// 
/// Features:
/// - Charts Tab with Pie, Bar, Line, and Area charts
/// - Enhanced Summary Cards
/// - Advanced Filters & Search
/// - Invoice Details Dialog with PDF view
/// - Invoice Status Management
/// - Export & Printing
/// - Invoice Analytics
/// - Payment Integration
class InvoicesScreen extends StatefulWidget {
  final String? contractId;

  const InvoicesScreen({
    super.key,
    this.contractId,
  });

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _invoices = [];
  List<dynamic> _filteredInvoices = [];
  List<dynamic> _allPayments = [];
  String? _currentUserRole;
  String? _userId;

  // Tab Controller
  late TabController _tabController;

  // Filters & Search
  String? _selectedStatus;
  String? _selectedTenantId;
  String? _selectedPropertyId;
  double? _minAmount;
  double? _maxAmount;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  bool _showFilters = false;

  // Properties and Tenants for filters
  List<dynamic> _properties = [];
  List<dynamic> _tenants = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserRole = prefs.getString('role');
      _userId = prefs.getString('userId');
    });
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    
    // Fetch invoices
    final (okInvoices, invoicesData) = await ApiService.getAllInvoices(
      contractId: widget.contractId,
    );
    if (okInvoices && invoicesData is List) {
      _invoices = invoicesData;
      _filteredInvoices = invoicesData;
    }

    // Fetch payments for integration
    if (_userId != null) {
      final (okPayments, paymentsData) = await ApiService.getUserPayments(_userId!);
      if (okPayments && paymentsData is List) {
        _allPayments = paymentsData;
      }
    }

    // Fetch properties and tenants for filters
    if (_currentUserRole == 'landlord' && _userId != null) {
      final (okProps, propsData) = await ApiService.getPropertiesByOwner(_userId!);
      if (okProps && propsData is List) {
        _properties = propsData;
      }

      final (okContracts, contractsData) = await ApiService.getAllContracts();
      if (okContracts && contractsData is List) {
        // Extract unique tenants
        final tenantMap = <String, Map>{};
        for (var contract in contractsData) {
          final tenant = contract['tenantId'];
          if (tenant is Map) {
            final tenantId = tenant['_id']?.toString() ?? '';
            if (!tenantMap.containsKey(tenantId)) {
              tenantMap[tenantId] = tenant;
            }
          }
        }
        _tenants = tenantMap.values.toList();
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(_invoices);

    // Search by invoice number
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((invoice) {
        final invoiceNumber = (invoice['invoiceNumber'] ?? '').toString().toLowerCase();
        return invoiceNumber.contains(searchTerm);
      }).toList();
    }

    // Status filter
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      filtered = filtered.where((invoice) {
        final status = _getInvoiceStatus(invoice);
        return status == _selectedStatus;
      }).toList();
    }

    // Tenant filter
    if (_selectedTenantId != null && _selectedTenantId!.isNotEmpty) {
      filtered = filtered.where((invoice) {
        final contract = invoice['contractId'];
        if (contract is Map) {
          final tenant = contract['tenantId'];
          if (tenant is Map) {
            return tenant['_id']?.toString() == _selectedTenantId;
          } else if (tenant is String) {
            return tenant == _selectedTenantId;
          }
        }
        return false;
      }).toList();
    }

    // Property filter
    if (_selectedPropertyId != null && _selectedPropertyId!.isNotEmpty) {
      filtered = filtered.where((invoice) {
        final contract = invoice['contractId'];
        if (contract is Map) {
          final property = contract['propertyId'];
          if (property is Map) {
            return property['_id']?.toString() == _selectedPropertyId;
          } else if (property is String) {
            return property == _selectedPropertyId;
          }
        }
        return false;
      }).toList();
    }

    // Amount range filter
    if (_minAmount != null) {
      filtered = filtered.where((invoice) => 
        ((invoice['total'] ?? 0) as num).toDouble() >= _minAmount!
      ).toList();
    }
    if (_maxAmount != null) {
      filtered = filtered.where((invoice) => 
        ((invoice['total'] ?? 0) as num).toDouble() <= _maxAmount!
      ).toList();
    }

    // Date range filter
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((invoice) {
        final issuedAt = invoice['issuedAt'];
        if (issuedAt == null) return false;
        try {
          final date = DateTime.parse(issuedAt);
          if (_startDate != null && date.isBefore(_startDate!)) return false;
          if (_endDate != null && date.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
          return true;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    setState(() {
      _filteredInvoices = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedTenantId = null;
      _selectedPropertyId = null;
      _minAmount = null;
      _maxAmount = null;
      _startDate = null;
      _endDate = null;
      _searchController.clear();
      _minAmountController.clear();
      _maxAmountController.clear();
    });
    _applyFilters();
  }

  String _getInvoiceStatus(dynamic invoice) {
    final payment = invoice['paymentId'];
    if (payment != null) {
      final paymentStatus = payment is Map ? payment['status'] : null;
      if (paymentStatus == 'paid') return 'paid';
    }
    
    final dueDate = invoice['dueDate'];
    if (dueDate != null) {
      try {
        final due = DateTime.parse(dueDate);
        if (DateTime.now().isAfter(due)) return 'overdue';
      } catch (e) {
        // Invalid date
      }
    }
    
    return 'pending';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Pending';
      case 'overdue':
        return 'Overdue';
      default:
        return status;
    }
  }

  // Enhanced Summary Calculations
  Map<String, dynamic> get _summaryStats {
    double totalAmount = 0;
    double paidAmount = 0;
    double pendingAmount = 0;
    double overdueAmount = 0;
    int paidCount = 0;
    int pendingCount = 0;
    int overdueCount = 0;

    for (var invoice in _filteredInvoices) {
      final amount = ((invoice['total'] ?? 0) as num).toDouble();
      final status = _getInvoiceStatus(invoice);
      
      totalAmount += amount;
      
      if (status == 'paid') {
        paidAmount += amount;
        paidCount++;
      } else if (status == 'overdue') {
        overdueAmount += amount;
        overdueCount++;
      } else {
        pendingAmount += amount;
        pendingCount++;
      }
    }

    final avgAmount = _filteredInvoices.isEmpty ? 0.0 : totalAmount / _filteredInvoices.length;
    final collectionRate = totalAmount > 0 ? (paidAmount / totalAmount * 100) : 0.0;

    return {
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'overdueAmount': overdueAmount,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
      'overdueCount': overdueCount,
      'averageAmount': avgAmount,
      'collectionRate': collectionRate,
    };
  }

  // Chart Data
  Map<String, double> get _statusDistribution {
    final distribution = <String, double>{};
    for (var invoice in _filteredInvoices) {
      final status = _getInvoiceStatus(invoice);
      final amount = ((invoice['total'] ?? 0) as num).toDouble();
      distribution[status] = (distribution[status] ?? 0) + amount;
    }
    return distribution;
  }

  Map<String, double> get _invoicesByTenant {
    final byTenant = <String, double>{};
    for (var invoice in _filteredInvoices) {
      final contract = invoice['contractId'];
      String tenantName = 'Unknown';
      if (contract is Map) {
        final tenant = contract['tenantId'];
        if (tenant is Map) {
          tenantName = tenant['name'] ?? 'Unknown';
        }
      }
      final amount = ((invoice['total'] ?? 0) as num).toDouble();
      byTenant[tenantName] = (byTenant[tenantName] ?? 0) + amount;
    }
    return byTenant;
  }

  List<FlSpot> get _monthlyTrends {
    final trends = <FlSpot>[];
    final invoicesByMonth = <String, double>{};
    
    for (var invoice in _filteredInvoices) {
      final issuedAt = invoice['issuedAt'];
      if (issuedAt != null) {
        try {
          final date = DateTime.parse(issuedAt);
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          final amount = ((invoice['total'] ?? 0) as num).toDouble();
          invoicesByMonth[monthKey] = (invoicesByMonth[monthKey] ?? 0) + amount;
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    final sortedMonths = invoicesByMonth.keys.toList()..sort();
    for (int i = 0; i < sortedMonths.length; i++) {
      trends.add(FlSpot(i.toDouble(), invoicesByMonth[sortedMonths[i]]!));
    }

    return trends;
  }

  List<FlSpot> get _revenueTrends {
    final trends = <FlSpot>[];
    final revenueByMonth = <String, double>{};
    
    for (var invoice in _filteredInvoices) {
      final status = _getInvoiceStatus(invoice);
      if (status == 'paid') {
        final issuedAt = invoice['issuedAt'];
        if (issuedAt != null) {
          try {
            final date = DateTime.parse(issuedAt);
            final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            final amount = ((invoice['total'] ?? 0) as num).toDouble();
            revenueByMonth[monthKey] = (revenueByMonth[monthKey] ?? 0) + amount;
          } catch (e) {
            // Skip invalid dates
          }
        }
      }
    }

    final sortedMonths = revenueByMonth.keys.toList()..sort();
    for (int i = 0; i < sortedMonths.length; i++) {
      trends.add(FlSpot(i.toDouble(), revenueByMonth[sortedMonths[i]]!));
    }

    return trends;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices Management'),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list : Icons.filter_list_outlined),
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'Export Report',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Invoices', icon: Icon(Icons.list)),
            Tab(text: 'Charts', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      backgroundColor: _scaffoldBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by invoice number...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _applyFilters();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (_) => _applyFilters(),
                      ),
                    ),
                    // Filters Section
                    if (_showFilters) _buildFiltersSection(),
                    // Tab View
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildInvoicesTab(),
                          _buildChartsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Status Filter
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                ],
                onChanged: (v) {
                  setState(() => _selectedStatus = v);
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 12),
            // Tenant Filter
            if (_tenants.isNotEmpty)
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedTenantId,
                  decoration: const InputDecoration(
                    labelText: 'Tenant',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Tenants'),
                    ),
                    ..._tenants.map((tenant) {
                      final tenantId = tenant['_id'] ?? '';
                      final tenantName = tenant['name'] ?? 'Unknown';
                      return DropdownMenuItem<String>(
                        value: tenantId.toString(),
                        child: Text(tenantName),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedTenantId = v);
                    _applyFilters();
                  },
                ),
              ),
            if (_tenants.isNotEmpty) const SizedBox(width: 12),
            // Property Filter
            if (_properties.isNotEmpty)
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedPropertyId,
                  decoration: const InputDecoration(
                    labelText: 'Property',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Properties'),
                    ),
                    ..._properties.map((prop) {
                      final propId = prop['_id'] ?? '';
                      final propName = prop['title'] ?? 'Unknown';
                      return DropdownMenuItem<String>(
                        value: propId.toString(),
                        child: Text(propName),
                      );
                    }),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedPropertyId = v);
                    _applyFilters();
                  },
                ),
              ),
            if (_properties.isNotEmpty) const SizedBox(width: 12),
            // Amount Range
            SizedBox(
              width: 120,
              child: TextField(
                controller: _minAmountController,
                decoration: const InputDecoration(
                  labelText: 'Min Amount',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  _minAmount = double.tryParse(v);
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _maxAmountController,
                decoration: const InputDecoration(
                  labelText: 'Max Amount',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  _maxAmount = double.tryParse(v);
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 12),
            // Date Range
            ElevatedButton.icon(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _startDate != null && _endDate != null
                      ? DateTimeRange(start: _startDate!, end: _endDate!)
                      : null,
                );
                if (range != null) {
                  setState(() {
                    _startDate = range.start;
                    _endDate = range.end;
                  });
                  _applyFilters();
                }
              },
              icon: const Icon(Icons.date_range),
              label: Text(_startDate != null && _endDate != null
                  ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                  : 'Date Range'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBeige,
                foregroundColor: _textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            // Clear All
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final stats = _summaryStats;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Summary Cards
          _buildEnhancedSummaryCards(stats),
          const SizedBox(height: 24),
          // Invoice Analytics
          _buildInvoiceAnalytics(),
          const SizedBox(height: 24),
          // Recent Activity
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildEnhancedSummaryCards(Map<String, dynamic> stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return GridView.count(
          crossAxisCount: isWide ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isWide ? 1.5 : 1.3,
          children: [
            _buildSummaryCard(
              'Total Invoices',
              NumberFormat.currency(symbol: '\$').format(stats['totalAmount']),
              Icons.receipt_long,
              Colors.blue,
            ),
            _buildSummaryCard(
              'Paid Invoices',
              NumberFormat.currency(symbol: '\$').format(stats['paidAmount']),
              Icons.check_circle,
              Colors.green,
            ),
            _buildSummaryCard(
              'Pending Invoices',
              NumberFormat.currency(symbol: '\$').format(stats['pendingAmount']),
              Icons.pending,
              Colors.orange,
            ),
            _buildSummaryCard(
              'Overdue Invoices',
              NumberFormat.currency(symbol: '\$').format(stats['overdueAmount']),
              Icons.warning,
              Colors.red,
            ),
            _buildSummaryCard(
              'Average Amount',
              NumberFormat.currency(symbol: '\$').format(stats['averageAmount']),
              Icons.calculate,
              Colors.purple,
            ),
            _buildSummaryCard(
              'Collection Rate',
              '${stats['collectionRate'].toStringAsFixed(1)}%',
              Icons.trending_up,
              Colors.teal,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceAnalytics() {
    final stats = _summaryStats;
    
    // Calculate average payment time
    double avgPaymentTime = 0;
    int validPayments = 0;
    for (var invoice in _filteredInvoices) {
      final status = _getInvoiceStatus(invoice);
      if (status == 'paid') {
        final issuedAt = invoice['issuedAt'];
        final payment = invoice['paymentId'];
        if (issuedAt != null && payment != null) {
          try {
            final issued = DateTime.parse(issuedAt);
            final paymentDate = payment is Map ? payment['date'] : null;
            if (paymentDate != null) {
              final paid = DateTime.parse(paymentDate);
              final days = paid.difference(issued).inDays;
              avgPaymentTime += days;
              validPayments++;
            }
          } catch (e) {
            // Skip invalid dates
          }
        }
      }
    }
    if (validPayments > 0) {
      avgPaymentTime = avgPaymentTime / validPayments;
    }

    // Overdue analysis (calculated in stats)

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsItem(
                    'Collection Rate',
                    '${stats['collectionRate'].toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnalyticsItem(
                    'Avg Payment Time',
                    '${avgPaymentTime.toStringAsFixed(0)} days',
                    Icons.schedule,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Overdue Analysis',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Overdue: ${stats['overdueCount']} invoices',
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              'Overdue Amount: ${NumberFormat.currency(symbol: '\$').format(stats['overdueAmount'])}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recentInvoices = _filteredInvoices.take(5).toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (recentInvoices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No recent activity'),
                ),
              )
            else
              ...recentInvoices.map((invoice) {
                final status = _getInvoiceStatus(invoice);
                final amount = ((invoice['total'] ?? 0) as num).toDouble();
                final invoiceNumber = invoice['invoiceNumber'] ?? 'N/A';
                final issuedAt = invoice['issuedAt'];
                String dateStr = 'N/A';
                if (issuedAt != null) {
                  try {
                    dateStr = DateFormat('MMM dd, yyyy').format(DateTime.parse(issuedAt));
                  } catch (e) {
                    // Keep N/A
                  }
                }
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    child: Icon(
                      Icons.receipt,
                      color: _getStatusColor(status),
                    ),
                  ),
                  title: Text(
                    invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${_getStatusText(status)} • $dateStr'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        NumberFormat.currency(symbol: '\$').format(amount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(_getStatusText(status)),
                        backgroundColor: _getStatusColor(status).withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _showInvoiceDetailsDialog(invoice),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesTab() {
    if (_filteredInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No invoices found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredInvoices.length,
        itemBuilder: (ctx, idx) {
          final invoice = _filteredInvoices[idx];
          return _buildInvoiceCard(invoice);
        },
      ),
    );
  }

  Widget _buildInvoiceCard(dynamic invoice) {
    final invoiceNumber = invoice['invoiceNumber'] ?? 'N/A';
    final total = ((invoice['total'] ?? 0) as num).toDouble();
    final issuedAt = invoice['issuedAt'];
    final status = _getInvoiceStatus(invoice);
    
    final contract = invoice['contractId'];
    String tenantName = 'N/A';
    String propertyName = 'N/A';
    
    if (contract is Map) {
      final tenant = contract['tenantId'];
      final property = contract['propertyId'];
      
      if (tenant is Map) {
        tenantName = tenant['name'] ?? 'N/A';
      }
      
      if (property is Map) {
        propertyName = property['title'] ?? 'N/A';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showInvoiceDetailsDialog(invoice),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    label: Text(_getStatusText(status)),
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    NumberFormat.currency(symbol: '\$').format(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: _accentGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Invoice Number', invoiceNumber),
              _buildInfoRow('Tenant', tenantName),
              _buildInfoRow('Property', propertyName),
              if (issuedAt != null)
                _buildInfoRow(
                  'Issued Date',
                  DateFormat('MMM dd, yyyy').format(DateTime.parse(issuedAt)),
                ),
              if (invoice['dueDate'] != null)
                _buildInfoRow(
                  'Due Date',
                  DateFormat('MMM dd, yyyy').format(DateTime.parse(invoice['dueDate'])),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (invoice['pdfUrl'] != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _viewInvoicePDF(invoice),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('View PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  if (invoice['pdfUrl'] != null) const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendInvoiceEmail(invoice),
                      icon: const Icon(Icons.email),
                      label: const Text('Send Email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (_currentUserRole == 'landlord' && status != 'paid') ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _updateInvoiceStatus(invoice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBeige,
                    foregroundColor: _textPrimary,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                  child: const Text('Update Status'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsTab() {
    if (_filteredInvoices.isEmpty) {
      return const Center(
        child: Text('No data available for charts'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pie Chart - Status Distribution
          _buildStatusPieChart(),
          const SizedBox(height: 24),
          // Bar Chart - Invoices by Tenant
          _buildInvoicesByTenantBarChart(),
          const SizedBox(height: 24),
          // Line Chart - Monthly Trends
          _buildMonthlyTrendsLineChart(),
          const SizedBox(height: 24),
          // Area Chart - Revenue Trends
          _buildRevenueAreaChart(),
        ],
      ),
    );
  }

  Widget _buildStatusPieChart() {
    final distribution = _statusDistribution;
    if (distribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = [
      Colors.green,
      Colors.orange,
      Colors.red,
    ];
    int colorIndex = 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoices by Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: distribution.entries.map((entry) {
                    final amount = entry.value;
                    final total = distribution.values.reduce((a, b) => a + b);
                    final percentage = (amount / total * 100);
                    
                    final color = colors[colorIndex % colors.length];
                    colorIndex++;
                    
                    return PieChartSectionData(
                      value: amount,
                      title: '${percentage.toStringAsFixed(1)}%',
                      color: color,
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: distribution.entries.map((entry) {
                final status = entry.key;
                final amount = entry.value;
                final color = _getStatusColor(status);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_getStatusText(status)}: ${NumberFormat.currency(symbol: '\$').format(amount)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesByTenantBarChart() {
    final byTenant = _invoicesByTenant;
    if (byTenant.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEntries = byTenant.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(10).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoices by Tenant',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: topEntries.isEmpty ? 1 : topEntries.first.value * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.grey[800]!,
                      tooltipRoundedRadius: 8,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < topEntries.length) {
                            final name = topEntries[index].key;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                name.length > 10 ? '${name.substring(0, 10)}...' : name,
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
                          return Text(
                            '\$${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
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
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  barGroups: topEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final invoice = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: invoice.value,
                          color: _accentGreen,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendsLineChart() {
    final trends = _monthlyTrends;
    if (trends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Invoice Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 50,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < trends.length) {
                            return Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: trends,
                      isCurved: true,
                      color: _accentGreen,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueAreaChart() {
    final trends = _revenueTrends;
    if (trends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue from Invoices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 50,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < trends.length) {
                            return Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: trends,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Invoice Details Dialog
  void _showInvoiceDetailsDialog(dynamic invoice) {
    final contract = invoice['contractId'];
    final payment = invoice['paymentId'];
    
    // Get related payments
    final relatedPayments = _allPayments.where((pay) {
      final payContractId = pay['contractId'];
      if (payContractId is Map) {
        return payContractId['_id']?.toString() == contract?['_id']?.toString();
      } else if (payContractId is String) {
        return payContractId == contract?['_id']?.toString();
      }
      return false;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Invoice Details',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                // Invoice Info
                _buildDetailRow('Invoice Number', invoice['invoiceNumber'] ?? 'N/A'),
                _buildDetailRow('Status', _getStatusText(_getInvoiceStatus(invoice))),
                _buildDetailRow('Total Amount', NumberFormat.currency(symbol: '\$').format(invoice['total'] ?? 0)),
                if (invoice['issuedAt'] != null)
                  _buildDetailRow('Issued Date', DateFormat('MMM dd, yyyy').format(DateTime.parse(invoice['issuedAt']))),
                if (invoice['dueDate'] != null)
                  _buildDetailRow('Due Date', DateFormat('MMM dd, yyyy').format(DateTime.parse(invoice['dueDate']))),
                const SizedBox(height: 16),
                // Contract Info
                if (contract is Map) ...[
                  const Text(
                    'Contract Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (contract['propertyId'] is Map)
                    _buildDetailRow('Property', contract['propertyId']['title'] ?? 'N/A'),
                  if (contract['tenantId'] is Map)
                    _buildDetailRow('Tenant', contract['tenantId']['name'] ?? 'N/A'),
                  const SizedBox(height: 16),
                ],
                // Payment History
                const Text(
                  'Payment History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (payment != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.payment, color: Colors.green),
                      title: Text('Payment: \$${payment is Map ? payment['amount'] ?? 0 : 0}'),
                      subtitle: Text(payment is Map ? (payment['date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(payment['date'])) : 'N/A') : 'N/A'),
                      trailing: Chip(
                        label: Text(payment is Map ? (payment['status'] ?? 'N/A') : 'N/A'),
                        backgroundColor: Colors.green.withOpacity(0.2),
                      ),
                    ),
                  )
                else if (relatedPayments.isNotEmpty)
                  ...relatedPayments.map((pay) {
                    final amount = ((pay['amount'] ?? 0) as num).toDouble();
                    final date = pay['date'];
                    String dateStr = 'N/A';
                    if (date != null) {
                      try {
                        dateStr = DateFormat('MMM dd, yyyy').format(DateTime.parse(date));
                      } catch (e) {
                        // Keep N/A
                      }
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.payment, color: Colors.green),
                        title: Text('Payment: ${NumberFormat.currency(symbol: '\$').format(amount)}'),
                        subtitle: Text(dateStr),
                        trailing: Chip(
                          label: Text(pay['status'] ?? 'N/A'),
                          backgroundColor: Colors.green.withOpacity(0.2),
                        ),
                      ),
                    );
                  })
                else
                  const Text('No payment history found', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                // Actions
                Row(
                  children: [
                    if (invoice['pdfUrl'] != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _viewInvoicePDF(invoice);
                          },
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('View PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    if (invoice['pdfUrl'] != null) const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _sendInvoiceEmail(invoice);
                        },
                        icon: const Icon(Icons.email),
                        label: const Text('Send Email'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _viewInvoicePDF(dynamic invoice) {
    final pdfUrl = invoice['pdfUrl'];
    if (pdfUrl != null && pdfUrl.toString().isNotEmpty) {
      // Open PDF URL
      launchUrl(Uri.parse(pdfUrl.toString()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF not available')),
      );
    }
  }

  void _sendInvoiceEmail(dynamic invoice) {
    final contract = invoice['contractId'];
    String? email;
    if (contract is Map) {
      final tenant = contract['tenantId'];
      if (tenant is Map) {
        email = tenant['email'];
      }
    }
    
    if (email != null && email.isNotEmpty) {
      final uri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=Invoice ${invoice['invoiceNumber'] ?? ''}',
      );
      launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not available')),
      );
    }
  }

  void _updateInvoiceStatus(dynamic invoice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Invoice Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Paid'),
              leading: Radio<String>(
                value: 'paid',
                groupValue: _getInvoiceStatus(invoice),
                onChanged: (value) {
                  Navigator.pop(ctx);
                  _updateStatus(invoice, 'paid');
                },
              ),
            ),
            ListTile(
              title: const Text('Pending'),
              leading: Radio<String>(
                value: 'pending',
                groupValue: _getInvoiceStatus(invoice),
                onChanged: (value) {
                  Navigator.pop(ctx);
                  _updateStatus(invoice, 'pending');
                },
              ),
            ),
            ListTile(
              title: const Text('Overdue'),
              leading: Radio<String>(
                value: 'overdue',
                groupValue: _getInvoiceStatus(invoice),
                onChanged: (value) {
                  Navigator.pop(ctx);
                  _updateStatus(invoice, 'overdue');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(dynamic invoice, String status) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Update invoice status
    final (ok, message) = await ApiService.updateInvoice(
      invoice['_id'],
      {'status': status},
    );

    if (mounted) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? _accentGreen : Colors.red,
        ),
      );
      if (ok) {
        _fetchAllData();
      }
    }
  }

  // Export Report
  Future<void> _exportReport() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final pdf = pw.Document();
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
      final userName = await SharedPreferences.getInstance().then((prefs) => prefs.getString('userName') ?? 'User');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            final stats = _summaryStats;
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'SHAQATI - Invoices Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                      ),
                    ),
                    pw.Text(
                      dateFormat.format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Complete Invoices Report',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'User: $userName',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),
              // Summary
              pw.Header(level: 1, text: 'Summary Overview'),
              pw.SizedBox(height: 10),
              _buildPdfSummaryTable(stats),
              pw.SizedBox(height: 30),
              // All Invoices
              pw.Header(level: 1, text: 'All Invoices (${_filteredInvoices.length})'),
              pw.SizedBox(height: 10),
              _buildPdfInvoicesTable(),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = 'invoices_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (mounted) {
        Navigator.pop(context);
      }

      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      } else {
        if (Platform.isAndroid) {
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Permission denied')),
              );
            }
            return;
          }

          Directory? directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }

          final file = File('${directory!.path}/$fileName');
          await file.writeAsBytes(bytes);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Report saved: $fileName')),
            );
          }
        } else if (Platform.isIOS) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          await Printing.sharePdf(bytes: bytes, filename: fileName);
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytes);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Report saved: $fileName')),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report exported successfully'),
            backgroundColor: _accentGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  pw.Widget _buildPdfSummaryTable(Map<String, dynamic> stats) {
    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        _buildPdfTableRow(['Metric', 'Value'], isHeader: true),
        _buildPdfTableRow(['Total Amount', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(stats['totalAmount'])]),
        _buildPdfTableRow(['Paid Amount', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(stats['paidAmount'])]),
        _buildPdfTableRow(['Pending Amount', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(stats['pendingAmount'])]),
        _buildPdfTableRow(['Overdue Amount', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(stats['overdueAmount'])]),
        _buildPdfTableRow(['Average Amount', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(stats['averageAmount'])]),
        _buildPdfTableRow(['Collection Rate', '${stats['collectionRate'].toStringAsFixed(1)}%']),
      ],
    );
  }

  pw.Widget _buildPdfInvoicesTable() {
    if (_filteredInvoices.isEmpty) {
      return pw.Text('No invoices found', style: pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        _buildPdfTableRow(['Invoice Number', 'Tenant', 'Amount', 'Status'], isHeader: true),
        ..._filteredInvoices.take(50).map((invoice) {
          final contract = invoice['contractId'];
          String tenant = 'N/A';
          
          if (contract is Map) {
            if (contract['tenantId'] is Map) {
              tenant = contract['tenantId']['name'] ?? 'N/A';
            }
          }
          
          return _buildPdfTableRow([
            invoice['invoiceNumber'] ?? 'N/A',
            tenant,
            NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(invoice['total'] ?? 0),
            _getStatusText(_getInvoiceStatus(invoice)),
          ]);
        }),
      ],
    );
  }

  pw.TableRow _buildPdfTableRow(List<String> cells, {bool isHeader = false}) {
    return pw.TableRow(
      decoration: isHeader
          ? pw.BoxDecoration(color: PdfColors.grey300)
          : null,
      children: cells.map((cell) => pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(
          cell,
          style: pw.TextStyle(
            fontSize: isHeader ? 10 : 9,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      )).toList(),
    );
  }
}
