import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/home_page.dart';

class AdminSystemSettingsScreen extends StatefulWidget {
  const AdminSystemSettingsScreen({super.key});

  @override
  State<AdminSystemSettingsScreen> createState() =>
      _AdminSystemSettingsScreenState();
}

class _AdminSystemSettingsScreenState extends State<AdminSystemSettingsScreen> {
  final Color _primaryGreen = const Color(0xFF2E7D32);

  bool _darkMode = false;
  bool _maintenanceMode = false;
  String _selectedLanguage = 'English';
  double _paymentFee = 2.5;

  // 🔒 تسجيل الخروج
  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logged out successfully!')));
  }

  // 💾 حفظ الإعدادات
  Future<void> _saveSettings() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 🎨 واجهة بناء الصفحة
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'System Settings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          width: MediaQuery.of(context).size.width > 900
              ? 800
              : MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚙️ System Configuration',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // جدول الإعدادات
              Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DataTable(
                  columnSpacing: 50,
                  headingRowColor: MaterialStateProperty.all(_primaryGreen),
                  headingTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  columns: const [
                    DataColumn(label: Text('Setting')),
                    DataColumn(label: Text('Value')),
                  ],
                  rows: [
                    DataRow(
                      cells: [
                        const DataCell(Text('Dark Mode')),
                        DataCell(
                          Switch(
                            value: _darkMode,
                            activeColor: _primaryGreen,
                            onChanged: (v) => setState(() => _darkMode = v),
                          ),
                        ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(Text('Maintenance Mode')),
                        DataCell(
                          Switch(
                            value: _maintenanceMode,
                            activeColor: Colors.redAccent,
                            onChanged: (v) =>
                                setState(() => _maintenanceMode = v),
                          ),
                        ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(Text('System Language')),
                        DataCell(
                          DropdownButton<String>(
                            value: _selectedLanguage,
                            items: const [
                              DropdownMenuItem(
                                value: 'English',
                                child: Text('English'),
                              ),
                              DropdownMenuItem(
                                value: 'Arabic',
                                child: Text('Arabic'),
                              ),
                              DropdownMenuItem(
                                value: 'French',
                                child: Text('French'),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedLanguage = val!),
                          ),
                        ),
                      ],
                    ),
                    DataRow(
                      cells: [
                        const DataCell(Text('Payment Fee (%)')),
                        DataCell(
                          Slider(
                            value: _paymentFee,
                            min: 0,
                            max: 10,
                            divisions: 20,
                            label: '${_paymentFee.toStringAsFixed(1)}%',
                            activeColor: _primaryGreen,
                            onChanged: (v) => setState(() => _paymentFee = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // سحب وإفلات تجريبي (ديكور)
              DragTarget<String>(
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: candidateData.isNotEmpty
                            ? Colors.orange
                            : Colors.grey.shade300,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: candidateData.isNotEmpty
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.grey.shade50,
                    ),
                    child: Center(
                      child: Text(
                        candidateData.isNotEmpty
                            ? '🎉 Drop here to apply changes!'
                            : '💡 Drag any setting icon here (demo)',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
                onAccept: (data) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Dropped "$data"!')));
                },
              ),

              const SizedBox(height: 30),

              // صف الأزرار السفلي
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
