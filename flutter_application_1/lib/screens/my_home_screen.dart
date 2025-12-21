import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class MyHomeScreen extends StatefulWidget {
  const MyHomeScreen({super.key});

  @override
  State<MyHomeScreen> createState() => _MyHomeScreenState();
}

class _MyHomeScreenState extends State<MyHomeScreen> {
  bool _isLoading = true;
  List<dynamic> _activeContracts = [];
  String? _userId;
  String? _userRole;
  LatLng? _propertyLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    _userRole = prefs.getString('role');

    if (_userId != null && _userRole == 'tenant') {
      await _fetchActiveContracts();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchActiveContracts() async {
    final (ok, data) = await ApiService.getUserContracts(_userId!);
    if (mounted) {
      setState(() {
        if (ok && data is List) {
          // Get only active or rented contracts
          _activeContracts = data
              .where((c) =>
                  c['status'] == 'active' ||
                  c['status'] == 'rented' ||
                  c['status'] == 'expiring_soon')
              .toList();

          // Set property location from first contract if available
          if (_activeContracts.isNotEmpty) {
            final contract = _activeContracts[0];
            final property = contract['propertyId'];
            if (property != null && property['location'] != null) {
              final coords = property['location']['coordinates'];
              if (coords != null && coords.length >= 2) {
                _propertyLocation = LatLng(coords[1], coords[0]);
              }
            }
          }
        }
        _isLoading = false;
      });
    }
  }

  void _openMapNavigation() {
    if (_propertyLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property location not available')),
      );
      return;
    }

    // Open Google Maps with navigation
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${_propertyLocation!.latitude},${_propertyLocation!.longitude}';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_userRole != 'tenant') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Home'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
        body: const Center(
          child: Text('This page is only available for tenants.'),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Home'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activeContracts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Home'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_outlined, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                'No Active Rentals',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You don\'t have any active rental contracts yet.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final contract = _activeContracts[0];
    final property = contract['propertyId'] ?? {};
    final unit = contract['unitId'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Home'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.home,
                            color: const Color(0xFF2E7D32), size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                property['title'] ?? 'Property',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (property['address'] != null)
                                Text(
                                  property['address'] ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Property Details
                    _buildDetailRow(
                      Icons.location_on,
                      'Location',
                      '${property['city'] ?? ''}, ${property['country'] ?? ''}',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.category,
                      'Type',
                      property['type'] ?? 'N/A',
                    ),
                    const SizedBox(height: 12),
                    if (unit['unitNumber'] != null)
                      _buildDetailRow(
                        Icons.door_front_door,
                        'Unit',
                        'Unit ${unit['unitNumber']}',
                      ),
                    if (unit['unitNumber'] != null) const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.square_foot,
                      'Area',
                      '${property['area'] ?? 'N/A'} sqm',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.bed,
                      'Bedrooms',
                      '${property['bedrooms'] ?? 'N/A'}',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.bathroom,
                      'Bathrooms',
                      '${property['bathrooms'] ?? 'N/A'}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Contract Details Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contract Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Start Date',
                      contract['startDate'] != null
                          ? DateFormat('yyyy-MM-dd')
                              .format(DateTime.parse(contract['startDate']))
                          : 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.event,
                      'End Date',
                      contract['endDate'] != null
                          ? DateFormat('yyyy-MM-dd')
                              .format(DateTime.parse(contract['endDate']))
                          : 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.attach_money,
                      'Monthly Rent',
                      '\$${contract['rentAmount'] ?? 'N/A'}',
                    ),
                    const SizedBox(height: 12),
                    if (contract['depositAmount'] != null)
                      _buildDetailRow(
                        Icons.security,
                        'Deposit',
                        '\$${contract['depositAmount']}',
                      ),
                    if (contract['depositAmount'] != null)
                      const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.payment,
                      'Payment Cycle',
                      contract['paymentCycle'] ?? 'Monthly',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.info,
                      'Status',
                      contract['status'] ?? 'N/A',
                      statusColor: _getStatusColor(contract['status']),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Map Section
            if (_propertyLocation != null) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.map, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Property Location',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _openMapNavigation,
                            icon: const Icon(Icons.directions),
                            label: const Text('Navigate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 300,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _propertyLocation!,
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('property'),
                            position: _propertyLocation!,
                            infoWindow: InfoWindow(
                              title: property['title'] ?? 'Property',
                              snippet: property['address'] ?? '',
                            ),
                          ),
                        },
                        onMapCreated: (controller) {
                          // Map controller available if needed
                        },
                        myLocationButtonEnabled: true,
                        myLocationEnabled: true,
                        mapType: MapType.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Amenities
            if (property['amenities'] != null &&
                (property['amenities'] as List).isNotEmpty) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Amenities',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (property['amenities'] as List)
                            .map<Widget>((amenity) => Chip(
                                  label: Text(amenity.toString()),
                                  backgroundColor:
                                      const Color(0xFF2E7D32).withOpacity(0.1),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {Color? statusColor}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: statusColor ?? Colors.black87,
              fontWeight:
                  statusColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'rented':
        return Colors.blue;
      case 'expiring_soon':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
