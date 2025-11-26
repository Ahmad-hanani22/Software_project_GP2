import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Color Palette for Landlord ---
const Color _primaryColor = Color(0xFF1976D2);
const Color _scaffoldBackground = Color(0xFFF5F5F5);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class LandlordPropertyManagementScreen extends StatefulWidget {
  const LandlordPropertyManagementScreen({super.key});
  @override
  State<LandlordPropertyManagementScreen> createState() =>
      _LandlordPropertyManagementScreenState();
}

class _LandlordPropertyManagementScreenState
    extends State<LandlordPropertyManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _properties = [];
  String? _landlordId;

  @override
  void initState() {
    super.initState();
    _loadLandlordIdAndFetchProperties();
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
      } else {
        _errorMessage = data.toString();
      }
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
                    child: const Text('Cancel')),
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
        backgroundColor: ok ? _primaryColor : Colors.red,
      ));
      if (ok) _fetchProperties();
    }
  }

  Future<void> _showCreateEditPropertyDialog(
      {Map<String, dynamic>? property}) async {
    final isEditing = property != null;
    final formKey = GlobalKey<FormState>();

    // --- 1. Initialize ALL Controllers ---
    final titleCtrl = TextEditingController(text: property?['title']);
    final descCtrl = TextEditingController(text: property?['description']);
    final priceCtrl =
        TextEditingController(text: property?['price']?.toString());
    final countryCtrl = TextEditingController(text: property?['country']);
    final cityCtrl = TextEditingController(text: property?['city']);
    final addressCtrl = TextEditingController(text: property?['address']);
    final areaCtrl = TextEditingController(text: property?['area']?.toString());
    final bedroomsCtrl =
        TextEditingController(text: property?['bedrooms']?.toString());
    final bathroomsCtrl =
        TextEditingController(text: property?['bathrooms']?.toString());
    final amenitiesCtrl = TextEditingController(
        text: (property?['amenities'] as List<dynamic>?)?.join(', '));
    // Handling nested location safely
    final lonCtrl = TextEditingController(
        text: property?['location']?['coordinates']?[0]?.toString() ?? '0.0');
    final latCtrl = TextEditingController(
        text: property?['location']?['coordinates']?[1]?.toString() ?? '0.0');

    String selectedType = property?['type'] ?? 'apartment';
    String selectedOperation = property?['operation'] ?? 'rent';

    List<String> existingImageUrls =
        List<String>.from(property?['images'] ?? []);
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
            title: Text(isEditing ? 'Edit Property' : 'Create New Property'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Basic Info ---
                      const Text("Basic Information",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _primaryColor)),
                      const SizedBox(height: 10),
                      TextFormField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Title', border: OutlineInputBorder()),
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                                controller: priceCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Price',
                                    border: OutlineInputBorder()),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                                controller: areaCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Area (sqm)',
                                    border: OutlineInputBorder()),
                                keyboardType: TextInputType.number),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                          controller: descCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder()),
                          maxLines: 3),

                      const SizedBox(height: 20),
                      // --- Type & Operation ---
                      const Text("Details & Type",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _primaryColor)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: const InputDecoration(
                                  labelText: 'Type',
                                  border: OutlineInputBorder()),
                              items: ['apartment', 'house', 'villa', 'shop']
                                  .map((t) => DropdownMenuItem(
                                      value: t, child: Text(t.toUpperCase())))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => selectedType = v!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedOperation,
                              decoration: const InputDecoration(
                                  labelText: 'Operation',
                                  border: OutlineInputBorder()),
                              items: ['rent', 'sale']
                                  .map((t) => DropdownMenuItem(
                                      value: t, child: Text(t.toUpperCase())))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => selectedOperation = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  controller: bedroomsCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Bedrooms',
                                      border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextFormField(
                                  controller: bathroomsCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Bathrooms',
                                      border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                          controller: amenitiesCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Amenities (comma separated)',
                              border: OutlineInputBorder())),

                      const SizedBox(height: 20),
                      // --- Location ---
                      const Text("Location",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _primaryColor)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  controller: countryCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Country',
                                      border: OutlineInputBorder()))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextFormField(
                                  controller: cityCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'City',
                                      border: OutlineInputBorder()))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                          controller: addressCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Address',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  controller: latCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Latitude',
                                      border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextFormField(
                                  controller: lonCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Longitude',
                                      border: OutlineInputBorder()),
                                  keyboardType: TextInputType.number)),
                        ],
                      ),

                      const SizedBox(height: 20),
                      // --- Images ---
                      const Text("Images",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _primaryColor)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                          icon: const Icon(Icons.image),
                          label: const Text('Select Images'),
                          onPressed: () => pickImages(setDialogState),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white)),
                      const SizedBox(height: 10),
                      if (existingImageUrls.isNotEmpty || newImages.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...existingImageUrls.map((url) => Stack(
                                  children: [
                                    Image.network(url,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover),
                                    Positioned(
                                        right: 0,
                                        top: 0,
                                        child: InkWell(
                                            onTap: () => setDialogState(() =>
                                                existingImageUrls.remove(url)),
                                            child: const Icon(Icons.cancel,
                                                color: Colors.red))),
                                  ],
                                )),
                            ...newImages.map((file) => FutureBuilder<Uint8List>(
                                  future: file.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                            ConnectionState.done &&
                                        snapshot.data != null) {
                                      return Stack(
                                        children: [
                                          Image.memory(snapshot.data!,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover),
                                          Positioned(
                                              right: 0,
                                              top: 0,
                                              child: InkWell(
                                                  onTap: () => setDialogState(
                                                      () => newImages
                                                          .remove(file)),
                                                  child: const Icon(
                                                      Icons.cancel,
                                                      color: Colors.red))),
                                        ],
                                      );
                                    }
                                    return const SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()));
                                  },
                                )),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isUploading = true);

                        // 1. Upload New Images
                        List<String> uploadedImageUrls = [];
                        for (var imageFile in newImages) {
                          final (success, data) =
                              await ApiService.uploadImage(imageFile);
                          if (success && data != null) {
                            uploadedImageUrls.add(data);
                          }
                        }

                        // 2. Prepare Data
                        final propertyData = {
                          'title': titleCtrl.text,
                          'price': double.tryParse(priceCtrl.text) ?? 0,
                          'description': descCtrl.text,
                          'type': selectedType,
                          'operation': selectedOperation,
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
                          'images': [
                            ...existingImageUrls,
                            ...uploadedImageUrls
                          ],
                          'location': {
                            'type': 'Point',
                            'coordinates': [
                              double.tryParse(lonCtrl.text) ?? 0,
                              double.tryParse(latCtrl.text) ?? 0
                            ]
                          },
                        };

                        // 3. Send to API
                        final (ok, message) = isEditing
                            ? await ApiService.updateProperty(
                                id: property!['_id'],
                                propertyData: propertyData)
                            : await ApiService.addProperty(propertyData);

                        if (mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(message)));
                          if (ok) _fetchProperties();
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white),
                child: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save Property'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: _scaffoldBackground,
        appBar: AppBar(
            elevation: 2,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            title: const Text('My Properties',
                style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                  tooltip: 'Refresh Properties',
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchProperties),
            ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateEditPropertyDialog(),
          label: const Text('Add New Property'),
          icon: const Icon(Icons.add),
          backgroundColor: _primaryColor,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primaryColor))
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _properties.isEmpty
                    ? const Center(
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.house_siding_outlined,
                              size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No Properties Yet',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary)),
                          Text('Click the "Add New Property" button to start.',
                              style: TextStyle(color: _textSecondary)),
                        ],
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _properties.length,
                        itemBuilder: (context, index) {
                          final property = _properties[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: property['images'] != null &&
                                          property['images'].isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.network(
                                              property['images'][0],
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover))
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child:
                                              const Icon(Icons.house_outlined)),
                                  title: Text(property['title'] ?? 'N/A',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${property['city']} - ${property['status']}'),
                                      Text(
                                          NumberFormat.simpleCurrency(
                                                  name: 'USD')
                                              .format(property['price']),
                                          style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  isThreeLine: true,
                                ),
                                ButtonBar(
                                  alignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Edit'),
                                      onPressed: () =>
                                          _showCreateEditPropertyDialog(
                                              property: property),
                                      style: TextButton.styleFrom(
                                          foregroundColor: _primaryColor),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete, size: 16),
                                      label: const Text('Delete'),
                                      onPressed: () =>
                                          _deleteProperty(property['_id']),
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.red),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ));
  }
}
