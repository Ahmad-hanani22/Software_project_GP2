import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/property_details_screen.dart';
import 'package:flutter_application_1/widgets/floating_smart_button.dart';

class BuyScreen extends StatefulWidget {
  const BuyScreen({super.key});

  @override
  State<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends State<BuyScreen> {
  List<dynamic> _properties = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCity = 'All';
  String _selectedType = 'All';
  int? _minPrice;
  int? _maxPrice;
  List<dynamic> _propertyTypes = [];

  @override
  void initState() {
    super.initState();
    _loadPropertyTypes();
    _fetchProperties();
  }

  Future<void> _loadPropertyTypes() async {
    final (success, result) = await ApiService.getPropertyTypes(activeOnly: true);
    if (success && result is List) {
      setState(() {
        _propertyTypes = result;
      });
    } else {
      // Fallback to default types
      _propertyTypes = [
        {'name': 'apartment', 'displayName': 'Apartment'},
        {'name': 'house', 'displayName': 'House'},
        {'name': 'villa', 'displayName': 'Villa'},
        {'name': 'shop', 'displayName': 'Shop'},
      ];
    }
  }

  Future<void> _fetchProperties() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllProperties();
    if (mounted) {
      setState(() {
        if (ok && data is List) {
          _properties = data
              .where((p) => p['operation'] == 'sale' && p['status'] == 'available')
              .toList();
        }
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredProperties {
    return _properties.where((p) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final city = (p['city'] ?? '').toString().toLowerCase();
        final address = (p['address'] ?? '').toString().toLowerCase();
        final matchesCity = city.contains(query);
        final matchesAddress = address.contains(query);
        if (!matchesCity && !matchesAddress) return false;
      }
      if (_selectedCity != 'All' && p['city'] != _selectedCity) return false;
      if (_selectedType != 'All' && p['type'] != _selectedType) return false;
      final price = (p['price'] as num?)?.toInt() ?? 0;
      if (_minPrice != null && price < _minPrice!) return false;
      if (_maxPrice != null && price > _maxPrice!) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Properties'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by city or address...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: ['All', 'Ramallah', 'Nablus', 'Hebron', 'Jenin', 'Jerusalem']
                            .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedCity = value ?? 'All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                              const DropdownMenuItem(value: 'All', child: Text('All')),
                              ..._propertyTypes
                                  .where((type) => type['isActive'] != false)
                                  .map((type) {
                                final name = type['name'] ?? '';
                                final displayName = type['displayName'] ?? name;
                                return DropdownMenuItem(
                                  value: name,
                                  child: Text(displayName),
                                );
                              })
                            ],
                        onChanged: (value) => setState(() => _selectedType = value ?? 'All'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Properties List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProperties.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home_outlined, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 20),
                            Text(
                              'No properties found',
                              style: TextStyle(color: Colors.grey[600], fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredProperties.length,
                        itemBuilder: (context, index) {
                          final property = _filteredProperties[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PropertyDetailsScreen(
                                      property: property,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (property['images'] != null &&
                                        (property['images'] as List).isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          property['images'][0],
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 120,
                                            height: 120,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.home),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.home, size: 50),
                                      ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            property['title'] ?? 'Property',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (property['address'] != null)
                                            Text(
                                              property['address'],
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on,
                                                  size: 16, color: Colors.grey[600]),
                                              Text(
                                                '${property['city'] ?? ''}, ${property['country'] ?? ''}',
                                                style: TextStyle(color: Colors.grey[600]),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (property['bedrooms'] != null)
                                                _buildInfoChip(
                                                    Icons.bed, '${property['bedrooms']}'),
                                              if (property['bathrooms'] != null) ...[
                                                const SizedBox(width: 8),
                                                _buildInfoChip(
                                                    Icons.bathroom, '${property['bathrooms']}'),
                                              ],
                                              if (property['area'] != null) ...[
                                                const SizedBox(width: 8),
                                                _buildInfoChip(
                                                    Icons.square_foot, '${property['area']} sqm'),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '\$${property['price'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: const FloatingSmartButton(),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }
}

