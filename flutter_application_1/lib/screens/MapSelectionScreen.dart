import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapSelectionScreen extends StatefulWidget {
  final double initialLat;
  final double initialLong;

  const MapSelectionScreen(
      {super.key,
      this.initialLat = 31.9038, // إحداثيات افتراضية (مثلاً رام الله/القدس)
      this.initialLong = 35.2034});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  LatLng? _pickedLocation;

  @override
  void initState() {
    super.initState();
    // تهيئة الموقع المختار مبدئياً بالموقع الحالي
    if (widget.initialLat != 0.0 && widget.initialLong != 0.0) {
      _pickedLocation = LatLng(widget.initialLat, widget.initialLong);
    } else {
      _pickedLocation = const LatLng(31.9038, 35.2034); // موقع افتراضي
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
        backgroundColor: const Color(0xFFD4B996), // نفس لون ثيمك
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation!,
              zoom: 14,
            ),
            onTap: _selectLocation, // عند النقر على الخريطة
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
          // زر التأكيد العائم في الأسفل
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                // إرجاع الإحداثيات للشاشة السابقة
                Navigator.of(context).pop(_pickedLocation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32), // اللون الأخضر
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
