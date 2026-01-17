import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/ownership_management_screen.dart';
import 'package:flutter_application_1/screens/units_management_screen.dart';
import 'package:flutter_application_1/screens/property_history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

class PropertySelectionScreen extends StatefulWidget {
  final String screenType; // 'ownership', 'units', 'history'

  const PropertySelectionScreen({
    super.key,
    required this.screenType,
  });

  @override
  State<PropertySelectionScreen> createState() => _PropertySelectionScreenState();
}

class _PropertySelectionScreenState extends State<PropertySelectionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _properties = [];
  List<dynamic> _tenantData = []; // For tenant: units/ownership/history
  String _searchQuery = '';
  String? _userRole;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('role');
      _userId = prefs.getString('userId');
    });

    // For tenant, fetch data directly
    if (_userRole == 'tenant' && _userId != null) {
      await _fetchTenantData();
    } else {
      // For admin/landlord, show property selection
      await _fetchProperties();
    }
  }

  Future<void> _fetchTenantData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (widget.screenType) {
        case 'units':
          await _fetchTenantUnits();
          break;
        case 'ownership':
          await _fetchTenantOwnership();
          break;
        case 'history':
          await _fetchTenantPropertyHistory();
          break;
        default:
          await _fetchProperties();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchTenantUnits() async {
    try {
      // Fetch active contracts
      final (ok, contractsData) = await ApiService.getUserContracts(_userId!);
      if (!mounted) return;

      if (!ok || contractsData is! List) {
        setState(() {
          _isLoading = false;
          _tenantData = [];
        });
        return;
      }

      // Filter active contracts
      final activeContracts = contractsData.where((contract) {
        final status = contract['status']?.toString().toLowerCase();
        return status == 'active' || status == 'rented';
      }).toList();

      // Extract units from contracts
      final unitsList = <Map<String, dynamic>>[];
      for (var contract in activeContracts) {
        final unit = contract['unitId'];
        final property = contract['propertyId'];
        if (unit != null) {
          unitsList.add({
            'unit': unit is Map ? unit : {'_id': unit},
            'property': property is Map ? property : {'_id': property},
            'contract': contract,
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _tenantData = unitsList;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading units: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchTenantOwnership() async {
    try {
      // Check if tenant has ownership records
      final (ok, ownershipData) = await ApiService.getOwnerProperties(_userId!);
      if (!mounted) return;

      if (!ok || ownershipData is! List || ownershipData.isEmpty) {
        setState(() {
          _isLoading = false;
          _tenantData = [];
          _errorMessage = null; // Not an error, just no ownership
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _tenantData = ownershipData;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null; // No ownership is not an error for tenant
        _tenantData = [];
      });
    }
  }

  Future<void> _fetchTenantPropertyHistory() async {
    try {
      // Fetch active contracts
      final (ok, contractsData) = await ApiService.getUserContracts(_userId!);
      if (!mounted) return;

      if (!ok || contractsData is! List) {
        setState(() {
          _isLoading = false;
          _tenantData = [];
        });
        return;
      }

      // Get property IDs from contracts
      final propertyIds = <String>{};
      for (var contract in contractsData) {
        final property = contract['propertyId'];
        if (property != null) {
          final propertyId = property['_id']?.toString() ?? 
                           (property is String ? property : null);
          if (propertyId != null) {
            propertyIds.add(propertyId);
          }
        }
      }

      // Fetch history for each property
      final historyList = <Map<String, dynamic>>[];
      for (var propertyId in propertyIds) {
        final (historyOk, historyData) = await ApiService.getPropertyHistory(propertyId);
        if (historyOk && historyData is List) {
          for (var history in historyData) {
            historyList.add({
              'history': history,
              'propertyId': propertyId,
            });
          }
        }
      }

      // Sort by date (newest first)
      historyList.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['history']['createdAt'] ?? 
                                       a['history']['date'] ?? DateTime.now().toString());
          final dateB = DateTime.parse(b['history']['createdAt'] ?? 
                                       b['history']['date'] ?? DateTime.now().toString());
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _tenantData = historyList;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading history: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final (ok, data) = await ApiService.getAllProperties();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (ok && data is List) {
          _properties = data;
        } else {
          _properties = [];
          _errorMessage = ok ? 'No properties found' : data.toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _properties = [];
        _errorMessage = 'Error loading properties: ${e.toString()}';
      });
    }
  }

  String _getScreenTitle() {
    if (_userRole == 'tenant') {
      switch (widget.screenType) {
        case 'ownership':
          return 'Ownership';
        case 'units':
          return 'My Units';
        case 'history':
          return 'Property History';
        default:
          return 'Property Details';
      }
    }
    
    switch (widget.screenType) {
      case 'ownership':
        return 'Select Property - Ownership';
      case 'units':
        return 'Select Property - Units';
      case 'history':
        return 'Select Property - History';
      default:
        return 'Select Property';
    }
  }

  void _navigateToScreen(Map<String, dynamic> property) {
    final propertyId = property['_id'];
    final propertyTitle = property['title'] ?? 'Property';

    Widget? targetScreen;
    switch (widget.screenType) {
      case 'ownership':
        targetScreen = OwnershipManagementScreen(
          propertyId: propertyId,
          propertyTitle: propertyTitle,
        );
        break;
      case 'units':
        targetScreen = UnitsManagementScreen(
          propertyId: propertyId,
          propertyTitle: propertyTitle,
        );
        break;
      case 'history':
        targetScreen = PropertyHistoryScreen(
          propertyId: propertyId,
          propertyTitle: propertyTitle,
        );
        break;
    }

    if (targetScreen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => targetScreen!),
      );
    }
  }

  List<dynamic> get _filteredProperties {
    if (_searchQuery.isEmpty) return _properties;
    final query = _searchQuery.toLowerCase();
    return _properties.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? '').toString().toLowerCase();
      final address = (p['address'] ?? '').toString().toLowerCase();
      return title.contains(query) ||
          city.contains(query) ||
          address.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isTenant = _userRole == 'tenant';

    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
      ),
      backgroundColor: _scaffoldBackground,
      body: Column(
        children: [
          // Search Bar (only for admin/landlord)
          if (!isTenant)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search properties...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

          // Content based on user role
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : isTenant
                    ? _buildTenantContent()
                    : _buildAdminLandlordContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantContent() {
    if (_errorMessage != null && _tenantData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              widget.screenType == 'ownership'
                  ? 'No ownership records found'
                  : 'No data available',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_tenantData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.screenType == 'units'
                  ? Icons.home_outlined
                  : widget.screenType == 'ownership'
                      ? Icons.people_outline
                      : Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              widget.screenType == 'units'
                  ? 'No units found'
                  : widget.screenType == 'ownership'
                      ? 'No ownership records'
                      : 'No property history',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    switch (widget.screenType) {
      case 'units':
        return _buildTenantUnitsList();
      case 'ownership':
        return _buildTenantOwnershipList();
      case 'history':
        return _buildTenantHistoryList();
      default:
        return const Center(child: Text('Unknown screen type'));
    }
  }

  Widget _buildTenantUnitsList() {
    return RefreshIndicator(
      onRefresh: _fetchTenantData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tenantData.length,
        itemBuilder: (ctx, idx) {
          final item = _tenantData[idx];
          final unit = item['unit'] as Map<String, dynamic>;
          final property = item['property'] as Map<String, dynamic>;
          final contract = item['contract'];

          final unitNumber = unit['unitNumber'] ?? 'N/A';
          final floor = unit['floor'] ?? 'N/A';
          final rentPrice = unit['rentPrice'] ?? property['price'] ?? 0;
          final propertyTitle = property['title'] ?? property['address'] ?? 'Property';
          final propertyAddress = property['address'] ?? '';
          final propertyCity = property['city'] ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _primaryBeige,
                child: Text(
                  unitNumber.toString().isNotEmpty ? unitNumber.toString()[0] : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                'Unit $unitNumber',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📍 $propertyTitle'),
                  if (propertyAddress.isNotEmpty || propertyCity.isNotEmpty)
                    Text('$propertyCity${propertyCity.isNotEmpty && propertyAddress.isNotEmpty ? ', ' : ''}$propertyAddress'),
                  Text('🏢 Floor: $floor'),
                  Text('💰 Rent: \$${rentPrice.toStringAsFixed(0)}/month'),
                  if (contract != null)
                    Text(
                      'Contract: ${contract['status'] ?? 'Active'}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              isThreeLine: true,
              onTap: () {
                // Navigate to unit details or contract details
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTenantOwnershipList() {
    return RefreshIndicator(
      onRefresh: _fetchTenantData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tenantData.length,
        itemBuilder: (ctx, idx) {
          final ownership = _tenantData[idx];
          final property = ownership['propertyId'] is Map
              ? ownership['propertyId']
              : null;
          final percentage = ownership['percentage'] ?? 0;
          final isPrimary = ownership['isPrimary'] ?? false;

          final propertyTitle = property?['title'] ?? property?['address'] ?? 'Property';
          final propertyAddress = property?['address'] ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isPrimary ? _primaryBeige : Colors.grey,
                child: const Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                propertyTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (propertyAddress.isNotEmpty)
                    Text('📍 $propertyAddress'),
                  Text('📊 Ownership: ${percentage.toStringAsFixed(1)}%'),
                  if (isPrimary)
                    const Text(
                      '👑 Primary Owner',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              isThreeLine: true,
              onTap: () {
                if (property != null) {
                  final propertyId = property['_id']?.toString() ?? property['_id'];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnershipManagementScreen(
                        propertyId: propertyId,
                        propertyTitle: propertyTitle,
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTenantHistoryList() {
    return RefreshIndicator(
      onRefresh: _fetchTenantData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tenantData.length,
        itemBuilder: (ctx, idx) {
          final item = _tenantData[idx];
          final history = item['history'] as Map<String, dynamic>;

          final eventType = history['eventType'] ?? 'update';
          final description = history['description'] ?? 'Property event';
          final dateStr = history['createdAt'] ?? history['date'] ?? DateTime.now().toString();
          DateTime? date;
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            date = DateTime.now();
          }

          IconData icon;
          Color color;
          switch (eventType.toLowerCase()) {
            case 'rented':
            case 'lease':
              icon = Icons.assignment;
              color = Colors.green;
              break;
            case 'maintenance':
              icon = Icons.build;
              color = Colors.orange;
              break;
            case 'payment':
              icon = Icons.payment;
              color = Colors.blue;
              break;
            default:
              icon = Icons.update;
              color = Colors.grey;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, color: color),
              ),
              title: Text(
                eventType.toString().toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd().add_jm().format(date),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminLandlordContent() {
    return _errorMessage != null
        ? Center(child: Text('Error: $_errorMessage'))
        : _filteredProperties.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No properties found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchProperties,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredProperties.length,
                  itemBuilder: (ctx, idx) {
                    final property = _filteredProperties[idx];
                    final title = property['title'] ?? 'Untitled';
                    final city = property['city'] ?? 'Unknown';
                    final address = property['address'] ?? '';
                    final price = property['price'] ?? 0;
                    final type = property['type'] ?? 'apartment';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _primaryBeige,
                          child: const Icon(Icons.home, color: Colors.white),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$city, $address'),
                            Text(
                              '${type.toString().toUpperCase()} - \$${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _navigateToScreen(property),
                      ),
                    );
                  },
                ),
              );
  }
}

