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

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

/// Enhanced Deposits Management Screen for Landlord
/// 
/// Features:
/// - Charts Tab with Pie, Bar, Line, and Donut charts
/// - Enhanced Summary Cards
/// - Advanced Filters
/// - Deposit Details Dialog with expenses integration
/// - Bulk Operations
/// - Deposit Analytics
/// - Enhanced Refund Workflow
/// - Integration with Expenses
class DepositsManagementScreen extends StatefulWidget {
  final String? contractId;

  const DepositsManagementScreen({
    super.key,
    this.contractId,
  });

  @override
  State<DepositsManagementScreen> createState() =>
      _DepositsManagementScreenState();
}

class _DepositsManagementScreenState extends State<DepositsManagementScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _deposits = [];
  List<dynamic> _filteredDeposits = [];
  List<dynamic> _allExpenses = [];
  String? _currentUserRole;
  String? _landlordId;

  // Tab Controller
  late TabController _tabController;

  // Filters
  String? _selectedStatus;
  String? _selectedPropertyId;
  String? _selectedTenantId;
  double? _minAmount;
  double? _maxAmount;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();

  // Properties and Tenants for filters
  List<dynamic> _properties = [];
  List<dynamic> _tenants = [];

  // Bulk selection
  Set<String> _selectedDepositIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserRole();
    if (widget.contractId != null) {
      _fetchDepositByContract();
    } else {
      _fetchAllData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserRole = prefs.getString('role');
      _landlordId = prefs.getString('userId');
    });
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    
    // Fetch deposits
    final (okDeposits, depositsData) = await ApiService.getAllDeposits();
    if (okDeposits && depositsData is List) {
      _deposits = depositsData;
      _filteredDeposits = depositsData;
    }

    // Fetch expenses (for integration)
    if (_landlordId != null) {
      final (okExpenses, expensesData) = await ApiService.getAllExpenses();
      if (okExpenses && expensesData is Map && expensesData['expenses'] is List) {
        _allExpenses = expensesData['expenses'];
      }
    }

    // Fetch properties and contracts for filters
    if (_landlordId != null) {
      final (okProps, propsData) = await ApiService.getPropertiesByOwner(_landlordId!);
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

  Future<void> _fetchDepositByContract() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getDepositByContract(widget.contractId!);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _deposits = data != null ? [data] : [];
        _filteredDeposits = _deposits;
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(_deposits);

    // Status filter
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      filtered = filtered.where((d) => (d['status'] ?? 'held') == _selectedStatus).toList();
    }

    // Property filter
    if (_selectedPropertyId != null && _selectedPropertyId!.isNotEmpty) {
      filtered = filtered.where((d) {
        final contract = d['contractId'];
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

    // Tenant filter
    if (_selectedTenantId != null && _selectedTenantId!.isNotEmpty) {
      filtered = filtered.where((d) {
        final contract = d['contractId'];
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

    // Amount range filter
    if (_minAmount != null) {
      filtered = filtered.where((d) => ((d['amount'] ?? 0) as num).toDouble() >= _minAmount!).toList();
    }
    if (_maxAmount != null) {
      filtered = filtered.where((d) => ((d['amount'] ?? 0) as num).toDouble() <= _maxAmount!).toList();
    }

    // Date range filter
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((d) {
        final createdAt = d['createdAt'];
        if (createdAt == null) return false;
        try {
          final date = DateTime.parse(createdAt);
          if (_startDate != null && date.isBefore(_startDate!)) return false;
          if (_endDate != null && date.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
          return true;
        } catch (e) {
          return false;
        }
      }).toList();
    }

    setState(() {
      _filteredDeposits = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedPropertyId = null;
      _selectedTenantId = null;
      _minAmount = null;
      _maxAmount = null;
      _startDate = null;
      _endDate = null;
      _minAmountController.clear();
      _maxAmountController.clear();
    });
    _applyFilters();
  }

  // Enhanced Summary Calculations
  Map<String, dynamic> get _summaryStats {
    double totalHeld = 0;
    double totalRefunded = 0;
    double pendingRefunds = 0;
    double totalAmount = 0;
    int heldCount = 0;
    int refundedCount = 0;
    int partiallyRefundedCount = 0;

    for (var deposit in _filteredDeposits) {
      final amount = ((deposit['amount'] ?? 0) as num).toDouble();
      final refundedAmount = ((deposit['refundedAmount'] ?? 0) as num).toDouble();
      final totalDeducted = ((deposit['totalDeducted'] ?? 0) as num).toDouble();
      final status = deposit['status'] ?? 'held';
      final availableAmount = amount - totalDeducted - refundedAmount;

      totalAmount += amount;
      totalRefunded += refundedAmount;

      if (status == 'held') {
        heldCount++;
        totalHeld += availableAmount;
      } else if (status == 'refunded') {
        refundedCount++;
      } else if (status == 'partially_refunded') {
        partiallyRefundedCount++;
        pendingRefunds += availableAmount;
      } else {
        pendingRefunds += availableAmount;
      }
    }

    final avgDeposit = _filteredDeposits.isEmpty ? 0.0 : totalAmount / _filteredDeposits.length;

    return {
      'totalHeld': totalHeld,
      'totalRefunded': totalRefunded,
      'pendingRefunds': pendingRefunds,
      'averageAmount': avgDeposit,
      'heldCount': heldCount,
      'refundedCount': refundedCount,
      'partiallyRefundedCount': partiallyRefundedCount,
      'totalAmount': totalAmount,
    };
  }

  // Chart Data
  Map<String, double> get _statusDistribution {
    final distribution = <String, double>{};
    for (var deposit in _filteredDeposits) {
      final status = deposit['status'] ?? 'held';
      final amount = ((deposit['amount'] ?? 0) as num).toDouble();
      distribution[status] = (distribution[status] ?? 0) + amount;
    }
    return distribution;
  }

  Map<String, double> get _depositsByProperty {
    final byProperty = <String, double>{};
    for (var deposit in _filteredDeposits) {
      final contract = deposit['contractId'];
      if (contract is Map) {
        final property = contract['propertyId'];
        String propName = 'Unknown';
        if (property is Map) {
          propName = property['title'] ?? property['address'] ?? 'Unknown';
        }
        final amount = ((deposit['amount'] ?? 0) as num).toDouble();
        byProperty[propName] = (byProperty[propName] ?? 0) + amount;
      }
    }
    return byProperty;
  }

  List<FlSpot> get _depositTrends {
    final trends = <FlSpot>[];
    final depositsByMonth = <String, double>{};
    
    for (var deposit in _filteredDeposits) {
      final createdAt = deposit['createdAt'];
      if (createdAt != null) {
        try {
          final date = DateTime.parse(createdAt);
          final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          final amount = ((deposit['amount'] ?? 0) as num).toDouble();
          depositsByMonth[monthKey] = (depositsByMonth[monthKey] ?? 0) + amount;
        } catch (e) {
          // Skip invalid dates
        }
      }
    }

    final sortedMonths = depositsByMonth.keys.toList()..sort();
    for (int i = 0; i < sortedMonths.length; i++) {
      trends.add(FlSpot(i.toDouble(), depositsByMonth[sortedMonths[i]]!));
    }

    return trends;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'held':
        return Colors.orange;
      case 'partially_refunded':
        return Colors.blue;
      case 'refunded':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'held':
        return 'Held';
      case 'partially_refunded':
        return 'Partially Refunded';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  bool get _canEdit => _currentUserRole == 'landlord';
  bool get _canCreate => _currentUserRole == 'tenant';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposits Management'),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
        actions: [
          if (_canEdit) ...[
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
            if (_selectedDepositIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.account_balance_wallet),
                onPressed: _bulkRefund,
                tooltip: 'Bulk Refund',
              ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Deposits', icon: Icon(Icons.list)),
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
                    // Filters Section
                    if (_showFilters) _buildFiltersSection(),
                    // Tab View
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildDepositsTab(),
                          _buildChartsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDepositDialog(),
              backgroundColor: _primaryBeige,
              foregroundColor: _textPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add Deposit'),
            )
          : null,
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
                  DropdownMenuItem(value: 'held', child: Text('Held')),
                  DropdownMenuItem(value: 'partially_refunded', child: Text('Partially Refunded')),
                  DropdownMenuItem(value: 'refunded', child: Text('Refunded')),
                ],
                onChanged: (v) {
                  setState(() => _selectedStatus = v);
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 12),
            // Property Filter
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
            const SizedBox(width: 12),
            // Tenant Filter
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
            const SizedBox(width: 12),
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
          // Deposit Analytics
          _buildDepositAnalytics(),
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
              'Total Deposits Held',
              NumberFormat.currency(symbol: '\$').format(stats['totalHeld']),
              Icons.lock,
              Colors.orange,
            ),
            _buildSummaryCard(
              'Total Refunded',
              NumberFormat.currency(symbol: '\$').format(stats['totalRefunded']),
              Icons.check_circle,
              Colors.green,
            ),
            _buildSummaryCard(
              'Pending Refunds',
              NumberFormat.currency(symbol: '\$').format(stats['pendingRefunds']),
              Icons.pending,
              Colors.blue,
            ),
            _buildSummaryCard(
              'Average Deposit',
              NumberFormat.currency(symbol: '\$').format(stats['averageAmount']),
              Icons.calculate,
              Colors.purple,
            ),
            _buildSummaryCard(
              'Held Count',
              '${stats['heldCount']}',
              Icons.inventory,
              Colors.orange,
            ),
            _buildSummaryCard(
              'Refunded Count',
              '${stats['refundedCount']}',
              Icons.done_all,
              Colors.green,
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

  Widget _buildDepositAnalytics() {
    final stats = _summaryStats;
    final totalDeposits = _filteredDeposits.length;
    final fullRefundRate = totalDeposits > 0
        ? (stats['refundedCount'] / totalDeposits * 100)
        : 0.0;

    // Calculate average hold duration
    double avgHoldDuration = 0;
    int validDurations = 0;
    for (var deposit in _filteredDeposits) {
      final createdAt = deposit['createdAt'];
      final refundedAt = deposit['refundedAt'];
      if (createdAt != null && refundedAt != null) {
        try {
          final created = DateTime.parse(createdAt);
          final refunded = DateTime.parse(refundedAt);
          final duration = refunded.difference(created).inDays;
          avgHoldDuration += duration;
          validDurations++;
        } catch (e) {
          // Skip invalid dates
        }
      }
    }
    if (validDurations > 0) {
      avgHoldDuration = avgHoldDuration / validDurations;
    }

    // Top deposits
    final sortedDeposits = List.from(_filteredDeposits);
    sortedDeposits.sort((a, b) {
      final amountA = ((a['amount'] ?? 0) as num).toDouble();
      final amountB = ((b['amount'] ?? 0) as num).toDouble();
      return amountB.compareTo(amountA);
    });
    final topDeposits = sortedDeposits.take(5).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deposit Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnalyticsItem(
                    'Full Refund Rate',
                    '${fullRefundRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAnalyticsItem(
                    'Avg Hold Duration',
                    '${avgHoldDuration.toStringAsFixed(0)} days',
                    Icons.schedule,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Top Deposits',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...topDeposits.map((deposit) {
              final amount = ((deposit['amount'] ?? 0) as num).toDouble();
              final contract = deposit['contractId'];
              String depositInfo = 'Deposit';
              if (contract is Map) {
                final property = contract['propertyId'];
                if (property is Map) {
                  depositInfo = property['title'] ?? 'Unknown';
                }
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(depositInfo)),
                    Text(
                      NumberFormat.currency(symbol: '\$').format(amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
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
    final recentDeposits = _filteredDeposits.take(5).toList();
    
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
            if (recentDeposits.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No recent activity'),
                ),
              )
            else
              ...recentDeposits.map((deposit) {
                final status = deposit['status'] ?? 'held';
                final amount = ((deposit['amount'] ?? 0) as num).toDouble();
                final createdAt = deposit['createdAt'];
                String dateStr = 'N/A';
                if (createdAt != null) {
                  try {
                    dateStr = DateFormat('MMM dd, yyyy').format(DateTime.parse(createdAt));
                  } catch (e) {
                    // Keep N/A
                  }
                }
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    child: Icon(
                      Icons.security,
                      color: _getStatusColor(status),
                    ),
                  ),
                  title: Text(
                    NumberFormat.currency(symbol: '\$').format(amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${_getStatusText(status)} • $dateStr'),
                  trailing: Chip(
                    label: Text(_getStatusText(status)),
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 10,
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositsTab() {
    if (_filteredDeposits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No deposits found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.contractId != null ? _fetchDepositByContract : _fetchAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredDeposits.length,
        itemBuilder: (ctx, idx) {
          final deposit = _filteredDeposits[idx];
          return _buildDepositCard(deposit);
        },
      ),
    );
  }

  Widget _buildDepositCard(dynamic deposit) {
    final status = deposit['status'] ?? 'held';
    final amount = ((deposit['amount'] ?? 0) as num).toDouble();
    final totalDeducted = ((deposit['totalDeducted'] ?? 0) as num).toDouble();
    final refundedAmount = ((deposit['refundedAmount'] ?? 0) as num).toDouble();
    final availableAmount = amount - totalDeducted - refundedAmount;
    final depositId = deposit['_id']?.toString() ?? '';

    final contract = deposit['contractId'];
    String propertyInfo = 'N/A';
    String tenantInfo = 'N/A';
    
    if (contract is Map) {
      final property = contract['propertyId'];
      final tenant = contract['tenantId'];
      
      if (property is Map) {
        propertyInfo = property['title'] ?? property['address'] ?? 'N/A';
      }
      
      if (tenant is Map) {
        tenantInfo = tenant['name'] ?? 'N/A';
      }
    }

    final isSelected = _selectedDepositIds.contains(depositId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isSelected ? _accentGreen.withOpacity(0.1) : null,
      child: InkWell(
        onTap: () => _showDepositDetailsDialog(deposit),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_canEdit)
                    Checkbox(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedDepositIds.add(depositId);
                          } else {
                            _selectedDepositIds.remove(depositId);
                          }
                        });
                      },
                    ),
                  Chip(
                    label: Text(_getStatusText(status)),
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    NumberFormat.currency(symbol: '\$').format(amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: _accentGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Property', propertyInfo),
              _buildInfoRow('Tenant', tenantInfo),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildAmountInfo('Deducted', totalDeducted, Colors.red),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildAmountInfo('Refunded', refundedAmount, Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildAmountInfo('Available', availableAmount, Colors.green),
              if (_canEdit && status != 'refunded' && availableAmount > 0) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showEnhancedRefundDialog(deposit),
                  icon: const Icon(Icons.account_balance_wallet),
                  label: const Text('Refund'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                  ),
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

  Widget _buildAmountInfo(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            NumberFormat.currency(symbol: '\$').format(amount),
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsTab() {
    if (_filteredDeposits.isEmpty) {
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
          // Bar Chart - Deposits by Property/Tenant
          _buildDepositsBarChart(),
          const SizedBox(height: 24),
          // Line Chart - Deposit Trends
          _buildDepositTrendsLineChart(),
          const SizedBox(height: 24),
          // Donut Chart - Refunded vs Held
          _buildRefundedVsHeldDonutChart(),
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
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.grey,
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
              'Deposits by Status',
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

  Widget _buildDepositsBarChart() {
    final byProperty = _depositsByProperty;
    if (byProperty.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEntries = byProperty.entries.toList()
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
              'Deposits by Property',
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
                    final deposit = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: deposit.value,
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

  Widget _buildDepositTrendsLineChart() {
    final trends = _depositTrends;
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
              'Deposit Trends Over Time',
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
                      belowBarData: BarAreaData(show: true, color: _accentGreen.withOpacity(0.2)),
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

  Widget _buildRefundedVsHeldDonutChart() {
    final stats = _summaryStats;
    final totalRefunded = stats['totalRefunded'] as double;
    final totalHeld = stats['totalHeld'] as double;
    final total = totalRefunded + totalHeld;
    
    if (total == 0) {
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
              'Refunded vs Held',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: totalRefunded,
                      title: '${(totalRefunded / total * 100).toStringAsFixed(1)}%',
                      color: Colors.green,
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: totalHeld,
                      title: '${(totalHeld / total * 100).toStringAsFixed(1)}%',
                      color: Colors.orange,
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 80,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem('Refunded', totalRefunded, Colors.green),
                _buildLegendItem('Held', totalHeld, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, double value, Color color) {
    return Row(
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              NumberFormat.currency(symbol: '\$').format(value),
              style: TextStyle(fontSize: 14, color: color),
            ),
          ],
        ),
      ],
    );
  }

  // Enhanced Deposit Details Dialog
  void _showDepositDetailsDialog(dynamic deposit) {
    final contract = deposit['contractId'];
    String? contractId;
    
    if (contract is Map) {
      contractId = contract['_id']?.toString();
    } else if (contract is String) {
      contractId = contract;
    }

    // Get related expenses
    final relatedExpenses = _allExpenses.where((expense) {
      final expContractId = expense['contractId'];
      if (expContractId is Map) {
        return expContractId['_id']?.toString() == contractId;
      } else if (expContractId is String) {
        return expContractId == contractId;
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
                      'Deposit Details',
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
                // Deposit Info
                _buildDetailRow('Status', _getStatusText(deposit['status'] ?? 'held')),
                _buildDetailRow('Amount', NumberFormat.currency(symbol: '\$').format(deposit['amount'] ?? 0)),
                _buildDetailRow('Total Deducted', NumberFormat.currency(symbol: '\$').format(deposit['totalDeducted'] ?? 0)),
                _buildDetailRow('Refunded Amount', NumberFormat.currency(symbol: '\$').format(deposit['refundedAmount'] ?? 0)),
                _buildDetailRow('Available', NumberFormat.currency(symbol: '\$').format(
                  ((deposit['amount'] ?? 0) as num).toDouble() - 
                  ((deposit['totalDeducted'] ?? 0) as num).toDouble() - 
                  ((deposit['refundedAmount'] ?? 0) as num).toDouble()
                )),
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
                // Related Expenses
                const Text(
                  'Related Expenses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (relatedExpenses.isEmpty)
                  const Text('No related expenses found', style: TextStyle(color: Colors.grey))
                else
                  ...relatedExpenses.map((expense) {
                    final amount = ((expense['amount'] ?? 0) as num).toDouble();
                    final type = expense['type'] ?? 'other';
                    final date = expense['date'];
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
                        leading: const Icon(Icons.receipt, color: Colors.red),
                        title: Text(type.toUpperCase()),
                        subtitle: Text(dateStr),
                        trailing: Text(
                          NumberFormat.currency(symbol: '\$').format(amount),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                // Timeline
                const Text(
                  'Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildTimelineItem('Created', deposit['createdAt']),
                if (deposit['refundedAt'] != null)
                  _buildTimelineItem('Refunded', deposit['refundedAt']),
                if (deposit['updatedAt'] != null)
                  _buildTimelineItem('Last Updated', deposit['updatedAt']),
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

  Widget _buildTimelineItem(String label, String? dateStr) {
    if (dateStr == null) return const SizedBox.shrink();
    String formatted = 'N/A';
    try {
      formatted = DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(dateStr));
    } catch (e) {
      // Keep N/A
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: _accentGreen),
          const SizedBox(width: 8),
          Text('$label: $formatted', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // Enhanced Refund Dialog
  void _showEnhancedRefundDialog(dynamic deposit) {
    final amountController = TextEditingController();
    final availableAmount = ((deposit['amount'] ?? 0) as num).toDouble() -
        ((deposit['totalDeducted'] ?? 0) as num).toDouble() -
        ((deposit['refundedAmount'] ?? 0) as num).toDouble();
    
    amountController.text = availableAmount.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund Deposit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Deposit: \$${deposit['amount']}'),
              Text('Deducted: \$${deposit['totalDeducted'] ?? 0}'),
              Text('Already Refunded: \$${deposit['refundedAmount'] ?? 0}'),
              const Divider(),
              Text(
                'Available for Refund: \$${availableAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Refund Amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        amountController.text = availableAmount.toStringAsFixed(2);
                      },
                      child: const Text('Full Refund'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        amountController.text = (availableAmount / 2).toStringAsFixed(2);
                      },
                      child: const Text('Half Refund'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final refundAmount = double.tryParse(amountController.text);
              if (refundAmount == null || refundAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }

              if (refundAmount > availableAmount) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refund amount cannot exceed available amount')),
                );
                return;
              }

              Navigator.of(ctx).pop();
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingCtx) => const Center(child: CircularProgressIndicator()),
              );

              final (ok, message) = await ApiService.updateDeposit(
                deposit['_id'],
                {'refundAmount': refundAmount},
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
                  if (widget.contractId != null) {
                    _fetchDepositByContract();
                  } else {
                    _fetchAllData();
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Refund'),
          ),
        ],
      ),
    );
  }

  // Bulk Refund
  void _bulkRefund() {
    if (_selectedDepositIds.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Refund'),
        content: Text('Refund ${_selectedDepositIds.length} selected deposit(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Implement bulk refund logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bulk refund feature coming soon')),
              );
            },
            child: const Text('Refund All'),
          ),
        ],
      ),
    );
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
                      'SHAQATI - Deposits Report',
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
                'Complete Deposits Report',
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
              // All Deposits
              pw.Header(level: 1, text: 'All Deposits (${_filteredDeposits.length})'),
              pw.SizedBox(height: 10),
              _buildPdfDepositsTable(),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = 'deposits_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

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
        _buildPdfTableRow(['Total Held', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(stats['totalHeld'])]),
        _buildPdfTableRow(['Total Refunded', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(stats['totalRefunded'])]),
        _buildPdfTableRow(['Pending Refunds', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(stats['pendingRefunds'])]),
        _buildPdfTableRow(['Average Amount', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(stats['averageAmount'])]),
        _buildPdfTableRow(['Held Count', '${stats['heldCount']}']),
        _buildPdfTableRow(['Refunded Count', '${stats['refundedCount']}']),
      ],
    );
  }

  pw.Widget _buildPdfDepositsTable() {
    if (_filteredDeposits.isEmpty) {
      return pw.Text('No deposits found', style: pw.TextStyle(color: PdfColors.grey));
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
        _buildPdfTableRow(['Property', 'Tenant', 'Amount', 'Status'], isHeader: true),
        ..._filteredDeposits.take(50).map((deposit) {
          final contract = deposit['contractId'];
          String property = 'N/A';
          String tenant = 'N/A';
          
          if (contract is Map) {
            if (contract['propertyId'] is Map) {
              property = contract['propertyId']['title'] ?? 'N/A';
            }
            if (contract['tenantId'] is Map) {
              tenant = contract['tenantId']['name'] ?? 'N/A';
            }
          }
          
          return _buildPdfTableRow([
            property,
            tenant,
            NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(deposit['amount'] ?? 0),
            _getStatusText(deposit['status'] ?? 'held'),
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

  // Create Deposit Dialog (kept from original)
  void _showCreateDepositDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return;

    final (ok, contractsData) = await ApiService.getUserContracts(userId);
    if (!ok || contractsData is! List<dynamic>) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load contracts')),
      );
      return;
    }

    final activeContracts = contractsData.where((c) {
      final status = c['status']?.toString().toLowerCase();
      return status == 'active';
    }).toList();

    if (activeContracts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No active contracts found. Deposits can only be added for active contracts.')),
      );
      return;
    }

    String? selectedContractId;
    Map<String, dynamic>? selectedContract;
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
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
                          'Add New Deposit',
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
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Contract *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      items: activeContracts.map((contract) {
                        final contractId = contract['_id'].toString();
                        final property = contract['propertyId'];
                        String contractInfo =
                            'Contract #${contractId.substring(0, 8)}';

                        if (property is Map && property['title'] != null) {
                          contractInfo =
                              '${property['title']} - \$${contract['rentAmount'] ?? 0}';
                        }

                        return DropdownMenuItem(
                          value: contractId,
                          child: Text(contractInfo),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        selectedContractId = value;
                        final contract = activeContracts.firstWhere(
                          (c) => c['_id'].toString() == value,
                        );
                        selectedContract = contract;
                        final suggestedAmount = contract['depositAmount'] ??
                            contract['rentAmount'] ??
                            0.0;
                        if (suggestedAmount > 0) {
                          amountController.text =
                              suggestedAmount.toStringAsFixed(2);
                        }
                        setDialogState(() {});
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a contract';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedContract != null) ...[
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
                                selectedContract!['depositAmount'] != null
                                    ? 'Suggested amount from contract: \$${selectedContract!['depositAmount']}'
                                    : 'Suggested amount (1 month rent): \$${selectedContract!['rentAmount'] ?? 0}',
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
                        if (selectedContractId == null) return;

                        final amount = double.tryParse(amountController.text);
                        if (amount == null || amount <= 0) return;

                        Navigator.of(ctx).pop();

                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (loadingCtx) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );

                        final (ok, message) = await ApiService.addDeposit({
                          'contractId': selectedContractId,
                          'amount': amount,
                        });

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: ok ? _accentGreen : Colors.red,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          if (ok) {
                            if (widget.contractId != null) {
                              _fetchDepositByContract();
                            } else {
                              _fetchAllData();
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Create Deposit',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
