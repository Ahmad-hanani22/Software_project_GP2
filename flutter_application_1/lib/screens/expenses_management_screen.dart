import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  
  // Enhanced Filters
  double? _minAmount;
  double? _maxAmount;
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  List<dynamic> _properties = [];
  List<dynamic> _units = [];
  String? _savedFilterName;
  List<Map<String, dynamic>> _savedFilters = [];
  
  // Recurring Expenses
  List<dynamic> _recurringExpenses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserRole();
    _loadBudget();
    _loadSavedFilters();
    _fetchProperties();
    _fetchExpenses();
    _fetchStats();
    _fetchRecurringExpenses();
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

  Future<void> _fetchProperties() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId != null) {
      final (ok, data) = await ApiService.getPropertiesByOwner(userId);
      if (ok && data is List) {
        setState(() {
          _properties = data;
        });
      }
    }
  }

  Future<void> _fetchRecurringExpenses() async {
    // This would fetch recurring expenses from API
    // For now, we'll check expenses with recurring flag
    setState(() {
      _recurringExpenses = _expenses.where((e) => e['isRecurring'] == true).toList();
    });
  }

  Future<void> _loadSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('saved_expense_filters');
    if (saved != null) {
      setState(() {
        _savedFilters = saved.map((s) => Map<String, dynamic>.from({
          'name': s,
          // Load filter data from prefs
        })).toList();
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredExpenses = List.from(_expenses);
      
      // Amount range filter
      if (_minAmount != null) {
        _filteredExpenses = _filteredExpenses.where((e) {
          final amount = ((e['amount'] ?? 0) as num).toDouble();
          return amount >= _minAmount!;
        }).toList();
      }
      if (_maxAmount != null) {
        _filteredExpenses = _filteredExpenses.where((e) {
          final amount = ((e['amount'] ?? 0) as num).toDouble();
          return amount <= _maxAmount!;
        }).toList();
      }
      
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
            icon: const Icon(Icons.download),
            onPressed: _exportReport,
            tooltip: 'Export Report',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Expenses', icon: Icon(Icons.list)),
            Tab(text: 'Charts', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      backgroundColor: _scaffoldBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        // Filters Section - Responsive
                        if (_showFilters)
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * 0.4,
                            ),
                            child: SingleChildScrollView(
                              child: _buildFiltersSection(),
                            ),
                          ),
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
                              _buildChartsTab(),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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
                'Advanced Filters',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (_savedFilters.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.bookmark),
                      onPressed: _showSavedFilters,
                      tooltip: 'Saved Filters',
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedType = null;
                        _startDate = null;
                        _endDate = null;
                        _selectedPropertyId = null;
                        _selectedUnitId = null;
                        _minAmount = null;
                        _maxAmount = null;
                        _minAmountController.clear();
                        _maxAmountController.clear();
                      });
                      _applyFilters();
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Quick Filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickFilterChip('This Week', () => _applyQuickFilter('week')),
              _buildQuickFilterChip('This Month', () => _applyQuickFilter('month')),
              _buildQuickFilterChip('This Year', () => _applyQuickFilter('year')),
            ],
          ),
          const SizedBox(height: 16),
          // Main Filters - Using SingleChildScrollView to prevent overflow
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Type Filter
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
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
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Property Filter with Search
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _selectedPropertyId,
                    decoration: const InputDecoration(
                      labelText: 'Property',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixIcon: Icon(Icons.search),
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
                          value: propId,
                          child: Text(propName),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedPropertyId = v;
                        _selectedUnitId = null; // Reset unit when property changes
                      });
                      _fetchExpenses();
                    },
                  ),
                ),
                // Unit Filter (if property selected)
                if (_selectedPropertyId != null) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnitId,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Units'),
                        ),
                        // Units would be fetched based on property
                      ],
                      onChanged: (v) {
                        setState(() => _selectedUnitId = v);
                        _fetchExpenses();
                      },
                    ),
                  ),
                ],
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
                const SizedBox(width: 12),
                // Save Filter Button
                IconButton(
                  icon: const Icon(Icons.bookmark_add),
                  onPressed: _saveCurrentFilter,
                  tooltip: 'Save Current Filter',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: false,
      onSelected: (_) => onTap(),
      selectedColor: _accentGreen,
      labelStyle: TextStyle(
        color: false ? Colors.white : _textPrimary,
      ),
    );
  }

  void _applyQuickFilter(String period) {
    final now = DateTime.now();
    setState(() {
      switch (period) {
        case 'week':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = now;
          break;
        case 'month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = now;
          break;
        case 'year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = now;
          break;
      }
    });
    _fetchExpenses();
  }

  void _saveCurrentFilter() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Save Filter'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Filter Name',
              hintText: 'e.g., Monthly Maintenance',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('saved_expense_filters') ?? [];
      saved.add(name);
      await prefs.setStringList('saved_expense_filters', saved);
      setState(() {
        _savedFilters.add({'name': name});
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Filter "$name" saved')),
      );
    }
  }

  void _showSavedFilters() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved Filters'),
        content: _savedFilters.isEmpty
            ? const Text('No saved filters')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _savedFilters.length,
                itemBuilder: (context, index) {
                  final filter = _savedFilters[index];
                  return ListTile(
                    title: Text(filter['name']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _savedFilters.removeAt(index);
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
          // Enhanced Summary Cards
          _buildEnhancedSummaryCards(),
          const SizedBox(height: 24),
          // Budget Setup (if not set)
          if (_budgetAmount == null || _budgetAmount == 0)
            _buildBudgetSetupCard(),
        ],
      ),
    );
  }

  Widget _buildChartsTab() {
    if (_filteredExpenses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No data available for charts'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bar Chart - Expenses by Property
          _buildPropertyComparisonBarChart(),
          const SizedBox(height: 24),
          // Area Chart - Expense Trend Over Time
          _buildExpenseTrendAreaChart(),
          const SizedBox(height: 24),
          // Enhanced Donut Chart - Expenses by Type
          _buildEnhancedDonutChart(),
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

  Widget _buildEnhancedSummaryCards() {
    final highestExpense = _filteredExpenses.isEmpty
        ? 0.0
        : _filteredExpenses.map((e) => ((e['amount'] ?? 0) as num).toDouble()).reduce((a, b) => a > b ? a : b);

    final typeCounts = <String, int>{};
    for (var expense in _filteredExpenses) {
      final type = expense['type'] ?? 'other';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    final mostFrequentType = typeCounts.isEmpty
        ? 'N/A'
        : typeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final now = DateTime.now();
    final thisMonthExpenses = _filteredExpenses.where((e) {
      try {
        final date = DateTime.parse(e['date']);
        return date.year == now.year && date.month == now.month;
      } catch (e) {
        return false;
      }
    }).toList();
    final lastMonthExpenses = _filteredExpenses.where((e) {
      try {
        final date = DateTime.parse(e['date']);
        final lastMonth = DateTime(now.year, now.month - 1);
        return date.year == lastMonth.year && date.month == lastMonth.month;
      } catch (e) {
        return false;
      }
    }).toList();

    final thisMonthTotal = thisMonthExpenses.fold<double>(
      0.0,
      (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble(),
    );
    final lastMonthTotal = lastMonthExpenses.fold<double>(
      0.0,
      (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble(),
    );

    final avgMonthlyExpense = _filteredExpenses.isEmpty
        ? 0.0
        : _total / (_filteredExpenses.length > 0 ? (_filteredExpenses.length / 30.0).ceil() : 1);

    final growthRate = lastMonthTotal > 0
        ? ((thisMonthTotal - lastMonthTotal) / lastMonthTotal * 100)
        : 0.0;

    return Column(
      children: [
        // Row 1: Total and Highest
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Expenses',
                value: NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(_total),
                icon: Icons.account_balance_wallet,
                color: _accentGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Highest Expense',
                value: NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(highestExpense),
                icon: Icons.trending_up,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Average Monthly and Growth Rate
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Avg Monthly',
                value: NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(avgMonthlyExpense),
                icon: Icons.calendar_month,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Growth Rate',
                value: '${growthRate.toStringAsFixed(1)}%',
                icon: growthRate >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                color: growthRate >= 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 3: Most Frequent Type and Count
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                title: 'Most Frequent',
                value: mostFrequentType.toUpperCase(),
                icon: Icons.category,
                color: Colors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                title: 'Total Count',
                value: '$_expenseCount',
                icon: Icons.receipt_long,
                color: Colors.orange,
              ),
            ),
          ],
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

  Widget _buildPropertyComparisonBarChart() {
    // Group expenses by property
    final Map<String, double> propertyExpenses = {};
    for (var expense in _filteredExpenses) {
      final property = expense['propertyId'];
      String propertyName = 'Unknown';
      if (property is Map) {
        propertyName = property['title'] ?? 'Unknown';
      }
      final amount = ((expense['amount'] ?? 0) as num).toDouble();
      propertyExpenses[propertyName] = (propertyExpenses[propertyName] ?? 0) + amount;
    }

    if (propertyExpenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No property expense data available')),
      );
    }

    final maxExpense = propertyExpenses.values.reduce((a, b) => a > b ? a : b);

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
          const Text(
            'Expenses by Property',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxExpense * 1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        final properties = propertyExpenses.keys.toList();
                        if (index >= 0 && index < properties.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              properties[index],
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${NumberFormat('#,##0').format(value)}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                barGroups: propertyExpenses.entries.toList().asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.value,
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
    );
  }

  Widget _buildExpenseTrendAreaChart() {
    // Group expenses by month
    final Map<String, double> monthlyExpenses = {};
    for (var expense in _filteredExpenses) {
      try {
        final date = DateTime.parse(expense['date']);
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final amount = ((expense['amount'] ?? 0) as num).toDouble();
        monthlyExpenses[monthKey] = (monthlyExpenses[monthKey] ?? 0) + amount;
      } catch (e) {
        // Skip invalid dates
      }
    }

    if (monthlyExpenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No trend data available')),
      );
    }

    // Get last 6 months
    final now = DateTime.now();
    final List<Map<String, dynamic>> monthlyData = [];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      monthlyData.add({
        'month': DateFormat('MMM yyyy').format(month),
        'expense': monthlyExpenses[monthKey] ?? 0.0,
      });
    }

    final maxExpense = monthlyData
        .map((d) => d['expense'] as double)
        .reduce((a, b) => a > b ? a : b);

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
          const Text(
            'Expense Trend Over Time',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${NumberFormat('#,##0').format(value)}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < monthlyData.length) {
                          return Text(
                            monthlyData[index]['month'],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: (monthlyData.length - 1).toDouble(),
                minY: 0,
                maxY: maxExpense * 1.2,
                lineBarsData: [
                  LineChartBarData(
                    spots: monthlyData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value['expense'] as double,
                      );
                    }).toList(),
                    isCurved: true,
                    color: _accentGreen,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _accentGreen.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedDonutChart() {
    final expensesByType = _expensesByType;
    if (expensesByType.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text('No expense type data available')),
      );
    }

    final total = expensesByType.values.reduce((a, b) => a + b);
    final colors = [
      _accentGreen,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
    ];

    int colorIndex = 0;
    final sections = expensesByType.entries.map((entry) {
      final percentage = ((entry.value / total) * 100).toStringAsFixed(1);
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: '$percentage%',
        radius: 50,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }).toList();

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
          const Text(
            'Expenses Distribution by Type',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 60,
                      sections: sections,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: expensesByType.entries.toList().asMap().entries.map((entry) {
                    final color = colors[entry.key % colors.length];
                    final percentage = ((entry.value.value / total) * 100).toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.value.key.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '\$${NumberFormat('#,##0.00').format(entry.value.value)} ($percentage%)',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport() async {
    // Directly export as PDF
    await _exportToPDF();
  }

  Future<void> _exportToPDF() async {
    try {
      // Show loading
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
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'SHAQATI - Expenses Report',
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
                'Complete Expenses Report',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'User: $userName',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Summary Section
              pw.Header(level: 1, text: 'Summary Overview'),
              pw.SizedBox(height: 10),
              _buildExpenseSummaryTable(),
              pw.SizedBox(height: 30),

              // Expenses by Type
              pw.Header(level: 1, text: 'Expenses by Type'),
              pw.SizedBox(height: 10),
              _buildExpensesByTypeTable(),
              pw.SizedBox(height: 30),

              // All Expenses
              pw.Header(level: 1, text: 'All Expenses (${_filteredExpenses.length})'),
              pw.SizedBox(height: 10),
              _buildExpensesTable(),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final fileName = 'expenses_report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
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
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  pw.Widget _buildExpenseSummaryTable() {
    final highestExpense = _filteredExpenses.isEmpty
        ? 0.0
        : _filteredExpenses.map((e) => ((e['amount'] ?? 0) as num).toDouble()).reduce((a, b) => a > b ? a : b);

    final typeCounts = <String, int>{};
    for (var expense in _filteredExpenses) {
      final type = expense['type'] ?? 'other';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }
    final mostFrequentType = typeCounts.isEmpty
        ? 'N/A'
        : typeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final now = DateTime.now();
    final thisMonthExpenses = _filteredExpenses.where((e) {
      try {
        final date = DateTime.parse(e['date']);
        return date.year == now.year && date.month == now.month;
      } catch (e) {
        return false;
      }
    }).toList();
    final lastMonthExpenses = _filteredExpenses.where((e) {
      try {
        final date = DateTime.parse(e['date']);
        final lastMonth = DateTime(now.year, now.month - 1);
        return date.year == lastMonth.year && date.month == lastMonth.month;
      } catch (e) {
        return false;
      }
    }).toList();

    final thisMonthTotal = thisMonthExpenses.fold<double>(
      0.0,
      (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble(),
    );
    final lastMonthTotal = lastMonthExpenses.fold<double>(
      0.0,
      (sum, e) => sum + ((e['amount'] ?? 0) as num).toDouble(),
    );

    final avgMonthlyExpense = _filteredExpenses.isEmpty
        ? 0.0
        : _total / (_filteredExpenses.length > 0 ? (_filteredExpenses.length / 30.0).ceil() : 1);

    final growthRate = lastMonthTotal > 0
        ? ((thisMonthTotal - lastMonthTotal) / lastMonthTotal * 100)
        : 0.0;

    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        _buildTableRow(['Metric', 'Value'], isHeader: true),
        _buildTableRow(['Total Expenses', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(_total)]),
        _buildTableRow(['Highest Expense', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(highestExpense)]),
        _buildTableRow(['Average Monthly', NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(avgMonthlyExpense)]),
        _buildTableRow(['Growth Rate', '${growthRate.toStringAsFixed(1)}%']),
        _buildTableRow(['Most Frequent Type', mostFrequentType.toUpperCase()]),
        _buildTableRow(['Total Count', '${_filteredExpenses.length}']),
      ],
    );
  }

  pw.Widget _buildExpensesByTypeTable() {
    final expensesByType = _expensesByType;
    if (expensesByType.isEmpty) {
      return pw.Text('No expense type data available', style: pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
      },
      children: [
        _buildTableRow(['Type', 'Total Amount'], isHeader: true),
        ...expensesByType.entries.map((entry) => _buildTableRow([
          entry.key.toUpperCase(),
          NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(entry.value),
        ])),
      ],
    );
  }

  pw.Widget _buildExpensesTable() {
    if (_filteredExpenses.isEmpty) {
      return pw.Text('No expenses found', style: pw.TextStyle(color: PdfColors.grey));
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        _buildTableRow(['Date', 'Type', 'Amount', 'Description'], isHeader: true),
        ..._filteredExpenses.take(50).map((expense) {
          final date = expense['date'] != null
              ? DateFormat('yyyy-MM-dd').format(DateTime.parse(expense['date']))
              : 'N/A';
          final type = expense['type'] ?? 'other';
          final amount = expense['amount'] ?? 0;
          final description = (expense['description'] ?? '').toString();
          final shortDesc = description.length > 30
              ? '${description.substring(0, 30)}...'
              : description.isEmpty ? 'N/A' : description;
          
          return _buildTableRow([
            date,
            type.toUpperCase(),
            NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(amount),
            shortDesc,
          ]);
        }),
      ],
    );
  }

  pw.TableRow _buildTableRow(List<String> cells, {bool isHeader = false}) {
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

  Future<void> _exportToExcel() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // For Excel, we'll create a CSV file (which can be opened in Excel)
      final csv = StringBuffer();
      
      // Header
      csv.writeln('SHAQATI - Expenses Report');
      csv.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      csv.writeln('');
      
      // Summary
      csv.writeln('Summary');
      csv.writeln('Metric,Value');
      csv.writeln('Total Expenses,${NumberFormat('#,##0.00').format(_total)}');
      csv.writeln('Total Count,${_filteredExpenses.length}');
      csv.writeln('');
      
      // Expenses by Type
      csv.writeln('Expenses by Type');
      csv.writeln('Type,Amount');
      final expensesByType = _expensesByType;
      for (var entry in expensesByType.entries) {
        csv.writeln('${entry.key},${NumberFormat('#,##0.00').format(entry.value)}');
      }
      csv.writeln('');
      
      // All Expenses
      csv.writeln('All Expenses');
      csv.writeln('Date,Type,Amount,Description');
      for (var expense in _filteredExpenses) {
        final date = expense['date'] != null
            ? DateFormat('yyyy-MM-dd').format(DateTime.parse(expense['date']))
            : 'N/A';
        final type = expense['type'] ?? 'other';
        final amount = expense['amount'] ?? 0;
        final description = (expense['description'] ?? '').toString().replaceAll(',', ';');
        csv.writeln('$date,$type,$amount,"$description"');
      }

      final csvContent = csv.toString();
      final fileName = 'expenses_report_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      if (kIsWeb) {
        // For web, show CSV content in dialog for user to copy or download
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('CSV Export'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Copy the content below and save as .csv file:'),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SelectableText(
                          csvContent,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
        return;
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
          await file.writeAsString(csvContent);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Report saved: $fileName')),
            );
          }
        } else if (Platform.isIOS) {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsString(csvContent);
          // Share the file
          await Printing.sharePdf(
            bytes: utf8.encode(csvContent),
            filename: fileName,
          );
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsString(csvContent);
          
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
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
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

  Future<void> _uploadReceipt() async {
    setState(() => _isUploading = true);
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final (ok, url) = await ApiService.uploadImage(image);
        setState(() {
          _isUploading = false;
          if (ok && url != null) {
            _receiptUrl = url;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(url ?? 'Upload failed')),
              );
            }
          }
        });
      } else {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading receipt: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    final expenseData = {
      'type': _type,
      'amount': double.parse(_amountController.text),
      'date': _selectedDate!.toIso8601String(),
      'description': _descriptionController.text,
      if (widget.propertyId != null) 'propertyId': widget.propertyId,
      if (widget.unitId != null) 'unitId': widget.unitId,
      if (widget.contractId != null) 'contractId': widget.contractId,
      if (_receiptUrl != null) 'receipt': _receiptUrl,
    };

    final (ok, _) = widget.expense != null
        ? await ApiService.updateExpense(widget.expense!['_id'], expenseData)
        : await ApiService.addExpense(expenseData);

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save expense')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.expense != null ? 'Edit Expense' : 'Add Expense',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type *',
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
              if (_receiptUrl != null) ...[
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _receiptUrl!.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: _receiptUrl!,
                            fit: BoxFit.cover,
                          )
                        : Image.network(_receiptUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadReceipt,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isUploading ? 'Uploading...' : 'Upload Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBeige,
                  foregroundColor: _textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
