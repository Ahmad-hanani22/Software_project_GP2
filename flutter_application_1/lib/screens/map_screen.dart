import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'property_details_screen.dart';

// --- 🎨 Colors Matching Home Page ---
const Color _primaryColor = Color(0xFF00695C); // Deep Teal
const Color _accentColor = Color(0xFFFFA000); // Amber

class MapScreen extends StatefulWidget {
  final List<dynamic> properties;

  const MapScreen({super.key, required this.properties});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  int _selectedPropertyIndex = -1;

  @override
  Widget build(BuildContext context) {
    // 1. تحديد مركز الخريطة
    LatLng center = const LatLng(32.2211, 35.2544); // Nablus Default
    if (widget.properties.isNotEmpty) {
      try {
        // GeoJSON is [Long, Lat], FlutterMap needs [Lat, Long]
        final firstLoc = widget.properties.first['location']['coordinates'];
        center = LatLng(firstLoc[1], firstLoc[0]);
      } catch (_) {}
    }

    return Scaffold(
      body: Stack(
        children: [
          // --- 1. The Map ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.0,
              onTap: (_, __) => setState(
                  () => _selectedPropertyIndex = -1), // Click map to deselect
            ),
            children: [
              // ✅ استخدام ستايل خرائط حديث (CartoDB Voyager) بدلاً من OSM التقليدي
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.shaqati.app',
              ),

              // ✅ العلامات (Markers)
              MarkerLayer(
                markers: widget.properties.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var p = entry.value;
                  try {
                    final coords = p['location']['coordinates'];
                    final isSelected = _selectedPropertyIndex == idx;

                    return Marker(
                      point: LatLng(coords[1], coords[0]),
                      width: isSelected ? 120 : 90, // تكبير عند الاختيار
                      height: 80,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedPropertyIndex = idx);
                          _mapController.move(LatLng(coords[1], coords[0]),
                              15.0); // تقريب الكاميرا
                        },
                        child: Column(
                          children: [
                            // Price Tag Container
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    isSelected ? _primaryColor : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: _primaryColor, width: 2),
                                boxShadow: [
                                  const BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2))
                                ],
                              ),
                              child: Text(
                                "\$${p['price']}",
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            // Pointer Icon
                            Icon(Icons.location_on,
                                color:
                                    isSelected ? _accentColor : _primaryColor,
                                size: isSelected ? 40 : 30),
                          ],
                        ),
                      ),
                    );
                  } catch (e) {
                    return const Marker(point: LatLng(0, 0), child: SizedBox());
                  }
                }).toList(),
              ),
            ],
          ),

          // --- 2. Back Button ---
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              radius: 24,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // --- 3. Selected Property Card (Floating at Bottom) ---
          if (_selectedPropertyIndex != -1)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PropertyDetailsScreen(
                          property: widget.properties[_selectedPropertyIndex]),
                    ),
                  );
                },
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(20)),
                        child: Image.network(
                          (widget.properties[_selectedPropertyIndex]
                                          ['images'] !=
                                      null &&
                                  widget
                                      .properties[_selectedPropertyIndex]
                                          ['images']
                                      .isNotEmpty)
                              ? widget.properties[_selectedPropertyIndex]
                                  ['images'][0]
                              : 'https://via.placeholder.com/150',
                          width: 130,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),

                      // Details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Type & Operation Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "${widget.properties[_selectedPropertyIndex]['type']} • ${widget.properties[_selectedPropertyIndex]['operation']}"
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryColor),
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Title
                              Text(
                                widget.properties[_selectedPropertyIndex]
                                        ['title'] ??
                                    'N/A',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Location
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on,
                                      size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      "${widget.properties[_selectedPropertyIndex]['city']}, ${widget.properties[_selectedPropertyIndex]['country']}",
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              const Spacer(),

                              // Price & Arrow
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "\$${widget.properties[_selectedPropertyIndex]['price']}",
                                    style: const TextStyle(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18),
                                  ),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 20, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
