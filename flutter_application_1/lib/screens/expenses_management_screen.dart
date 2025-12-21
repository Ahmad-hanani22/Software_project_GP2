import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

/// Expenses Management Screen
///
/// Logic:
/// - Landlord: Can add/edit/delete expenses (full management)
/// - Admin: Can only view expenses (read-only, monitoring purpose)
/// - Tenant: Can only view expenses related to their contracts
///
/// Note: Expenses should be linked to contracts/deposits for deduction logic:
/// When contract ends, expenses are deducted from the deposit
/// Example: Deposit 1000, Expenses 300 (door repair 200 + cleaning 100) = Refund 700
class ExpensesManagementScreen extends StatefulWidget {
  final String? propertyId;
  final String? unitId;
  final String? contractId; // Optional: Link expense to specific contract

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

class _ExpensesManagementScreenState extends State<ExpensesManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _expenses = [];
  double _total = 0.0;
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchExpenses();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserRole = prefs.getString('role');
    });
  }

  Future<void> _fetchExpenses() async {
    setState(() => _isLoading = true);
    // Only filter by propertyId/unitId if they are explicitly provided
    // Otherwise, fetch all expenses
    final (ok, data) = await ApiService.getAllExpenses(
      propertyId: widget.propertyId,
      unitId: widget.unitId,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        // Handle both list response and object with expenses/total
        if (data is List) {
          _expenses = data;
          _total = _expenses.fold<double>(
            0.0,
            (sum, expense) =>
                sum + ((expense['amount'] ?? 0) as num).toDouble(),
          );
        } else if (data is Map) {
          _expenses = data['expenses'] ?? data['data'] ?? [];
          _total = ((data['total'] ?? 0) as num).toDouble();
          if (_total == 0 && _expenses.isNotEmpty) {
            _total = _expenses.fold<double>(
              0.0,
              (sum, expense) =>
                  sum + ((expense['amount'] ?? 0) as num).toDouble(),
            );
          }
        } else {
          _expenses = [];
          _total = 0.0;
        }
      } else {
        _errorMessage = data.toString();
      }
    });
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
      if (ok) _fetchExpenses();
    }
  }

  void _openExpenseForm({Map<String, dynamic>? expense}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: _ExpenseFormSheet(
            propertyId: widget.propertyId,
            unitId: widget.unitId,
            contractId: widget.contractId,
            expense: expense,
            onSaved: () {
              Navigator.of(ctx).pop();
              _fetchExpenses();
            },
          ),
        ),
      ),
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

  // Only Landlord can add/edit expenses
  // Admin can only view (read-only)
  bool get _canEdit => _currentUserRole == 'landlord';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses Management'),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
      ),
      backgroundColor: _scaffoldBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : Column(
                  children: [
                    // Total card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _accentGreen,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Expenses:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            NumberFormat.currency(symbol: '\$').format(_total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Expenses list
                    Expanded(
                      child: _expenses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.receipt_long_outlined,
                                      size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No expenses found',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey),
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
                                itemCount: _expenses.length,
                                itemBuilder: (ctx, idx) {
                                  final expense = _expenses[idx];
                                  final type = expense['type'] ?? '';
                                  final amount = expense['amount'] ?? 0;
                                  final date = expense['date'] != null
                                      ? DateTime.parse(expense['date'])
                                      : null;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: _getTypeColor(type),
                                        child: Icon(
                                          _getTypeIcon(type),
                                          color: Colors.white,
                                        ),
                                      ),
                                      title: Text(
                                        _getTypeText(type),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (expense['description'] != null)
                                            Text(expense['description']),
                                          if (date != null)
                                            Text(
                                              DateFormat('yyyy-MM-dd')
                                                  .format(date),
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          if (expense['propertyId'] != null &&
                                              expense['propertyId'] is Map)
                                            Text(
                                              'Property: ${expense['propertyId']['title']}',
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            NumberFormat.currency(symbol: '\$')
                                                .format(amount),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _accentGreen,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (_canEdit)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit,
                                                      color: _primaryBeige),
                                                  onPressed: () =>
                                                      _openExpenseForm(
                                                          expense: expense),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      color: Colors.red),
                                                  onPressed: () =>
                                                      _deleteExpense(
                                                          expense['_id']),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      isThreeLine: true,
                                    ),
                                  );
                                },
                              ),
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
}

class _ExpenseFormSheet extends StatefulWidget {
  final String? propertyId;
  final String? unitId;
  final String? contractId; // Link expense to contract for deposit deduction
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

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    final expenseData = {
      // Property, unit, and contract are all optional
      if (widget.propertyId != null && widget.propertyId!.isNotEmpty) 
        'propertyId': widget.propertyId,
      if (widget.unitId != null && widget.unitId!.isNotEmpty) 
        'unitId': widget.unitId,
      if (widget.contractId != null && widget.contractId!.isNotEmpty)
        'contractId': widget.contractId, // Link to contract for deposit deduction logic
      'type': _type,
      'amount': double.tryParse(_amountController.text) ?? 0,
      'description': _descriptionController.text.trim(),
      'date': _selectedDate!.toIso8601String(),
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
        // Call onSaved which will refresh the list and close the dialog
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
                  DropdownMenuItem(
                      value: 'insurance', child: Text('Insurance')),
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
