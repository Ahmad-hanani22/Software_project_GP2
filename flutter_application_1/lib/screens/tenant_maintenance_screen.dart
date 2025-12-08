import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TenantMaintenanceScreen extends StatefulWidget {
  const TenantMaintenanceScreen({super.key});

  @override
  State<TenantMaintenanceScreen> createState() => _TenantMaintenanceScreenState();
}

class _TenantMaintenanceScreenState extends State<TenantMaintenanceScreen> {
  bool _isLoading = true;
  List<dynamic> _requests = [];
  List<dynamic> _myActiveContracts = [];
  String? _userId;
  
  // للإضافة
  final _descController = TextEditingController();
  String? _selectedPropertyId;
  XFile? _selectedImage;
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
        _myActiveContracts = data.where((c) => c['status'] == 'active').toList();
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
      );
      
      if (mounted) {
        setDialogState(() => _isSubmitting = false);
        if (ok) {
          Navigator.pop(context);
          _descController.clear();
          _selectedImage = null;
          _fetchRequests();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) setDialogState(() => _isSubmitting = false);
    }
  }

  void _showAddDialog() {
    if (_myActiveContracts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You need an active contract to request maintenance."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        )
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          child: Text(c['propertyId']['title'] ?? 'Unknown Property', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => _selectedPropertyId = val),
                      decoration: const InputDecoration(labelText: "Property", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder(), hintText: "Describe the issue..."),
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) setDialogState(() => _selectedImage = image);
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: _selectedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [Icon(Icons.add_a_photo, color: Colors.grey, size: 30), SizedBox(height: 5), Text("Add Photo (Optional)", style: TextStyle(color: Colors.grey))],
                              )
                            : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover)),
                      ),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submitRequest(setDialogState),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Submit Request"),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Maintenance"),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00695C)))
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.handyman_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 20),
                      Text("No maintenance requests yet", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
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
                    
                    if (status == 'in_progress') { statusColor = Colors.blue; statusIcon = Icons.sync; }
                    if (status == 'resolved') { statusColor = Colors.green; statusIcon = Icons.check_circle; }

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip(
                                  label: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                  backgroundColor: statusColor.withOpacity(0.1),
                                  avatar: Icon(statusIcon, size: 14, color: statusColor),
                                  padding: const EdgeInsets.symmetric(horizontal: 0), // Compact
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                if (r['createdAt'] != null)
                                  Text(
                                    r['createdAt'].toString().substring(0, 10),
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(r['description'] ?? "No Description", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.home_work_outlined, size: 16, color: Colors.grey),
                                const SizedBox(width: 5),
                                Expanded(child: Text(r['propertyId']?['title'] ?? 'Unknown Property', style: const TextStyle(color: Colors.grey))),
                              ],
                            ),
                            if (r['images'] != null && (r['images'] as List).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(r['images'][0], height: 120, width: double.infinity, fit: BoxFit.cover),
                                ),
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