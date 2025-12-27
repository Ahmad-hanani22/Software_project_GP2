import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

class BuildingsManagementScreen extends StatefulWidget {
  const BuildingsManagementScreen({super.key});

  @override
  State<BuildingsManagementScreen> createState() =>
      _BuildingsManagementScreenState();
}

class _BuildingsManagementScreenState
    extends State<BuildingsManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _buildings = [];
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchBuildings();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('role');
    });
  }

  Future<void> _fetchBuildings() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllBuildings();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _buildings = data as List<dynamic>;
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  Future<void> _deleteBuilding(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المبنى'),
        content: const Text('هل أنت متأكد من حذف هذا المبنى؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final (ok, msg) = await ApiService.deleteBuilding(id);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المبنى بنجاح')),
      );
      _fetchBuildings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _showAddBuildingDialog() async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final countryCtrl = TextEditingController();
    final totalFloorsCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final managementCompanyCtrl = TextEditingController();
    final yearBuiltCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مبنى جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المبنى *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'العنوان *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'المدينة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countryCtrl,
                decoration: const InputDecoration(
                  labelText: 'الدولة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalFloorsCtrl,
                decoration: const InputDecoration(
                  labelText: 'عدد الطوابق',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: managementCompanyCtrl,
                decoration: const InputDecoration(
                  labelText: 'شركة الإدارة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearBuiltCtrl,
                decoration: const InputDecoration(
                  labelText: 'سنة البناء',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال اسم المبنى والعنوان')),
                );
                return;
              }

              final buildingData = {
                'name': nameCtrl.text,
                'address': addressCtrl.text,
                'city': cityCtrl.text.isNotEmpty ? cityCtrl.text : null,
                'country': countryCtrl.text.isNotEmpty ? countryCtrl.text : null,
                'totalFloors': totalFloorsCtrl.text.isNotEmpty
                    ? int.tryParse(totalFloorsCtrl.text) ?? 1
                    : 1,
                'description': descriptionCtrl.text.isNotEmpty
                    ? descriptionCtrl.text
                    : null,
                'managementCompany': managementCompanyCtrl.text.isNotEmpty
                    ? managementCompanyCtrl.text
                    : null,
                'yearBuilt': yearBuiltCtrl.text.isNotEmpty
                    ? int.tryParse(yearBuiltCtrl.text)
                    : null,
              };

              final (ok, msg) = await ApiService.addBuilding(buildingData);
              if (!mounted) return;

              if (ok) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إضافة المبنى بنجاح')),
                );
                _fetchBuildings();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg)),
                );
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditBuildingDialog(dynamic building) async {
    final nameCtrl = TextEditingController(text: building['name'] ?? '');
    final addressCtrl = TextEditingController(text: building['address'] ?? '');
    final cityCtrl = TextEditingController(text: building['city'] ?? '');
    final countryCtrl = TextEditingController(text: building['country'] ?? '');
    final totalFloorsCtrl =
        TextEditingController(text: building['totalFloors']?.toString() ?? '');
    final descriptionCtrl =
        TextEditingController(text: building['description'] ?? '');
    final managementCompanyCtrl =
        TextEditingController(text: building['managementCompany'] ?? '');
    final yearBuiltCtrl =
        TextEditingController(text: building['yearBuilt']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل المبنى'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم المبنى *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'العنوان *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'المدينة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countryCtrl,
                decoration: const InputDecoration(
                  labelText: 'الدولة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalFloorsCtrl,
                decoration: const InputDecoration(
                  labelText: 'عدد الطوابق',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: managementCompanyCtrl,
                decoration: const InputDecoration(
                  labelText: 'شركة الإدارة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearBuiltCtrl,
                decoration: const InputDecoration(
                  labelText: 'سنة البناء',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || addressCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء إدخال اسم المبنى والعنوان')),
                );
                return;
              }

              final buildingData = {
                'name': nameCtrl.text,
                'address': addressCtrl.text,
                'city': cityCtrl.text.isNotEmpty ? cityCtrl.text : null,
                'country': countryCtrl.text.isNotEmpty ? countryCtrl.text : null,
                'totalFloors': totalFloorsCtrl.text.isNotEmpty
                    ? int.tryParse(totalFloorsCtrl.text) ?? 1
                    : 1,
                'description': descriptionCtrl.text.isNotEmpty
                    ? descriptionCtrl.text
                    : null,
                'managementCompany': managementCompanyCtrl.text.isNotEmpty
                    ? managementCompanyCtrl.text
                    : null,
                'yearBuilt': yearBuiltCtrl.text.isNotEmpty
                    ? int.tryParse(yearBuiltCtrl.text)
                    : null,
              };

              final (ok, msg) =
                  await ApiService.updateBuilding(building['_id'], buildingData);
              if (!mounted) return;

              if (ok) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث المبنى بنجاح')),
                );
                _fetchBuildings();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg)),
                );
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _userRole == 'landlord' || _userRole == 'admin';

    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('إدارة المباني', style: TextStyle(color: Colors.white)),
        backgroundColor: _accentGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: canEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showAddBuildingDialog,
                  tooltip: 'إضافة مبنى جديد',
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('خطأ: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchBuildings,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _buildings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد مباني',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (canEdit) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddBuildingDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('إضافة مبنى جديد'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchBuildings,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _buildings.length,
                        itemBuilder: (ctx, idx) {
                          final building = _buildings[idx];
                          final owner = building['ownerId'] ?? {};
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: _primaryBeige,
                                child: const Icon(Icons.business,
                                    color: Colors.white),
                              ),
                              title: Text(
                                building['name'] ?? 'بدون اسم',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (building['address'] != null)
                                    Text('📍 ${building['address']}'),
                                  if (building['city'] != null ||
                                      building['country'] != null)
                                    Text(
                                      '${building['city'] ?? ''}${building['city'] != null && building['country'] != null ? ', ' : ''}${building['country'] ?? ''}',
                                    ),
                                  if (building['totalFloors'] != null)
                                    Text('🏢 ${building['totalFloors']} طابق'),
                                  if (owner['name'] != null)
                                    Text('👤 ${owner['name']}'),
                                ],
                              ),
                              trailing: canEdit
                                  ? PopupMenuButton(
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text('تعديل'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  size: 20, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('حذف',
                                                  style:
                                                      TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showEditBuildingDialog(building);
                                        } else if (value == 'delete') {
                                          _deleteBuilding(building['_id']);
                                        }
                                      },
                                    )
                                  : null,
                              onTap: () {
                                // يمكن إضافة صفحة تفاصيل المبنى لاحقاً
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

