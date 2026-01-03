import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // تأكد من إضافة المكتبة

// --- Helper for Alerts ---
enum AppAlertType { success, error, info }

void showAppAlert({
  required BuildContext context,
  required String title,
  required String message,
  AppAlertType type = AppAlertType.info,
}) {
  Color iconColor;
  IconData iconData;
  switch (type) {
    case AppAlertType.success:
      iconColor = Colors.green;
      iconData = Icons.check_circle_outline;
      break;
    case AppAlertType.error:
      iconColor = Colors.red;
      iconData = Icons.error_outline;
      break;
    case AppAlertType.info:
      iconColor = Colors.blue;
      iconData = Icons.info_outline;
      break;
  }

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, color: iconColor, size: 48),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: iconColor)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// --- Property Model ---
class Property {
  final String id;
  String title,
      description,
      type,
      operation,
      currency,
      country,
      city,
      address,
      status;
  double price, area;
  int bedrooms, bathrooms;
  List<String> amenities, images;
  bool verified;
  final DateTime createdAt;
  DateTime? updatedAt;
  Map<String, dynamic> location;

  Property(
      {required this.id,
      required this.title,
      required this.description,
      required this.type,
      required this.operation,
      required this.price,
      required this.currency,
      required this.country,
      required this.city,
      required this.address,
      required this.area,
      required this.bedrooms,
      required this.bathrooms,
      required this.amenities,
      required this.images,
      required this.status,
      required this.verified,
      required this.createdAt,
      this.updatedAt,
      required this.location});

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['_id'] ?? '',
      title: json['title'] ?? 'N/A',
      description: json['description'] ?? '',
      type: json['type'] ?? 'apartment',
      operation: json['operation'] ?? 'rent',
      price: (json['price'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'USD',
      country: json['country'] ?? '',
      city: json['city'] ?? '',
      address: json['address'] ?? '',
      area: (json['area'] ?? 0.0).toDouble(),
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      amenities: List<String>.from(json['amenities'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      status: json['status'] ?? 'pending_approval',
      verified: json['verified'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      location: json['location'] ??
          {
            'type': 'Point',
            'coordinates': [0.0, 0.0]
          },
    );
  }
}

// --- Constants ---
const double _kWebBreakpoint = 850.0;
const Color _primaryGreen = Color(0xFF2E7D32);
const Color _lightGreenAccent = Color(0xFFE8F5E9);
const Color _scaffoldBackground = Color(0xFFF5F5DC);
const Color _cardBackground = Colors.white;
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

// ============================================================================
// ================= MAIN SCREEN =============================================
// ============================================================================

class AdminPropertyManagementScreen extends StatefulWidget {
  const AdminPropertyManagementScreen({super.key});
  @override
  State<AdminPropertyManagementScreen> createState() =>
      _AdminPropertyManagementScreenState();
}

class _AdminPropertyManagementScreenState
    extends State<AdminPropertyManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Property> _properties = [];
  List<Property> _filteredProperties = [];
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();
    _fetchProperties();
    _searchController.addListener(_filterProperties);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProperties);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProperties() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllProperties();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _properties =
            (data as List).map((json) => Property.fromJson(json)).toList();
        _filterProperties();
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  void _filterProperties() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProperties = _properties.where((prop) {
        final matchesSearch = prop.title.toLowerCase().contains(query) ||
            prop.city.toLowerCase().contains(query) ||
            prop.address.toLowerCase().contains(query);
        final matchesStatus = _selectedStatusFilter == null ||
            _selectedStatusFilter == 'All Statuses' ||
            prop.status.toLowerCase() == _selectedStatusFilter!.toLowerCase();
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  // --- NEW: Open Bottom Sheet Form ---
  void _openPropertyForm({Property? property}) {
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
        child: AdminPropertyFormSheet(
          property: property,
          onSubmit: (data, isEdit) async {
            Navigator.pop(ctx);
            setState(() => _isLoading = true);

            final (ok, message) = isEdit
                ? await ApiService.updateProperty(
                    id: property!.id, propertyData: data)
                : await ApiService.addProperty(data);

            if (mounted) {
              showAppAlert(
                  context: context,
                  title: ok ? 'Success' : 'Error',
                  message: message,
                  type: ok ? AppAlertType.success : AppAlertType.error);
              if (ok) _fetchProperties();
            }
          },
        ),
      ),
    );
  }

  Future<void> _deleteProperty(String propertyId, String propertyTitle) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: Text('Confirm Deletion',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold)),
                content: Text(
                    'Are you sure you want to delete property "$propertyTitle"?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white),
                      child: const Text('Delete'))
                ]));
    if (confirm != true) return;
    final (ok, message) = await ApiService.deleteProperty(propertyId);
    if (mounted) {
      showAppAlert(
          context: context,
          title: ok ? 'Success' : 'Error',
          message: message,
          type: ok ? AppAlertType.success : AppAlertType.error);
      if (ok) _fetchProperties();
    }
  }

  Future<void> _approveProperty(Property property) async {
    final (ok, message) = await ApiService.updateProperty(
        id: property.id,
        propertyData: {'status': 'available', 'verified': true});
    if (mounted) {
      showAppAlert(
          context: context,
          title: ok ? 'Success' : 'Error',
          message: ok
              ? 'The property "${property.title}" is now available.'
              : message,
          type: ok ? AppAlertType.success : AppAlertType.error);
      if (ok) _fetchProperties();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: _scaffoldBackground,
        appBar: AppBar(
            elevation: 2,
            backgroundColor: _primaryGreen,
            foregroundColor: Colors.white,
            title: const Text('Property Management',
                style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchProperties),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                      onPressed: () => _openPropertyForm(),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Add Property',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _primaryGreen,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)))))
            ]),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primaryGreen))
            : _properties.isEmpty
                ? _buildEmptyState()
                : Column(children: [
                    _buildFilterBar(),
                    Expanded(
                        child: LayoutBuilder(builder: (context, constraints) {
                      if (constraints.maxWidth > _kWebBreakpoint) {
                        return _buildPropertiesGridView(constraints);
                      } else {
                        return _buildPropertiesListView();
                      }
                    }))
                  ]));
  }

  Widget _buildFilterBar() {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        decoration: BoxDecoration(color: _cardBackground, boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ]),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildStatusFilterDropdown()
            ]);
          }
          return Row(children: [
            Expanded(flex: 3, child: _buildSearchBar()),
            const SizedBox(width: 20),
            Expanded(flex: 1, child: _buildStatusFilterDropdown())
          ]);
        }));
  }

  Widget _buildSearchBar() {
    return TextField(
        controller: _searchController,
        decoration: InputDecoration(
            hintText: 'Search properties...',
            prefixIcon: const Icon(Icons.search, color: _primaryGreen),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            filled: true,
            fillColor: _lightGreenAccent.withOpacity(0.5),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16)));
  }

  Widget _buildStatusFilterDropdown() {
    return DropdownButtonFormField<String>(
        value: _selectedStatusFilter ?? 'All Statuses',
        decoration: InputDecoration(
            prefixIcon: const Icon(Icons.filter_list_alt, color: _primaryGreen),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            filled: true,
            fillColor: _lightGreenAccent.withOpacity(0.5),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
        items: const ['All Statuses', 'pending_approval', 'available', 'rented']
            .map((status) => DropdownMenuItem(
                value: status,
                child: Text(status.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                        color: _textPrimary, fontWeight: FontWeight.w500))))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedStatusFilter = value;
            _filterProperties();
          });
        },
        dropdownColor: _cardBackground);
  }

  Widget _buildPropertiesListView() {
    return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _filteredProperties.length,
        itemBuilder: (context, index) {
          final property = _filteredProperties[index];
          return _buildMobilePropertyCard(property);
        });
  }

  Widget _buildPropertiesGridView(BoxConstraints constraints) {
    int crossAxisCount = 3;
    if (constraints.maxWidth > 1400) crossAxisCount = 4;
    return GridView.builder(
        padding: const EdgeInsets.all(24.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 0.8),
        itemCount: _filteredProperties.length,
        itemBuilder: (context, index) {
          final property = _filteredProperties[index];
          return _buildWebPropertyCard(property);
        });
  }

  Widget _buildMobilePropertyCard(Property property) {
    return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildPropertyImage(property, width: 130, height: 160),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusChip(property.status),
                          const SizedBox(height: 8),
                          Text(property.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('${property.city}, ${property.address}',
                              style: const TextStyle(
                                  color: _textSecondary, fontSize: 12),
                              maxLines: 1),
                          const SizedBox(height: 8),
                          Text(
                              NumberFormat.simpleCurrency(decimalDigits: 0)
                                  .format(property.price),
                              style: const TextStyle(
                                  color: _primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ])))
          ]),
          const Divider(height: 1),
          _buildActionButtons(property)
        ]));
  }

  Widget _buildWebPropertyCard(Property property) {
    return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            _buildPropertyImage(property, width: double.infinity, height: 180),
            Positioned(
                top: 10, right: 10, child: _buildStatusChip(property.status)),
          ]),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(property.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(property.city,
                            style: const TextStyle(
                                color: _textSecondary, fontSize: 13)),
                        const Spacer(),
                        Text(
                            NumberFormat.simpleCurrency(decimalDigits: 0)
                                .format(property.price),
                            style: const TextStyle(
                                color: _primaryGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ]))),
          _buildActionButtons(property)
        ]));
  }

  Widget _buildPropertyImage(Property property,
      {required double width, required double height}) {
    return SizedBox(
        width: width,
        height: height,
        child: property.images.isNotEmpty
            ? Image.network(property.images.first,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, color: Colors.grey)))
            : Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.image, color: Colors.grey)));
  }

  Widget _buildActionButtons(Property property) {
    return Container(
        color: Colors.grey.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (property.status == 'pending_approval')
            TextButton.icon(
                icon: const Icon(Icons.check_circle,
                    size: 16, color: Colors.amber),
                label: const Text('Approve',
                    style: TextStyle(color: Colors.amber)),
                onPressed: () => _approveProperty(property)),
          IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
              onPressed: () => _openPropertyForm(property: property)),
          IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteProperty(property.id, property.title)),
        ]));
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    if (status == 'available') color = Colors.green;
    if (status == 'pending_approval') color = Colors.amber;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12)),
        child: Text(status.toUpperCase(),
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _buildEmptyState() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.inbox, size: 64, color: Colors.grey),
      const SizedBox(height: 16),
      const Text('No properties found'),
      const SizedBox(height: 16),
      ElevatedButton(
          onPressed: () => _openPropertyForm(),
          child: const Text('Add Property'))
    ]));
  }
}

