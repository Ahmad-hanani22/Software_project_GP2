import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

/// Enhanced Expenses Management Screen
///
/// Features:
/// - Multiple statistical summary cards
/// - Charts and graphs (Pie chart, Line chart)
/// - Advanced filters (date range, type, property, unit)
/// - Enhanced expense cards with receipt support
/// - Expense details dialog
/// - Receipt upload/view
/// - Budget tracking
class ExpensesManagementScreen extends StatefulWidget {
  final String? propertyId;
  final String? unitId;
  final String? contractId;

  const ExpensesManagementScreen({
    super.key,
    this.propertyId,
    this.unitId,
    this.contractId,
  });

  @override
  State<ExpensesManagementScreen> createState() =>
      _ExpensesManagementScreenState();
}

class _ExpensesManagementScreenState extends State<ExpensesManagementScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _expenses = [];
  List<dynamic> _filteredExpenses = [];
  double _total = 0.0;
  String? _currentUserRole;
  Map<String, dynamic>? _stats;

  // Filters
  String? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedPropertyId;
  String? _selectedUnitId;

  // Budget
  double? _budgetAmount;
  bool _showBudgetInput = false;

  // UI State
  late TabController _tabController;
  bool _showFilters = false;
  bool _showCharts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserRole();
    _loadBudget();
    _fetchExpenses();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserRole = prefs.getString('role');
    });
  }

  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _budgetAmount = prefs.getDouble('expense_budget');
    });
  }

  Future<void> _saveBudget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('expense_budget', _budgetAmount ?? 0);
    setState(() {
      _showBudgetInput = false;
    });
    _applyFilters();
  }

  Future<void> _fetchExpenses() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllExpenses(
      propertyId: widget.propertyId ?? _selectedPropertyId,
      unitId: widget.unitId ?? _selectedUnitId,
      type: _selectedType,
      startDate: _startDate?.toIso8601String(),
      endDate: _endDate?.toIso8601String(),
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        if (data is List) {
          _expenses = data;
        } else if (data is Map) {
          _expenses = data['expenses'] ?? data['data'] ?? [];
        } else {
          _expenses = [];
        }
        _applyFilters();
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  Future<void> _fetchStats() async {
    final (ok, data) = await ApiService.getExpenseStats(
      propertyId: widget.propertyId ?? _selectedPropertyId,
      unitId: widget.unitId ?? _selectedUnitId,
      startDate: _startDate?.toIso8601String(),
      endDate: _endDate?.toIso8601String(),
    );
    if (mounted && ok) {
      setState(() {
        _stats = data is Map ? Map<String, dynamic>.from(data) : null;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredExpenses = List.from(_expenses);
      _total = _filteredExpenses.fold<double>(
        0.0,
        (sum, expense) => sum + ((expense['amount'] ?? 0) as num).toDouble(),
      );
    });
    _fetchStats();
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text('Confirm Delete', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final (ok, message) = await ApiService.deleteExpense(expenseId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? _accentGreen : Colors.red,
        ),
      );
      if (ok) {
        _fetchExpenses();
        _fetchStats();
      }
    }
  }

  void _openExpenseForm({Map<String, dynamic>? expense}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: _ExpenseFormSheet(
            propertyId: widget.propertyId,
            unitId: widget.unitId,
            contractId: widget.contractId,
            expense: expense,
            onSaved: () {
              Navigator.of(ctx).pop();
              _fetchExpenses();
              _fetchStats();
            },
          ),
        ),
      ),
    );
  }

  void _showExpenseDetails(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (ctx) => _ExpenseDetailsDialog(expense: expense),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'maintenance':
        return Colors.orange;
      case 'tax':
        return Colors.red;
      case 'utility':
        return Colors.blue;
      case 'management':
        return Colors.purple;
      case 'insurance':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getTypeText(String type) {
    switch (type) {
      case 'maintenance':
        return 'Maintenance';
      case 'tax':
        return 'Tax';
      case 'utility':
        return 'Utility';
      case 'management':
        return 'Management';
      case 'insurance':
        return 'Insurance';
      case 'other':
        return 'Other';
      default:
        return type;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'maintenance':
        return Icons.build;
      case 'tax':
        return Icons.receipt;
      case 'utility':
        return Icons.electric_bolt;
      case 'management':
        return Icons.business;
      case 'insurance':
        return Icons.shield;
      default:
        return Icons.attach_money;
    }
  }

  bool get _canEdit => _currentUserRole == 'landlord';

  // Calculate statistics
  double get _monthlyTotal {
    final now = DateTime.now();
    return _filteredExpenses.where((e) {
      final date = e['date'] != null ? DateTime.parse(e['date']) : null;
      return date != null && date.year == now.year && date.month == now.month;
    }).fold<double>(
      0.0,
      (sum, expense) => sum + ((expense['amount'] ?? 0) as num).toDouble(),
    );
  }

  double get _averageExpense {
    if (_filteredExpenses.isEmpty) return 0;
    return _total / _filteredExpenses.length;
  }

  int get _expenseCount => _filteredExpenses.length;

  Map<String, double> get _expensesByType {
    final Map<String, double> map = {};
    for (var expense in _filteredExpenses) {
      final type = expense['type'] ?? 'other';
      final amount = ((expense['amount'] ?? 0) as num).toDouble();
      map[type] = (map[type] ?? 0) + amount;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses Management'),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
        actions: [
          IconButton(
            icon: Icon(
                _showFilters ? Icons.filter_list : Icons.filter_list_outlined),
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
          ),
          IconButton(
            icon:
                Icon(_showCharts ? Icons.bar_chart : Icons.bar_chart_outlined),
            onPressed: () {
              setState(() => _showCharts = !_showCharts);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Expenses', icon: Icon(Icons.list)),
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
                    // Budget Section
                    if (_budgetAmount != null && _budgetAmount! > 0)
                      _buildBudgetCard(),
                    // Tab View
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildExpensesTab(),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openExpenseForm(),
              backgroundColor: _primaryBeige,
              foregroundColor: _textPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedType = null;
                    _startDate = null;
                    _endDate = null;
                    _selectedPropertyId = null;
                    _selectedUnitId = null;
                  });
                  _fetchExpenses();
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Type Filter
              DropdownButton<String>(
                value: _selectedType,
                hint: const Text('Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'tax', child: Text('Tax')),
                  DropdownMenuItem(value: 'utility', child: Text('Utility')),
                  DropdownMenuItem(
                      value: 'management', child: Text('Management')),
                  DropdownMenuItem(
                      value: 'insurance', child: Text('Insurance')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) {
                  setState(() => _selectedType = v);
                  _fetchExpenses();
                },
              ),
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
                    _fetchExpenses();
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    final remaining = (_budgetAmount ?? 0) - _total;
    final percentage = _budgetAmount! > 0 ? (_total / _budgetAmount!) * 100 : 0;
    final isOverBudget = remaining < 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverBudget ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverBudget ? Colors.red : Colors.green,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Budget Tracking',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () {
                  setState(() => _showBudgetInput = true);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget: ${NumberFormat.currency(symbol: '\$').format(_budgetAmount)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Spent: ${NumberFormat.currency(symbol: '\$').format(_total)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Remaining: ${NumberFormat.currency(symbol: '\$').format(remaining)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isOverBudget ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isOverBudget ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage > 1 ? 1 : (percentage / 100),
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              isOverBudget ? Colors.red : Colors.green,
            ),
          ),
          if (_showBudgetInput) ...[
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Budget Amount',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                _budgetAmount = double.tryParse(v);
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => _showBudgetInput = false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _saveBudget,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          _buildSummaryCards(),
          const SizedBox(height: 24),
          // Charts
          if (_showCharts) ...[
            _buildChartsSection(),
            const SizedBox(height: 24),
          ],
          // Budget Setup (if not set)
          if (_budgetAmount == null || _budgetAmount == 0)
            _buildBudgetSetupCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        // Total Expenses Card
        _buildSummaryCard(
          title: 'Total Expenses',
          value: NumberFormat.currency(symbol: '\$').format(_total),
          icon: Icons.account_balance_wallet,
          color: _accentGreen,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'This Month',
                value:
                    NumberFormat.currency(symbol: '\$').format(_monthlyTotal),
                icon: Icons.calendar_month,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Average',
                value:
                    NumberFormat.currency(symbol: '\$').format(_averageExpense),
                icon: Icons.trending_up,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(
          title: 'Total Count',
          value: '$_expenseCount',
          icon: Icons.receipt_long,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
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
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    if (_filteredExpenses.isEmpty) {
      return const Center(
        child: Text('No data available for charts'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Charts & Analytics',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // Pie Chart - Expenses by Type
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expenses by Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildPieChart(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Line Chart - Monthly Trend
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Trend',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildLineChart(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    // Use stats if available
    final statsByType = _stats != null && _stats!['byType'] != null
        ? List<Map<String, dynamic>>.from(_stats!['byType'])
        : _expensesByType.entries
            .map((e) => {
                  '_id': e.key,
                  'total': e.value,
                })
            .toList();

    if (statsByType.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final colors = [
      Colors.orange,
      Colors.red,
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.grey,
    ];
    int colorIndex = 0;

    final pieChartData = statsByType.map((entry) {
      final value = (entry['total'] as num).toDouble();
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        value: value,
        title: '${(value / _total * 100).toStringAsFixed(1)}%',
        color: color,
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: pieChartData,
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }

  Widget _buildLineChart() {
    // Group expenses by month
    final Map<String, double> monthlyData = {};
    for (var expense in _filteredExpenses) {
      if (expense['date'] != null) {
        final date = DateTime.parse(expense['date']);
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final amount = ((expense['amount'] ?? 0) as num).toDouble();
        monthlyData[key] = (monthlyData[key] ?? 0) + amount;
      }
    }

    if (monthlyData.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final sortedKeys = monthlyData.keys.toList()..sort();
    final spots = sortedKeys.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), monthlyData[entry.value]!);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _accentGreen,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: _accentGreen.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSetupCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: _accentGreen),
              SizedBox(width: 8),
              Text(
                'Set Budget',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monthly Budget Amount',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
            onChanged: (v) {
              _budgetAmount = double.tryParse(v);
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saveBudget,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Set Budget'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    return _filteredExpenses.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No expenses found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                if (_canEdit) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _openExpenseForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBeige,
                      foregroundColor: _textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _fetchExpenses,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredExpenses.length,
              itemBuilder: (ctx, idx) {
                final expense = _filteredExpenses[idx];
                return _buildEnhancedExpenseCard(expense);
              },
            ),
          );
  }

  Widget _buildEnhancedExpenseCard(Map<String, dynamic> expense) {
    final type = expense['type'] ?? '';
    final amount = expense['amount'] ?? 0;
    final date =
        expense['date'] != null ? DateTime.parse(expense['date']) : null;
    final receiptUrl = expense['receipt'] ?? expense['receiptUrl'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showExpenseDetails(expense),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(type),
                  color: _getTypeColor(type),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getTypeText(type),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          NumberFormat.currency(symbol: '\$').format(amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _accentGreen,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (expense['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        expense['description'],
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (date != null) ...[
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('yyyy-MM-dd').format(date),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (receiptUrl != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.receipt,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Receipt',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              if (_canEdit)
                PopupMenuButton(
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openExpenseForm(expense: expense);
                    } else if (value == 'delete') {
                      _deleteExpense(expense['_id']);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Expense Details Dialog
class _ExpenseDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> expense;

  const _ExpenseDetailsDialog({required this.expense});

  @override
  Widget build(BuildContext context) {
    final type = expense['type'] ?? '';
    final amount = expense['amount'] ?? 0;
    final date =
        expense['date'] != null ? DateTime.parse(expense['date']) : null;
    final receiptUrl = expense['receipt'] ?? expense['receiptUrl'];

    String _getTypeText(String type) {
      switch (type) {
        case 'maintenance':
          return 'Maintenance';
        case 'tax':
          return 'Tax';
        case 'utility':
          return 'Utility';
        case 'management':
          return 'Management';
        case 'insurance':
          return 'Insurance';
        case 'other':
          return 'Other';
        default:
          return type;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Expense Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Type
              _buildDetailRow('Type', _getTypeText(type)),
              const SizedBox(height: 12),
              // Amount
              _buildDetailRow(
                'Amount',
                NumberFormat.currency(symbol: '\$').format(amount),
                valueColor: _accentGreen,
                valueStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              // Date
              if (date != null)
                _buildDetailRow(
                  'Date',
                  DateFormat('yyyy-MM-dd').format(date),
                ),
              const SizedBox(height: 12),
              // Description
              if (expense['description'] != null)
                _buildDetailRow('Description', expense['description']),
              const SizedBox(height: 12),
              // Receipt
              if (receiptUrl != null) ...[
                const Text(
                  'Receipt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Receipt'),
                            backgroundColor: _primaryBeige,
                          ),
                          body: Center(
                            child: PhotoView(
                              imageProvider:
                                  CachedNetworkImageProvider(receiptUrl),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: receiptUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Color? valueColor, TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ??
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                ),
          ),
        ),
      ],
    );
  }
}

// Enhanced Expense Form with Receipt Upload
class _ExpenseFormSheet extends StatefulWidget {
  final String? propertyId;
  final String? unitId;
  final String? contractId;
  final Map<String, dynamic>? expense;
  final VoidCallback onSaved;

  const _ExpenseFormSheet({
    required this.propertyId,
    required this.unitId,
    this.contractId,
    this.expense,
    required this.onSaved,
  });

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'maintenance';
  DateTime? _selectedDate;
  String? _receiptUrl;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _amountController.text = (widget.expense!['amount'] ?? 0).toString();
      _descriptionController.text = widget.expense!['description'] ?? '';
      _type = widget.expense!['type'] ?? 'maintenance';
      if (widget.expense!['date'] != null) {
        _selectedDate = DateTime.parse(widget.expense!['date']);
      }
      _receiptUrl = widget.expense!['receipt'] ?? widget.expense!['receiptUrl'];
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickReceipt() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _isUploading = true);
        final (ok, url) = await ApiService.uploadImage(image);
        setState(() {
          _isUploading = false;
          if (ok && url != null) {
            _receiptUrl = url;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(url ?? 'Upload failed')),
            );
          }
        });
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    final expenseData = {
      if (widget.propertyId != null && widget.propertyId!.isNotEmpty)
        'propertyId': widget.propertyId,
      if (widget.unitId != null && widget.unitId!.isNotEmpty)
        'unitId': widget.unitId,
      if (widget.contractId != null && widget.contractId!.isNotEmpty)
        'contractId': widget.contractId,
      'type': _type,
      'amount': double.tryParse(_amountController.text) ?? 0,
      'description': _descriptionController.text.trim(),
      'date': _selectedDate!.toIso8601String(),
      if (_receiptUrl != null) 'receiptUrl': _receiptUrl,
    };

    final (ok, message) = widget.expense != null
        ? await ApiService.updateExpense(widget.expense!['_id'], expenseData)
        : await ApiService.addExpense(expenseData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? _accentGreen : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      if (ok) {
        widget.onSaved();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.expense != null ? 'Edit Expense' : 'Add New Expense',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Expense Type *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'maintenance', child: Text('Maintenance')),
                DropdownMenuItem(value: 'tax', child: Text('Tax')),
                DropdownMenuItem(value: 'utility', child: Text('Utility')),
                DropdownMenuItem(
                    value: 'management', child: Text('Management')),
                DropdownMenuItem(value: 'insurance', child: Text('Insurance')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'maintenance'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Required';
                if (double.tryParse(v!) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                          : 'Select Date',
                    ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            // Receipt Upload
            const Text(
              'Receipt (Optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (_receiptUrl != null)
              Stack(
                children: [
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: _receiptUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () {
                        setState(() => _receiptUrl = null);
                      },
                    ),
                  ),
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickReceipt,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isUploading ? 'Uploading...' : 'Upload Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBeige,
                  foregroundColor: _textPrimary,
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBeige,
                foregroundColor: _textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
