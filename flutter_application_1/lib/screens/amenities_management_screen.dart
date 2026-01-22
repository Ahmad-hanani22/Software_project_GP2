import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:fl_chart/fl_chart.dart';

const double _kMobileBreakpoint = 600.0;
const Color _primaryGreen = Color(0xFF2E7D32);
const Color _lightGreenAccent = Color(0xFFE8F5E9);
const Color _primaryBeige = Color(0xFFC4A574);
const Color _lightBeigeAccent = Color(0xFFF5EDE4);
const Color _scaffoldBackground = Color(0xFFFAFAFA);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class Amenity {
  final String id;
  final String name;
  final String displayName;
  final String icon;
  final bool isActive;
  final int order;
  final String? description;

  Amenity({
    required this.id,
    required this.name,
    required this.displayName,
    required this.icon,
    required this.isActive,
    required this.order,
    this.description,
  });

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      id: json['_id'] ?? json['id'],
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      icon: json['icon'] ?? 'check_circle',
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

class AmenitiesManagementScreen extends StatefulWidget {
  final String role;

  const AmenitiesManagementScreen({super.key, this.role = 'admin'});

  @override
  State<AmenitiesManagementScreen> createState() =>
      _AmenitiesManagementScreenState();
}

class _AmenitiesManagementScreenState extends State<AmenitiesManagementScreen>
    with SingleTickerProviderStateMixin {
  List<Amenity> _amenities = [];
  bool _isLoading = true;
  String? _errorMessage;
  late TabController _tabController;

  bool get _isAdmin => widget.role == 'admin';
  Color get _primary => _isAdmin ? _primaryGreen : _primaryBeige;
  Color get _lightAccent => _isAdmin ? _lightGreenAccent : _lightBeigeAccent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAmenities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAmenities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (success, result) = await ApiService.getAmenities(activeOnly: false);
    if (success && result is List) {
      setState(() {
        _amenities = result.map((json) => Amenity.fromJson(json)).toList()
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

  Future<void> _deleteAmenity(Amenity amenity) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete amenity'),
        content: Text(
            'Are you sure you want to delete "${amenity.displayName}"?\n\nThis action cannot be undone.'),
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

    final (success, message) = await ApiService.deleteAmenity(amenity.id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _primary,
          ),
        );
        _fetchAmenities();
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

  Future<void> _toggleAmenityStatus(Amenity amenity) async {
    final (success, message) = await ApiService.toggleAmenityStatus(amenity.id);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: _primary,
          ),
        );
        _fetchAmenities();
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

  void _showAddEditDialog({Amenity? amenity}) {
    final nameController = TextEditingController(text: amenity?.name ?? '');
    final displayNameController =
        TextEditingController(text: amenity?.displayName ?? '');
    final iconController =
        TextEditingController(text: amenity?.icon ?? 'check_circle');
    final descriptionController =
        TextEditingController(text: amenity?.description ?? '');
    final orderController =
        TextEditingController(text: amenity?.order.toString() ?? '0');
    bool isActive = amenity?.isActive ?? true;

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
                    amenity == null ? 'Add new amenity' : 'Edit amenity',
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
                      hintText: 'e.g. wifi, parking, pool',
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
                      labelText: 'Display name',
                      hintText: 'e.g. Wifi, Parking, Pool',
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
                      labelText: 'Icon name',
                      hintText: 'e.g. wifi, parking, pool',
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
                      labelText: 'Description (optional)',
                      hintText: 'Amenity description',
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
                        activeColor: _primary,
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
                                content: Text('Please fill in all required fields'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final order = int.tryParse(orderController.text) ?? 0;

                          if (amenity == null) {
                            // Create new
                            final (success, message) =
                                await ApiService.createAmenity(
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
                                    backgroundColor: _primary,
                                  ),
                                );
                                _fetchAmenities();
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
                                await ApiService.updateAmenity(
                              id: amenity.id,
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
                                    backgroundColor: _primary,
                                  ),
                                );
                                _fetchAmenities();
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
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: Text(amenity == null ? 'Add' : 'Update'),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: const Text('Amenities Management'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Amenities'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Statistics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAmenities,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'Add new amenity',
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
                        onPressed: _fetchAmenities,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAmenities,
                  color: _primary,
                  child: _amenities.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_outline,
                                  size: 64, color: _textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                'No amenities found',
                                style: TextStyle(color: _textSecondary),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add first amenity'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            // Amenities List Tab
                            ListView.builder(
                              padding: EdgeInsets.all(isMobile ? 16 : 24),
                              itemCount: _amenities.length,
                              itemBuilder: (context, index) {
                                final amenity = _amenities[index];
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
                                      backgroundColor: amenity.isActive
                                          ? _lightAccent
                                          : Colors.grey[300],
                                      child: Icon(
                                        _getIconData(amenity.icon),
                                        color: amenity.isActive
                                            ? _primary
                                            : Colors.grey,
                                      ),
                                    ),
                                    title: Text(
                                      amenity.displayName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: amenity.isActive
                                            ? _textPrimary
                                            : Colors.grey,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Name: ${amenity.name}'),
                                        Row(
                                          children: [
                                            Chip(
                                              label: Text(
                                                  'Order: ${amenity.order}'),
                                              backgroundColor:
                                                  _lightAccent,
                                              labelStyle: TextStyle(
                                                  fontSize: 11,
                                                  color: _primary),
                                            ),
                                            const SizedBox(width: 8),
                                            Chip(
                                              label: Text(amenity.isActive
                                                  ? 'Active'
                                                  : 'Inactive'),
                                              backgroundColor: amenity.isActive
                                                  ? _lightAccent
                                                  : Colors.grey[200],
                                              labelStyle: TextStyle(
                                                fontSize: 11,
                                                color: amenity.isActive
                                                    ? _primary
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
                                                const Duration(
                                                    milliseconds: 100), () {
                                              _showAddEditDialog(
                                                  amenity: amenity);
                                            });
                                          },
                                        ),
                                        PopupMenuItem(
                                          child: Row(
                                            children: [
                                              Icon(
                                                amenity.isActive
                                                    ? Icons.visibility_off
                                                    : Icons.visibility,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(amenity.isActive
                                                  ? 'Disable'
                                                  : 'Enable'),
                                            ],
                                          ),
                                          onTap: () {
                                            Future.delayed(
                                                const Duration(
                                                    milliseconds: 100), () {
                                              _toggleAmenityStatus(amenity);
                                            });
                                          },
                                        ),
                                        PopupMenuItem(
                                          child: const Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  size: 20, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                          onTap: () {
                                            Future.delayed(
                                                const Duration(
                                                    milliseconds: 100), () {
                                              _deleteAmenity(amenity);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Charts Tab
                            _buildChartsTab(),
                          ],
                        ),
                ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'wifi':
        return Icons.wifi;
      case 'parking':
        return Icons.local_parking;
      case 'pool':
        return Icons.pool;
      case 'gym':
        return Icons.fitness_center;
      case 'ac':
        return Icons.ac_unit;
      case 'heater':
        return Icons.thermostat;
      case 'balcony':
        return Icons.balcony;
      case 'elevator':
        return Icons.elevator;
      case 'security':
        return Icons.security;
      case 'garden':
        return Icons.local_florist;
      case 'furnished':
        return Icons.chair;
      case 'check_circle':
      default:
        return Icons.check_circle;
    }
  }

  Widget _buildChartsTab() {
    final activeCount = _amenities.where((a) => a.isActive).length;
    final inactiveCount = _amenities.length - activeCount;

    if (_amenities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No data for statistics',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
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
              'Amenities statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: activeCount.toDouble(),
                      title: '$activeCount',
                      color: _primary,
                      radius: 70,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: inactiveCount.toDouble(),
                      title: '$inactiveCount',
                      color: Colors.grey,
                      radius: 70,
                      titleStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Active: $activeCount',
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(width: 24),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Inactive: $inactiveCount',
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
