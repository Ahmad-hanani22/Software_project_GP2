import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

const double _kMobileBreakpoint = 600.0;
const Color _primaryGreen = Color(0xFF2E7D32);
const Color _lightGreenAccent = Color(0xFFE8F5E9);
const Color _scaffoldBackground = Color(0xFFFAFAFA);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class PropertyType {
  final String id;
  final String name;
  final String displayName;
  final String icon;
  final bool isActive;
  final int order;
  final String? description;

  PropertyType({
    required this.id,
    required this.name,
    required this.displayName,
    required this.icon,
    required this.isActive,
    required this.order,
    this.description,
  });

  factory PropertyType.fromJson(Map<String, dynamic> json) {
    return PropertyType(
      id: json['_id'] ?? json['id'],
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      icon: json['icon'] ?? 'home',
      isActive: json['isActive'] ?? true,
      order: json['order'] ?? 0,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'displayName': displayName,
      'icon': icon,
      'isActive': isActive,
      'order': order,
      'description': description,
    };
  }
}

class AdminPropertyTypesManagementScreen extends StatefulWidget {
  const AdminPropertyTypesManagementScreen({super.key});

  @override
  State<AdminPropertyTypesManagementScreen> createState() =>
      _AdminPropertyTypesManagementScreenState();
}

class _AdminPropertyTypesManagementScreenState
    extends State<AdminPropertyTypesManagementScreen> {
  List<PropertyType> _propertyTypes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPropertyTypes();
  }

  Future<void> _fetchPropertyTypes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (success, result) = await ApiService.getPropertyTypes();
    if (success && result is List) {
      setState(() {
        _propertyTypes = result
            .map((json) => PropertyType.fromJson(json))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePropertyType(PropertyType type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property Type'),
        content: Text(
            'Are you sure you want to delete "${type.displayName}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final (success, message) = await ApiService.deletePropertyType(type.id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        _fetchPropertyTypes();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePropertyTypeStatus(PropertyType type) async {
    final (success, message) =
        await ApiService.togglePropertyTypeStatus(type.id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        _fetchPropertyTypes();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddEditDialog({PropertyType? type}) {
    final nameController = TextEditingController(text: type?.name ?? '');
    final displayNameController =
        TextEditingController(text: type?.displayName ?? '');
    final iconController = TextEditingController(text: type?.icon ?? 'home');
    final descriptionController =
        TextEditingController(text: type?.description ?? '');
    final orderController =
        TextEditingController(text: type?.order.toString() ?? '0');
    bool isActive = type?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width > _kMobileBreakpoint
                ? 500
                : double.infinity,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type == null ? 'Add Property Type' : 'Edit Property Type',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name (lowercase)',
                      hintText: 'e.g., apartment, house, villa',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: displayNameController,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      hintText: 'e.g., Apartment, House, Villa',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: iconController,
                    decoration: InputDecoration(
                      labelText: 'Icon Name',
                      hintText: 'e.g., apartment, home, villa',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Order',
                      hintText: '0, 1, 2, ...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.sort),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Description in English',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value ?? true;
                          });
                        },
                        activeColor: _primaryGreen,
                      ),
                      const Text('Active'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.isEmpty ||
                              displayNameController.text.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all required fields'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final order = int.tryParse(orderController.text) ?? 0;

                          if (type == null) {
                            // Create new
                            final (success, message) =
                                await ApiService.createPropertyType(
                              name: nameController.text.trim().toLowerCase(),
                              displayName: displayNameController.text.trim(),
                              icon: iconController.text.trim(),
                              description: descriptionController.text.trim(),
                              order: order,
                            );

                            if (success) {
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _fetchPropertyTypes();
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } else {
                            // Update existing
                            final (success, message) =
                                await ApiService.updatePropertyType(
                              id: type.id,
                              name: nameController.text.trim().toLowerCase(),
                              displayName: displayNameController.text.trim(),
                              icon: iconController.text.trim(),
                              description: descriptionController.text.trim(),
                              order: order,
                              isActive: isActive,
                            );

                            if (success) {
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                _fetchPropertyTypes();
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: Text(type == null ? 'Add' : 'Update'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _kMobileBreakpoint;

    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('Property Types Management'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPropertyTypes,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'Add New Type',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_errorMessage',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPropertyTypes,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPropertyTypes,
                  color: _primaryGreen,
                  child: _propertyTypes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_outlined,
                                  size: 64, color: _textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                'No property types found',
                                style: TextStyle(color: _textSecondary),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Type'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryGreen,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          itemCount: _propertyTypes.length,
                          itemBuilder: (context, index) {
                            final type = _propertyTypes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: type.isActive
                                      ? _lightGreenAccent
                                      : Colors.grey[300],
                                  child: Icon(
                                    _getIconData(type.icon),
                                    color: type.isActive
                                        ? _primaryGreen
                                        : Colors.grey,
                                  ),
                                ),
                                title: Text(
                                  type.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: type.isActive
                                        ? _textPrimary
                                        : Colors.grey,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Name: ${type.name}'),
                                    Row(
                                      children: [
                                        Chip(
                                          label: Text('Order: ${type.order}'),
                                          backgroundColor: _lightGreenAccent,
                                          labelStyle: const TextStyle(
                                              fontSize: 11,
                                              color: _primaryGreen),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(type.isActive
                                              ? 'Active'
                                              : 'Inactive'),
                                          backgroundColor: type.isActive
                                              ? _lightGreenAccent
                                              : Colors.grey[200],
                                          labelStyle: TextStyle(
                                            fontSize: 11,
                                            color: type.isActive
                                                ? _primaryGreen
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton(
                                  icon: const Icon(Icons.more_vert),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      child: const Row(
                                        children: [
                                          Icon(Icons.edit, size: 20),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                      onTap: () {
                                        Future.delayed(
                                            const Duration(milliseconds: 100),
                                            () {
                                          _showAddEditDialog(type: type);
                                        });
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: Row(
                                        children: [
                                          Icon(
                                            type.isActive
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(type.isActive
                                              ? 'Deactivate'
                                              : 'Activate'),
                                        ],
                                      ),
                                      onTap: () {
                                        Future.delayed(
                                            const Duration(milliseconds: 100),
                                            () {
                                          _togglePropertyTypeStatus(type);
                                        });
                                      },
                                    ),
                                    PopupMenuItem(
                                      child: const Row(
                                        children: [
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                      onTap: () {
                                        Future.delayed(
                                            const Duration(milliseconds: 100),
                                            () {
                                          _deletePropertyType(type);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'apartment':
        return Icons.apartment;
      case 'home':
      case 'house':
        return Icons.home;
      case 'villa':
        return Icons.villa;
      case 'business':
      case 'office':
        return Icons.business;
      case 'store':
      case 'shop':
        return Icons.store;
      case 'landscape':
      case 'land':
        return Icons.landscape;
      default:
        return Icons.home;
    }
  }
}

