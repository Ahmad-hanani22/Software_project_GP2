import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// Reusing AppAlertType and showAppAlert from previous screens
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
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
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

// ---------------------------------------------
// AdminUser Data Model
// ---------------------------------------------
class AdminUser {
  final String id;
  String name;
  String email;
  String role;
  String? phone;
  final DateTime createdAt;
  DateTime? updatedAt;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    required this.createdAt,
    this.updatedAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      role: json['role'] ?? 'tenant',
      phone: json['phone'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

const double _kMobileBreakpoint = 600.0;
// --- UPDATED COLOR PALETTE (matching LoginScreen's green) ---
const Color _primaryGreen =
    Color(0xFF2E7D32); // The exact green from LoginScreen
const Color _lightGreenAccent =
    Color(0xFFE8F5E9); // A very light tint of green for accents
const Color _darkGreenAccent = Color(0xFF1B5E20); // A darker shade of green
const Color _scaffoldBackground = Color(0xFFFAFAFA); // Grey 50
const Color _cardBackground = Colors.white;
const Color _textPrimary = Color(0xFF424242); // Grey 800
const Color _textSecondary = Color(0xFF757575); // Grey 600
const Color _borderColor = Color(0xFFE0E0E0); // Grey 300

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  List<AdminUser> _users = [];
  List<AdminUser> _filteredUsers = [];
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRoleFilter;
  late TabController _tabController; // لتصفية الأدوار

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_filterUsers);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (ok, data) =
        await ApiService.getAllUsers(); // Using the new API method

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (ok) {
          _users =
              (data as List).map((json) => AdminUser.fromJson(json)).toList();
          _filterUsers(); // Apply initial filter
        } else {
          _errorMessage = data.toString();
          showAppAlert(
            context: context,
            title: 'Error',
            message: 'Failed to load users: $_errorMessage',
            type: AppAlertType.error,
          );
        }
      });
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch = user.name.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.role.toLowerCase().contains(query) ||
            (user.phone?.toLowerCase().contains(query) ?? false);

        final matchesRole = _selectedRoleFilter == null ||
            _selectedRoleFilter == 'All Roles' ||
            user.role.toLowerCase() == _selectedRoleFilter!.toLowerCase();

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> _showCreateEditUserDialog({AdminUser? user}) async {
    final bool isEditing = user != null;
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController(text: user?.name);
    final _emailController = TextEditingController(text: user?.email);
    final _phoneController = TextEditingController(text: user?.phone);
    final _passwordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    String _selectedRole = user?.role ?? 'tenant';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEditing ? 'Edit User' : 'Create New User',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(color: _textPrimary),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Name', Icons.person),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: _inputDecoration('Email', Icons.email),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an email';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: _inputDecoration('Phone (Optional)', Icons.phone),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: _inputDecoration('Role', Icons.assignment_ind),
                  items: const ['admin', 'landlord', 'tenant']
                      .map(
                        (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role,
                                style: TextStyle(color: _textPrimary))),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a role';
                    }
                    return null;
                  },
                  style: TextStyle(color: _textPrimary),
                  dropdownColor: _cardBackground,
                ),
                const SizedBox(height: 16),
                if (!isEditing) // Password is required for creation
                  Column(
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        decoration: _inputDecoration('Password', Icons.lock),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: _inputDecoration(
                          'Confirm Password',
                          Icons.lock,
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                if (isEditing) // Optional password change for editing
                  TextFormField(
                    controller: _passwordController,
                    decoration: _inputDecoration(
                      'New Password (Optional)',
                      Icons.lock_reset,
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          value.length < 6) {
                        return 'New password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: _textSecondary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(); // Close dialog first

                bool ok;
                String message;

                if (isEditing) {
                  // Update user
                  final String? newPassword =
                      _passwordController.text.isNotEmpty
                          ? _passwordController.text
                          : null;
                  (ok, message) = await ApiService.updateUser(
                    id: user!.id,
                    name: _nameController.text,
                    email: _emailController.text,
                    phone: _phoneController.text.isEmpty
                        ? ''
                        : _phoneController
                            .text, // Pass empty string for clearing
                    role: _selectedRole,
                    password: newPassword,
                  );
                } else {
                  // Create user
                  (ok, message) = await ApiService.addUser(
                    name: _nameController.text,
                    email: _emailController.text,
                    phone: _phoneController.text.isEmpty
                        ? null
                        : _phoneController.text,
                    role: _selectedRole,
                    password: _passwordController.text,
                  );
                }

                if (mounted) {
                  if (ok) {
                    showAppAlert(
                      context: context,
                      title: isEditing ? 'User Updated' : 'User Created',
                      message: message,
                      type: AppAlertType.success,
                    );
                    _fetchUsers(); // Refresh the list
                  } else {
                    showAppAlert(
                      context: context,
                      title: 'Error',
                      message: message,
                      type: AppAlertType.error,
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(isEditing ? 'Save Changes' : 'Create User'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Deletion',
          style: TextStyle(
              color: Colors.red.shade700, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete user "$userName"? This action cannot be undone.',
          style: TextStyle(color: _textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: _textSecondary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final (ok, message) = await ApiService.deleteUser(userId);
      if (mounted) {
        if (ok) {
          showAppAlert(
            context: context,
            title: 'User Deleted',
            message: message,
            type: AppAlertType.success,
          );
          _fetchUsers(); // Refresh the list
        } else {
          showAppAlert(
            context: context,
            title: 'Error',
            message: message,
            type: AppAlertType.error,
          );
        }
      }
    }
  }

  // Helper for consistent input decoration
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _primaryGreen),
      labelStyle: TextStyle(color: _textSecondary),
      hintStyle: TextStyle(color: _textSecondary.withOpacity(0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), // More rounded
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: _primaryGreen, width: 2), // Primary green focus
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _borderColor),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      floatingLabelStyle: const TextStyle(color: _primaryGreen),
      filled: true,
      fillColor: _cardBackground,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= _kMobileBreakpoint;
    final ColorScheme colorScheme = Theme.of(context)
        .colorScheme; // Using theme color scheme for general colors

    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        elevation: 4, // زيادة البروز
        backgroundColor: _primaryGreen, // لون أخضر أساسي
        foregroundColor: Colors.white, // لون الأيقونات والنص أبيض
        titleSpacing: isMobile ? 0 : 12,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(.2), // أيقونة داخل خلفية بيضاء شفافة
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.people_alt_outlined,
                  color: Colors.white), // لون أبيض
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'User Management',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isMobile ? 18 : 20, // حجم الخط يتكيف
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Users'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Charts'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Users',
            icon: const Icon(Icons.refresh, color: Colors.white), // لون أبيض
            onPressed: _fetchUsers,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton.icon(
              onPressed: () => _showCreateEditUserDialog(),
              icon: const Icon(Icons.add,
                  color: _primaryGreen, size: 18), // أيقونة خضراء
              label: isMobile
                  ? const Text('')
                  : const Text(
                      'Add User',
                      style: TextStyle(
                          color: _primaryGreen, fontWeight: FontWeight.w600),
                    ), // نص أخضر
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // خلفية بيضاء
                foregroundColor: _primaryGreen,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 14,
                  vertical: isMobile ? 8 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),
          if (!isMobile) const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: colorScheme.error,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading users: $_errorMessage',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: colorScheme.error, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchUsers,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_tabController.index == 0)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: isMobile
                            ? Column(
                                // على الموبايل: البحث ثم التصفية
                                children: [
                                  _buildSearchBar(),
                                  const SizedBox(height: 12),
                                  _buildRoleFilterDropdown(isMobile),
                                ],
                              )
                            : Row(
                                // على الشاشات الكبيرة: البحث بجانب التصفية
                                children: [
                                  Expanded(
                                    child: _buildSearchBar(),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildRoleFilterDropdown(isMobile),
                                  ),
                                ],
                              ),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Users List Tab
                          _filteredUsers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_off_outlined,
                                    size: 80,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No users found matching your search.',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: _textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your search terms or adding new users.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _textSecondary.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 4, // ظل أوضح
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        15), // حواف أكثر استدارة
                                  ),
                                  color: _cardBackground,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        _buildRoleAvatar(user.role),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _textPrimary,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                user.email,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _textSecondary,
                                                ),
                                              ),
                                              if (user.phone != null &&
                                                  user.phone!.isNotEmpty)
                                                Text(
                                                  'Phone: ${user.phone}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: _textSecondary,
                                                  ),
                                                ),
                                              const SizedBox(height: 6),
                                              _buildRoleChip(user.role),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Joined: ${DateFormat('yyyy-MM-dd').format(user.createdAt)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _textSecondary
                                                      .withOpacity(0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // الأزرار هنا (تعديل وحذف)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors
                                                    .blueAccent, // يمكن تغيير هذا إذا أردنا لوناً مختلفاً
                                              ),
                                              tooltip: 'Edit User',
                                              onPressed: () =>
                                                  _showCreateEditUserDialog(
                                                user: user,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors
                                                    .redAccent, // يمكن تغيير هذا إذا أردنا لوناً مختلفاً
                                              ),
                                              tooltip: 'Delete User',
                                              onPressed: () => _deleteUser(
                                                  user.id, user.name),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          // Charts Tab
                          _buildChartsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // New: Build Search Bar Widget
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search users by name, email, role, or phone...',
        prefixIcon: Icon(Icons.search, color: _primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: _lightGreenAccent.withOpacity(0.5), // Soft green background
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        hintStyle: TextStyle(color: _textSecondary.withOpacity(0.7)),
      ),
      style: TextStyle(color: _textPrimary), // Text color for input
    );
  }

  // New: Build Role Filter Dropdown Widget
  Widget _buildRoleFilterDropdown(bool isMobile) {
    return DropdownButtonFormField<String>(
      value: _selectedRoleFilter ?? 'All Roles',
      decoration: InputDecoration(
        labelText: isMobile ? null : 'Filter by Role',
        hintText: 'Filter by Role',
        prefixIcon: Icon(Icons.filter_list, color: _primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: _lightGreenAccent.withOpacity(0.5), // Soft green background
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
        labelStyle: TextStyle(color: _textSecondary),
        hintStyle: TextStyle(color: _textSecondary.withOpacity(0.7)),
      ),
      items: const ['All Roles', 'admin', 'landlord', 'tenant']
          .map(
            (role) => DropdownMenuItem(
              value: role,
              child: Text(role, style: TextStyle(color: _textPrimary)),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedRoleFilter = value;
          _filterUsers(); // Re-filter when role changes
        });
      },
      dropdownColor: _cardBackground, // Background for dropdown items
      style: TextStyle(
        color: _textPrimary,
      ), // Text style for selected item
    );
  }

  // Helper widget for role avatar
  Widget _buildRoleAvatar(String role) {
    IconData icon;
    Color bgColor;
    Color iconColor;

    switch (role.toLowerCase()) {
      case 'admin':
        icon = Icons.security;
        bgColor = Colors.red.shade100; // Keep red for admin warning
        iconColor = Colors.red;
        break;
      case 'landlord':
        icon = Icons.business;
        bgColor = Colors.blue.shade100; // Keep blue for landlord
        iconColor = Colors.blue;
        break;
      case 'tenant':
        icon = Icons.person;
        bgColor = _primaryGreen.withOpacity(0.1); // Use light green accent
        iconColor = _primaryGreen;
        break;
      default:
        icon = Icons.person_outline;
        bgColor = Colors.grey.shade200;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: bgColor,
      radius: 28,
      child: Icon(icon, color: iconColor, size: 28),
    );
  }

  // Helper widget for role chip
  Widget _buildRoleChip(String role) {
    Color chipColor;
    Color textColor;
    String roleText = role.toUpperCase();

    switch (role.toLowerCase()) {
      case 'admin':
        chipColor = Colors.red.shade700; // Keep red for admin warning
        textColor = Colors.white;
        break;
      case 'landlord':
        chipColor = Colors.blue.shade700; // Keep blue for landlord
        textColor = Colors.white;
        break;
      case 'tenant':
        chipColor = _primaryGreen; // Primary green
        textColor = Colors.white;
        break;
      default:
        chipColor = Colors.grey.shade600;
        textColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        roleText,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Charts Tab
  Widget _buildChartsTab() {
    // Calculate users by role
    final Map<String, int> usersByRole = {};
    for (var user in _filteredUsers.isEmpty ? _users : _filteredUsers) {
      final role = user.role.toLowerCase();
      usersByRole[role] = (usersByRole[role] ?? 0) + 1;
    }

    if (usersByRole.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No data available for charts',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Users by Role',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sections: _buildPieChartSections(usersByRole),
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildLegend(usersByRole),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, int> usersByRole) {
    final colors = [
      Colors.red.shade700, // Admin
      Colors.blue.shade700, // Landlord
      _primaryGreen, // Tenant
      Colors.grey.shade600, // Other
    ];
    int colorIndex = 0;
    final total = usersByRole.values.fold<int>(0, (sum, count) => sum + count);

    return usersByRole.entries.map((entry) {
      final percentage = (entry.value / total * 100);
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        color: color,
        radius: 70,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, int> usersByRole) {
    final colors = [
      Colors.red.shade700,
      Colors.blue.shade700,
      _primaryGreen,
      Colors.grey.shade600,
    ];
    int colorIndex = 0;

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: usersByRole.entries.map((entry) {
        final color = colors[colorIndex % colors.length];
        colorIndex++;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.key.toUpperCase()}: ${entry.value}',
              style: const TextStyle(fontSize: 16, color: _textPrimary, fontWeight: FontWeight.w500),
            ),
          ],
        );
      }).toList(),
    );
  }
}
