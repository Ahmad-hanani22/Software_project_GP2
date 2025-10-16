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
const double _kTabletBreakpoint = 900.0;

// يمكن استخدامها لتعديلات إضافية
class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

enum AppAlertType { success, error, info }

// Custom alert function - متجاوبة الآن بالكامل
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

  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < _kMobileBreakpoint;
  final dialogPadding = isMobile ? 16.0 : 24.0;
  final titleFontSize = isMobile ? 18.0 : 20.0;
  final messageFontSize = isMobile ? 14.0 : 16.0;

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenWidth * 0.9 : 400.0,
        ),
        child: Padding(
          padding: EdgeInsets.all(dialogPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: iconColor, size: 48),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                  color: iconColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: messageFontSize),
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
          _error =
              data?.toString() ??
              "Invalid data format or unknown error from API";
        }
      } else {
        _error =
            data?.toString() ?? 'Unknown error occurred during fetch users.';
      }
    });
  }

  // ✳️ نافذة إضافة / تعديل المستخدم - متجاوبة الآن بالكامل
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
        late String _selectedRoleInDialog = currentRole;
        final isMobile = screenWidth < _kMobileBreakpoint;
        final dialogHorizontalPadding = isMobile ? 16.0 : 20.0;
        final dialogVerticalPadding = isMobile ? 16.0 : 20.0;
        final itemSpacing = isMobile ? 8.0 : 10.0;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setInnerState) {
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? screenWidth * 0.95 : 500.0,
                  maxHeight: screenWidth > _kMobileBreakpoint
                      ? 600
                      : screenWidth * 1.2,
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      dialogHorizontalPadding,
                      dialogVerticalPadding,
                      dialogHorizontalPadding,
                      itemSpacing, // Bottom padding for buttons
                    ),
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
                                fontSize: isMobile ? 16 : 18,
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
                        SizedBox(height: itemSpacing + 2), // Adjusted spacing
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: itemSpacing),
                        TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: itemSpacing),
                        DropdownButtonFormField<String>(
                          value: _selectedRoleInDialog,
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
                              _selectedRoleInDialog =
                                  (v ?? _selectedRoleInDialog);
                            });
                          },
                        ),
                        SizedBox(height: itemSpacing),
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
                        SizedBox(height: itemSpacing + 6), // Adjusted spacing
                        screenWidth > _kMobileBreakpoint
                            ? Row(
                                children: _dialogButtons(
                                  ctx,
                                  isEdit,
                                  nameCtrl,
                                  emailCtrl,
                                  passwordCtrl,
                                  _selectedRoleInDialog,
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
                                  _selectedRoleInDialog,
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
                  message: "Failed to delete user: ${msg ?? 'Unknown error'}",
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
    String role,
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
                role: role != user.role ? role : null,
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
                  message: 'Failed to update user: ${msg ?? 'Unknown error'}',
                  type: AppAlertType.error,
                );
              }
            } else {
              final (ok, msg) = await ApiService.addUser(
                name: name,
                email: email,
                password: password,
                role: role,
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
                  message: 'Failed to add user: ${msg ?? 'Unknown error'}',
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
        // زر التحديث
        IconButton(
          tooltip: 'Refresh',
          onPressed: _fetchUsers,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 4),
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
          const SizedBox(width: 4),
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
                'Error: ${_error ?? 'An unexpected error occurred.'}',
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

  // الجسم الرئيسي (متجاوب بشكل كامل)
  Widget _buildContent(double screenWidth) {
    final filtered = _filtered;

    // تم تغيير ListView إلى Column هنا
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          screenWidth > _kMobileBreakpoint ? 16 : 10,
          16,
          screenWidth > _kMobileBreakpoint ? 16 : 10,
          24,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // لضمان تمدد العناصر عرضياً
          children: [
            _hero(filteredCount: filtered.length, screenWidth: screenWidth),
            const SizedBox(height: 16),
            _filtersBar(screenWidth),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: filtered.isEmpty
                  ? _emptyState()
                  : _cardsReorderable(filtered, screenWidth),
            ),
          ],
        ),
      ),
    );
  }

  // هيدر فخم + إحصائيات متحركة (متجاوب)
  Widget _hero({required int filteredCount, required double screenWidth}) {
    final double horizontalPadding = screenWidth > _kMobileBreakpoint ? 16 : 10;
    final double heroContainerPadding = 18;
    final double itemSpacing = 8;

    int crossAxisCount;
    if (screenWidth > _kTabletBreakpoint) {
      crossAxisCount = 5;
    } else if (screenWidth > _kMobileBreakpoint) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    final double totalHorizontalContentWidth =
        screenWidth - (2 * horizontalPadding);
    final double availableWidthForMetrics =
        totalHorizontalContentWidth -
        (2 * heroContainerPadding) -
        (itemSpacing * (crossAxisCount - 1));
    double metricItemWidth = availableWidthForMetrics / crossAxisCount;

    metricItemWidth = metricItemWidth.clamp(140.0, double.infinity);

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
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: itemSpacing,
              runSpacing: itemSpacing,
              alignment: WrapAlignment.start,
              children: [
                _metric(
                  'Total',
                  _total,
                  Icons.people_alt,
                  width: metricItemWidth,
                ),
                _metric(
                  'Admins',
                  _admins,
                  Icons.security,
                  width: metricItemWidth,
                ),
                _metric(
                  'Landlords',
                  _landlords,
                  Icons.business_center,
                  width: metricItemWidth,
                ),
                _metric(
                  'Tenants',
                  _tenants,
                  Icons.person_outline,
                  width: metricItemWidth,
                ),
                _metric(
                  'Filtered',
                  filteredCount,
                  Icons.filter_alt,
                  width: metricItemWidth,
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
    required double width,
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
    return SizedBox(width: width, child: content);
  }

  // شريط البحث + الفلترة (متجاوب)
  Widget _filtersBar(double screenWidth) {
    bool isMobile = screenWidth < _kMobileBreakpoint;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _filterWidgets(isMobile),
              )
            : Row(children: _filterWidgets(isMobile)),
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
        width: isMobile ? double.infinity : 170,
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
        width: isMobile ? double.infinity : null,
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

  // كروت + سحب وإفلات (Reorderable) - سيتم استخدامه كـ "عرض القائمة" الموحد
  Widget _cardsReorderable(List<AdminUser> list, double screenWidth) {
    final keys = list.map((u) => ValueKey(u.id)).toList();
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(), // يُفضل هذا ليتولى SingleChildScrollView الأب التمرير
      buildDefaultDragHandles:
          false, // لا ننشئ مقابض سحب افتراضية لأننا سنستخدم واحدة مخصصة داخل البطاقة
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
        return ReorderableDragStartListener(
          key: keys[i], // المفتاح يجب أن يكون على العنصر القابل للسحب
          index: i,
          child: _UserCard(
            // استخدام البطاقة المخصصة الجديدة
            user: u,
            roleColor: _roleColor(u.role),
            dateFormatter: _dateFmt,
            screenWidth: screenWidth,
            onEdit: () => _showUserDialog(user: u),
            onDelete: () => _confirmDelete(u),
          ),
        );
      },
    );
  }
}

