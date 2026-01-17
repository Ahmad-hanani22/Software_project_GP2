import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/units_management_screen.dart';
import 'package:flutter_application_1/screens/property_history_screen.dart';
import 'package:flutter_application_1/screens/ownership_management_screen.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

// --- Theme Colors ---
const Color _primaryBeige = Color(0xFFD4B996);
const Color _darkBeige = Color(0xFF8D6E63);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);
const Color _textSecondary = Color(0xFF8D8D8D);

class LandlordPropertyManagementScreen extends StatefulWidget {
  const LandlordPropertyManagementScreen({super.key});
  @override
  State<LandlordPropertyManagementScreen> createState() =>
      _LandlordPropertyManagementScreenState();
}

class _LandlordPropertyManagementScreenState
    extends State<LandlordPropertyManagementScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _properties = [];
  List<dynamic> _filteredProperties = [];
  String? _landlordId;
  late TabController _tabController;
  int _currentTabIndex = 0;
  
  // Filters
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter;
  String? _selectedTypeFilter;
  String? _selectedCityFilter;
  double? _minPrice;
  double? _maxPrice;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _searchController.addListener(_filterProperties);
    _loadLandlordIdAndFetchProperties();
  }

  void _handleTabChange() {
    if (_tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.removeListener(_filterProperties);
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _loadLandlordIdAndFetchProperties() async {
    final prefs = await SharedPreferences.getInstance();
    final landlordId = prefs.getString('userId');
    if (landlordId != null) {
      setState(() => _landlordId = landlordId);
      _fetchProperties();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Could not verify landlord identity.";
      });
    }
  }

  Future<void> _fetchProperties() async {
    if (_landlordId == null) return;
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getPropertiesByOwner(_landlordId!);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _properties = data as List<dynamic>;
        _filterProperties();
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  void _filterProperties() {
    List<dynamic> temp = List.from(_properties);

    // Search filter
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      temp = temp.where((p) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        final city = (p['city'] ?? '').toString().toLowerCase();
        final address = (p['address'] ?? '').toString().toLowerCase();
        return title.contains(query) || city.contains(query) || address.contains(query);
      }).toList();
    }

    // Status filter
    if (_selectedStatusFilter != null) {
      temp = temp.where((p) => p['status'] == _selectedStatusFilter).toList();
    }

    // Type filter
    if (_selectedTypeFilter != null) {
      temp = temp.where((p) => p['type'] == _selectedTypeFilter).toList();
    }

    // City filter
    if (_selectedCityFilter != null) {
      temp = temp.where((p) => p['city'] == _selectedCityFilter).toList();
    }

    // Price range filter
    if (_minPrice != null) {
      temp = temp.where((p) => (p['price'] ?? 0) >= _minPrice!).toList();
    }
    if (_maxPrice != null) {
      temp = temp.where((p) => (p['price'] ?? 0) <= _maxPrice!).toList();
    }

    setState(() {
      _filteredProperties = temp;
    });
  }

  Future<void> _deleteProperty(String propertyId) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Confirm Deletion',
                  style: TextStyle(color: Colors.red)),
              content:
                  const Text('Are you sure you want to delete this property?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey))),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirm != true) return;

    final (ok, message) = await ApiService.deleteProperty(propertyId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: ok ? _accentGreen : Colors.red,
      ));
      if (ok) _fetchProperties();
    }
  }

  void _openPropertyForm({Map<String, dynamic>? property}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: PropertyFormSheet(
          property: property,
          onSubmit: (data, isEdit) async {
            Navigator.pop(ctx);
            setState(() => _isLoading = true);

            if (isEdit) {
              final (ok, message) = await ApiService.updateProperty(
                  id: property!['_id'], propertyData: data);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(message),
                    backgroundColor: ok ? _accentGreen : Colors.red));
                _fetchProperties();
              }
            } else {
              // ✅ عند الإنشاء، نحصل على property object كامل (يحتوي على _id)
              final (ok, responseData) = await ApiService.addProperty(data);
              
              if (mounted) {
                final message = ok 
                    ? 'Property created successfully. You can now manage units.'
                    : (responseData is String ? responseData : 'Operation failed');
                
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(message),
                    backgroundColor: ok ? _accentGreen : Colors.red));
                
                await _fetchProperties();
                
                // ✅ بعد الإنشاء، فتح إدارة الشقق مباشرة إذا كان من نوع apartment
                if (ok && responseData is Map && data['type'] == 'apartment') {
                  final createdPropertyId = responseData['_id']?.toString();
                  if (createdPropertyId != null) {
                    await Future.delayed(const Duration(milliseconds: 500));
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => UnitsManagementScreen(
                            propertyId: createdPropertyId,
                            propertyTitle: data['title'] ?? 'Property',
                          ),
                        ),
                      );
                    }
                  }
                }
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryBeige,
        foregroundColor: Colors.white,
        title: const Text('My Properties',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.home_work), text: 'Properties'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Charts'),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _fetchProperties),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPropertyForm(),
        label: const Text('Add Property'),
        icon: const Icon(Icons.add_home_work),
        backgroundColor: _accentGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : _properties.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Visibility(
                      visible: _currentTabIndex == 0,
                      maintainState: true,
                      child: _buildFilterBar(),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Properties Tab
                          _filteredProperties.isEmpty && _properties.isNotEmpty
                              ? _buildNoResultsState()
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth > 800) {
                                      return _buildGridView(constraints);
                                    } else {
                                      return _buildListView();
                                    }
                                  },
                                ),
                          // Charts Tab
                          _buildChartsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // --- 1. تصميم الموبايل (قائمة) ---
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) {
        final property = _filteredProperties[index];
        return _buildPropertyCard(property, isWeb: false);
      },
    );
  }

  // --- 2. تصميم الويب (شبكة) ---
  Widget _buildGridView(BoxConstraints constraints) {
    // تحديد عدد الأعمدة بناءً على عرض الشاشة
    int crossAxisCount = constraints.maxWidth > 1400 ? 4 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(24.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.85, // نسبة الطول للعرض للكارت
      ),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) {
        final property = _filteredProperties[index];
        return _buildPropertyCard(property, isWeb: true);
      },
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by title, city, or address...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterProperties();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: _selectedStatusFilter != null ||
                          _selectedTypeFilter != null ||
                          _selectedCityFilter != null ||
                          _minPrice != null ||
                          _maxPrice != null
                      ? _accentGreen
                      : Colors.grey,
                ),
                onPressed: _showFilterDialog,
                tooltip: 'Filter Options',
                style: IconButton.styleFrom(
                  backgroundColor: _selectedStatusFilter != null ||
                          _selectedTypeFilter != null ||
                          _selectedCityFilter != null ||
                          _minPrice != null ||
                          _maxPrice != null
                      ? _accentGreen.withOpacity(0.1)
                      : Colors.grey[100],
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final cities = _properties.map((p) => p['city']).whereType<String>().toSet().toList()..sort();
    final types = _properties.map((p) => p['type']).whereType<String>().toSet().toList()..sort();
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Properties'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Filter
                const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('available', 'Available', _selectedStatusFilter, (val) {
                      setDialogState(() {
                        _selectedStatusFilter = _selectedStatusFilter == val ? null : val;
                      });
                    }),
                    _buildFilterChip('rented', 'Rented', _selectedStatusFilter, (val) {
                      setDialogState(() {
                        _selectedStatusFilter = _selectedStatusFilter == val ? null : val;
                      });
                    }),
                    _buildFilterChip('pending', 'Pending', _selectedStatusFilter, (val) {
                      setDialogState(() {
                        _selectedStatusFilter = _selectedStatusFilter == val ? null : val;
                      });
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                // Type Filter
                if (types.isNotEmpty) ...[
                  const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: types.map((type) => _buildFilterChip(
                      type,
                      type,
                      _selectedTypeFilter,
                      (val) {
                        setDialogState(() {
                          _selectedTypeFilter = _selectedTypeFilter == val ? null : val;
                        });
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                // City Filter
                if (cities.isNotEmpty) ...[
                  const Text('City:', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButtonFormField<String>(
                    value: _selectedCityFilter,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Cities')),
                      ...cities.map((city) => DropdownMenuItem(value: city, child: Text(city))),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        _selectedCityFilter = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                // Price Range
                const Text('Price Range:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Min Price',
                          border: OutlineInputBorder(),
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          _minPrice = val.isEmpty ? null : double.tryParse(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Max Price',
                          border: OutlineInputBorder(),
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) {
                          _maxPrice = val.isEmpty ? null : double.tryParse(val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _selectedStatusFilter = null;
                  _selectedTypeFilter = null;
                  _selectedCityFilter = null;
                  _minPrice = null;
                  _maxPrice = null;
                  _minPriceController.clear();
                  _maxPriceController.clear();
                });
                _filterProperties();
                Navigator.pop(ctx);
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _filterProperties();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accentGreen),
              child: const Text('Apply', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, String? selected, Function(String) onTap) {
    final isSelected = selected == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(value),
      selectedColor: _accentGreen.withOpacity(0.2),
      checkmarkColor: _accentGreen,
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No properties found', style: TextStyle(color: Colors.grey[600], fontSize: 18)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _selectedStatusFilter = null;
              _selectedTypeFilter = null;
              _selectedCityFilter = null;
              _minPrice = null;
              _maxPrice = null;
              _minPriceController.clear();
              _maxPriceController.clear();
              _searchController.clear();
              _filterProperties();
            },
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Property Distribution by Type", style: _headerStyle),
          const SizedBox(height: 16),
          _buildPropertyTypePieChart(),
          const SizedBox(height: 40),
          Text("Properties by City/Region", style: _headerStyle),
          const SizedBox(height: 16),
          _buildPropertyCityBarChart(),
          const SizedBox(height: 40),
          Text("Property Locations Map", style: _headerStyle),
          const SizedBox(height: 16),
          _buildPropertyMapView(),
          const SizedBox(height: 40),
          Text("Property Analytics", style: _headerStyle),
          const SizedBox(height: 16),
          _buildPropertyAnalytics(),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => const TextStyle(
      fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary);

  Widget _buildPropertyTypePieChart() {
    // Group properties by type
    Map<String, int> typeCounts = {};
    for (var prop in _properties) {
      final type = prop['type'] ?? 'Unknown';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    if (typeCounts.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text("No property type data available")),
      );
    }

    final colors = [
      _accentGreen,
      _primaryBeige,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    int colorIndex = 0;
    final sections = typeCounts.entries.map((entry) {
      final total = typeCounts.values.reduce((a, b) => a + b);
      final percentage = ((entry.value / total) * 100).toStringAsFixed(0);
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '$percentage%',
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }).toList();

    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: sections,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: typeCounts.entries.map((entry) {
                final color = colors[typeCounts.keys.toList().indexOf(entry.key) % colors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.key)),
                      Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCityBarChart() {
    // Group properties by city
    Map<String, int> cityCounts = {};
    for (var prop in _properties) {
      final city = prop['city'] ?? 'Unknown';
      cityCounts[city] = (cityCounts[city] ?? 0) + 1;
    }

    if (cityCounts.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text("No city data available")),
      );
    }

    final maxCount = cityCounts.values.reduce((a, b) => a > b ? a : b);

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  final cities = cityCounts.keys.toList();
                  if (index >= 0 && index < cities.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        cities[index],
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
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
          barGroups: cityCounts.entries.toList().asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value.toDouble(),
                  color: _accentGreen,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPropertyMapView() {
    // Get properties with coordinates
    final propertiesWithCoords = _properties.where((p) {
      return p['latitude'] != null && p['longitude'] != null;
    }).toList();

    if (propertiesWithCoords.isEmpty) {
      return Container(
        height: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text("No property locations available")),
      );
    }

    // Calculate center point
    double avgLat = 0, avgLng = 0;
    for (var prop in propertiesWithCoords) {
      avgLat += (prop['latitude'] ?? 0.0);
      avgLng += (prop['longitude'] ?? 0.0);
    }
    avgLat /= propertiesWithCoords.length;
    avgLng /= propertiesWithCoords.length;

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(avgLat, avgLng),
            zoom: 12,
          ),
          markers: propertiesWithCoords.asMap().entries.map((entry) {
            final prop = entry.value;
            return Marker(
              markerId: MarkerId(prop['_id'] ?? entry.key.toString()),
              position: LatLng(prop['latitude'], prop['longitude']),
              infoWindow: InfoWindow(
                title: prop['title'] ?? 'Property',
                snippet: prop['city'] ?? '',
              ),
            );
          }).toSet(),
        ),
      ),
    );
  }

  Widget _buildPropertyAnalytics() {
    // Calculate analytics for each property
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _calculatePropertyAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text("No analytics data available")),
          );
        }

        return Column(
          children: snapshot.data!.map((analytics) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analytics['propertyTitle'] ?? 'Property',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildAnalyticsCard(
                          'Occupancy Rate',
                          '${analytics['occupancyRate']}%',
                          Icons.trending_up,
                          _accentGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAnalyticsCard(
                          'Revenue',
                          '\$${NumberFormat('#,##0.00').format(analytics['revenue'])}',
                          Icons.attach_money,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAnalyticsCard(
                          'Costs',
                          '\$${NumberFormat('#,##0.00').format(analytics['costs'])}',
                          Icons.receipt,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAnalyticsCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _calculatePropertyAnalytics() async {
    List<Map<String, dynamic>> analytics = [];
    
    for (var prop in _properties) {
      final propertyId = prop['_id'];
      
      // Fetch contracts for this property
      final (okContracts, contractsData) = await ApiService.getAllContracts();
      List<dynamic> propertyContracts = [];
      if (okContracts && contractsData is List) {
        propertyContracts = contractsData.where((c) {
          final propId = c['propertyId'];
          if (propId is Map) {
            return propId['_id'] == propertyId;
          }
          return propId == propertyId;
        }).toList();
      }

      // Calculate occupancy rate
      final totalUnits = prop['units']?.length ?? 1;
      final rentedUnits = propertyContracts.length;
      final occupancyRate = totalUnits > 0 ? ((rentedUnits / totalUnits) * 100).toStringAsFixed(1) : '0.0';

      // Calculate revenue (from payments)
      double revenue = 0.0;
      for (var contract in propertyContracts) {
        final (okPayments, paymentsData) = await ApiService.getPaymentsByContract(contract['_id']);
        if (okPayments && paymentsData is List) {
          for (var payment in paymentsData) {
            if (payment['status'] == 'paid') {
              revenue += (payment['amount'] ?? 0).toDouble();
            }
          }
        }
      }

      // Calculate costs (from maintenance)
      double costs = 0.0;
      final (okMaintenance, maintenanceData) = await ApiService.getMaintenanceByProperty(propertyId);
      if (okMaintenance && maintenanceData is List) {
        for (var req in maintenanceData) {
          if (req['status'] == 'resolved' && req['cost'] != null) {
            costs += (req['cost'] ?? 0).toDouble();
          }
        }
      }

      analytics.add({
        'propertyTitle': prop['title'],
        'occupancyRate': occupancyRate,
        'revenue': revenue,
        'costs': costs,
      });
    }

    return analytics;
  }

  // --- 3. تصميم الكارت نفسه (مشترك ومحسن) ---
  Widget _buildPropertyCard(dynamic property, {required bool isWeb}) {
    final title = property['title'] ?? 'No Title';
    final price = property['price'] ?? 0;
    final city = property['city'] ?? 'Unknown';
    final image = (property['images'] != null && property['images'].isNotEmpty)
        ? property['images'][0]
        : null;

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // لقص الصورة الزائدة
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // منطقة الصورة
          Stack(
            children: [
              Container(
                height: isWeb ? 200 : 180, // ارتفاع ثابت للصورة
                width: double.infinity,
                color: Colors.grey.shade200,
                child: image != null
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.image,
                            size: 50, color: Colors.grey),
                      )
                    : const Icon(Icons.image, size: 50, color: Colors.grey),
              ),
              // التاج (Tag) للحالة أو النوع
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (property['operation'] ?? 'RENT').toString().toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary),
                  ),
                ),
              ),
              // مؤشر 3D Model
              if (property['model3dUrl'] != null && 
                  property['model3dUrl'].toString().isNotEmpty)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.view_in_ar, 
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        const Text(
                          '3D',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // منطقة المعلومات
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween, // توزيع المسافات
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: _textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: _textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // السعر وأيقونات التعديل
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        NumberFormat.simpleCurrency(decimalDigits: 0)
                            .format(price),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _accentGreen,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.home_work,
                                size: 20, color: _accentGreen),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => UnitsManagementScreen(
                                    propertyId: property['_id'],
                                    propertyTitle: title,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'Manage Units',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.history,
                                size: 20, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => PropertyHistoryScreen(
                                    propertyId: property['_id'],
                                    propertyTitle: title,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'Property History',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.people,
                                size: 20, color: Colors.purple),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => OwnershipManagementScreen(
                                    propertyId: property['_id'],
                                    propertyTitle: title,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'Ownership',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                size: 20, color: _darkBeige),
                            onPressed: () =>
                                _openPropertyForm(property: property),
                            tooltip: 'Edit',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 20, color: Colors.redAccent),
                            onPressed: () => _deleteProperty(property['_id']),
                            tooltip: 'Delete',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- حالة عدم وجود بيانات ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.real_estate_agent_outlined,
              size: 80, color: _primaryBeige.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No Properties Yet',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          TextButton(
            onPressed: () => _openPropertyForm(),
            child: const Text("Create your first listing",
                style: TextStyle(color: _accentGreen)),
          )
        ],
      ),
    );
  }
}

// ============================================================================
// ================= FORM SHEET WIDGET ========================================
// ============================================================================

class PropertyFormSheet extends StatefulWidget {
  final Map<String, dynamic>? property;
  final Function(Map<String, dynamic> data, bool isEdit) onSubmit;

  const PropertyFormSheet({super.key, this.property, required this.onSubmit});

  @override
  State<PropertyFormSheet> createState() => _PropertyFormSheetState();
}

class _PropertyFormSheetState extends State<PropertyFormSheet> {
  final _formKey = GlobalKey<FormState>();

  final titleCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  double _latitude = 0.0;
  double _longitude = 0.0;

  String _selectedType = 'apartment';
  String _selectedOperation = 'rent';
  String? _paymentFrequency; // Payment frequency for rent
  int? _rentDurationMonths; // Rent duration in months
  int _bedrooms = 1;
  int _bathrooms = 1;
  List<dynamic> _propertyTypes = [];
  bool _loadingTypes = false;
  
  // Additional property details
  String? _propertyCondition; // Property condition
  String? _furnishingStatus; // Furnishing status
  int _parkingSpaces = 0; // Number of parking spaces
  int _floors = 1; // Number of floors
  String? _yearBuilt; // Year built
  bool _hasElevator = false; // Has elevator
  bool _hasGarden = false; // Has garden
  bool _hasBalcony = false; // Has balcony
  bool _hasPool = false; // Has pool
  
  // ✅ معلومات العمارات (Apartment-specific)
  int _totalUnits = 0; // عدد الشقق في العمارة
  String? _buildingId; // Building ID (اختياري)
  String _unitsDisplayMode = 'all'; // all, selected, available
  List<Map<String, dynamic>> _unitsList = []; // قائمة الشقق
  String? _heatingType; // Heating type
  String? _coolingType; // Cooling type
  String? _securityFeatures; // Security features
  String? _nearbyFacilities; // Nearby facilities
  String? _model3dUrl; // 3D model URL

  final List<String> _availableAmenities = [
    'Wifi',
    'Parking',
    'Pool',
    'Gym',
    'AC',
    'Heater',
    'Balcony',
    'Elevator',
    'Security',
    'Garden',
    'Furnished'
  ];
  List<String> _selectedAmenities = [];

  List<String> _existingImages = [];
  List<XFile> _newImages = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadPropertyTypes();
    if (widget.property != null) {
      final p = widget.property!;
      titleCtrl.text = p['title'] ?? '';
      priceCtrl.text = p['price']?.toString() ?? '';
      areaCtrl.text = p['area']?.toString() ?? '';
      descCtrl.text = p['description'] ?? '';
      addressCtrl.text = p['address'] ?? '';
      cityCtrl.text = p['city'] ?? '';
      countryCtrl.text = p['country'] ?? '';
      _selectedType = p['type'] ?? 'apartment';
      _selectedOperation = p['operation'] ?? 'rent';
      _bedrooms = p['bedrooms'] ?? 1;
      _bathrooms = p['bathrooms'] ?? 1;
      _existingImages = List<String>.from(p['images'] ?? []);
      _selectedAmenities = List<String>.from(p['amenities'] ?? []);
      
      // Additional fields
      _paymentFrequency = p['paymentFrequency'] ?? p['paymentCycle'];
      _rentDurationMonths = p['rentDurationMonths'];
      _propertyCondition = p['condition'];
      _furnishingStatus = p['furnishingStatus'];
      _parkingSpaces = p['parkingSpaces'] ?? 0;
      _floors = p['floors'] ?? 1;
      _yearBuilt = p['yearBuilt']?.toString();
      _hasElevator = p['hasElevator'] ?? false;
      _hasGarden = p['hasGarden'] ?? false;
      _hasBalcony = p['hasBalcony'] ?? false;
      _hasPool = p['hasPool'] ?? false;
      _heatingType = p['heatingType'];
      _coolingType = p['coolingType'];
      _securityFeatures = p['securityFeatures'];
      _nearbyFacilities = p['nearbyFacilities'];
      _model3dUrl = p['model3dUrl'];
      
      // ✅ معلومات العمارات
      _totalUnits = p['totalUnits'] ?? 0;
      _buildingId = p['buildingId']?.toString();
      _unitsDisplayMode = p['unitsDisplayMode'] ?? 'all';
      
      // تحميل الشقق إذا كانت موجودة
      if (p['units'] != null && p['units'] is List) {
        _unitsList = List<Map<String, dynamic>>.from(p['units']);
      }

      if (p['location'] != null && p['location']['coordinates'] != null) {
        final coords = p['location']['coordinates'];
        if (coords is List && coords.length == 2) {
          _longitude = (coords[0] as num).toDouble();
          _latitude = (coords[1] as num).toDouble();
        }
      }
    }
  }

  Future<void> _loadPropertyTypes() async {
    setState(() => _loadingTypes = true);
    final (success, result) = await ApiService.getPropertyTypes(activeOnly: true);
    if (success && result is List) {
      setState(() {
        _propertyTypes = result;
        _loadingTypes = false;
        // Set default type if available
        if (_propertyTypes.isNotEmpty && _selectedType.isEmpty) {
          _selectedType = _propertyTypes[0]['name'] ?? 'apartment';
        }
      });
    } else {
      setState(() => _loadingTypes = false);
      // Fallback to default types if API fails
      _propertyTypes = [
        {'name': 'apartment', 'displayName': 'Apartment'},
        {'name': 'house', 'displayName': 'House'},
        {'name': 'villa', 'displayName': 'Villa'},
        {'name': 'office', 'displayName': 'Office'},
        {'name': 'shop', 'displayName': 'Shop'},
      ];
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? pickedLocation = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (ctx) => MapSelectionScreen(
          initialLat: _latitude != 0.0 ? _latitude : 31.90,
          initialLong: _longitude != 0.0 ? _longitude : 35.20,
        ),
      ),
    );

    if (pickedLocation != null) {
      setState(() {
        _latitude = pickedLocation.latitude;
        _longitude = pickedLocation.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Location updated successfully!"),
        backgroundColor: _accentGreen,
        duration: Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  widget.property == null ? 'Create Property' : 'Edit Property',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionLabel("What are you listing?"),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    children: [
                      _buildOperationTab('Rent', _selectedOperation == 'rent'),
                      _buildOperationTab('Sale', _selectedOperation == 'sale'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _loadingTypes
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _propertyTypes
                              .where((type) => type['isActive'] != false)
                              .map((type) {
                            final typeName = type['name'] ?? '';
                            final displayName = type['displayName'] ?? typeName.toUpperCase();
                            final isSelected = _selectedType == typeName;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: FilterChip(
                                selected: isSelected,
                                showCheckmark: false,
                                label: Text(displayName.toUpperCase()),
                                labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : _textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                                backgroundColor: Colors.white,
                                selectedColor: _accentGreen,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                        color: isSelected
                                            ? _accentGreen
                                            : Colors.grey.shade300)),
                                onSelected: (val) =>
                                    setState(() => _selectedType = typeName),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                // ✅ قسم معلومات العمارات (فقط لـ Apartment)
                if (_selectedType == 'apartment') ...[
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accentGreen.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.apartment, color: _accentGreen),
                            const SizedBox(width: 8),
                            _buildSectionLabel("Apartment Information", fontSize: 16),
                          ],
                        ),
                        const SizedBox(height: 15),
                        _buildFancyTextField(
                          TextEditingController(text: _totalUnits.toString()),
                          "Total Units (Number of Apartments)",
                          icon: Icons.home_work,
                          isNumber: true,
                          onChanged: (value) {
                            final units = int.tryParse(value) ?? 0;
                            setState(() {
                              _totalUnits = units;
                              // إذا كان عدد الشقق أكبر من القائمة الحالية، نضيف شقق جديدة
                              // ✅ كل شقة لها بياناتها الخاصة (Encapsulation)
                              if (_unitsList.length < units) {
                                for (int i = _unitsList.length; i < units; i++) {
                                  // استخدام بيانات افتراضية من Property كقيم أولية فقط
                                  // كل Unit له بياناته الخاصة ويمكن تعديلها لاحقاً
                                  _unitsList.add({
                                    'unitNumber': 'Apt ${i + 1}', // رقم الشقة الخاص
                                    'floor': ((i ~/ 4) + 1), // توزيع على الطوابق (4 شقق لكل طابق)
                                    'rooms': _bedrooms, // قيمة أولية
                                    'area': double.tryParse(areaCtrl.text) ?? 0, // قيمة أولية
                                    'rentPrice': (double.tryParse(priceCtrl.text) ?? 0), // قيمة أولية
                                    'bathrooms': _bathrooms, // قيمة أولية
                                    'status': 'vacant', // حالة خاصة لكل شقة
                                    'description': '', // وصف خاص لكل شقة
                                    'images': [], // صور خاصة لكل شقة
                                    'amenities': [], // مميزات خاصة لكل شقة
                                  });
                                }
                              } else if (_unitsList.length > units) {
                                // إزالة الشقق الزائدة إذا قل العدد
                                _unitsList = _unitsList.take(units).toList();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _unitsDisplayMode,
                          decoration: InputDecoration(
                            labelText: "Units Display Mode",
                            prefixIcon: const Icon(Icons.visibility),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: [
                            DropdownMenuItem(value: 'all', child: Text('All Units (كل الشقق)')),
                            DropdownMenuItem(value: 'selected', child: Text('Selected Units (الشقق المحددة)')),
                            DropdownMenuItem(value: 'available', child: Text('Available Only (المتاحة فقط)')),
                          ],
                          onChanged: (value) => setState(() => _unitsDisplayMode = value ?? 'all'),
                        ),
                        if (_totalUnits > 0) ...[
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Units List (${_unitsList.length} units)",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: widget.property?['_id'] != null ? () {
                                        // عرض صفحة إدارة الشقق (فقط عند التعديل)
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (ctx) => UnitsManagementScreen(
                                              propertyId: widget.property!['_id'],
                                              propertyTitle: titleCtrl.text.isNotEmpty ? titleCtrl.text : widget.property!['title'] ?? 'Property',
                                            ),
                                          ),
                                        ).then((_) {
                                          // إعادة تحميل الشقق بعد العودة
                                          // (سيتم تحميلها من Backend عند التعديل)
                                        });
                                      } : null,
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text("Manage Units"),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _accentGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Manage unit details: unit number, floor, price, rooms, area, status, etc.",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                if (_unitsList.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  ..._unitsList.take(3).map((unit) => Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Icon(Icons.home, size: 16, color: _accentGreen),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "${unit['unitNumber']} - Floor ${unit['floor']} - \$${unit['rentPrice'] ?? unit['price'] ?? 0}",
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: unit['status'] == 'vacant' ? Colors.green.shade100 : Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                unit['status'] ?? 'vacant',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: unit['status'] == 'vacant' ? Colors.green.shade800 : Colors.orange.shade800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  if (_unitsList.length > 3)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        "... and ${_unitsList.length - 3} more units",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 25),
                _buildSectionLabel("Property Details"),
                const SizedBox(height: 15),
                _buildFancyTextField(titleCtrl, "Property Title",
                    icon: Icons.title),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                        child: _buildFancyTextField(priceCtrl, "Price",
                            icon: Icons.attach_money, isNumber: true)),
                    const SizedBox(width: 15),
                    Expanded(
                        child: _buildFancyTextField(areaCtrl, "Area (m²)",
                            icon: Icons.square_foot, isNumber: true)),
                  ],
                ),
                const SizedBox(height: 15),
                _buildFancyTextField(descCtrl, "Description",
                    icon: Icons.description, maxLines: 3),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCounter("Bedrooms", _bedrooms,
                        (val) => setState(() => _bedrooms = val)),
                    _buildCounter("Bathrooms", _bathrooms,
                        (val) => setState(() => _bathrooms = val)),
                  ],
                ),
                const SizedBox(height: 25),
                _buildSectionLabel("Amenities"),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableAmenities.map((amenity) {
                    final isSelected = _selectedAmenities.contains(amenity);
                    return ChoiceChip(
                      label: Text(amenity),
                      selected: isSelected,
                      selectedColor: _primaryBeige.withOpacity(0.4),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedAmenities.add(amenity);
                          } else {
                            _selectedAmenities.remove(amenity);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                // Rental Information (only for rent)
                if (_selectedOperation == 'rent') ...[
                  const SizedBox(height: 25),
                  _buildSectionLabel("Rental Information"),
                  const SizedBox(height: 10),
                  _buildSectionLabel("Payment Frequency", fontSize: 14),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        _buildPaymentFrequencyTab('Daily', _paymentFrequency == 'daily'),
                        _buildPaymentFrequencyTab('Weekly', _paymentFrequency == 'weekly'),
                        _buildPaymentFrequencyTab('Monthly', _paymentFrequency == 'monthly'),
                        _buildPaymentFrequencyTab('Yearly', _paymentFrequency == 'yearly'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildFancyTextField(
                    TextEditingController(text: _rentDurationMonths?.toString() ?? ''),
                    "Rent Duration (Months)",
                    icon: Icons.calendar_today,
                    isNumber: true,
                    onChanged: (value) {
                      _rentDurationMonths = int.tryParse(value);
                    },
                  ),
                ],
                // Additional Property Details
                const SizedBox(height: 25),
                _buildSectionLabel("Additional Property Details"),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildFancyTextField(
                        TextEditingController(text: _parkingSpaces.toString()),
                        "Parking Spaces",
                        icon: Icons.local_parking,
                        isNumber: true,
                        onChanged: (value) {
                          _parkingSpaces = int.tryParse(value) ?? 0;
                        },
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildFancyTextField(
                        TextEditingController(text: _floors.toString()),
                        "Floors",
                        icon: Icons.layers,
                        isNumber: true,
                        onChanged: (value) {
                          _floors = int.tryParse(value) ?? 1;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                _buildFancyTextField(
                  TextEditingController(text: _yearBuilt ?? ''),
                  "Year Built",
                  icon: Icons.calendar_today,
                  isNumber: true,
                  onChanged: (value) {
                    _yearBuilt = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _propertyCondition,
                  decoration: InputDecoration(
                    labelText: "Property Condition",
                    prefixIcon: const Icon(Icons.home),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: ['New', 'Used', 'Under Construction', 'Renovated']
                      .map((condition) => DropdownMenuItem(
                            value: condition,
                            child: Text(condition),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _propertyCondition = value),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _furnishingStatus,
                  decoration: InputDecoration(
                    labelText: "Furnishing Status",
                    prefixIcon: const Icon(Icons.chair),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: ['Furnished', 'Unfurnished', 'Semi-Furnished']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _furnishingStatus = value),
                ),
                const SizedBox(height: 15),
                _buildSectionLabel("Facilities", fontSize: 14),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFacilityChip("Elevator", _hasElevator, (val) => setState(() => _hasElevator = val)),
                    _buildFacilityChip("Garden", _hasGarden, (val) => setState(() => _hasGarden = val)),
                    _buildFacilityChip("Balcony", _hasBalcony, (val) => setState(() => _hasBalcony = val)),
                    _buildFacilityChip("Pool", _hasPool, (val) => setState(() => _hasPool = val)),
                  ],
                ),
                const SizedBox(height: 15),
                _buildFancyTextField(
                  TextEditingController(text: _heatingType ?? ''),
                  "Heating Type (e.g., Central, Electric)",
                  icon: Icons.ac_unit,
                  onChanged: (value) {
                    _heatingType = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 15),
                _buildFancyTextField(
                  TextEditingController(text: _coolingType ?? ''),
                  "Cooling Type (e.g., AC, Fan)",
                  icon: Icons.ac_unit,
                  onChanged: (value) {
                    _coolingType = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 15),
                _buildFancyTextField(
                  TextEditingController(text: _securityFeatures ?? ''),
                  "Security Features",
                  icon: Icons.security,
                  maxLines: 2,
                  onChanged: (value) {
                    _securityFeatures = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 15),
                _buildFancyTextField(
                  TextEditingController(text: _nearbyFacilities ?? ''),
                  "Nearby Facilities",
                  icon: Icons.local_activity,
                  maxLines: 2,
                  onChanged: (value) {
                    _nearbyFacilities = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 15),
                _buildFancyTextField(
                  TextEditingController(text: _model3dUrl ?? ''),
                  "3D Model URL (Optional)",
                  icon: Icons.view_in_ar,
                  onChanged: (value) {
                    _model3dUrl = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 25),
                _buildSectionLabel("Location"),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickLocation,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.shade100,
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ]),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.map, color: Colors.blue),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  cityCtrl.text.isEmpty
                                      ? "Select on Map"
                                      : "${cityCtrl.text}, ${countryCtrl.text}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(
                                  _latitude == 0
                                      ? "Tap to pin location"
                                      : "Lat: $_latitude, Lng: $_longitude",
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildFancyTextField(
                    addressCtrl, "Street Address / Building No.",
                    icon: Icons.location_on_outlined),
                const SizedBox(height: 25),
                _buildSectionLabel("Photos"),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      InkWell(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final List<XFile> picked =
                              await picker.pickMultiImage();
                          setState(() => _newImages.addAll(picked));
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(
                                  color: _accentGreen,
                                  style: BorderStyle
                                      .solid), // تم التعديل هنا (dashed -> solid)
                              borderRadius: BorderRadius.circular(12)),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: _accentGreen),
                              SizedBox(height: 4),
                              Text("Add",
                                  style: TextStyle(
                                      color: _accentGreen, fontSize: 12))
                            ],
                          ),
                        ),
                      ),
                      ..._existingImages.map((url) => _buildThumb(url, false,
                          () => setState(() => _existingImages.remove(url)))),
                      ..._newImages.map((file) => FutureBuilder<Uint8List>(
                            future: file.readAsBytes(),
                            builder: (_, snap) => snap.hasData
                                ? _buildThumb(
                                    snap.data!,
                                    true,
                                    () =>
                                        setState(() => _newImages.remove(file)))
                                : const SizedBox(
                                    width: 100,
                                    child: Center(
                                        child: CircularProgressIndicator())),
                          ))
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))
          ]),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save Property",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
            ),
          ),
        )
      ],
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == 0 && _longitude == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a location")));
      return;
    }

    setState(() => _isUploading = true);

    List<String> uploadedUrls = [];
    for (var file in _newImages) {
      final (ok, url) = await ApiService.uploadImage(file);
      if (ok && url != null) uploadedUrls.add(url);
    }

    final data = <String, dynamic>{
      'title': titleCtrl.text,
      'price': double.tryParse(priceCtrl.text) ?? 0,
      'description': descCtrl.text,
      'type': _selectedType,
      'operation': _selectedOperation,
      'country': countryCtrl.text,
      'city': cityCtrl.text,
      'address': addressCtrl.text,
      'area': double.tryParse(areaCtrl.text) ?? 0,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'amenities': _selectedAmenities,
      'images': [..._existingImages, ...uploadedUrls],
      'location': {
        'type': 'Point',
        'coordinates': [_longitude, _latitude]
      },
      'parkingSpaces': _parkingSpaces,
      'floors': _floors,
      'hasElevator': _hasElevator,
      'hasGarden': _hasGarden,
      'hasBalcony': _hasBalcony,
      'hasPool': _hasPool,
    };
    
    // ✅ معلومات العمارات (فقط لـ Apartment)
    if (_selectedType == 'apartment') {
      data['totalUnits'] = _totalUnits;
      data['unitsDisplayMode'] = _unitsDisplayMode;
      if (_buildingId != null && _buildingId!.isNotEmpty) {
        data['buildingId'] = _buildingId;
      }
      // إرسال قائمة الشقق (يتم حفظها كـ Units منفصلة في Backend)
      if (_unitsList.isNotEmpty) {
        data['units'] = _unitsList;
      }
    }
    
    // Add rental-specific fields
    if (_selectedOperation == 'rent') {
      if (_paymentFrequency != null) {
        data['paymentFrequency'] = _paymentFrequency;
      }
      if (_rentDurationMonths != null) {
        data['rentDurationMonths'] = _rentDurationMonths;
      }
    }
    
    // Add optional fields
    if (_propertyCondition != null) {
      data['condition'] = _propertyCondition;
    }
    if (_furnishingStatus != null) {
      data['furnishingStatus'] = _furnishingStatus;
    }
    if (_yearBuilt != null && _yearBuilt!.isNotEmpty) {
      final year = int.tryParse(_yearBuilt!);
      if (year != null) {
        data['yearBuilt'] = year;
      }
    }
    if (_heatingType != null && _heatingType!.isNotEmpty) {
      data['heatingType'] = _heatingType;
    }
    if (_coolingType != null && _coolingType!.isNotEmpty) {
      data['coolingType'] = _coolingType;
    }
    if (_securityFeatures != null && _securityFeatures!.isNotEmpty) {
      data['securityFeatures'] = _securityFeatures;
    }
    if (_nearbyFacilities != null && _nearbyFacilities!.isNotEmpty) {
      data['nearbyFacilities'] = _nearbyFacilities;
    }
    if (_model3dUrl != null && _model3dUrl!.isNotEmpty) {
      data['model3dUrl'] = _model3dUrl;
    }

    widget.onSubmit(data, widget.property != null);
  }

  Widget _buildThumb(dynamic source, bool isBytes, VoidCallback onDelete) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isBytes
                ? Image.memory(source, fit: BoxFit.cover)
                : Image.network(source, fit: BoxFit.cover),
          ),
        ),
        Positioned(
            top: 4,
            right: 14,
            child: GestureDetector(
              onTap: onDelete,
              child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.close, size: 14, color: Colors.red)),
            ))
      ],
    );
  }

  Widget _buildOperationTab(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedOperation = label.toLowerCase()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: isActive ? _textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1), blurRadius: 4)
                    ]
                  : []),
          child: Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              _iconBtn(
                  Icons.remove, () => value > 0 ? onChange(value - 1) : null),
              SizedBox(
                  width: 30,
                  child: Text("$value",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
              _iconBtn(Icons.add, () => onChange(value + 1)),
            ],
          ),
        )
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: _textPrimary),
      ),
    );
  }

  Widget _buildFancyTextField(TextEditingController c, String label,
      {IconData? icon, bool isNumber = false, int maxLines = 1, Function(String)? onChanged}) {
    return TextFormField(
      controller: c,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: (v) => v!.isEmpty ? 'Required' : null,
      onChanged: onChanged,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: _primaryBeige) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accentGreen)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
    );
  }

  Widget _buildSectionLabel(String text, {double fontSize = 16}) {
    return Text(text,
        style: TextStyle(
            fontSize: fontSize, fontWeight: FontWeight.bold, color: _darkBeige));
  }

  Widget _buildPaymentFrequencyTab(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentFrequency = label.toLowerCase()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _accentGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 4)
                  ]
                : [],
          ),
          child: Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isActive ? Colors.white : _textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildFacilityChip(String label, bool isSelected, Function(bool) onChanged) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: _primaryBeige.withOpacity(0.4),
      onSelected: onChanged,
    );
  }
}

// ============================================================================
// ================= MAP SELECTION SCREEN (NEW) ==============================
// ============================================================================

class MapSelectionScreen extends StatefulWidget {
  final double initialLat;
  final double initialLong;

  const MapSelectionScreen(
      {super.key, this.initialLat = 31.9038, this.initialLong = 35.2034});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  LatLng? _pickedLocation;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != 0.0 && widget.initialLong != 0.0) {
      _pickedLocation = LatLng(widget.initialLat, widget.initialLong);
    } else {
      _pickedLocation = const LatLng(31.9038, 35.2034);
    }
  }

  void _selectLocation(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: const Color(0xFFD4B996),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation!,
              zoom: 14,
            ),
            onTap: _selectLocation,
            markers: _pickedLocation == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('m1'),
                      position: _pickedLocation!,
                      infoWindow: const InfoWindow(title: "Selected Location"),
                    ),
                  },
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_pickedLocation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
