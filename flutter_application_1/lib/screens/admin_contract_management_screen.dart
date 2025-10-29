// lib/screens/admin_contract_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

const Color _primaryGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFF5F5F5);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class AdminContractManagementScreen extends StatefulWidget {
  const AdminContractManagementScreen({super.key});

  @override
  State<AdminContractManagementScreen> createState() =>
      _AdminContractManagementScreenState();
}

class _AdminContractManagementScreenState
    extends State<AdminContractManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _contracts = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchContracts();
  }

  Future<void> _fetchContracts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final (ok, data) = await ApiService.getAllContracts();
    if (mounted) {
      setState(() {
        if (ok) {
          _contracts = data as List<dynamic>;
        } else {
          _errorMessage = data.toString();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteContract(String contractId) async {
    final confirm = await _showConfirmationDialog(
      context,
      title: 'Delete Contract',
      content: 'Are you sure you want to permanently delete this contract?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;

    final (ok, message) = await ApiService.deleteContract(contractId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? _primaryGreen : Colors.red,
      ));
      if (ok) _fetchContracts();
    }
  }

  Future<void> _updateContractStatus(
      String contractId, String newStatus) async {
    final (ok, message) =
        await ApiService.updateContract(contractId, {'status': newStatus});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? _primaryGreen : Colors.red,
      ));
      if (ok) _fetchContracts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('Contract Management'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Add new contract functionality is for demonstration.'),
              ));
            },
            tooltip: 'Add New Contract',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchContracts,
            tooltip: 'Refresh Contracts',
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _primaryGreen));
    }
    if (_errorMessage != null) {
      return Center(
          child: Text('Error: $_errorMessage',
              style: const TextStyle(color: Colors.red)));
    }
    if (_contracts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Contracts Found',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            Text('Contracts will appear here once they are created.',
                style: TextStyle(color: _textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _contracts.length,
      itemBuilder: (context, index) {
        return _ContractCard(
          contract: _contracts[index],
          onDelete: () => _deleteContract(_contracts[index]['_id']),
          onUpdateStatus: (newStatus) =>
              _updateContractStatus(_contracts[index]['_id'], newStatus),
        );
      },
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Map<String, dynamic> contract;
  final VoidCallback onDelete;
  final ValueChanged<String> onUpdateStatus;

  const _ContractCard(
      {required this.contract,
      required this.onDelete,
      required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final property = contract['propertyId'] as Map<String, dynamic>? ?? {};
    final tenant = contract['tenantId'] as Map<String, dynamic>? ?? {};
    final landlord = contract['landlordId'] as Map<String, dynamic>? ?? {};
    final status = contract['status'] ?? 'unknown';

    final currencyFormat =
        NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0);
    final dateFormat = DateFormat('d MMM, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property['title'] ?? 'N/A Property',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: _primaryGreen),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ID: ${contract['_id']}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(status.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: status == 'active'
                          ? Colors.green.shade100
                          : (status == 'expired'
                              ? Colors.orange.shade100
                              : Colors.grey.shade200),
                      labelStyle: TextStyle(
                          color: status == 'active'
                              ? Colors.green.shade800
                              : (status == 'expired'
                                  ? Colors.orange.shade800
                                  : Colors.grey.shade700)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildInfoRow(Icons.person_outline, 'Tenant:',
                    tenant['name'] ?? 'N/A', tenant['email'] ?? ''),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.business_center_outlined, 'Landlord:',
                    landlord['name'] ?? 'N/A', landlord['email'] ?? ''),
                const Divider(height: 24),
                _buildInfoRow(Icons.payments_outlined, 'Rent Amount:',
                    currencyFormat.format(contract['rentAmount'] ?? 0)),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.date_range_outlined, 'Contract Period:',
                    '${dateFormat.format(DateTime.parse(contract['startDate']))} to ${dateFormat.format(DateTime.parse(contract['endDate']))}'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                )),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  onSelected: (value) => onUpdateStatus(value),
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'active',
                      child: Text('Mark as Active'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'expired',
                      child: Text('Mark as Expired'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'terminated',
                      child: Text('Mark as Terminated'),
                    ),
                  ],
                  child: const Chip(
                    label: Text('Change Status'),
                    avatar: Icon(Icons.edit, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_forever_outlined,
                      color: Colors.redAccent),
                  onPressed: onDelete,
                  tooltip: 'Delete Contract',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      [String? subValue]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: _textPrimary)),
              if (subValue != null && subValue.isNotEmpty)
                Text(subValue,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: _textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

Future<bool?> _showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = 'Confirm',
  Color confirmColor = _primaryGreen,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.bold, color: confirmColor)),
      content: Text(content),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}
