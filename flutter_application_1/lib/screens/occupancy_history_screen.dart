import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

class OccupancyHistoryScreen extends StatefulWidget {
  const OccupancyHistoryScreen({super.key});

  @override
  State<OccupancyHistoryScreen> createState() => _OccupancyHistoryScreenState();
}

class _OccupancyHistoryScreenState extends State<OccupancyHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _histories = [];
  String _searchType = 'unit'; // 'unit' or 'tenant'
  String? _selectedUnitId;
  String? _selectedTenantId;
  List<dynamic> _units = [];
  List<dynamic> _tenants = [];
  bool _loadingUnits = false;
  bool _loadingTenants = false;
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

    // If tenant, fetch history directly
    if (_userRole == 'tenant' && _userId != null) {
      _searchType = 'tenant';
      _selectedTenantId = _userId;
      _fetchHistory();
    } else {
      // For admin/landlord, load units and tenants for selection
      _loadUnits();
      _loadTenants();
    }
  }

  Future<void> _loadUnits() async {
    setState(() => _loadingUnits = true);
    try {
      final (ok, data) = await ApiService.getAllUnits();
      if (!mounted) return;
      setState(() {
        _loadingUnits = false;
        if (ok && data is List) {
          _units = data;
        } else {
          _units = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUnits = false;
        _units = [];
      });
    }
  }

  Future<void> _loadTenants() async {
    setState(() => _loadingTenants = true);
    try {
      final (ok, data) = await ApiService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _loadingTenants = false;
        if (ok && data is List) {
          // Filter to get only tenants
          _tenants = data
              .where((user) => user is Map && user['role'] == 'tenant')
              .toList();
        } else {
          _tenants = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingTenants = false;
        _tenants = [];
      });
    }
  }

  Future<void> _fetchHistory() async {
    if (_searchType == 'unit' && _selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit')),
      );
      return;
    }
    if (_searchType == 'tenant' && _selectedTenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tenant')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (ok, data) = _searchType == 'unit'
        ? await ApiService.getOccupancyByUnit(_selectedUnitId!)
        : await ApiService.getOccupancyByTenant(_selectedTenantId!);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _histories = data as List<dynamic>;
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  String _getStatusText(Map<String, dynamic> history) {
    final to = history['to'];
    if (to == null) return 'Current';
    return 'Ended';
  }

  Color _getStatusColor(Map<String, dynamic> history) {
    final to = history['to'];
    if (to == null) return _accentGreen;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Occupancy History'),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
      ),
      backgroundColor: _scaffoldBackground,
      body: Column(
        children: [
          // Show search filters only for admin/landlord
          if (_userRole != 'tenant') ...[
            // Search Type Selector
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('By Unit'),
                      selected: _searchType == 'unit',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _searchType = 'unit';
                            _selectedTenantId = null;
                            _histories = [];
                          });
                        }
                      },
                      selectedColor: _primaryBeige,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('By Tenant'),
                      selected: _searchType == 'tenant',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _searchType = 'tenant';
                            _selectedUnitId = null;
                            _histories = [];
                          });
                        }
                      },
                      selectedColor: _primaryBeige,
                    ),
                  ),
                ],
              ),
            ),

            // Selection Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _searchType == 'unit'
                  ? DropdownButtonFormField<String>(
                      value: _selectedUnitId,
                      decoration: const InputDecoration(
                        labelText: 'Select Unit',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      items: _loadingUnits
                          ? []
                          : _units.map((unit) {
                              final property = unit['propertyId'] is Map
                                  ? unit['propertyId']
                                  : null;
                              final propertyTitle =
                                  property?['title'] ?? 'Unknown Property';
                              final unitNumber = unit['unitNumber'] ?? 'N/A';
                              return DropdownMenuItem<String>(
                                value: unit['_id'],
                                child: Text('$propertyTitle - Unit $unitNumber'),
                              );
                            }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUnitId = value;
                          _histories = [];
                        });
                      },
                    )
                  : DropdownButtonFormField<String>(
                      value: _selectedTenantId,
                      decoration: const InputDecoration(
                        labelText: 'Select Tenant',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: _loadingTenants
                          ? []
                          : _tenants.map((tenant) {
                              final name = tenant['name'] ?? 'Unknown';
                              final email = tenant['email'] ?? '';
                              return DropdownMenuItem<String>(
                                value: tenant['_id'],
                                child: Text('$name ($email)'),
                              );
                            }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedTenantId = value;
                          _histories = [];
                        });
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Search Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _fetchHistory,
                  icon: const Icon(Icons.search),
                  label: const Text('Search History'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBeige,
                    foregroundColor: _textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text('Error: $_errorMessage'))
                    : _histories.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No occupancy history found',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchHistory,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _histories.length,
                              itemBuilder: (ctx, idx) {
                                final history = _histories[idx];
                                final unit = history['unitId'] is Map
                                    ? history['unitId']
                                    : null;
                                final tenant = history['tenantId'] is Map
                                    ? history['tenantId']
                                    : null;
                                final contract = history['contractId'] is Map
                                    ? history['contractId']
                                    : null;

                                final from = history['from'] != null
                                    ? DateTime.parse(history['from'])
                                    : null;
                                final to = history['to'] != null
                                    ? DateTime.parse(history['to'])
                                    : null;

                                final statusText = _getStatusText(history);
                                final statusColor = _getStatusColor(history);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: statusColor,
                                      child: const Icon(Icons.home,
                                          color: Colors.white, size: 20),
                                    ),
                                    title: Text(
                                      unit?['unitNumber'] != null
                                          ? 'Unit ${unit['unitNumber']}'
                                          : 'Unit N/A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (tenant != null)
                                          Text('Tenant: ${tenant['name'] ?? 'Unknown'}'),
                                        if (contract != null)
                                          Text(
                                              'Contract: ${contract['_id']?.toString().substring(0, 8) ?? 'N/A'}'),
                                        const SizedBox(height: 4),
                                        if (from != null)
                                          Text(
                                            'From: ${DateFormat('yyyy-MM-dd').format(from)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        if (to != null)
                                          Text(
                                            'To: ${DateFormat('yyyy-MM-dd').format(to)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        if (to == null)
                                          const Text(
                                            'Status: Current',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        if (history['notes'] != null &&
                                            history['notes'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'Notes: ${history['notes']}',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        statusText,
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.white),
                                      ),
                                      backgroundColor: statusColor,
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
    );
  }
}

