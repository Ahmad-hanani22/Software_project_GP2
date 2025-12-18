import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // تمت إضافة المكتبة هنا
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/units_management_screen.dart';
import 'package:flutter_application_1/screens/property_history_screen.dart';
import 'package:flutter_application_1/screens/ownership_management_screen.dart';
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

  void _openPropertyForm({Map<String, dynamic>? property}) {
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
        child: PropertyFormSheet(
          property: property,
          onSubmit: (data, isEdit) async {
            Navigator.pop(ctx);
            setState(() => _isLoading = true);

            final (ok, message) = isEdit
                ? await ApiService.updateProperty(
                    id: property!['_id'], propertyData: data)
                : await ApiService.addProperty(data);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(message),
                  backgroundColor: ok ? _accentGreen : Colors.red));
              _fetchProperties();
            }
          },
        ),
      ),
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
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _fetchProperties),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPropertyForm(),
        label: const Text('Add Property'),
        icon: const Icon(Icons.add_home_work),
        backgroundColor: _accentGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentGreen))
          : _properties.isEmpty
              ? _buildEmptyState()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // إذا كان العرض أكبر من 800 (يعني ويب أو تابلت)
                    if (constraints.maxWidth > 800) {
                      return _buildGridView(constraints);
                    } else {
                      // إذا كان موبايل
                      return _buildListView();
                    }
                  },
                ),
    );
  }

  // --- 1. تصميم الموبايل (قائمة) ---
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _properties.length,
      itemBuilder: (context, index) {
        final property = _properties[index];
        return _buildPropertyCard(property, isWeb: false);
      },
    );
  }

  // --- 2. تصميم الويب (شبكة) ---
  Widget _buildGridView(BoxConstraints constraints) {
    // تحديد عدد الأعمدة بناءً على عرض الشاشة
    int crossAxisCount = constraints.maxWidth > 1400 ? 4 : 3;

    return GridView.builder(
      padding: const EdgeInsets.all(24.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.85, // نسبة الطول للعرض للكارت
      ),
      itemCount: _properties.length,
      itemBuilder: (context, index) {
        final property = _properties[index];
        return _buildPropertyCard(property, isWeb: true);
      },
    );
  }

  // --- 3. تصميم الكارت نفسه (مشترك ومحسن) ---
  Widget _buildPropertyCard(dynamic property, {required bool isWeb}) {
    final title = property['title'] ?? 'No Title';
    final price = property['price'] ?? 0;
    final city = property['city'] ?? 'Unknown';
    final image = (property['images'] != null && property['images'].isNotEmpty)
        ? property['images'][0]
        : null;

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // لقص الصورة الزائدة
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // منطقة الصورة
          Stack(
            children: [
              Container(
                height: isWeb ? 200 : 180, // ارتفاع ثابت للصورة
                width: double.infinity,
                color: Colors.grey.shade200,
                child: image != null
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(Icons.image,
                            size: 50, color: Colors.grey),
                      )
                    : const Icon(Icons.image, size: 50, color: Colors.grey),
              ),
              // التاج (Tag) للحالة أو النوع
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (property['operation'] ?? 'RENT').toString().toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary),
                  ),
                ),
              )
            ],
          ),

          // منطقة المعلومات
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween, // توزيع المسافات
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: _textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: _textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // السعر وأيقونات التعديل
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        NumberFormat.simpleCurrency(decimalDigits: 0)
                            .format(price),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _accentGreen,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.home_work,
                                size: 20, color: _accentGreen),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => UnitsManagementScreen(
                                    propertyId: property['_id'],
                                    propertyTitle: title,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'Manage Units',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.history,
                                size: 20, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => PropertyHistoryScreen(
                                    propertyId: property['_id'],
                                    propertyTitle: title,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'Property History',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.people,
                                size: 20, color: Colors.purple),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => OwnershipManagementScreen(
                                    propertyId: property['_id'],
                                    propertyTitle: title,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'Ownership',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                size: 20, color: _darkBeige),
                            onPressed: () =>
                                _openPropertyForm(property: property),
                            tooltip: 'Edit',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 20, color: Colors.redAccent),
                            onPressed: () => _deleteProperty(property['_id']),
                            tooltip: 'Delete',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- حالة عدم وجود بيانات ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.real_estate_agent_outlined,
              size: 80, color: _primaryBeige.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No Properties Yet',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
          TextButton(
            onPressed: () => _openPropertyForm(),
            child: const Text("Create your first listing",
                style: TextStyle(color: _accentGreen)),
          )
        ],
      ),
    );
  }
}

