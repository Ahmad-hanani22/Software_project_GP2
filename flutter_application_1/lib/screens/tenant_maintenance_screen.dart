import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_application_1/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TenantMaintenanceScreen extends StatefulWidget {
  const TenantMaintenanceScreen({super.key});

  @override
  State<TenantMaintenanceScreen> createState() =>
      _TenantMaintenanceScreenState();
}

class _TenantMaintenanceScreenState extends State<TenantMaintenanceScreen> {
  bool _isLoading = true;
  List<dynamic> _requests = [];
  List<dynamic> _myActiveContracts = [];
  String? _userId;

  // للإضافة
  final _descController = TextEditingController();
  String? _selectedPropertyId;
  String _selectedRequestType = 'maintenance'; // 'maintenance' or 'complaint'
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes; // For web compatibility
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
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
        if (ok) _requests = data as List<dynamic>;
        _isLoading = false;
      });
    }
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
      if (_selectedImage != null) {
        final (imgOk, imgUrl) = await ApiService.uploadImage(_selectedImage!);
        if (imgOk && imgUrl != null) images.add(imgUrl);
      }

      final (ok, msg) = await ApiService.createMaintenance(
        propertyId: _selectedPropertyId!,
        description: _descController.text,
        images: images,
        type: _selectedRequestType,
      );

      if (mounted) {
        setDialogState(() => _isSubmitting = false);
        if (ok) {
          Navigator.pop(context);
          _descController.clear();
          _selectedImage = null;
          _selectedImageBytes = null;
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
        content: const Text("Are you sure you want to delete this maintenance request?"),
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
    
    final descController = TextEditingController(text: currentDescription);
    String selectedType = currentType;
    XFile? selectedImage;
    Uint8List? selectedImageBytes;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
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
                                  Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                                  SizedBox(height: 5),
                                  Text("Add Photo (Optional)", style: TextStyle(color: Colors.grey)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? selectedImageBytes != null
                                        ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
                                        : const Center(child: CircularProgressIndicator())
                                    : Image.file(File(selectedImage!.path), fit: BoxFit.cover),
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
                              Icon(Icons.report_problem, size: 20, color: Colors.orange),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
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
                              final (imgOk, imgUrl) = await ApiService.uploadImage(selectedImage!);
                              if (imgOk && imgUrl != null) images.add(imgUrl);
                            }

                            // Update maintenance request (tenant can update description, type, and images, not status)
                            final (ok, msg) = await ApiService.updateMaintenance(
                              requestId,
                              null, // Tenant cannot change status
                              description: descController.text,
                              images: images.isNotEmpty ? images : null,
                              type: selectedType,
                            );
                            if (mounted) {
                              setDialogState(() => isSubmitting = false);
                              if (ok) {
                                Navigator.pop(context);
                                _fetchRequests();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg), backgroundColor: Colors.green),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg), backgroundColor: Colors.red),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
                        final XFile? image =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          if (kIsWeb) {
                            // For web, read bytes directly
                            final bytes = await image.readAsBytes();
                            setDialogState(() {
                              _selectedImage = image;
                              _selectedImageBytes = bytes;
                            });
                          } else {
                            setDialogState(() {
                              _selectedImage = image;
                              _selectedImageBytes = null;
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
                        child: _selectedImage == null
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
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? _selectedImageBytes != null
                                        ? Image.memory(_selectedImageBytes!,
                                            fit: BoxFit.cover)
                                        : const Center(
                                            child: CircularProgressIndicator())
                                    : Image.file(File(_selectedImage!.path),
                                        fit: BoxFit.cover)),
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
                              Icon(Icons.report_problem, size: 20, color: Colors.orange),
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

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Maintenance and Complaints"),
        backgroundColor: const Color(0xFF00695C),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF00695C),
        icon: const Icon(Icons.add),
        label: const Text("New Request"),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00695C)))
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.handyman_outlined,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 20),
                      Text("No maintenance requests yet",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final r = _requests[index];
                    final status = r['status'] ?? 'pending';
                    Color statusColor = Colors.orange;
                    IconData statusIcon = Icons.access_time;

                    if (status == 'in_progress') {
                      statusColor = Colors.blue;
                      statusIcon = Icons.sync;
                    }
                    if (status == 'resolved') {
                      statusColor = Colors.green;
                      statusIcon = Icons.check_circle;
                    }

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip(
                                  label: Text(status.toUpperCase(),
                                      style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                  backgroundColor: statusColor.withOpacity(0.1),
                                  avatar: Icon(statusIcon,
                                      size: 14, color: statusColor),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 0), // Compact
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                if (r['createdAt'] != null)
                                  Text(
                                    r['createdAt'].toString().substring(0, 10),
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 12),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(r['description'] ?? "No Description",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.home_work_outlined,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 5),
                                Expanded(
                                    child: Text(
                                        r['propertyId']?['title'] ??
                                            'Unknown Property',
                                        style: const TextStyle(
                                            color: Colors.grey))),
                              ],
                            ),
                            if (r['images'] != null &&
                                (r['images'] as List).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: GestureDetector(
                                  onTap: () => _showImageDialog(context, r['images'][0]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(r['images'][0],
                                        height: 80,
                                        width: 120,
                                        fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            // Edit and Delete buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _editRequest(context, r),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text('Update'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _deleteRequest(context, r['_id']),
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('Delete'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  },
                ),
    );
  }
}
