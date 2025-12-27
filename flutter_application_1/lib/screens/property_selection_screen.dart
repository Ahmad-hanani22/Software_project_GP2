import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/ownership_management_screen.dart';
import 'package:flutter_application_1/screens/units_management_screen.dart';
import 'package:flutter_application_1/screens/property_history_screen.dart';

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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchProperties();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
      ),
      backgroundColor: _scaffoldBackground,
      body: Column(
        children: [
          // Search Bar
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

          // Properties List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text('Error: $_errorMessage'))
                    : _filteredProperties.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.home_outlined,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No properties found',
                                  style:
                                      TextStyle(fontSize: 18, color: Colors.grey),
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
                                      child: const Icon(Icons.home,
                                          color: Colors.white),
                                    ),
                                    title: Text(
                                      title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('$city, $address'),
                                        Text(
                                          '${type.toString().toUpperCase()} - \$${price.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios,
                                        size: 16),
                                    onTap: () => _navigateToScreen(property),
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

