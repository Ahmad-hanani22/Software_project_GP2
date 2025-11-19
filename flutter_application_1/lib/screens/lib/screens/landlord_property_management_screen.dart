import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Initialize controllers
    final titleCtrl = TextEditingController(text: property?['title']);
    final descCtrl = TextEditingController(text: property?['description']);
    final priceCtrl =
        TextEditingController(text: property?['price']?.toString());
    final cityCtrl = TextEditingController(text: property?['city']);
    final addressCtrl = TextEditingController(text: property?['address']);
    // ... add all other controllers from admin screen ...

    String selectedType = property?['type'] ?? 'apartment';
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
              width: MediaQuery.of(context).size.width * 0.8,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextFormField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(labelText: 'Title'),
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      TextFormField(
                          controller: priceCtrl,
                          decoration: const InputDecoration(labelText: 'Price'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      TextFormField(
                          controller: descCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Description'),
                          maxLines: 3),
                      TextFormField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'City')),
                      TextFormField(
                          controller: addressCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Address')),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: ['apartment', 'house', 'villa', 'shop']
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text(t.toUpperCase())))
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedType = v!),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                          icon: const Icon(Icons.image),
                          label: const Text('Add Images'),
                          onPressed: () => pickImages(setDialogState)),
                      Wrap(
                        spacing: 8,
                        children: [
                          ...existingImageUrls.map((url) => Image.network(url,
                              width: 60, height: 60, fit: BoxFit.cover)),
                          // ✅ THIS IS THE FIX: Always use Image.network for picker results
                          ...newImages.map((file) => Image.network(file.path,
                              width: 60, height: 60, fit: BoxFit.cover)),
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

                        List<String> uploadedImageUrls = [];
                        for (var imageFile in newImages) {
                          final (success, data) =
                              await ApiService.uploadImage(imageFile);
                          if (success && data != null) {
                            uploadedImageUrls.add(data);
                          }
                        }

                        final propertyData = {
                          'title': titleCtrl.text,
                          'price': double.tryParse(priceCtrl.text) ?? 0,
                          'description': descCtrl.text,
                          'type': selectedType,
                          'city': cityCtrl.text,
                          'address': addressCtrl.text,
                          'images': [
                            ...existingImageUrls,
                            ...uploadedImageUrls
                          ],
                          // Dummy data for other required fields
                          'country': 'Unknown',
                          'operation': 'rent',
                          'location': {
                            'type': 'Point',
                            'coordinates': [0.0, 0.0]
                          },
                          'area': 0,
                          'bedrooms': 0,
                          'bathrooms': 0,
                        };

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
                child: isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save'),
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
