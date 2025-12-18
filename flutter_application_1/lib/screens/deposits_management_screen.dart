import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

/// Deposits Management Screen
///
/// Logic:
/// - Landlord: Can manage deposits (view, refund)
/// - Admin: Should NOT manage deposits (removed from admin dashboard)
/// - Tenant: Can view their own deposits (read-only)
///
/// Deposit Deduction Flow:
/// 1. Contract ends
/// 2. Landlord adds expenses (linked to contract)
/// 3. Expenses are deducted from deposit
/// 4. Remaining amount is refunded
/// Example: Deposit 1000 → Expenses 300 → Refund 700
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

class _DepositsManagementScreenState extends State<DepositsManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _deposits = [];
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    if (widget.contractId != null) {
      _fetchDepositByContract();
    } else {
      _fetchAllDeposits();
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserRole = prefs.getString('role');
    });
  }

  Future<void> _fetchAllDeposits() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllDeposits();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _deposits = data as List<dynamic>;
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  Future<void> _fetchDepositByContract() async {
    setState(() => _isLoading = true);
    final (ok, data) =
        await ApiService.getDepositByContract(widget.contractId!);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _deposits = data != null ? [data] : [];
      } else {
        _errorMessage = data.toString();
      }
    });
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

  // Only Landlord can manage deposits (refund)
  // Admin should not manage deposits
  bool get _canEdit => _currentUserRole == 'landlord';

  void _showRefundDialog(dynamic deposit) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund Deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Held Amount: \$${deposit['amount']}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Refund Amount',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
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

              Navigator.of(ctx).pop();
              final (ok, message) = await ApiService.updateDeposit(
                deposit['_id'],
                {'refundAmount': refundAmount},
              );

              if (mounted) {
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
                    _fetchAllDeposits();
                  }
                }
              }
            },
            child: const Text('Refund'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposits Management'),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
      ),
      backgroundColor: _scaffoldBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _deposits.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.security_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No deposits found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: widget.contractId != null
                          ? _fetchDepositByContract
                          : _fetchAllDeposits,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _deposits.length,
                        itemBuilder: (ctx, idx) {
                          final deposit = _deposits[idx];
                          final status = deposit['status'] ?? 'held';
                          final amount = deposit['amount'] ?? 0;
                          final totalDeducted = deposit['totalDeducted'] ?? 0;
                          final refundedAmount = deposit['refundedAmount'] ?? 0;
                          final availableAmount =
                              amount - totalDeducted - refundedAmount;

                          final contract = deposit['contractId'];
                          String contractInfo = 'Contract';
                          if (contract is Map) {
                            final tenant = contract['tenantId'];
                            if (tenant is Map) {
                              contractInfo =
                                  'Tenant: ${tenant['name'] ?? 'N/A'}';
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Chip(
                                        label: Text(_getStatusText(status)),
                                        backgroundColor: _getStatusColor(status)
                                            .withOpacity(0.2),
                                        labelStyle: TextStyle(
                                          color: _getStatusColor(status),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        NumberFormat.currency(symbol: '\$')
                                            .format(amount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: _accentGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    contractInfo,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildAmountInfo('Deducted',
                                            totalDeducted, Colors.red),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildAmountInfo('Refunded',
                                            refundedAmount, Colors.blue),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildAmountInfo('Available', availableAmount,
                                      Colors.green),
                                  if (_canEdit &&
                                      status != 'refunded' &&
                                      availableAmount > 0) ...[
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showRefundDialog(deposit),
                                      icon: const Icon(
                                          Icons.account_balance_wallet),
                                      label: const Text('Refund'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _accentGreen,
                                        foregroundColor: Colors.white,
                                        minimumSize:
                                            const Size(double.infinity, 40),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            NumberFormat.currency(symbol: '\$').format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
