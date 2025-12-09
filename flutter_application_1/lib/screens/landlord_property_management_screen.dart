import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Theme Colors ---
const Color _primaryBeige = Color(0xFFD4B996);
const Color _darkBeige = Color(0xFF8D6E63);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);
const Color _textSecondary = Color(0xFF8D8D8D);

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
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey))),
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
        backgroundColor: ok ? _accentGreen : Colors.red,
      ));
      if (ok) _fetchProperties();
    }
  }

  Future<void> _showCreateEditPropertyDialog(
      {Map<String, dynamic>? property}) async {
    final isEditing = property != null;
    final formKey = GlobalKey<FormState>();

    // Controllers
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
            title: Text(isEditing ? 'Edit Property' : 'Create New Property',
                style: const TextStyle(color: _textPrimary)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Basic Information",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: _darkBeige)),
                      const SizedBox(height: 10),
                      _buildTextField(titleCtrl, 'Title',
                          validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(priceCtrl, 'Price',
                                isNumber: true)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildTextField(areaCtrl, 'Area (sqm)',
                                isNumber: true)),
                      ]),
                      const SizedBox(height: 10),
                      _buildTextField(descCtrl, 'Description', maxLines: 3),
                      const SizedBox(height: 20),
                      const Text("Details & Type",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: _darkBeige)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedType,
                            decoration: _inputDecoration('Type'),
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
                            decoration: _inputDecoration('Operation'),
                            items: ['rent', 'sale']
                                .map((t) => DropdownMenuItem(
                                    value: t, child: Text(t.toUpperCase())))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedOperation = v!),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(bedroomsCtrl, 'Bedrooms',
                                isNumber: true)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildTextField(bathroomsCtrl, 'Bathrooms',
                                isNumber: true)),
                      ]),
                      const SizedBox(height: 10),
                      _buildTextField(
                          amenitiesCtrl, 'Amenities (comma separated)'),
                      const SizedBox(height: 20),
                      const Text("Location",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: _darkBeige)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(countryCtrl, 'Country')),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(cityCtrl, 'City')),
                      ]),
                      const SizedBox(height: 10),
                      _buildTextField(addressCtrl, 'Address'),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _buildTextField(latCtrl, 'Latitude',
                                isNumber: true)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildTextField(lonCtrl, 'Longitude',
                                isNumber: true)),
                      ]),
                      const SizedBox(height: 20),
                      const Text("Images",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: _darkBeige)),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Select Images'),
                          onPressed: () => pickImages(setDialogState),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: _accentGreen,
                              side: const BorderSide(color: _accentGreen))),
                      const SizedBox(height: 10),
                      if (existingImageUrls.isNotEmpty || newImages.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...existingImageUrls.map((url) =>
                                _buildImageThumbnail(
                                    url,
                                    false,
                                    () => setDialogState(
                                        () => existingImageUrls.remove(url)))),
                            ...newImages.map((file) => FutureBuilder<Uint8List>(
                                  future: file.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                            ConnectionState.done &&
                                        snapshot.data != null) {
                                      return _buildImageThumbnail(
                                          snapshot.data!,
                                          true,
                                          () => setDialogState(
                                              () => newImages.remove(file)));
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
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey))),
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
                          if (success && data != null)
                            uploadedImageUrls.add(data);
                        }

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

                        final (ok, message) = isEditing
                            ? await ApiService.updateProperty(
                                id: property!['_id'],
                                propertyData: propertyData)
                            : await ApiService.addProperty(propertyData);

                        if (mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(message),
                              backgroundColor: _accentGreen));
                          if (ok) _fetchProperties();
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
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

  Widget _buildTextField(TextEditingController ctrl, String label,
      {bool isNumber = false,
      int maxLines = 1,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      decoration: _inputDecoration(label),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: validator,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _textSecondary),
      border: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _accentGreen, width: 2)),
      enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildImageThumbnail(
      dynamic imageSource, bool isBytes, VoidCallback onDelete) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isBytes
              ? Image.memory(imageSource,
                  width: 80, height: 80, fit: BoxFit.cover)
              : Image.network(imageSource,
                  width: 80, height: 80, fit: BoxFit.cover),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: InkWell(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.cancel, color: Colors.red, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: _scaffoldBackground,
        appBar: AppBar(
            elevation: 0,
            backgroundColor: _primaryBeige,
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
          label: const Text('Add Property'),
          icon: const Icon(Icons.add),
          backgroundColor: _accentGreen,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _accentGreen))
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _properties.isEmpty
                    ? Center(
                        child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.house_siding_outlined,
                              size: 80, color: _primaryBeige.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          const Text('No Properties Yet',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary)),
                          const Text('Click the button below to start.',
                              style: TextStyle(color: _textSecondary)),
                        ],
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _properties.length,
                        itemBuilder: (context, index) {
                          final property = _properties[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: property['images'] != null &&
                                          property['images'].isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Image.network(
                                              property['images'][0],
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover))
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                              color: _scaffoldBackground,
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Icon(Icons.house_outlined,
                                              color: _darkBeige)),
                                  title: Text(property['title'] ?? 'N/A',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _textPrimary)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${property['city']} • ${property['status']}',
                                            style: const TextStyle(
                                                color: _textSecondary,
                                                fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text(
                                            NumberFormat.simpleCurrency(
                                                    name: 'USD')
                                                .format(property['price']),
                                            style: const TextStyle(
                                                color: _accentGreen,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0),
                                  child: Divider(color: Colors.grey.shade200),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.edit, size: 18),
                                        label: const Text('Edit'),
                                        onPressed: () =>
                                            _showCreateEditPropertyDialog(
                                                property: property),
                                        style: TextButton.styleFrom(
                                            foregroundColor: _darkBeige),
                                      ),
                                      TextButton.icon(
                                        icon:
                                            const Icon(Icons.delete, size: 18),
                                        label: const Text('Delete'),
                                        onPressed: () =>
                                            _deleteProperty(property['_id']),
                                        style: TextButton.styleFrom(
                                            foregroundColor:
                                                Colors.red.shade400),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ));
  }
}