// ============================================================
// 📄 بطاقة المستخدم المخصصة (تصميم جديد)
// ============================================================
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.roleColor,
    required this.dateFormatter,
    required this.screenWidth,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminUser user;
  final Color roleColor;
  final DateFormat dateFormatter;
  final double screenWidth;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = screenWidth < _kMobileBreakpoint;

    return Card(
      elevation: 2, // ارتفاع بسيط للبطاقة لإبرازها
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // زوايا دائرية أكثر
      ),
      margin: const EdgeInsets.only(bottom: 12), // مسافة بين البطاقات
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: roleColor.withOpacity(.15),
                  child: Icon(
                    Icons.person,
                    color: roleColor,
                  ), // أيقونة شخص للدلالة على المستخدم
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 18 : 20,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 15,
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: TextStyle(
                      color: roleColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .5,
                      fontSize: isMobile ? 10 : 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24), // فاصل بين قسم المعلومات والأزرار
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Created: ${dateFormatter.format(user.createdAt)}',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: Colors.grey[600],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize
                      .min, // لضمان ألا تأخذ الأزرار مساحة أكبر من اللازم
                  children: [
                    IconButton(
                      tooltip: 'Edit User',
                      icon: Icon(
                        Icons.edit,
                        color: Colors.blue[600],
                        size: isMobile ? 20 : 22,
                      ),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      tooltip: 'Delete User',
                      icon: Icon(
                        Icons.delete_forever,
                        color: Colors.red[600],
                        size: isMobile ? 20 : 22,
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
