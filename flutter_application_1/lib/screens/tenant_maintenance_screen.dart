import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_1/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

// Helpers for status normalization and SLA / resolution analytics
String _normalizeStatus(dynamic s) {
  final v = (s ?? 'pending').toString();
  if (v == 'completed') return 'resolved';
  return v;
}

bool _isOverdue(Map r, {int days = 5}) {
  final status = _normalizeStatus(r['status']);
  if (status == 'resolved') return false;
  final createdAt = DateTime.tryParse((r['createdAt'] ?? '').toString());
  if (createdAt == null) return false;
  return DateTime.now().difference(createdAt).inDays >= days;
}

double _avgResolutionHours(List<dynamic> reqs) {
  final resolved =
      reqs.where((r) => _normalizeStatus(r['status']) == 'resolved');
  final durations = <int>[];

  for (final r in resolved) {
    final c = DateTime.tryParse((r['createdAt'] ?? '').toString());
    final u = DateTime.tryParse((r['updatedAt'] ?? '').toString());
    if (c != null && u != null) {
      durations.add(u.difference(c).inHours);
    }
  }
  if (durations.isEmpty) return 0;
  return durations.reduce((a, b) => a + b) / durations.length;
}

class TenantMaintenanceScreen extends StatefulWidget {
  const TenantMaintenanceScreen({super.key});

  @override
  State<TenantMaintenanceScreen> createState() =>
      _TenantMaintenanceScreenState();
}