// ============================================================================
// ================= FORM SHEET WIDGET ========================================
// ============================================================================

class PropertyFormSheet extends StatefulWidget {
  final Map<String, dynamic>? property;
  final Function(Map<String, dynamic> data, bool isEdit) onSubmit;

  const PropertyFormSheet({super.key, this.property, required this.onSubmit});

  @override
  State<PropertyFormSheet> createState() => _PropertyFormSheetState();
}

class _PropertyFormSheetState extends State<PropertyFormSheet> {
  final _formKey = GlobalKey<FormState>();

  final titleCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  double _latitude = 0.0;
  double _longitude = 0.0;

  String _selectedType = 'apartment';
  String _selectedOperation = 'rent';
  int _bedrooms = 1;
  int _bathrooms = 1;

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
    if (widget.property != null) {
      final p = widget.property!;
      titleCtrl.text = p['title'] ?? '';
      priceCtrl.text = p['price']?.toString() ?? '';
      areaCtrl.text = p['area']?.toString() ?? '';
      descCtrl.text = p['description'] ?? '';
      addressCtrl.text = p['address'] ?? '';
      cityCtrl.text = p['city'] ?? '';
      countryCtrl.text = p['country'] ?? '';
      _selectedType = p['type'] ?? 'apartment';
      _selectedOperation = p['operation'] ?? 'rent';
      _bedrooms = p['bedrooms'] ?? 1;
      _bathrooms = p['bathrooms'] ?? 1;
      _existingImages = List<String>.from(p['images'] ?? []);
      _selectedAmenities = List<String>.from(p['amenities'] ?? []);

      if (p['location'] != null && p['location']['coordinates'] != null) {
        final coords = p['location']['coordinates'];
        if (coords is List && coords.length == 2) {
          _longitude = (coords[0] as num).toDouble();
          _latitude = (coords[1] as num).toDouble();
        }
      }
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
        content: Text("Location updated successfully!"),
        backgroundColor: _accentGreen,
        duration: Duration(seconds: 1),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionLabel("What are you listing?"),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300)),
                  child: Row(
                    children: [
                      _buildOperationTab('Rent', _selectedOperation == 'rent'),
                      _buildOperationTab('Sale', _selectedOperation == 'sale'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['apartment', 'house', 'villa', 'office', 'shop']
                        .map((type) {
                      final isSelected = _selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          label: Text(type.toUpperCase()),
                          labelStyle: TextStyle(
                              color: isSelected ? Colors.white : _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                          backgroundColor: Colors.white,
                          selectedColor: _accentGreen,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                  color: isSelected
                                      ? _accentGreen
                                      : Colors.grey.shade300)),
                          onSelected: (val) =>
                              setState(() => _selectedType = type),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 25),
                _buildSectionLabel("Property Details"),
                const SizedBox(height: 15),
                _buildFancyTextField(titleCtrl, "Property Title",
                    icon: Icons.title),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                        child: _buildFancyTextField(priceCtrl, "Price",
                            icon: Icons.attach_money, isNumber: true)),
                    const SizedBox(width: 15),
                    Expanded(
                        child: _buildFancyTextField(areaCtrl, "Area (m²)",
                            icon: Icons.square_foot, isNumber: true)),
                  ],
                ),
                const SizedBox(height: 15),
                _buildFancyTextField(descCtrl, "Description",
                    icon: Icons.description, maxLines: 3),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCounter("Bedrooms", _bedrooms,
                        (val) => setState(() => _bedrooms = val)),
                    _buildCounter("Bathrooms", _bathrooms,
                        (val) => setState(() => _bathrooms = val)),
                  ],
                ),
                const SizedBox(height: 25),
                _buildSectionLabel("Amenities"),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableAmenities.map((amenity) {
                    final isSelected = _selectedAmenities.contains(amenity);
                    return ChoiceChip(
                      label: Text(amenity),
                      selected: isSelected,
                      selectedColor: _primaryBeige.withOpacity(0.4),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedAmenities.add(amenity);
                          } else {
                            _selectedAmenities.remove(amenity);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 25),
                _buildSectionLabel("Location"),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickLocation,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.grey.shade100,
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ]),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.map, color: Colors.blue),
                        ),
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(
                                  _latitude == 0
                                      ? "Tap to pin location"
                                      : "Lat: $_latitude, Lng: $_longitude",
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
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
                _buildFancyTextField(
                    addressCtrl, "Street Address / Building No.",
                    icon: Icons.location_on_outlined),
                const SizedBox(height: 25),
                _buildSectionLabel("Photos"),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      InkWell(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final List<XFile> picked =
                              await picker.pickMultiImage();
                          setState(() => _newImages.addAll(picked));
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border.all(
                                  color: _accentGreen,
                                  style: BorderStyle
                                      .solid), // تم التعديل هنا (dashed -> solid)
                              borderRadius: BorderRadius.circular(12)),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: _accentGreen),
                              SizedBox(height: 4),
                              Text("Add",
                                  style: TextStyle(
                                      color: _accentGreen, fontSize: 12))
                            ],
                          ),
                        ),
                      ),
                      ..._existingImages.map((url) => _buildThumb(url, false,
                          () => setState(() => _existingImages.remove(url)))),
                      ..._newImages.map((file) => FutureBuilder<Uint8List>(
                            future: file.readAsBytes(),
                            builder: (_, snap) => snap.hasData
                                ? _buildThumb(
                                    snap.data!,
                                    true,
                                    () =>
                                        setState(() => _newImages.remove(file)))
                                : const SizedBox(
                                    width: 100,
                                    child: Center(
                                        child: CircularProgressIndicator())),
                          ))
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
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
              onPressed: _isUploading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _accentGreen,
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == 0 && _longitude == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a location")));
      return;
    }

    setState(() => _isUploading = true);

    List<String> uploadedUrls = [];
    for (var file in _newImages) {
      final (ok, url) = await ApiService.uploadImage(file);
      if (ok && url != null) uploadedUrls.add(url);
    }

    final data = {
      'title': titleCtrl.text,
      'price': double.tryParse(priceCtrl.text) ?? 0,
      'description': descCtrl.text,
      'type': _selectedType,
      'operation': _selectedOperation,
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
      }
    };

    widget.onSubmit(data, widget.property != null);
  }

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
                  child: Icon(Icons.close, size: 14, color: Colors.red)),
            ))
      ],
    );
  }

  Widget _buildOperationTab(String label, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedOperation = label.toLowerCase()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: isActive ? _textPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1), blurRadius: 4)
                    ]
                  : []),
          child: Text(label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildCounter(String label, int value, Function(int) onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              _iconBtn(
                  Icons.remove, () => value > 0 ? onChange(value - 1) : null),
              SizedBox(
                  width: 30,
                  child: Text("$value",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
              _iconBtn(Icons.add, () => onChange(value + 1)),
            ],
          ),
        )
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: _textPrimary),
      ),
    );
  }

  Widget _buildFancyTextField(TextEditingController c, String label,
      {IconData? icon, bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: c,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: (v) => v!.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: _primaryBeige) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accentGreen)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: _darkBeige));
  }
}

// ============================================================================
// ================= MAP SELECTION SCREEN (NEW) ==============================
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
        backgroundColor: const Color(0xFFD4B996),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation!,
              zoom: 14,
            ),
            onTap: _selectLocation,
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
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(_pickedLocation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
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