// ============================================================================
// ================= PROFESSIONAL FORM SHEET (Admin) =========================
// ============================================================================

class AdminPropertyFormSheet extends StatefulWidget {
  final Property? property;
  final Function(Map<String, dynamic> data, bool isEdit) onSubmit;

  const AdminPropertyFormSheet(
      {super.key, this.property, required this.onSubmit});

  @override
  State<AdminPropertyFormSheet> createState() => _AdminPropertyFormSheetState();
}

class _AdminPropertyFormSheetState extends State<AdminPropertyFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final titleCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final countryCtrl = TextEditingController();

  // Location
  double _latitude = 0.0;
  double _longitude = 0.0;

  // Selections
  String _selectedType = 'apartment';
  String _selectedOperation = 'rent';
  String _selectedStatus = 'pending_approval'; // Admin specific
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
  String? _heatingType; // Heating type
  String? _coolingType; // Cooling type
  String? _securityFeatures; // Security features
  String? _nearbyFacilities; // Nearby facilities
  String? _model3dUrl; // 3D model URL

  // Amenities & Images
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
      titleCtrl.text = p.title;
      priceCtrl.text = p.price.toString();
      areaCtrl.text = p.area.toString();
      descCtrl.text = p.description;
      addressCtrl.text = p.address;
      cityCtrl.text = p.city;
      countryCtrl.text = p.country;
      _selectedType = p.type;
      _selectedOperation = p.operation;
      _selectedStatus = p.status;
      _bedrooms = p.bedrooms;
      _bathrooms = p.bathrooms;
      _existingImages = List.from(p.images);
      _selectedAmenities = List.from(p.amenities);

      if (p.location['coordinates'] != null) {
        final coords = p.location['coordinates'];
        _longitude = (coords[0] as num).toDouble();
        _latitude = (coords[1] as num).toDouble();
      }

      // Load additional fields - need to fetch full property data from API
      // Since Property model doesn't include these fields, we'll load them separately
      _loadAdditionalPropertyData();
    }
  }

  Future<void> _loadAdditionalPropertyData() async {
    if (widget.property == null) return;

    try {
      // Fetch all properties and find the one we're editing
      final (ok, data) = await ApiService.getAllProperties();
      if (ok && data is List) {
        final propertyJson = data.cast<Map<String, dynamic>>().firstWhere(
              (p) => p['_id'] == widget.property!.id,
              orElse: () => <String, dynamic>{},
            );

        if (propertyJson.isNotEmpty) {
          setState(() {
            _paymentFrequency = propertyJson['paymentFrequency'] ??
                propertyJson['paymentCycle'];
            _rentDurationMonths = propertyJson['rentDurationMonths'];
            _propertyCondition = propertyJson['condition'];
            _furnishingStatus = propertyJson['furnishingStatus'];
            _parkingSpaces = propertyJson['parkingSpaces'] ?? 0;
            _floors = propertyJson['floors'] ?? 1;
            _yearBuilt = propertyJson['yearBuilt']?.toString();
            _hasElevator = propertyJson['hasElevator'] ?? false;
            _hasGarden = propertyJson['hasGarden'] ?? false;
            _hasBalcony = propertyJson['hasBalcony'] ?? false;
            _hasPool = propertyJson['hasPool'] ?? false;
            _heatingType = propertyJson['heatingType'];
            _coolingType = propertyJson['coolingType'];
            _securityFeatures = propertyJson['securityFeatures'];
            _nearbyFacilities = propertyJson['nearbyFacilities'];
            _model3dUrl = propertyJson['model3dUrl'];
          });
        }
      }
    } catch (e) {
      // Silently fail - fields will remain at defaults
      print('Error loading additional property data: $e');
    }
  }

  Future<void> _loadPropertyTypes() async {
    setState(() => _loadingTypes = true);
    final (success, result) =
        await ApiService.getPropertyTypes(activeOnly: true);
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
        content: Text("Location updated!"),
        backgroundColor: _primaryGreen,
        duration: Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
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

        // Form Body
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Status (Admin Feature)
                _buildSectionLabel("Status"),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: _inputDeco("Property Status"),
                  items: ['pending_approval', 'available', 'rented']
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.replaceAll('_', ' ').toUpperCase())))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v!),
                ),
                const SizedBox(height: 20),

                // 2. Operation
                _buildSectionLabel("Operation Type"),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    children: [
                      _buildOperationTab('rent'),
                      _buildOperationTab('sale'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Type
                _loadingTypes
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _propertyTypes
                              .where((type) => type['isActive'] != false)
                              .map((type) {
                            final typeName = type['name'] ?? '';
                            final displayName =
                                type['displayName'] ?? typeName.toUpperCase();
                            final isSelected = _selectedType == typeName;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: FilterChip(
                                selected: isSelected,
                                label: Text(displayName.toUpperCase()),
                                selectedColor: _primaryGreen,
                                labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : _textPrimary),
                                onSelected: (v) =>
                                    setState(() => _selectedType = typeName),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                const SizedBox(height: 20),

                // 4. Details
                _buildSectionLabel("Details"),
                const SizedBox(height: 10),
                _buildTextField(titleCtrl, "Title", Icons.title),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            priceCtrl, "Price", Icons.attach_money,
                            isNum: true)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _buildTextField(
                            areaCtrl, "Area (m²)", Icons.square_foot,
                            isNum: true)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField(descCtrl, "Description", Icons.description,
                    maxLines: 3),
                const SizedBox(height: 20),

                // 5. Rooms
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCounter("Bedrooms", _bedrooms,
                        (v) => setState(() => _bedrooms = v)),
                    _buildCounter("Bathrooms", _bathrooms,
                        (v) => setState(() => _bathrooms = v)),
                  ],
                ),
                const SizedBox(height: 20),

                // 6. Amenities
                _buildSectionLabel("Amenities"),
                Wrap(
                  spacing: 8,
                  children: _availableAmenities.map((a) {
                    final isSelected = _selectedAmenities.contains(a);
                    return ChoiceChip(
                      label: Text(a),
                      selected: isSelected,
                      selectedColor: _primaryGreen.withOpacity(0.3),
                      onSelected: (v) => setState(() => v
                          ? _selectedAmenities.add(a)
                          : _selectedAmenities.remove(a)),
                    );
                  }).toList(),
                ),
                // Rental Information (only for rent)
                if (_selectedOperation == 'rent') ...[
                  const SizedBox(height: 20),
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
                        _buildPaymentFrequencyTab(
                            'daily', _paymentFrequency == 'daily'),
                        _buildPaymentFrequencyTab(
                            'weekly', _paymentFrequency == 'weekly'),
                        _buildPaymentFrequencyTab(
                            'monthly', _paymentFrequency == 'monthly'),
                        _buildPaymentFrequencyTab(
                            'yearly', _paymentFrequency == 'yearly'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    TextEditingController(
                        text: _rentDurationMonths?.toString() ?? ''),
                    "Rent Duration (Months)",
                    Icons.calendar_today,
                    isNum: true,
                    onChanged: (value) {
                      _rentDurationMonths = int.tryParse(value);
                    },
                  ),
                ],
                // Additional Property Details
                const SizedBox(height: 20),
                _buildSectionLabel("Additional Property Details"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        TextEditingController(text: _parkingSpaces.toString()),
                        "Parking Spaces",
                        Icons.local_parking,
                        isNum: true,
                        onChanged: (value) {
                          _parkingSpaces = int.tryParse(value) ?? 0;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        TextEditingController(text: _floors.toString()),
                        "Floors",
                        Icons.layers,
                        isNum: true,
                        onChanged: (value) {
                          _floors = int.tryParse(value) ?? 1;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  TextEditingController(text: _yearBuilt ?? ''),
                  "Year Built",
                  Icons.calendar_today,
                  isNum: true,
                  onChanged: (value) {
                    _yearBuilt = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _propertyCondition,
                  decoration: _inputDeco("Property Condition"),
                  items: ['New', 'Used', 'Under Construction', 'Renovated']
                      .map((condition) => DropdownMenuItem(
                            value: condition,
                            child: Text(condition),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _propertyCondition = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _furnishingStatus,
                  decoration: _inputDeco("Furnishing Status"),
                  items: ['Furnished', 'Unfurnished', 'Semi-Furnished']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _furnishingStatus = value),
                ),
                const SizedBox(height: 10),
                _buildSectionLabel("Facilities", fontSize: 14),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFacilityChip("Elevator", _hasElevator,
                        (val) => setState(() => _hasElevator = val)),
                    _buildFacilityChip("Garden", _hasGarden,
                        (val) => setState(() => _hasGarden = val)),
                    _buildFacilityChip("Balcony", _hasBalcony,
                        (val) => setState(() => _hasBalcony = val)),
                    _buildFacilityChip("Pool", _hasPool,
                        (val) => setState(() => _hasPool = val)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  TextEditingController(text: _heatingType ?? ''),
                  "Heating Type (e.g., Central, Electric)",
                  Icons.ac_unit,
                  onChanged: (value) {
                    _heatingType = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  TextEditingController(text: _coolingType ?? ''),
                  "Cooling Type (e.g., AC, Fan)",
                  Icons.ac_unit,
                  onChanged: (value) {
                    _coolingType = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  TextEditingController(text: _securityFeatures ?? ''),
                  "Security Features",
                  Icons.security,
                  maxLines: 2,
                  onChanged: (value) {
                    _securityFeatures = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  TextEditingController(text: _nearbyFacilities ?? ''),
                  "Nearby Facilities",
                  Icons.local_activity,
                  maxLines: 2,
                  onChanged: (value) {
                    _nearbyFacilities = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 10),
                _buildTextField(
                  TextEditingController(text: _model3dUrl ?? ''),
                  "3D Model URL (Optional)",
                  Icons.view_in_ar,
                  onChanged: (value) {
                    _model3dUrl = value.isEmpty ? null : value;
                  },
                ),
                const SizedBox(height: 20),

                // 7. Location (Map)
                _buildSectionLabel("Location"),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickLocation,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300)),
                    child: Row(
                      children: [
                        const Icon(Icons.map, color: _primaryGreen),
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
                                      fontWeight: FontWeight.bold)),
                              Text(
                                  _latitude == 0
                                      ? "Tap to pin location"
                                      : "$_latitude, $_longitude",
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
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
                _buildTextField(addressCtrl, "Detailed Address", Icons.home),
                const SizedBox(height: 20),

                // 8. Images
                _buildSectionLabel("Images"),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      InkWell(
                        onTap: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickMultiImage();
                          setState(() => _newImages.addAll(picked));
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(color: _primaryGreen),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.add_a_photo,
                              color: _primaryGreen),
                        ),
                      ),
                      ..._existingImages.map((url) => _buildThumb(url, false,
                          () => setState(() => _existingImages.remove(url)))),
                      ..._newImages.map((file) => FutureBuilder<Uint8List>(
                          future: file.readAsBytes(),
                          builder: (_, snap) => snap.hasData
                              ? _buildThumb(snap.data, true,
                                  () => setState(() => _newImages.remove(file)))
                              : const SizedBox(
                                  width: 100,
                                  child: Center(
                                      child: CircularProgressIndicator())))),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),

        // Submit Button
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
              onPressed: _isUploading ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
      'status': _selectedStatus,
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

  // --- Helpers for Form ---

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
                    child: Icon(Icons.close, size: 14, color: Colors.red))))
      ],
    );
  }

  Widget _buildOperationTab(String label) {
    final isActive = _selectedOperation == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedOperation = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController c, String lbl, IconData icon,
      {bool isNum = false, int maxLines = 1, Function(String)? onChanged}) {
    return TextFormField(
      controller: c,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: (v) => v!.isEmpty ? 'Required' : null,
      onChanged: onChanged,
      decoration: _inputDeco(lbl, icon: icon),
    );
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: _primaryGreen) : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16));
  }

  Widget _buildCounter(String label, int val, Function(int) onChange) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => val > 0 ? onChange(val - 1) : null),
            Text("$val",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => onChange(val + 1)),
          ],
        ),
      )
    ]);
  }

  Widget _buildSectionLabel(String t, {double fontSize = 16}) => Text(t,
      style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: _primaryGreen));

  Widget _buildPaymentFrequencyTab(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentFrequency = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : _textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFacilityChip(
      String label, bool isSelected, Function(bool) onChanged) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: _primaryGreen.withOpacity(0.3),
      onSelected: onChanged,
    );
  }
}

// ============================================================================
// ================= MAP SELECTION SCREEN ====================================
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: _primaryGreen,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation!,
              zoom: 14,
            ),
            onTap: (pos) => setState(() => _pickedLocation = pos),
            markers: _pickedLocation == null
                ? {}
                : {
                    Marker(
                        markerId: const MarkerId('m1'),
                        position: _pickedLocation!)
                  },
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_pickedLocation),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Confirm Location',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
