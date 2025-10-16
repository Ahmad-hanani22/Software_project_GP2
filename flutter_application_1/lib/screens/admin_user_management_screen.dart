import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

// ============================================================
// 📊 نموذج المستخدم
// ============================================================
class AdminUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      role: json['role'] ?? 'N/A',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  AdminUser copyWith({
    String? name,
    String? email,
    String? role,
    DateTime? createdAt,
  }) {
    return AdminUser(
      id: id,
      name: (name ?? this.name),
      email: (email ?? this.email),
      role: (role ?? this.role),
      createdAt: (createdAt ?? this.createdAt),
    );
  }
}

// ============================================================
// 🧭 شاشة إدارة المستخدمين (نسخة فخمة)
// ============================================================

// تعريف نقاط التوقف لتحديد أحجام الشاشات
const double _kMobileBreakpoint = 600.0;
const double _kTabletBreakpoint = 900.0; // يمكن استخدامها لتعديلات إضافية

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

enum AppAlertType { success, error, info }

// Custom alert function
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

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen>
    with SingleTickerProviderStateMixin {
  final Color _primary = const Color(0xFF2E7D32);
  final _searchCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  bool _loading = true;
  String? _error;
  List<AdminUser> _users = [];
  String _roleFilter = 'All';
  bool _cardMode = false; // جدول / كروت (سحب وإفلات)
  late final AnimationController _heroAnim;

  @override
  void initState() {
    super.initState();
    _heroAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _heroAnim.dispose();
    super.dispose();
  }

  // 🟢 جلب جميع المستخدمين
  Future<void> _fetchUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final (ok, data) = await ApiService.getAllUsers();
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (ok) {
        if (data is List) {
          _users = data.map((e) => AdminUser.fromJson(e)).toList();
        } else {
          _error = "Invalid data format from API";
        }
      } else {
        _error = data.toString();
      }
    });
  }

  // ✳️ نافذة إضافة / تعديل المستخدم
  void _showUserDialog({AdminUser? user}) {
    final isEdit = user != null;

    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final passwordCtrl = TextEditingController();
    String currentRole = user?.role.toLowerCase() ?? 'tenant';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        // Define _selectedRoleInDialog here, outside StatefulBuilder's builder
        // This ensures it's initialized once per dialog instance and state persists.
        late String _selectedRoleInDialog = currentRole;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // تحديد عرض مرن للـ Dialog
          child: StatefulBuilder(
            // Use StatefulBuilder to manage dialog's internal state
            builder: (context, setInnerState) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth > _kMobileBreakpoint
                      ? 500
                      : screenWidth * 0.9,
                  maxHeight: screenWidth > _kMobileBreakpoint
                      ? 600
                      : screenWidth * 1.2,
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isEdit
                                  ? Icons.edit
                                  : Icons.person_add_alt_1_outlined,
                              color: _primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEdit ? "Edit User" : "Add New User",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _primary,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value:
                              _selectedRoleInDialog, // Use the state variable
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'landlord',
                              child: Text('Landlord'),
                            ),
                            DropdownMenuItem(
                              value: 'tenant',
                              child: Text('Tenant'),
                            ),
                          ],
                          onChanged: (v) {
                            setInnerState(() {
                              // Update state within the dialog
                              _selectedRoleInDialog =
                                  (v ?? _selectedRoleInDialog);
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: passwordCtrl,
                          decoration: InputDecoration(
                            labelText: isEdit
                                ? 'New Password (optional)'
                                : 'Password (required)',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        // جعل أزرار الحفظ والإلغاء تتكيف مع حجم الشاشة
                        screenWidth > _kMobileBreakpoint
                            ? Row(
                                children: _dialogButtons(
                                  ctx,
                                  isEdit,
                                  nameCtrl,
                                  emailCtrl,
                                  passwordCtrl,
                                  _selectedRoleInDialog, // Pass the updated role
                                  user,
                                ),
                              )
                            : Column(
                                children: _dialogButtons(
                                  ctx,
                                  isEdit,
                                  nameCtrl,
                                  emailCtrl,
                                  passwordCtrl,
                                  _selectedRoleInDialog, // Pass the updated role
                                  user,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // 🗑️ حذف المستخدم
  void _confirmDelete(AdminUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete '${user.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final (ok, msg) = await ApiService.deleteUser(user.id);
              if (ok) {
                showAppAlert(
                  context: context,
                  title: 'Success',
                  message: "User '${user.name}' deleted successfully!",
                  type: AppAlertType.success,
                );
                _fetchUsers();
              } else {
                showAppAlert(
                  context: context,
                  title: 'Deletion Failed',
                  message: "Failed to delete user: $msg",
                  type: AppAlertType.error,
                );
              }
            },
            label: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  // =============== Helpers ===============
  List<AdminUser> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _users.where((u) {
      final matchQ =
          q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
      final matchRole =
          _roleFilter == 'All' ||
          u.role.toLowerCase() == _roleFilter.toLowerCase();
      return matchQ && matchRole;
    }).toList();
  }

  int get _total => _users.length;
  int get _admins =>
      _users.where((u) => u.role.toLowerCase() == 'admin').length;
  int get _landlords =>
      _users.where((u) => u.role.toLowerCase() == 'landlord').length;
  int get _tenants =>
      _users.where((u) => u.role.toLowerCase() == 'tenant').length;

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red[700]!;
      case 'landlord':
        return Colors.blue[700]!;
      case 'tenant':
        return Colors.green[700]!;
      default:
        return Colors.grey;
    }
  }

  // أزرار الـ Dialog مشتركة بين Row و Column
  List<Widget> _dialogButtons(
    BuildContext ctx,
    bool isEdit,
    TextEditingController nameCtrl,
    TextEditingController emailCtrl,
    TextEditingController passwordCtrl,
    String role, // This 'role' will now be the updated _selectedRoleInDialog
    AdminUser? user,
  ) {
    return [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.arrow_back),
          label: const Text("Cancel"),
        ),
      ),
      SizedBox(
        width: MediaQuery.of(ctx).size.width > _kMobileBreakpoint ? 10 : 0,
        height: MediaQuery.of(ctx).size.width > _kMobileBreakpoint ? 0 : 10,
      ),
      Expanded(
        child: ElevatedButton.icon(
          icon: Icon(isEdit ? Icons.save : Icons.add),
          label: Text(isEdit ? "Save Changes" : "Add User"),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () async {
            final name = nameCtrl.text.trim();
            final email = emailCtrl.text.trim();
            final password = passwordCtrl.text.trim();

            if (name.isEmpty ||
                email.isEmpty ||
                (!isEdit && password.isEmpty)) {
              showAppAlert(
                context: context,
                title: 'Input Error',
                message: 'Please fill all required fields.',
                type: AppAlertType.error,
              );
              return;
            }

            Navigator.pop(ctx);

            if (isEdit) {
              final (ok, msg) = await ApiService.updateUser(
                id: user!.id,
                name: name != user.name ? name : null,
                email: email != user.email ? email : null,
                role: role != user.role
                    ? role
                    : null, // Use the passed 'role' parameter
                password: password.isNotEmpty ? password : null,
              );
              if (ok) {
                showAppAlert(
                  context: context,
                  title: 'Success',
                  message: 'User updated successfully!',
                  type: AppAlertType.success,
                );
                _fetchUsers();
              } else {
                showAppAlert(
                  context: context,
                  title: 'Update Failed',
                  message: 'Failed to update user: $msg',
                  type: AppAlertType.error,
                );
              }
            } else {
              final (ok, msg) = await ApiService.addUser(
                name: name,
                email: email,
                password: password,
                role: role, // Use the passed 'role' parameter
              );
              if (ok) {
                showAppAlert(
                  context: context,
                  title: 'Success',
                  message: 'User added successfully!',
                  type: AppAlertType.success,
                );
                _fetchUsers();
              } else {
                showAppAlert(
                  context: context,
                  title: 'Add User Failed',
                  message: 'Failed to add user: $msg',
                  type: AppAlertType.error,
                );
              }
            }
          },
        ),
      ),
    ];
  }

  // ============================================================
  // 🧱 واجهة المستخدم
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xffF6F7F9),
      appBar: _buildAppBar(screenWidth),
      floatingActionButton: _buildFAB(),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
          ? _buildError()
          : _buildContent(screenWidth),
    );
  }

  // AppBar حديث + Logout (تعديل ليكون متجاوباً)
  AppBar _buildAppBar(double screenWidth) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      titleSpacing: screenWidth > _kMobileBreakpoint
          ? 12
          : 0, // Even smaller spacing for very narrow screens
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.admin_panel_settings, color: _primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            // Added Expanded to ensure title text handles overflow
            child: Text(
              'User Management',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: screenWidth > _kMobileBreakpoint
                    ? 20
                    : 16, // تصغير الخط على الشاشات الصغيرة
              ),
              overflow: TextOverflow.ellipsis, // Handle long titles
            ),
          ),
        ],
      ),
      actions: [
        // زر تبديل العرض (جدول / كروت)
        Tooltip(
          message: _cardMode
              ? 'Switch to Table View'
              : 'Switch to Card (Drag & Drop) View',
          child: IconButton(
            onPressed: () {
              setState(() => _cardMode = !_cardMode);
            },
            icon: Icon(
              _cardMode
                  ? Icons.table_chart_outlined
                  : Icons.view_agenda_outlined,
            ),
          ),
        ),
        // زر التحديث
        IconButton(
          tooltip: 'Refresh',
          onPressed: _fetchUsers,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 4), // Reduced from 6
        // زر تسجيل الخروج (يتغير شكله حسب حجم الشاشة)
        screenWidth > _kMobileBreakpoint
            ? TextButton.icon(
                onPressed: () async {
                  await ApiService.logout();
                  if (!mounted) return;
                  Navigator.of(context).maybePop();
                  showAppAlert(
                    context: context,
                    title: 'Logged Out',
                    message: 'You have been successfully logged out.',
                    type: AppAlertType.info,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                label: const Text('Logout'),
                style: TextButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
            : IconButton(
                // زر صغير على الشاشات الضيقة
                onPressed: () async {
                  await ApiService.logout();
                  if (!mounted) return;
                  Navigator.of(context).maybePop();
                  showAppAlert(
                    context: context,
                    title: 'Logged Out',
                    message: 'You have been successfully logged out.',
                    type: AppAlertType.info,
                  );
                },
                icon: Icon(Icons.logout, color: _primary),
                tooltip: 'Logout',
              ),
        if (screenWidth > _kMobileBreakpoint)
          const SizedBox(width: 12)
        else
          const SizedBox(width: 4), // Reduced from 8
      ],
    );
  }

  // زر إضافة عائم
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showUserDialog(),
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add),
      label: const Text('Add User'),
    );
  }

  // قسم الخطأ
  Widget _buildError() {
    return Center(
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 12),
              Text(
                'Error: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(backgroundColor: _primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // الجسم الرئيسي (تعديل ليكون متجاوباً)
  Widget _buildContent(double screenWidth) {
    final filtered = _filtered;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        screenWidth > _kMobileBreakpoint ? 16 : 10,
        16,
        screenWidth > _kMobileBreakpoint ? 16 : 10,
        24,
      ),
      children: [
        _hero(filteredCount: filtered.length, screenWidth: screenWidth),
        const SizedBox(height: 16),
        _filtersBar(screenWidth),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: filtered.isEmpty
              ? _emptyState()
              : _cardMode
              ? _cardsReorderable(filtered, screenWidth)
              : _centeredTable(filtered, screenWidth),
        ),
      ],
    );
  }

  // هيدر فخم + إحصائيات متحركة (تعديل ليكون متجاوباً)
  Widget _hero({required int filteredCount, required double screenWidth}) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _heroAnim, curve: Curves.easeOut),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primary, _primary.withOpacity(.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(.22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard_customize, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Admin • User Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: screenWidth > _kMobileBreakpoint ? 16 : 14,
                  ),
                ),
                const Spacer(),
                if (screenWidth > _kMobileBreakpoint)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _cardMode ? 'Card View' : 'Table View',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // استخدام Wrap بدلاً من Row للمقاييس لتجنب تجاوز الحدود على الشاشات الصغيرة
            Wrap(
              spacing: 8, // المسافة الأفقية بين العناصر
              runSpacing: 8, // المسافة الرأسية بين الصفوف
              alignment: WrapAlignment.center, // محاذاة العناصر في المنتصف
              children: [
                _metric(
                  'Total',
                  _total,
                  Icons.people_alt,
                  flex: screenWidth > _kMobileBreakpoint ? 1 : null,
                  width: screenWidth > _kMobileBreakpoint
                      ? null
                      : (screenWidth / 2) - 24, // Adjusted width
                ),
                _metric(
                  'Admins',
                  _admins,
                  Icons.security,
                  flex: screenWidth > _kMobileBreakpoint ? 1 : null,
                  width: screenWidth > _kMobileBreakpoint
                      ? null
                      : (screenWidth / 2) - 24, // Adjusted width
                ),
                _metric(
                  'Landlords',
                  _landlords,
                  Icons.business_center,
                  flex: screenWidth > _kMobileBreakpoint ? 1 : null,
                  width: screenWidth > _kMobileBreakpoint
                      ? null
                      : (screenWidth / 2) - 24, // Adjusted width
                ),
                _metric(
                  'Tenants',
                  _tenants,
                  Icons.person_outline,
                  flex: screenWidth > _kMobileBreakpoint ? 1 : null,
                  width: screenWidth > _kMobileBreakpoint
                      ? null
                      : (screenWidth / 2) - 24, // Adjusted width
                ),
                _metric(
                  'Filtered',
                  filteredCount,
                  Icons.filter_alt,
                  flex: screenWidth > _kMobileBreakpoint ? 1 : null,
                  width: screenWidth > _kMobileBreakpoint
                      ? null
                      : (screenWidth / 2) - 24, // Adjusted width
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // تعديل _metric ليكون مرناً ضمن Wrap
  Widget _metric(
    String label,
    int value,
    IconData icon, {
    int? flex,
    double? width,
  }) {
    Widget content = TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween(begin: 0, end: value.toDouble()),
      builder: (_, v, __) => Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.2),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      v.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (flex != null) {
      return Expanded(flex: flex, child: content);
    }
    if (width != null) {
      return SizedBox(width: width, child: content);
    }
    return content;
  }

  // شريط البحث + الفلترة (تعديل ليكون متجاوباً)
  Widget _filtersBar(double screenWidth) {
    bool isMobile = screenWidth < _kMobileBreakpoint;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: isMobile
            ? Column(
                // على الشاشات الصغيرة، نضع العناصر في عمود
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _filterWidgets(isMobile),
              )
            : Row(
                // على الشاشات الكبيرة، نضع العناصر في صف
                children: _filterWidgets(isMobile),
              ),
      ),
    );
  }

  // عناصر الفلترة المشتركة بين Row و Column
  List<Widget> _filterWidgets(bool isMobile) {
    return [
      Expanded(
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search name or email...',
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      if (isMobile) const SizedBox(height: 10) else const SizedBox(width: 10),
      SizedBox(
        width: isMobile ? double.infinity : 170, // عرض كامل على الموبايل
        child: DropdownButtonFormField<String>(
          value: _roleFilter,
          decoration: InputDecoration(
            labelText: 'Role',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'All', child: Text('All')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
            DropdownMenuItem(value: 'landlord', child: Text('Landlord')),
            DropdownMenuItem(value: 'tenant', child: Text('Tenant')),
          ],
          onChanged: (v) => setState(() => _roleFilter = v ?? 'All'),
        ),
      ),
      if (isMobile) const SizedBox(height: 10) else const SizedBox(width: 10),
      SizedBox(
        width: isMobile ? double.infinity : null, // عرض كامل على الموبايل
        child: OutlinedButton.icon(
          onPressed: () {
            _searchCtrl.clear();
            setState(() => _roleFilter = 'All');
          },
          icon: const Icon(Icons.clear_all),
          label: const Text('Reset'),
        ),
      ),
    ];
  }

  // حالة لا يوجد نتائج
  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off, color: Colors.grey[400], size: 80),
          const SizedBox(height: 10),
          const Text('No users match your filters'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _roleFilter = 'All');
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  // جدول في المنتصف وبارز (تعديل ليكون متجاوباً)
  Widget _centeredTable(List<AdminUser> list, double screenWidth) {
    return Center(
      child: SingleChildScrollView(
        // Moved SingleChildScrollView here
        scrollDirection: Axis.horizontal,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(12),
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll(
                _primary.withOpacity(.08),
              ),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.grey[50];
                }
                return Colors.white;
              }),
              columnSpacing: screenWidth > _kMobileBreakpoint
                  ? 22
                  : 12, // تقليل المسافة على الشاشات الصغيرة
              showCheckboxColumn: false,
              columns: const [
                DataColumn(
                  label: Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Role',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Created At',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  numeric: true,
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: list.map((u) {
                return DataRow(
                  onSelectChanged: (_) => _showUserDialog(user: u),
                  cells: [
                    DataCell(
                      Text(
                        u.name,
                        overflow: TextOverflow.ellipsis, // Added
                      ),
                    ),
                    DataCell(
                      Text(
                        u.email,
                        overflow: TextOverflow.ellipsis, // Added
                      ),
                    ),
                    DataCell(
                      Text(
                        u.role,
                        style: TextStyle(
                          color: _roleColor(u.role),
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis, // Added
                      ),
                    ),
                    DataCell(
                      Text(
                        _dateFmt.format(u.createdAt),
                        overflow: TextOverflow.ellipsis, // Added
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showUserDialog(user: u),
                            visualDensity:
                                VisualDensity.compact, // Make icons smaller
                            padding:
                                EdgeInsets.zero, // Remove padding around icon
                            constraints: const BoxConstraints(
                              maxWidth: 30,
                              maxHeight: 30,
                            ), // Constrain icon button size
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(u),
                            visualDensity:
                                VisualDensity.compact, // Make icons smaller
                            padding:
                                EdgeInsets.zero, // Remove padding around icon
                            constraints: const BoxConstraints(
                              maxWidth: 30,
                              maxHeight: 30,
                            ), // Constrain icon button size
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // كروت + سحب وإفلات (Reorderable) (تعديل ليكون متجاوباً)
  Widget _cardsReorderable(List<AdminUser> list, double screenWidth) {
    final keys = list.map((u) => ValueKey(u.id)).toList();

    return Center(
      // إزالة ConstrainedBox هنا للسماح للكروت بالتكيف
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: list.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = list.removeAt(oldIndex);
            list.insert(newIndex, item);
          });
        },
        itemBuilder: (context, i) {
          final u = list[i];
          return Container(
            key: keys[i],
            margin: const EdgeInsets.only(bottom: 10),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                leading: ReorderableDragStartListener(
                  index: i,
                  child: CircleAvatar(
                    backgroundColor: _roleColor(u.role).withOpacity(.12),
                    child: Icon(
                      Icons.drag_indicator,
                      color: _roleColor(u.role),
                    ),
                  ),
                ),
                title: Column(
                  // استخدام Column لتكديس العناصر الرأسية
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            u.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow
                                .ellipsis, // التعامل مع النصوص الطويلة
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth > _kMobileBreakpoint
                                ? 10
                                : 6, // Reduced padding for very narrow screens
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _roleColor(u.role).withOpacity(.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            u.role.toUpperCase(),
                            style: TextStyle(
                              color: _roleColor(u.role),
                              fontWeight: FontWeight.bold,
                              letterSpacing: .4,
                              fontSize: screenWidth > _kMobileBreakpoint
                                  ? null
                                  : 10, // تصغير حجم الخط على الشاشات الصغيرة
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      u.email,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    _dateFmt.format(u.createdAt),
                    style: const TextStyle(
                      height: 1.2,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
                trailing: screenWidth > _kMobileBreakpoint
                    ? Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showUserDialog(user: u),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(u),
                          ),
                        ],
                      )
                    : Column(
                        // تكديس الأزرار عمودياً على الشاشات الصغيرة
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment:
                            MainAxisAlignment.center, // Center vertically
                        crossAxisAlignment:
                            CrossAxisAlignment.end, // Align to end
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blue,
                              size: 20,
                            ),
                            onPressed: () => _showUserDialog(user: u),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => _confirmDelete(u),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
