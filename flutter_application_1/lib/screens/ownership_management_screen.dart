import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

class OwnershipManagementScreen extends StatefulWidget {
  final String propertyId;
  final String propertyTitle;

  const OwnershipManagementScreen({
    super.key,
    required this.propertyId,
    required this.propertyTitle,
  });

  @override
  State<OwnershipManagementScreen> createState() =>
      _OwnershipManagementScreenState();
}

class _OwnershipManagementScreenState extends State<OwnershipManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _ownerships = [];

  @override
  void initState() {
    super.initState();
    _fetchOwnerships();
  }

  Future<void> _fetchOwnerships() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getPropertyOwnership(widget.propertyId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _ownerships = data as List<dynamic>;
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  Future<void> _deleteOwnership(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text('Confirm Delete', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to delete this ownership?'),
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

    final (ok, message) = await ApiService.deleteOwnership(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? _accentGreen : Colors.red,
        ),
      );
      if (ok) _fetchOwnerships();
    }
  }

  void _openOwnershipForm({Map<String, dynamic>? ownership}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OwnershipFormSheet(
        propertyId: widget.propertyId,
        ownership: ownership,
        onSaved: () {
          Navigator.of(ctx).pop();
          _fetchOwnerships();
        },
      ),
    );
  }

  double _calculateTotalPercentage() {
    double total = 0;
    for (var ownership in _ownerships) {
      total += (ownership['percentage'] ?? 0).toDouble();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final totalPercentage = _calculateTotalPercentage();

    return Scaffold(
      appBar: AppBar(
        title: Text('Ownership - ${widget.propertyTitle}'),
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
                    // Total ownership percentage card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: totalPercentage > 100
                            ? Colors.red
                            : totalPercentage == 100
                                ? _accentGreen
                                : Colors.orange,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Ownership:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${totalPercentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Owners list
                    Expanded(
                      child: _ownerships.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.people_outline,
                                      size: 64, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No owners found',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _openOwnershipForm(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Owner'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryBeige,
                                      foregroundColor: _textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchOwnerships,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _ownerships.length,
                                itemBuilder: (ctx, idx) {
                                  final ownership = _ownerships[idx];
                                  final owner = ownership['ownerId'] is Map
                                      ? ownership['ownerId']
                                      : {};
                                  final ownerName = owner['name'] ?? 'Unknown';
                                  final percentage =
                                      ownership['percentage'] ?? 0;
                                  final isPrimary =
                                      ownership['isPrimary'] ?? false;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 2,
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isPrimary
                                            ? _accentGreen
                                            : _primaryBeige,
                                        child: Text(
                                          ownerName[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ownerName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          if (isPrimary)
                                            const Chip(
                                              label: Text('Primary'),
                                              backgroundColor: _accentGreen,
                                              labelStyle: TextStyle(
                                                  color: Colors.white),
                                            ),
                                        ],
                                      ),
                                      subtitle: Text('Ownership: $percentage%'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                color: _primaryBeige),
                                            onPressed: () => _openOwnershipForm(
                                                ownership: ownership),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () => _deleteOwnership(
                                                ownership['_id']),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openOwnershipForm(),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add Owner'),
      ),
    );
  }
}

class _OwnershipFormSheet extends StatefulWidget {
  final String propertyId;
  final Map<String, dynamic>? ownership;
  final VoidCallback onSaved;

  const _OwnershipFormSheet({
    required this.propertyId,
    this.ownership,
    required this.onSaved,
  });

  @override
  State<_OwnershipFormSheet> createState() => _OwnershipFormSheetState();
}

class _OwnershipFormSheetState extends State<_OwnershipFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ownerIdController = TextEditingController();
  final _percentageController = TextEditingController();
  bool _isPrimary = false;

  @override
  void initState() {
    super.initState();
    if (widget.ownership != null) {
      final owner = widget.ownership!['ownerId'];
      if (owner is Map) {
        _ownerIdController.text = owner['_id'] ?? '';
      } else {
        _ownerIdController.text = owner.toString();
      }
      _percentageController.text =
          (widget.ownership!['percentage'] ?? 0).toString();
      _isPrimary = widget.ownership!['isPrimary'] ?? false;
    }
  }

  @override
  void dispose() {
    _ownerIdController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  Future<void> _saveOwnership() async {
    if (!_formKey.currentState!.validate()) return;

    final ownershipData = {
      'propertyId': widget.propertyId,
      'ownerId': _ownerIdController.text.trim(),
      'percentage': double.tryParse(_percentageController.text) ?? 0,
      'isPrimary': _isPrimary,
    };

    final (ok, message) = widget.ownership != null
        ? await ApiService.updateOwnership(
            widget.ownership!['_id'], ownershipData)
        : await ApiService.addOwnership(ownershipData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? _accentGreen : Colors.red,
        ),
      );
      if (ok) widget.onSaved();
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.ownership != null
                    ? 'Edit Ownership'
                    : 'Add New Ownership',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerIdController,
                decoration: const InputDecoration(
                  labelText: 'Owner ID (User ID) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _percentageController,
                decoration: const InputDecoration(
                  labelText: 'Percentage (%) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Required';
                  final percent = double.tryParse(v!);
                  if (percent == null || percent < 0 || percent > 100) {
                    return 'Must be between 0 and 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Primary Owner'),
                value: _isPrimary,
                onChanged: (v) => setState(() => _isPrimary = v ?? false),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveOwnership,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBeige,
                  foregroundColor: _textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
