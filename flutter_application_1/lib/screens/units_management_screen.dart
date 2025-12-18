import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

class UnitsManagementScreen extends StatefulWidget {
  final String propertyId;
  final String propertyTitle;

  const UnitsManagementScreen({
    super.key,
    required this.propertyId,
    required this.propertyTitle,
  });

  @override
  State<UnitsManagementScreen> createState() => _UnitsManagementScreenState();
}

class _UnitsManagementScreenState extends State<UnitsManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _units = [];

  @override
  void initState() {
    super.initState();
    _fetchUnits();
  }

  Future<void> _fetchUnits() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getUnitsByProperty(widget.propertyId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _units = data as List<dynamic>;
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  Future<void> _deleteUnit(String unitId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text('Confirm Delete', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to delete this unit?'),
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

    final (ok, message) = await ApiService.deleteUnit(unitId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? _accentGreen : Colors.red,
        ),
      );
      if (ok) _fetchUnits();
    }
  }

  void _openUnitForm({Map<String, dynamic>? unit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UnitFormSheet(
        propertyId: widget.propertyId,
        unit: unit,
        onSaved: () {
          Navigator.of(ctx).pop();
          _fetchUnits();
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'vacant':
        return Colors.green;
      case 'occupied':
        return Colors.orange;
      case 'reserved':
        return Colors.blue;
      case 'maintenance':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'vacant':
        return 'Vacant';
      case 'occupied':
        return 'Occupied';
      case 'reserved':
        return 'Reserved';
      case 'maintenance':
        return 'Maintenance';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Units Management - ${widget.propertyTitle}'),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
      ),
      backgroundColor: _scaffoldBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _units.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.home_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No units found',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _openUnitForm(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Unit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBeige,
                              foregroundColor: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchUnits,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _units.length,
                        itemBuilder: (ctx, idx) {
                          final unit = _units[idx];
                          final status = unit['status'] ?? 'vacant';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(status),
                                child: Text(
                                  unit['unitNumber'] ?? '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                'Unit ${unit['unitNumber'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (unit['floor'] != null)
                                    Text('Floor: ${unit['floor']}'),
                                  if (unit['rooms'] != null)
                                    Text('Rooms: ${unit['rooms']}'),
                                  if (unit['rentPrice'] != null)
                                    Text(
                                      'Price: ${NumberFormat.currency(symbol: '\$').format(unit['rentPrice'])}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _accentGreen,
                                      ),
                                    ),
                                  Chip(
                                    label: Text(_getStatusText(status)),
                                    backgroundColor: _getStatusColor(status)
                                        .withOpacity(0.2),
                                    labelStyle: TextStyle(
                                      color: _getStatusColor(status),
                                      fontSize: 12,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: _primaryBeige),
                                    onPressed: () => _openUnitForm(unit: unit),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteUnit(unit['_id']),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUnitForm(),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add Unit'),
      ),
    );
  }
}

class _UnitFormSheet extends StatefulWidget {
  final String propertyId;
  final Map<String, dynamic>? unit;
  final VoidCallback onSaved;

  const _UnitFormSheet({
    required this.propertyId,
    this.unit,
    required this.onSaved,
  });

  @override
  State<_UnitFormSheet> createState() => _UnitFormSheetState();
}

class _UnitFormSheetState extends State<_UnitFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _unitNumberController = TextEditingController();
  final _floorController = TextEditingController();
  final _roomsController = TextEditingController();
  final _areaController = TextEditingController();
  final _rentPriceController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _status = 'vacant';

  @override
  void initState() {
    super.initState();
    if (widget.unit != null) {
      _unitNumberController.text = widget.unit!['unitNumber'] ?? '';
      _floorController.text = (widget.unit!['floor'] ?? '').toString();
      _roomsController.text = (widget.unit!['rooms'] ?? '').toString();
      _areaController.text = (widget.unit!['area'] ?? '').toString();
      _rentPriceController.text = (widget.unit!['rentPrice'] ?? '').toString();
      _bathroomsController.text = (widget.unit!['bathrooms'] ?? '').toString();
      _descriptionController.text = widget.unit!['description'] ?? '';
      _status = widget.unit!['status'] ?? 'vacant';
    }
  }

  @override
  void dispose() {
    _unitNumberController.dispose();
    _floorController.dispose();
    _roomsController.dispose();
    _areaController.dispose();
    _rentPriceController.dispose();
    _bathroomsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) return;

    final unitData = {
      'propertyId': widget.propertyId,
      'unitNumber': _unitNumberController.text.trim(),
      'floor': int.tryParse(_floorController.text) ?? 0,
      'rooms': int.tryParse(_roomsController.text) ?? 0,
      'area': double.tryParse(_areaController.text),
      'rentPrice': double.tryParse(_rentPriceController.text) ?? 0,
      'bathrooms': int.tryParse(_bathroomsController.text) ?? 0,
      'description': _descriptionController.text.trim(),
      'status': _status,
    };

    final (ok, message) = widget.unit != null
        ? await ApiService.updateUnit(widget.unit!['_id'], unitData)
        : await ApiService.addUnit(unitData);

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
                widget.unit != null ? 'Edit Unit' : 'Add New Unit',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unitNumberController,
                decoration: const InputDecoration(
                  labelText: 'Unit Number *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _floorController,
                      decoration: const InputDecoration(
                        labelText: 'Floor',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _roomsController,
                      decoration: const InputDecoration(
                        labelText: 'Rooms',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'Area (m²)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _bathroomsController,
                      decoration: const InputDecoration(
                        labelText: 'Bathrooms',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rentPriceController,
                decoration: const InputDecoration(
                  labelText: 'Rent Price *',
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
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'vacant', child: Text('Vacant')),
                  DropdownMenuItem(value: 'occupied', child: Text('Occupied')),
                  DropdownMenuItem(value: 'reserved', child: Text('Reserved')),
                  DropdownMenuItem(
                      value: 'maintenance', child: Text('Maintenance')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'vacant'),
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
                onPressed: _saveUnit,
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