// --- Theme Colors ---
const Color _primaryGreen = Color(0xFF2E7D32);
const Color _primaryBlue = Color(0xFF1976D2); // Blue for Tenant
const Color _scaffoldBackground = Color(0xFFF5F5F5);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class _TenantMaintenanceScreenState extends State<TenantMaintenanceScreen> {
  bool _isLoading = true;
  List<dynamic> _requests = [];
  List<dynamic> _filteredRequests = [];
  List<dynamic> _myActiveContracts = [];
  String? _userId;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter;

  // Statistics
  int _totalRequests = 0;
  int _pendingRequests = 0;
  int _inProgressRequests = 0;
  int _resolvedRequests = 0;
  int _overdueRequests = 0;
  double _avgResolveHours = 0;

  // للإضافة
  final _descController = TextEditingController();
  String? _selectedPropertyId;
  String _selectedRequestType = 'maintenance'; // 'maintenance' or 'complaint'
  // Multiple images support
  List<XFile> _selectedImages = [];
  List<Uint8List> _selectedImagesBytes = [];
  String _selectedPriority = 'medium';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_filterRequests);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    if (_userId != null) {
      await Future.wait([
        _fetchRequests(),
        _fetchActiveProperties(),
      ]);
    }
  }

  Future<void> _fetchRequests() async {
    final (ok, data) = await ApiService.getTenantRequests(_userId!);
    if (mounted) {
      setState(() {
        if (ok) {
          _requests = data as List<dynamic>;
          _calculateStatistics();
        }
        _isLoading = false;
      });
      _filterRequests();
    }
  }

  void _calculateStatistics() {
    _totalRequests = _requests.length;
    _pendingRequests = _requests
        .where((r) => _normalizeStatus(r['status']) == 'pending')
        .length;
    _inProgressRequests = _requests
        .where((r) => _normalizeStatus(r['status']) == 'in_progress')
        .length;
    _resolvedRequests = _requests
        .where((r) => _normalizeStatus(r['status']) == 'resolved')
        .length;
    _overdueRequests = _requests.where((r) => _isOverdue(r)).length;
    _avgResolveHours = _avgResolutionHours(_requests);
  }

  void _filterRequests() {
    setState(() {
      final searchQuery = _searchController.text.toLowerCase();
      final now = DateTime.now();

      _filteredRequests = _requests.where((request) {
        final status = _normalizeStatus(request['status']);

        // Status filter including "overdue"
        bool statusMatch = true;
        if (_selectedStatusFilter != null) {
          if (_selectedStatusFilter == 'overdue') {
            statusMatch = _isOverdue(request);
          } else {
            statusMatch = status == _selectedStatusFilter;
          }
        }
        if (!statusMatch) return false;

        // Search filter
        if (searchQuery.isNotEmpty) {
          final property = request['propertyId'] ?? {};
          final propertyName =
              (property['title'] ?? '').toString().toLowerCase();
          final description =
              (request['description'] ?? '').toString().toLowerCase();

          final match = propertyName.contains(searchQuery) ||
              description.contains(searchQuery);
          if (!match) return false;
        }

        return true;
      }).toList();

      // Sort: newest first
      _filteredRequests.sort((a, b) {
        final da = DateTime.tryParse((a['createdAt'] ?? '').toString()) ??
            DateTime(1970);
        final db = DateTime.tryParse((b['createdAt'] ?? '').toString()) ??
            DateTime(1970);
        return db.compareTo(da);
      });
    });
  }

  void _setStatusFilter(String? status) {
    setState(() {
      _selectedStatusFilter = status;
    });
    _filterRequests();
  }

  Future<void> _fetchActiveProperties() async {
    final (ok, data) = await ApiService.getUserContracts(_userId!);
    if (ok && data is List) {
      setState(() {
        // Consider both "active" and "rented" contracts so tenants can request maintenance
        _myActiveContracts = data
            .where((c) => c['status'] == 'active' || c['status'] == 'rented')
            .toList();
        if (_myActiveContracts.isNotEmpty) {
          _selectedPropertyId = _myActiveContracts[0]['propertyId']['_id'];
        }
      });
    }
  }

  Future<void> _submitRequest(StateSetter setDialogState) async {
    if (_descController.text.isEmpty) return;
    setDialogState(() => _isSubmitting = true);

    try {
      List<String> images = [];
      for (final img in _selectedImages) {
        final (imgOk, imgUrl) = await ApiService.uploadImage(img);
        if (imgOk && imgUrl != null) images.add(imgUrl);
      }

      final (ok, msg) = await ApiService.createMaintenance(
        propertyId: _selectedPropertyId!,
        description: _descController.text,
        images: images,
        type: _selectedRequestType,
        priority: _selectedPriority,
      );

      if (mounted) {
        setDialogState(() => _isSubmitting = false);
        if (ok) {
          Navigator.pop(context);
          _descController.clear();
          _selectedImages = [];
          _selectedImagesBytes = [];
          _fetchRequests();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) setDialogState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteRequest(BuildContext context, String requestId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Request"),
        content: const Text(
            "Are you sure you want to delete this maintenance request?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final (ok, msg) = await ApiService.deleteMaintenance(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? "Request deleted successfully" : msg),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
        if (ok) _fetchRequests();
      }
    }
  }

  void _editRequest(BuildContext context, dynamic request) {
    final requestId = request['_id'];
    final currentDescription = request['description'] ?? '';
    final currentType = request['type'] ?? 'maintenance';
    final currentPriority = request['priority'] ?? 'medium';

    final descController = TextEditingController(text: currentDescription);
    String selectedType = currentType;
    String selectedPriority = currentPriority;
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text("Edit Request"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        border: OutlineInputBorder(),
                        hintText: "Describe the issue...",
                      ),
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          if (kIsWeb) {
                            final bytes = await image.readAsBytes();
                            setDialogState(() {
                              selectedImage = image;
                              selectedImageBytes = bytes;
                            });
                          } else {
                            setDialogState(() {
                              selectedImage = image;
                              selectedImageBytes = null;
                            });
                          }
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: selectedImage == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo,
                                      color: Colors.grey, size: 30),
                                  SizedBox(height: 5),
                                  Text("Add Photo (Optional)",
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? selectedImageBytes != null
                                        ? Image.memory(selectedImageBytes!,
                                            fit: BoxFit.cover)
                                        : const Center(
                                            child: CircularProgressIndicator())
                                    : Image.file(File(selectedImage!.path),
                                        fit: BoxFit.cover),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Request Type",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Row(
                            children: [
                              Icon(Icons.build, size: 20, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('صيانة (Maintenance)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'complaint',
                          child: Row(
                            children: [
                              Icon(Icons.report_problem,
                                  size: 20, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('شكوى (Complaint)'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Priority",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'low',
                          child: Text('Low'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text('High'),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedPriority = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (descController.text.isEmpty) return;
                          setDialogState(() => isSubmitting = true);

                          try {
                            List<String> images = [];
                            if (selectedImage != null) {
                              final (imgOk, imgUrl) =
                                  await ApiService.uploadImage(selectedImage!);
                              if (imgOk && imgUrl != null) images.add(imgUrl);
                            }

                            // Update maintenance request (tenant can update description, type, and images, not status)
                            final (ok, msg) =
                                await ApiService.updateMaintenance(
                              requestId,
                              null, // Tenant cannot change status
                              description: descController.text,
                              images: images.isNotEmpty ? images : null,
                              type: selectedType,
                              priority: selectedPriority,
                            );
                            if (mounted) {
                              setDialogState(() => isSubmitting = false);
                              if (ok) {
                                Navigator.pop(context);
                                _fetchRequests();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(msg),
                                      backgroundColor: Colors.green),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(msg),
                                      backgroundColor: Colors.red),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              setDialogState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Update Request"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddDialog() {
    if (_myActiveContracts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("You need an active contract to request maintenance."),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text("New Request"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedPropertyId,
                      isExpanded: true,
                      items: _myActiveContracts.map((c) {
                        return DropdownMenuItem(
                          value: c['propertyId']['_id'].toString(),
                          child: Text(
                              c['propertyId']['title'] ?? 'Unknown Property',
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setDialogState(() => _selectedPropertyId = val),
                      decoration: const InputDecoration(
                          labelText: "Property", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Priority",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'low',
                          child: Text('Low'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: Text('High'),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (val) => setDialogState(
                          () => _selectedPriority = val ?? 'medium'),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: "Description",
                          border: OutlineInputBorder(),
                          hintText: "Describe the issue..."),
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () async {
                        final ImagePicker picker = ImagePicker();
                        final List<XFile> images =
                            await picker.pickMultiImage();
                        if (images.isNotEmpty) {
                          if (kIsWeb) {
                            final bytesList = <Uint8List>[];
                            for (final img in images) {
                              bytesList.add(await img.readAsBytes());
                            }
                            setDialogState(() {
                              _selectedImages = images;
                              _selectedImagesBytes = bytesList;
                            });
                          } else {
                            setDialogState(() {
                              _selectedImages = images;
                              _selectedImagesBytes = [];
                            });
                          }
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.grey[100],
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12)),
                        child: _selectedImages.isEmpty
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo,
                                      color: Colors.grey, size: 30),
                                  SizedBox(height: 5),
                                  Text("Add Photo (Optional)",
                                      style: TextStyle(color: Colors.grey))
                                ],
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: kIsWeb
                                          ? Image.memory(
                                              _selectedImagesBytes[index],
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.file(
                                              File(_selectedImages[index].path),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedRequestType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Request Type",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'maintenance',
                          child: Row(
                            children: [
                              Icon(Icons.build, size: 20, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('صيانة (Maintenance)'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'complaint',
                          child: Row(
                            children: [
                              Icon(Icons.report_problem,
                                  size: 20, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('شكوى (Complaint)'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            _selectedRequestType = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _submitRequest(setDialogState),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Submit Request"),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showImageGallery(List<String> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageGallery(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is String) {
        return DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(date));
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text("Maintenance & Complaints",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: _primaryBlue,
        icon: const Icon(Icons.add),
        label: const Text("New Request"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : Column(
              children: [
                // Summary Dashboard
                _buildSummaryDashboard(),
                // Search and Filter Bar
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search by property or description...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _filterRequests();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick status chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _selectedStatusFilter == null,
                        onSelected: (_) => _setStatusFilter(null),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Pending'),
                        selected: _selectedStatusFilter == 'pending',
                        onSelected: (_) => _setStatusFilter('pending'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('In progress'),
                        selected: _selectedStatusFilter == 'in_progress',
                        onSelected: (_) => _setStatusFilter('in_progress'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Resolved'),
                        selected: _selectedStatusFilter == 'resolved',
                        onSelected: (_) => _setStatusFilter('resolved'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('Overdue'),
                        selected: _selectedStatusFilter == 'overdue',
                        onSelected: (_) => _setStatusFilter('overdue'),
                      ),
                    ],
                  ),
                ),
                // Results
                Expanded(
                  child: _filteredRequests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _requests.isEmpty
                                    ? Icons.handyman_outlined
                                    : Icons.search_off,
                                size: 80,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _requests.isEmpty
                                    ? 'No Maintenance Requests'
                                    : 'No results found',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _requests.isEmpty
                                    ? 'Create your first maintenance request'
                                    : 'Try adjusting your search or filter.',
                                style: const TextStyle(color: _textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchRequests,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            itemCount: _filteredRequests.length,
                            itemBuilder: (context, index) {
                              return _MaintenanceCard(
                                request: _filteredRequests[index],
                                onEdit: _editRequest,
                                onDelete: _deleteRequest,
                                onImageTap: _showImageGallery,
                                formatDate: _formatDate,
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryDashboard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildStatCard(
            'Total',
            _totalRequests.toString(),
            Icons.list_alt,
            _primaryBlue,
            onTap: () => _setStatusFilter(null),
          ),
          _buildStatCard(
            'Pending',
            _pendingRequests.toString(),
            Icons.access_time,
            Colors.orange,
            onTap: () => _setStatusFilter('pending'),
          ),
          _buildStatCard(
            'In progress',
            _inProgressRequests.toString(),
            Icons.build,
            Colors.blue,
            onTap: () => _setStatusFilter('in_progress'),
          ),
          _buildStatCard(
            'Resolved',
            _resolvedRequests.toString(),
            Icons.check_circle,
            Colors.green,
            onTap: () => _setStatusFilter('resolved'),
          ),
          _buildStatCard(
            'Overdue',
            _overdueRequests.toString(),
            Icons.priority_high,
            Colors.red,
            onTap: () => _setStatusFilter('overdue'),
          ),
          _buildStatCard(
            'Avg resolve',
            _avgResolveHours > 0
                ? '${_avgResolveHours.toStringAsFixed(1)}h'
                : '—',
            Icons.timer,
            Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    String? tempStatusFilter = _selectedStatusFilter;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Filter by Status'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String?>(
                  title: const Text('All'),
                  value: null,
                  groupValue: tempStatusFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempStatusFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Pending'),
                  value: 'pending',
                  groupValue: tempStatusFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempStatusFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('In Progress'),
                  value: 'in_progress',
                  groupValue: tempStatusFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempStatusFilter = value;
                    });
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Resolved'),
                  value: 'resolved',
                  groupValue: tempStatusFilter,
                  activeColor: _primaryGreen,
                  onChanged: (value) {
                    setModalState(() {
                      tempStatusFilter = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setModalState(() {
                  tempStatusFilter = null;
                });
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatusFilter = tempStatusFilter;
                });
                Navigator.pop(context);
                _filterRequests();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// =================== MAINTENANCE CARD WIDGET ====================
// ===================================================================
class _MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Function(BuildContext, dynamic) onEdit;
  final Function(BuildContext, String) onDelete;
  final Function(List<String>, int) onImageTap;
  final String Function(dynamic) formatDate;

  const _MaintenanceCard({
    required this.request,
    required this.onEdit,
    required this.onDelete,
    required this.onImageTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final property = request['propertyId'] ?? {};
    final rawStatus = request['status'] ?? 'pending';
    final status = _normalizeStatus(rawStatus);
    final priority = request['priority'] ?? 'medium';
    final requestType = request['type'] ?? 'maintenance';
    final images = request['images'] is List
        ? List<String>.from(request['images'] ?? [])
        : <String>[];
    final createdAt = request['createdAt'];
    final updatedAt = request['updatedAt'];

    // SLA badge
    String? slaBadge() {
      final created =
          DateTime.tryParse((request['createdAt'] ?? '').toString());
      if (created == null) return null;
      final days = DateTime.now().difference(created).inDays;
      if (status == 'pending' && days >= 3) return 'DELAYED';
      if (status == 'in_progress' && days >= 7) return 'LONG';
      return null;
    }

    final String? sla = slaBadge();

    final bool canModify = status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Property and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property['title'] ?? 'N/A Property',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: _primaryBlue),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        property['address'] ?? '',
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildTypeBadge(requestType),
                    const SizedBox(height: 8),
                    _buildPriorityBadge(priority),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statusButton(status),
                        if (sla != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sla,
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              width: double.infinity,
              child: Text(
                request['description'] ?? 'No description provided.',
                style: const TextStyle(
                    fontSize: 16, color: _textPrimary, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            // Images Gallery
            if (images.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length > 3 ? 3 : images.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => onImageTap(images, index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: images[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (images.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+${images.length - 3} more images',
                    style: const TextStyle(
                      fontSize: 14,
                      color: _primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
            // Timeline
            if (createdAt != null) ...[
              Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 18, color: _textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    'Created: ${formatDate(createdAt)}',
                    style: const TextStyle(fontSize: 14, color: _textSecondary),
                  ),
                ],
              ),
              if (updatedAt != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.update, size: 18, color: _textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      'Updated: ${formatDate(updatedAt)}',
                      style:
                          const TextStyle(fontSize: 14, color: _textSecondary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
            ],
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.delete,
                      color: canModify ? Colors.red : Colors.grey, size: 24),
                  onPressed: canModify
                      ? () => onDelete(context, request['_id'])
                      : null,
                  tooltip: 'Delete',
                  padding: const EdgeInsets.all(12),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: canModify ? () => onEdit(context, request) : null,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Update', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color;
    String label;
    IconData icon;

    switch (type.toLowerCase()) {
      case 'complaint':
        color = Colors.orange;
        label = 'شكوى';
        icon = Icons.report_problem;
        break;
      default: // maintenance
        color = Colors.blue;
        label = 'صيانة';
        icon = Icons.build;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    String label;
    IconData icon;

    switch (priority.toLowerCase()) {
      case 'urgent':
        color = Colors.red;
        label = 'Urgent';
        icon = Icons.priority_high;
        break;
      case 'high':
        color = Colors.orange;
        label = 'High';
        icon = Icons.arrow_upward;
        break;
      case 'low':
        color = Colors.blue;
        label = 'Low';
        icon = Icons.arrow_downward;
        break;
      default:
        color = Colors.grey;
        label = 'Medium';
        icon = Icons.remove;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusButton(String status) {
    Color bg;
    if (status == 'pending') {
      bg = Colors.orange;
    } else if (status == 'in_progress') {
      bg = Colors.blue;
    } else {
      bg = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ===================================================================
// =================== FULL SCREEN IMAGE GALLERY ====================
// ===================================================================
class _FullScreenImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageGallery> createState() =>
      _FullScreenImageGalleryState();
}

class _FullScreenImageGalleryState extends State<_FullScreenImageGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.images.length}'),
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(widget.images[index]),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          );
        },
        itemCount: widget.images.length,
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
          ),
        ),
        pageController: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
