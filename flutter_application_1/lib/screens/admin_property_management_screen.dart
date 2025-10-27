// lib/screens/admin_property_management_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

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

const double _kWebBreakpoint = 850.0;
const Color _primaryGreen = Color(0xFF2E7D32);
const Color _lightGreenAccent = Color(0xFFE8F5E9);
const Color _scaffoldBackground = Color(0xFFF5F5DC);
const Color _cardBackground = Colors.white;
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

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

  Future<void> _showCreateEditPropertyDialog({Property? property}) async {
    final isEditing = property != null;
    final formKey = GlobalKey<FormState>();

    final titleCtrl = TextEditingController(text: property?.title);
    final descCtrl = TextEditingController(text: property?.description);
    final priceCtrl = TextEditingController(text: property?.price.toString());
    final currencyCtrl =
        TextEditingController(text: property?.currency ?? 'USD');
    final countryCtrl = TextEditingController(text: property?.country);
    final cityCtrl = TextEditingController(text: property?.city);
    final addressCtrl = TextEditingController(text: property?.address);
    final areaCtrl = TextEditingController(text: property?.area.toString());
    final bedroomsCtrl =
        TextEditingController(text: property?.bedrooms.toString());
    final bathroomsCtrl =
        TextEditingController(text: property?.bathrooms.toString());
    final amenitiesCtrl =
        TextEditingController(text: property?.amenities.join(', '));
    final lonCtrl = TextEditingController(
        text: property?.location['coordinates'][0].toString());
    final latCtrl = TextEditingController(
        text: property?.location['coordinates'][1].toString());

    String selectedType = property?.type ?? 'apartment';
    String selectedOperation = property?.operation ?? 'rent';
    String selectedStatus = property?.status ?? 'pending_approval';

    List<String> existingImageUrls = List<String>.from(property?.images ?? []);
    List<XFile> newImages = [];
    bool isUploading = false;
    final ImagePicker picker = ImagePicker();

    Future<void> pickImages(StateSetter setDialogState) async {
      final List<XFile> pickedFiles = await picker.pickMultiImage();
      setDialogState(() => newImages.addAll(pickedFiles));
    }

    await showDialog(
      context: context,
      barrierDismissible: !isUploading,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEditing ? 'Edit Property' : 'Create New Property',
                style: TextStyle(
                    color: _primaryGreen, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.85,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogSectionTitle(
                          "Basic Info", Icons.info_outline),
                      _buildTextField(titleCtrl, 'Title', Icons.title,
                          isRequired: true),
                      const SizedBox(height: 15),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(priceCtrl, 'Price',
                                Icons.monetization_on_outlined,
                                isNumeric: true, isRequired: true)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _buildTextField(
                                currencyCtrl, 'Currency', Icons.attach_money)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _buildTextField(
                                areaCtrl, 'Area (sqm)', Icons.square_foot,
                                isNumeric: true)),
                      ]),
                      const SizedBox(height: 15),
                      Row(children: [
                        Expanded(
                            child: _buildDropdown(
                                selectedType,
                                'Type',
                                ['apartment', 'house', 'villa', 'shop'],
                                (v) =>
                                    setDialogState(() => selectedType = v!))),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _buildDropdown(
                                selectedOperation,
                                'Operation',
                                ['rent', 'sale'],
                                (v) => setDialogState(
                                    () => selectedOperation = v!))),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _buildDropdown(
                                selectedStatus,
                                'Status',
                                ['pending_approval', 'available', 'rented'],
                                (v) =>
                                    setDialogState(() => selectedStatus = v!))),
                      ]),
                      const SizedBox(height: 20),
                      _buildDialogSectionTitle(
                          "Location", Icons.location_on_outlined),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(
                                countryCtrl, 'Country', Icons.flag_outlined)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _buildTextField(
                                cityCtrl, 'City', Icons.location_city)),
                      ]),
                      const SizedBox(height: 15),
                      _buildTextField(addressCtrl, 'Full Address',
                          Icons.home_work_outlined),
                      const SizedBox(height: 15),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(
                                lonCtrl, 'Longitude', Icons.map,
                                isNumeric: true)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _buildTextField(
                                latCtrl, 'Latitude', Icons.map,
                                isNumeric: true)),
                      ]),
                      const SizedBox(height: 20),
                      _buildDialogSectionTitle("Details", Icons.list_alt),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(
                                bedroomsCtrl, 'Bedrooms', Icons.bed,
                                isNumeric: true)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _buildTextField(
                                bathroomsCtrl, 'Bathrooms', Icons.bathtub,
                                isNumeric: true)),
                      ]),
                      const SizedBox(height: 15),
                      _buildTextField(amenitiesCtrl,
                          'Amenities (comma-separated)', Icons.pool),
                      const SizedBox(height: 20),
                      _buildDialogSectionTitle(
                          "Description", Icons.description),
                      _buildTextField(
                          descCtrl, 'Property Description', Icons.notes,
                          maxLines: 4),
                      const SizedBox(height: 20),
                      _buildDialogSectionTitle("Images", Icons.image),
                      _buildProfessionalImagePicker(
                          existingImageUrls,
                          newImages,
                          setDialogState,
                          () => pickImages(setDialogState)),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isUploading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                icon: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(
                    isUploading ? 'Uploading & Saving...' : 'Save Property'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: isUploading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isUploading = true);

                        List<String> uploadedImageUrls = [];
                        for (var imageFile in newImages) {
                          final (success, data) =
                              await ApiService.uploadImage(imageFile);
                          if (success && data != null) {
                            uploadedImageUrls.add(data);
                          } else {
                            if (mounted)
                              showAppAlert(
                                  context: context,
                                  title: 'Upload Failed',
                                  message:
                                      'Could not upload ${imageFile.name}. Reason: $data',
                                  type: AppAlertType.error);
                            setDialogState(() => isUploading = false);
                            return;
                          }
                        }

                        final finalImageUrls = [
                          ...existingImageUrls,
                          ...uploadedImageUrls
                        ];
                        final propertyData = {
                          'title': titleCtrl.text,
                          'description': descCtrl.text,
                          'price': double.tryParse(priceCtrl.text) ?? 0,
                          'currency': currencyCtrl.text,
                          'country': countryCtrl.text,
                          'city': cityCtrl.text,
                          'address': addressCtrl.text,
                          'area': double.tryParse(areaCtrl.text) ?? 0,
                          'bedrooms': int.tryParse(bedroomsCtrl.text) ?? 0,
                          'bathrooms': int.tryParse(bathroomsCtrl.text) ?? 0,
                          'amenities': amenitiesCtrl.text
                              .split(',')
                              .map((e) => e.trim())
                              .where((e) => e.isNotEmpty)
                              .toList(),
                          'images': finalImageUrls,
                          'location': {
                            'type': 'Point',
                            'coordinates': [
                              double.tryParse(lonCtrl.text) ?? 0,
                              double.tryParse(latCtrl.text) ?? 0
                            ]
                          },
                          'type': selectedType,
                          'operation': selectedOperation,
                          'status': selectedStatus,
                        };

                        final (ok, message) = isEditing
                            ? await ApiService.updateProperty(
                                id: property!.id, propertyData: propertyData)
                            : await ApiService.addProperty(propertyData);

                        if (mounted) {
                          Navigator.of(ctx).pop();
                          showAppAlert(
                              context: context,
                              title: ok ? 'Success' : 'Error',
                              message: message,
                              type: ok
                                  ? AppAlertType.success
                                  : AppAlertType.error);
                          if (ok) _fetchProperties();
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool isNumeric = false, bool isRequired = false, int maxLines = 1}) {
    return TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: _primaryGreen, size: 22),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryGreen, width: 2)),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.multiline,
        maxLines: maxLines,
        validator: isRequired
            ? (v) => v!.isEmpty ? '$label is required' : null
            : null);
  }

  Widget _buildDropdown(String value, String label, List<String> items,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.tune, color: _primaryGreen, size: 22),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primaryGreen, width: 2)),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
        items: items
            .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 14))))
            .toList(),
        onChanged: onChanged);
  }

  Widget _buildDialogSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0, top: 5.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryGreen),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _primaryGreen)),
            ],
          ),
          const Divider(thickness: 1.5, height: 20),
        ],
      ),
    );
  }

  Widget _buildProfessionalImagePicker(List<String> existingUrls,
      List<XFile> newFiles, StateSetter setState, VoidCallback onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.05),
              border: Border.all(
                  color: _primaryGreen.withOpacity(0.4),
                  width: 2,
                  style: BorderStyle
                      .solid), // Simulated dashed by using light solid
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.cloud_upload_outlined,
                    size: 40, color: _primaryGreen),
                SizedBox(height: 8),
                Text("Click here to select images",
                    style: TextStyle(
                        color: _primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text("Supports JPG, PNG",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (existingUrls.isNotEmpty || newFiles.isNotEmpty) ...[
          const SizedBox(height: 15),
          const Text("Selected Images:",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: _textSecondary)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300)),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ...existingUrls.map((url) => _buildImageThumbnail(
                    Image.network(url,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Center(
                            child:
                                Icon(Icons.broken_image, color: Colors.grey))),
                    () => setState(() => existingUrls.remove(url)),
                    isNetwork: true)),
                ...newFiles.map((file) => _buildImageThumbnail(
                    kIsWeb
                        ? Image.network(file.path, fit: BoxFit.cover)
                        : Image.file(File(file.path), fit: BoxFit.cover),
                    () => setState(() => newFiles.remove(file)),
                    isNetwork: false)),
              ],
            ),
          )
        ]
      ],
    );
  }

  Widget _buildImageThumbnail(Widget imageWidget, VoidCallback onRemove,
      {required bool isNetwork}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade400),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ]),
          clipBehavior: Clip.antiAlias,
          child: imageWidget,
        ),
        Positioned(
          top: -8,
          right: -8,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
        if (isNetwork)
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 2),
                color: Colors.black54,
                child: const Text("Existing",
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ))
      ],
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
                    'Are you sure you want to delete property "$propertyTitle"? This cannot be undone.'),
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
      if (ok) {
        _fetchProperties();
      }
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
      if (ok) {
        _fetchProperties();
      }
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
            centerTitle: false,
            actions: [
              IconButton(
                  tooltip: 'Refresh Properties',
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchProperties),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                      onPressed: () => _showCreateEditPropertyDialog(),
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
            : _errorMessage != null
                ? _buildErrorWidget()
                : Column(children: [
                    _buildFilterBar(),
                    Expanded(
                        child: _filteredProperties.isEmpty
                            ? _buildEmptyState()
                            : LayoutBuilder(builder: (context, constraints) {
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
            hintText: 'Search by title, city, or address...',
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
    int crossAxisCount = 2;
    if (constraints.maxWidth > 1600) {
      crossAxisCount = 4;
    } else if (constraints.maxWidth > 1100) {
      crossAxisCount = 3;
    }
    return GridView.builder(
        padding: const EdgeInsets.all(24.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 0.85),
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
            _buildPropertyImage(property, width: 130, height: 180),
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
                                  fontSize: 18,
                                  color: _textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.location_on,
                                size: 14, color: _textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(
                                    '${property.city}, ${property.address}',
                                    style: const TextStyle(
                                        color: _textSecondary, fontSize: 13),
                                    overflow: TextOverflow.ellipsis)),
                          ]),
                          const SizedBox(height: 8),
                          Wrap(runSpacing: 8, spacing: 8, children: [
                            _buildInfoBadge(
                                Icons.bed, '${property.bedrooms} Beds'),
                            _buildInfoBadge(
                                Icons.bathtub, '${property.bathrooms} Baths'),
                            _buildInfoBadge(Icons.square_foot,
                                '${property.area.toInt()} m²'),
                          ]),
                          const SizedBox(height: 12),
                          Text(
                              NumberFormat.simpleCurrency(
                                      locale: 'en_US', decimalDigits: 0)
                                  .format(property.price),
                              style: const TextStyle(
                                  color: _primaryGreen,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18)),
                        ])))
          ]),
          const Divider(height: 1),
          _buildActionButtons(property)
        ]));
  }

  Widget _buildWebPropertyCard(Property property) {
    return Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            _buildPropertyImage(property, width: double.infinity, height: 200),
            Positioned(
                top: 12, right: 12, child: _buildStatusChip(property.status)),
          ]),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(property.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: _textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.location_on,
                                    size: 16, color: _textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(
                                        property.address.isNotEmpty
                                            ? property.address
                                            : '${property.city}, ${property.country}',
                                        style: const TextStyle(
                                            color: _textSecondary,
                                            fontSize: 14),
                                        overflow: TextOverflow.ellipsis)),
                              ]),
                            ]),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _buildInfoBadge(
                                  Icons.bed, '${property.bedrooms} Beds'),
                              const SizedBox(width: 12),
                              _buildInfoBadge(
                                  Icons.bathtub, '${property.bathrooms} Baths'),
                              const SizedBox(width: 12),
                              _buildInfoBadge(Icons.square_foot,
                                  '${property.area.toInt()} m²'),
                            ]),
                        Text(
                            '${NumberFormat.simpleCurrency(locale: 'en_US', decimalDigits: 0).format(property.price)} / ${property.operation == 'rent' ? 'month' : ''}',
                            style: const TextStyle(
                                color: _primaryGreen,
                                fontWeight: FontWeight.w900,
                                fontSize: 20)),
                      ]))),
          _buildActionButtons(property)
        ]));
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: _lightGreenAccent, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, size: 14, color: _primaryGreen),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primaryGreen))
        ]));
  }

  Widget _buildPropertyImage(Property property,
      {required double width, required double height}) {
    return SizedBox(
        width: width,
        height: height,
        child: property.images.isNotEmpty &&
                Uri.tryParse(property.images.first)?.isAbsolute == true
            ? Image.network(property.images.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                        child: Icon(Icons.broken_image_rounded,
                            size: 40, color: Colors.grey))))
            : Container(
                color: Colors.grey.shade100,
                child: const Center(
                    child: Icon(Icons.add_a_photo_rounded,
                        size: 40, color: Colors.grey))));
  }

  Widget _buildActionButtons(Property property) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(color: Colors.grey.shade50),
        child: Row(children: [
          if (property.status == 'pending_approval')
            Expanded(
              child: ElevatedButton.icon(
                  onPressed: () => _approveProperty(property),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)))),
            ),
          if (property.status == 'pending_approval') const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
                icon: Icon(Icons.edit_rounded,
                    color: Colors.blue.shade700, size: 20),
                tooltip: 'Edit Property',
                onPressed: () =>
                    _showCreateEditPropertyDialog(property: property)),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
                icon: Icon(Icons.delete_rounded,
                    color: Colors.red.shade700, size: 20),
                tooltip: 'Delete Property',
                onPressed: () => _deleteProperty(property.id, property.title)),
          )
        ]));
  }

  Widget _buildStatusChip(String status) {
    Color chipColor, textColor;
    IconData icon;
    String statusText = status.replaceAll('_', ' ').toUpperCase();
    switch (status.toLowerCase()) {
      case 'pending_approval':
        chipColor = Colors.amber.shade100;
        textColor = Colors.amber.shade800;
        icon = Icons.hourglass_top_rounded;
        break;
      case 'available':
        chipColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle_rounded;
        break;
      case 'rented':
        chipColor = Colors.grey.shade300;
        textColor = Colors.grey.shade800;
        icon = Icons.lock_rounded;
        break;
      default:
        chipColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        icon = Icons.info_outline;
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: chipColor, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 6),
          Text(statusText,
              style: TextStyle(
                  color: textColor, fontSize: 11, fontWeight: FontWeight.w800))
        ]));
  }

  Widget _buildErrorWidget() {
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(24.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline_rounded,
                  color: Colors.red.shade300, size: 80),
              const SizedBox(height: 16),
              Text('Oops! Something went wrong.',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary)),
              const SizedBox(height: 8),
              Text(_errorMessage ?? 'Unknown error occurred.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textSecondary, fontSize: 16)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  onPressed: _fetchProperties,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white))
            ])));
  }

  Widget _buildEmptyState() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.real_estate_agent_outlined,
          size: 100, color: Colors.grey.shade300),
      const SizedBox(height: 24),
      const Text('No Properties Yet',
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary)),
      const SizedBox(height: 12),
      const Text('Start by adding your first property listing.',
          style: TextStyle(fontSize: 16, color: _textSecondary)),
      const SizedBox(height: 32),
      ElevatedButton.icon(
          onPressed: () => _showCreateEditPropertyDialog(),
          icon: const Icon(Icons.add_home_rounded),
          label: const Text('Add Property Now'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))
    ]));
  }
}
