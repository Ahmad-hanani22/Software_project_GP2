import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'property_details_screen.dart';

class EnhancedMapScreen extends StatefulWidget {
  final List<dynamic> properties;
  final Function(String, dynamic)? onMapControl;

  const EnhancedMapScreen({
    super.key,
    required this.properties,
    this.onMapControl,
  });

  @override
  State<EnhancedMapScreen> createState() => _EnhancedMapScreenState();
}

class _EnhancedMapScreenState extends State<EnhancedMapScreen> {
  final MapController _mapController = MapController();
  int _selectedPropertyIndex = -1;
  String _selectedFilter = 'all';
  double _currentZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMoveEnd) {
        setState(() {
          _currentZoom = _mapController.camera.zoom;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine center
    LatLng center = const LatLng(32.2211, 35.2544); // Nablus Default
    if (widget.properties.isNotEmpty) {
      try {
        final firstLoc = widget.properties.first['location']?['coordinates'];
        if (firstLoc != null && firstLoc.length >= 2) {
          center = LatLng(firstLoc[1], firstLoc[0]);
        }
      } catch (_) {}
    }

    // Filter properties
    final filteredProperties = _getFilteredProperties();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Properties Map'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => _centerOnProperties(),
            tooltip: 'Center',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _currentZoom,
              onTap: (_, __) => setState(() => _selectedPropertyIndex = -1),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.shaqati.app',
              ),
              MarkerLayer(
                markers: _buildMarkers(filteredProperties),
              ),
            ],
          ),
          // Zoom controls
          Positioned(
            right: 16,
            top: 100,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _currentZoom + 1);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _currentZoom - 1);
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
          // Property info card
          if (_selectedPropertyIndex >= 0 && _selectedPropertyIndex < filteredProperties.length)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildPropertyCard(filteredProperties[_selectedPropertyIndex]),
            ),
          // Properties list button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'list',
              onPressed: () => _showPropertiesList(filteredProperties),
              backgroundColor: const Color(0xFF2E7D32),
              icon: const Icon(Icons.list, color: Colors.white),
              label: Text(
                '${filteredProperties.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(List<dynamic> properties) {
    return properties.asMap().entries.map((entry) {
      final index = entry.key;
      final property = entry.value;
      try {
        final coords = property['location']?['coordinates'];
        if (coords == null || coords.length < 2) return Marker(point: const LatLng(0, 0), child: const SizedBox());
        
        final lat = coords[1];
        final lng = coords[0];
        final isSelected = index == _selectedPropertyIndex;
        
        return Marker(
          point: LatLng(lat, lng),
          width: isSelected ? 50 : 40,
          height: isSelected ? 50 : 40,
          child: GestureDetector(
            onTap: () => setState(() => _selectedPropertyIndex = index),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? Colors.red : const Color(0xFF2E7D32),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.home,
                color: Colors.white,
                size: isSelected ? 24 : 20,
              ),
            ),
          ),
        );
      } catch (e) {
        return Marker(point: const LatLng(0, 0), child: const SizedBox());
      }
    }).toList();
  }

  Widget _buildPropertyCard(dynamic property) {
    return Card(
      elevation: 8,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailsScreen(property: property),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      property['title'] ?? 'Property',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property['city'] ?? 'Unknown',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${property['price'] ?? 0}',
                      style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailsScreen(property: property),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> _getFilteredProperties() {
    if (_selectedFilter == 'all') return widget.properties;
    
    return widget.properties.where((p) {
      switch (_selectedFilter) {
        case 'rent':
          return p['operation'] == 'rent';
        case 'sale':
          return p['operation'] == 'sale';
        case 'cheap':
          final price = (p['price'] as num?)?.toDouble() ?? 0;
          return price < 1000;
        case 'expensive':
          final price = (p['price'] as num?)?.toDouble() ?? 0;
          return price > 5000;
        default:
          return true;
      }
    }).toList();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Properties'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('All'),
              value: 'all',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('For Rent'),
              value: 'rent',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('For Sale'),
              value: 'sale',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Cheap (<\$1000)'),
              value: 'cheap',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Expensive (>\$5000)'),
              value: 'expensive',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() => _selectedFilter = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _centerOnProperties() {
    if (widget.properties.isEmpty) return;
    
    try {
      final coords = widget.properties.first['location']?['coordinates'];
      if (coords != null && coords.length >= 2) {
        _mapController.move(LatLng(coords[1], coords[0]), 13.0);
      }
    } catch (_) {}
  }

  void _showPropertiesList(List<dynamic> properties) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Properties (${properties.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final property = properties[index];
                  return ListTile(
                    leading: const Icon(Icons.home, color: Color(0xFF2E7D32)),
                    title: Text(property['title'] ?? 'Property'),
                    subtitle: Text('${property['city'] ?? 'Unknown'} - \$${property['price'] ?? 0}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedPropertyIndex = index);
                      final coords = property['location']?['coordinates'];
                      if (coords != null && coords.length >= 2) {
                        _mapController.move(LatLng(coords[1], coords[0]), 15.0);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
