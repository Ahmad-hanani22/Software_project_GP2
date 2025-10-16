import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/home_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // ✅ استيراد fl_chart

// ✅ استيراد جميع شاشات الإدارة الجديدة
import 'package:flutter_application_1/screens/admin_user_management_screen.dart';
import 'package:flutter_application_1/screens/admin_property_management_screen.dart';
import 'package:flutter_application_1/screens/admin_contract_management_screen.dart';
import 'package:flutter_application_1/screens/admin_payments_transactions_screen.dart';
import 'package:flutter_application_1/screens/admin_maintenance_complaints_screen.dart';
import 'package:flutter_application_1/screens/admin_reviews_management_screen.dart';
import 'package:flutter_application_1/screens/admin_notifications_management_screen.dart';
import 'package:flutter_application_1/screens/admin_system_settings_screen.dart';

// ==============================================
// 📊 Data Models for Admin Dashboard (UPDATED)
// ==============================================

// ---------------------------------------------
// Main Dashboard Data Model
// ---------------------------------------------
class AdminDashboardData {
  final String message;
  final SummaryStats summary;
  final LatestEntries latest;
  final AnalyticsData analytics;

  AdminDashboardData({
    required this.message,
    required this.summary,
    required this.latest,
    required this.analytics,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      message: json['message'] ?? 'Admin Dashboard data loaded.',
      summary: SummaryStats.fromJson(json['summary'] ?? {}),
      latest: LatestEntries.fromJson(json['latest'] ?? {}),
      analytics: AnalyticsData.fromJson(json['analytics'] ?? {}),
    );
  }
}

// ---------------------------------------------
// Summary Stats Models (UPDATED to match Backend)
// ---------------------------------------------
class SummaryStats {
  final int totalUsers;
  final int totalLandlords;
  final int totalTenants;
  final int totalProperties;
  final int totalContracts;
  final int totalPayments;
  final int totalMaintenances;
  final int totalComplaints;
  final int totalReviews;
  final int totalNotifications;

  SummaryStats({
    required this.totalUsers,
    required this.totalLandlords,
    required this.totalTenants,
    required this.totalProperties,
    required this.totalContracts,
    required this.totalPayments,
    required this.totalMaintenances,
    required this.totalComplaints,
    required this.totalReviews,
    required this.totalNotifications,
  });

  factory SummaryStats.fromJson(Map<String, dynamic> json) {
    return SummaryStats(
      totalUsers: json['totalUsers'] ?? 0,
      totalLandlords: json['totalLandlords'] ?? 0,
      totalTenants: json['totalTenants'] ?? 0,
      totalProperties: json['totalProperties'] ?? 0,
      totalContracts: json['totalContracts'] ?? 0,
      totalPayments: json['totalPayments'] ?? 0,
      totalMaintenances: json['totalMaintenances'] ?? 0,
      totalComplaints: json['totalComplaints'] ?? 0,
      totalReviews: json['totalReviews'] ?? 0,
      totalNotifications: json['totalNotifications'] ?? 0,
    );
  }
}

// ---------------------------------------------
// Latest Entries Models (UPDATED)
// ---------------------------------------------
class LatestEntries {
  final List<LatestUser> users;
  final List<LatestProperty> properties;
  final List<LatestContract> contracts;
  final List<LatestPayment> payments;
  final List<LatestComplaint> complaints;
  final List<LatestReview> reviews;

  LatestEntries({
    required this.users,
    required this.properties,
    required this.contracts,
    required this.payments,
    required this.complaints,
    required this.reviews,
  });

  factory LatestEntries.fromJson(Map<String, dynamic> json) {
    return LatestEntries(
      users: (json['users'] as List?)
              ?.map((e) => LatestUser.fromJson(e))
              .toList() ??
          [],
      properties: (json['properties'] as List?)
              ?.map((e) => LatestProperty.fromJson(e))
              .toList() ??
          [],
      contracts: (json['contracts'] as List?)
              ?.map((e) => LatestContract.fromJson(e))
              .toList() ??
          [],
      payments: (json['payments'] as List?)
              ?.map((e) => LatestPayment.fromJson(e))
              .toList() ??
          [],
      complaints: (json['complaints'] as List?)
              ?.map((e) => LatestComplaint.fromJson(e))
              .toList() ??
          [],
      reviews: (json['reviews'] as List?)
              ?.map((e) => LatestReview.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class LatestUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final DateTime createdAt;

  LatestUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory LatestUser.fromJson(Map<String, dynamic> json) {
    return LatestUser(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      role: json['role'] ?? 'N/A',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class LatestProperty {
  final String id;
  final String title;
  final double price;
  final String status;
  final DateTime createdAt;

  LatestProperty({
    required this.id,
    required this.title,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  factory LatestProperty.fromJson(Map<String, dynamic> json) {
    return LatestProperty(
      id: json['_id'] ?? '',
      title: json['title'] ?? 'N/A',
      price: (json['price'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'N/A',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class LatestContract {
  final String id;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  LatestContract({
    required this.id,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory LatestContract.fromJson(Map<String, dynamic> json) {
    return LatestContract(
      id: json['_id'] ?? '',
      status: json['status'] ?? 'N/A',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class LatestPayment {
  final String id;
  final double amount;
  final String status;
  final DateTime createdAt;

  LatestPayment({
    required this.id,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory LatestPayment.fromJson(Map<String, dynamic> json) {
    return LatestPayment(
      id: json['_id'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'N/A',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class LatestComplaint {
  final String id;
  final String description;
  final String status;
  final DateTime createdAt;

  LatestComplaint({
    required this.id,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory LatestComplaint.fromJson(Map<String, dynamic> json) {
    return LatestComplaint(
      id: json['_id'] ?? '',
      description: json['description'] ?? 'N/A',
      status: json['status'] ?? 'N/A',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class LatestReview {
  final String id;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String? reviewerName;
  final String? propertyTitle;

  LatestReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.reviewerName,
    this.propertyTitle,
  });

  factory LatestReview.fromJson(Map<String, dynamic> json) {
    return LatestReview(
      id: json['_id'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? 'N/A',
      createdAt: DateTime.parse(json['createdAt']),
      reviewerName: json['reviewerId']?['name'], // Updated to reviewerId
      propertyTitle: json['propertyId']?['title'], // Updated to propertyId
    );
  }
}

// ---------------------------------------------
// Analytics Models (UPDATED to match Backend)
// ---------------------------------------------
class AnalyticsData {
  final List<StatCount> userStats;
  final List<StatCount> propertyStats;
  final List<PaymentStat> paymentStats;
  final List<StatCount> contractStats;
  final List<StatCount> maintenanceStats;
  final List<StatCount> complaintStats;
  final double totalRevenue;

  AnalyticsData({
    required this.userStats,
    required this.propertyStats,
    required this.paymentStats,
    required this.contractStats,
    required this.maintenanceStats,
    required this.complaintStats,
    required this.totalRevenue,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      userStats: (json['userStats'] as List?)
              ?.map((e) => StatCount.fromJson(e))
              .toList() ??
          [],
      propertyStats: (json['propertyStats'] as List?)
              ?.map((e) => StatCount.fromJson(e))
              .toList() ??
          [],
      paymentStats: (json['paymentStats'] as List?)
              ?.map((e) => PaymentStat.fromJson(e))
              .toList() ??
          [],
      contractStats: (json['contractStats'] as List?)
              ?.map((e) => StatCount.fromJson(e))
              .toList() ??
          [],
      maintenanceStats: (json['maintenanceStats'] as List?)
              ?.map((e) => StatCount.fromJson(e))
              .toList() ??
          [],
      complaintStats: (json['complaintStats'] as List?)
              ?.map((e) => StatCount.fromJson(e))
              .toList() ??
          [],
      totalRevenue: (json['totalRevenue'] ?? 0.0).toDouble(),
    );
  }
}

class StatCount {
  final String id;
  final int count;

  StatCount({required this.id, required this.count});

  factory StatCount.fromJson(Map<String, dynamic> json) {
    return StatCount(
      id: json['_id']?.toString() ?? 'N/A',
      count: json['count'] ?? 0,
    );
  }
}

class PaymentStat extends StatCount {
  final double total;

  PaymentStat({required super.id, required super.count, required this.total});

  factory PaymentStat.fromJson(Map<String, dynamic> json) {
    return PaymentStat(
      id: json['_id']?.toString() ?? 'N/A',
      count: json['count'] ?? 0,
      total: (json['total'] ?? 0.0).toDouble(),
    );
  }
}

// ==============================================
// ✅ Admin Dashboard Screen Implementation
// ==============================================

const double _kMobileBreakpoint =
    600.0; // Define mobile breakpoint for responsiveness

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

enum AppAlertType {
  success,
  error,
  info,
} // Re-define if not globally available

// Custom alert function (copy-pasted if not globally available)
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

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  // Added SingleTickerProviderStateMixin for animations
  final Color _primaryGreen = const Color(0xFF2E7D32);
  String? _adminName;
  AdminDashboardData? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  late final AnimationController
      _welcomeAnimController; // Animation for welcome section

  @override
  void initState() {
    super.initState();
    _welcomeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadAdminData();
    _fetchDashboardStats();
  }

  @override
  void dispose() {
    _welcomeAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _adminName = prefs.getString('userName') ?? 'Admin';
    });
    final (ok, userData) = await ApiService.getMe();
    if (ok && userData != null) {
      setState(() {
        _adminName = userData['name'] ?? 'Admin';
      });
    }
  }

  Future<void> _fetchDashboardStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (ok, data) = await ApiService.getAdminDashboard();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (ok) {
          _dashboardData = AdminDashboardData.fromJson(data);
          _welcomeAnimController.forward(
            from: 0,
          ); // Play animation on successful load
        } else {
          _errorMessage = data.toString();
          showAppAlert(
            context: context,
            title: 'Error',
            message: 'Failed to load dashboard data: $data',
            type: AppAlertType.error,
          );
        }
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
    showAppAlert(
      context: context,
      title: 'Logged Out',
      message: 'You have been successfully logged out!',
      type: AppAlertType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: _buildAppBar(screenWidth), // Updated AppBar
      drawer: _AdminDrawer(
        onLogout: _logout,
        adminName: _adminName,
        primaryGreen: _primaryGreen,
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
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading data: $_errorMessage',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchDashboardStats,
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
              : ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > _kMobileBreakpoint ? 24 : 16,
                    vertical: 24,
                  ),
                  children: [
                    _buildWelcomeSection(context),
                    const SizedBox(height: 30),
                    _buildSectionHeader(context, 'System Summary'),
                    const SizedBox(height: 20),
                    _buildSummaryGrid(
                      context,
                      _dashboardData!.summary,
                      screenWidth,
                    ),
                    const SizedBox(height: 40),
                    _buildSectionHeader(context, 'Latest Activities'),
                    const SizedBox(height: 20),
                    _buildLatestActivities(context, _dashboardData!.latest),
                    const SizedBox(height: 40),
                    _buildSectionHeader(context, 'Performance Analytics'),
                    const SizedBox(height: 20),
                    _buildAnalyticsSection(
                      context,
                      _dashboardData!.analytics,
                      screenWidth,
                    ),
                  ],
                ),
    );
  }

  // New: Common Section Header
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
    );
  }

  // Updated AppBar to match User Management Screen style
  AppBar _buildAppBar(double screenWidth) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      titleSpacing: screenWidth > _kMobileBreakpoint ? 12 : 0,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.dashboard, color: _primaryGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Admin Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: screenWidth > _kMobileBreakpoint ? 20 : 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh, color: Colors.black87),
          onPressed: _fetchDashboardStats,
        ),
        screenWidth > _kMobileBreakpoint
            ? TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                label: const Text('Logout'),
                style: TextButton.styleFrom(
                  backgroundColor: _primaryGreen,
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
                icon: Icon(Icons.logout, color: _primaryGreen),
                tooltip: 'Logout',
                onPressed: _logout,
              ),
        if (screenWidth > _kMobileBreakpoint)
          const SizedBox(width: 12)
        else
          const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _welcomeAnimController,
        curve: Curves.easeOut,
      ),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: _primaryGreen,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back, ${_adminName ?? 'Admin'}!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Here\'s a quick overview of your system today.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminSystemSettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings, color: Color(0xFF2E7D32)),
                  label: const Text(
                    'Manage System',
                    style: TextStyle(color: Color(0xFF2E7D32)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ بناء شبكة بطاقات الإحصائيات الملخصة (UPDATED for responsiveness)
  Widget _buildSummaryGrid(
    BuildContext context,
    SummaryStats stats,
    double screenWidth,
  ) {
    int crossAxisCount;
    if (screenWidth > 1200) {
      crossAxisCount = 5;
    } else if (screenWidth > 900) {
      crossAxisCount = 4;
    } else if (screenWidth > _kMobileBreakpoint) {
      // Tablet size
      crossAxisCount = 3;
    } else {
      // Mobile size
      crossAxisCount = 2;
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      childAspectRatio: 1.2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard(
          context,
          'Total Users',
          stats.totalUsers, // Pass int for animation
          Icons.people_alt_outlined,
          Colors.blueAccent,
        ),
        _buildStatCard(
          context,
          'Landlords',
          stats.totalLandlords, // Pass int for animation
          Icons.business_center_outlined,
          Colors.indigo,
        ),
        _buildStatCard(
          context,
          'Tenants',
          stats.totalTenants, // Pass int for animation
          Icons.person_pin_outlined,
          Colors.teal,
        ),
        _buildStatCard(
          context,
          'Properties',
          stats.totalProperties, // Pass int for animation
          Icons.home_work_outlined,
          _primaryGreen,
        ),
        _buildStatCard(
          context,
          'Contracts',
          stats.totalContracts, // Pass int for animation
          Icons.description_outlined,
          Colors.purple,
        ),
        _buildStatCard(
          context,
          'Payments',
          stats.totalPayments, // Pass int for animation
          Icons.credit_card_outlined,
          Colors.orange,
        ),
        _buildStatCard(
          context,
          'Maintenance',
          stats.totalMaintenances, // Pass int for animation
          Icons.build_outlined,
          Colors.brown,
        ),
        _buildStatCard(
          context,
          'Complaints',
          stats.totalComplaints, // Pass int for animation
          Icons.warning_amber_rounded,
          Colors.redAccent,
        ),
        _buildStatCard(
          context,
          'Reviews',
          stats.totalReviews, // Pass int for animation
          Icons.star_outline,
          Colors.amber,
        ),
        _buildStatCard(
          context,
          'Notifications',
          stats.totalNotifications, // Pass int for animation
          Icons.notifications_none_outlined,
          Colors.cyan,
        ),
      ],
    );
  }

  // ✅ بناء بطاقة إحصائية واحدة (مع إضافة TweenAnimationBuilder)
  Widget _buildStatCard(
    BuildContext context,
    String title,
    int value, // Changed to int
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 20,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 1000),
              builder: (context, val, child) {
                return Text(
                  val.toInt().toString(), // Display as int
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ بناء قسم الأنشطة الأخيرة (UPDATED with Card style)
  Widget _buildLatestActivities(BuildContext context, LatestEntries latest) {
    return Column(
      children: [
        _buildLatestSection(
          context,
          title: 'Latest Users',
          items: latest.users,
          itemBuilder: (user) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user.name, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${user.email} - ${user.role}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(DateFormat('yyyy-MM-dd').format(user.createdAt)),
            visualDensity: VisualDensity.compact, // Compact list tile
          ),
          onViewAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminUserManagementScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _buildLatestSection(
          context,
          title: 'Latest Properties',
          items: latest.properties,
          itemBuilder: (property) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.home)),
            title: Text(property.title, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '\$${property.price.toStringAsFixed(0)} - ${property.status}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(DateFormat('yyyy-MM-dd').format(property.createdAt)),
            visualDensity: VisualDensity.compact,
          ),
          onViewAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminPropertyManagementScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _buildLatestSection(
          context,
          title: 'Latest Contracts',
          items: latest.contracts,
          itemBuilder: (contract) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.description)),
            title: Text(
              'Contract Status: ${contract.status}',
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Starts: ${DateFormat('yyyy-MM-dd').format(contract.startDate)} - Ends: ${DateFormat('yyyy-MM-dd').format(contract.endDate)}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(DateFormat('yyyy-MM-dd').format(contract.createdAt)),
            visualDensity: VisualDensity.compact,
          ),
          onViewAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminContractManagementScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _buildLatestSection(
          context,
          title: 'Latest Payments',
          items: latest.payments,
          itemBuilder: (payment) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.credit_card)),
            title: Text(
              'Amount: \$${payment.amount.toStringAsFixed(2)}',
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Status: ${payment.status}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(DateFormat('yyyy-MM-dd').format(payment.createdAt)),
            visualDensity: VisualDensity.compact,
          ),
          onViewAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminPaymentsTransactionsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _buildLatestSection(
          context,
          title: 'Latest Complaints',
          items: latest.complaints,
          itemBuilder: (complaint) => ListTile(
            leading: const CircleAvatar(child: Icon(Icons.report)),
            title: Text(complaint.description, overflow: TextOverflow.ellipsis),
            subtitle: Text(complaint.status, overflow: TextOverflow.ellipsis),
            trailing: Text(
              DateFormat('yyyy-MM-dd').format(complaint.createdAt),
            ),
            visualDensity: VisualDensity.compact,
          ),
          onViewAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminMaintenanceComplaintsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _buildLatestSection(
          context,
          title: 'Latest Reviews',
          items: latest.reviews,
          itemBuilder: (review) => ListTile(
            leading: CircleAvatar(child: Text(review.rating.toString())),
            title: Text(review.comment, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              'By ${review.reviewerName ?? 'Anonymous'} for ${review.propertyTitle ?? 'N/A'}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(DateFormat('yyyy-MM-dd').format(review.createdAt)),
            visualDensity: VisualDensity.compact,
          ),
          onViewAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminReviewsManagementScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  // ✅ دالة مساعدة لبناء أقسام الأنشطة الأخيرة (UPDATED to match Card styling)
  Widget _buildLatestSection<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    VoidCallback? onViewAll,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    child: Text(
                      'View All',
                      style: TextStyle(color: _primaryGreen),
                    ),
                  ),
              ],
            ),
            const Divider(height: 25),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length > 3
                  ? 3
                  : items.length, // Show max 3 latest items
              itemBuilder: (context, index) => itemBuilder(items[index]),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ بناء قسم التحليلات (UPDATED - Pie Chart for User Stats)
  Widget _buildAnalyticsSection(
    BuildContext context,
    AnalyticsData analytics,
    double screenWidth,
  ) {
    final Color primaryGreen = const Color(0xFF2E7D32);

    final List<PieChartSectionData> userPieChartSections =
        analytics.userStats.map((stat) {
      Color color;
      switch (stat.id.toLowerCase()) {
        case 'admin':
          color = Colors.redAccent;
          break;
        case 'landlord':
          color = Colors.blueAccent;
          break;
        case 'tenant':
          color = primaryGreen;
          break;
        default:
          color = Colors.grey;
      }
      return PieChartSectionData(
        color: color,
        value: stat.count.toDouble(),
        title: '${stat.id} (${stat.count})',
        radius: screenWidth > _kMobileBreakpoint ? 80 : 60, // Responsive radius
        titleStyle: TextStyle(
          fontSize: screenWidth > _kMobileBreakpoint
              ? 14
              : 12, // Responsive font size
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: _Badge(
          stat.id,
          size: screenWidth > _kMobileBreakpoint ? 20 : 16,
          borderColor: color,
        ), // Responsive badge size
        badgePositionPercentageOffset: .98,
      );
    }).toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const Divider(height: 25),
            _buildAnalyticsItem(
              'Total Revenue',
              '\$${analytics.totalRevenue.toStringAsFixed(2)}',
              Icons.monetization_on,
              Colors.green,
            ),
            const SizedBox(height: 20),
            Text(
              'User Distribution by Role',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: screenWidth > _kMobileBreakpoint
                  ? 300
                  : 250, // Responsive height
              child: PieChart(
                PieChartData(
                  sections: userPieChartSections,
                  centerSpaceRadius: screenWidth > _kMobileBreakpoint
                      ? 40
                      : 30, // Responsive center space
                  sectionsSpace: 2,
                  startDegreeOffset: 180,
                  pieTouchData: PieTouchData(
                    touchCallback: (
                      FlTouchEvent event,
                      PieTouchResponse? pieTouchResponse,
                    ) {
                      // يمكنك إضافة تفاعل هنا
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Legend for the Pie Chart
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: analytics.userStats.map((stat) {
                Color color;
                switch (stat.id.toLowerCase()) {
                  case 'admin':
                    color = Colors.redAccent;
                    break;
                  case 'landlord':
                    color = Colors.blueAccent;
                    break;
                  case 'tenant':
                    color = primaryGreen;
                    break;
                  default:
                    color = Colors.grey;
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 16, height: 16, color: color),
                    const SizedBox(width: 8),
                    Text(stat.id, style: const TextStyle(fontSize: 14)),
                  ],
                );
              }).toList(),
            ),

            // باقي الإحصائيات في شكل قوائم
            const SizedBox(height: 20),
            _buildStatList(
              context,
              'Properties by Status',
              analytics.propertyStats,
            ),
            _buildPaymentStatList(
              context,
              'Payments by Status',
              analytics.paymentStats,
            ),
            _buildStatList(
              context,
              'Contracts by Status',
              analytics.contractStats,
            ),
            _buildStatList(
              context,
              'Maintenance by Status',
              analytics.maintenanceStats,
            ),
            _buildStatList(
              context,
              'Complaints by Status',
              analytics.complaintStats,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ بناء عنصر تحليل بسيط
  Widget _buildAnalyticsItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Text(
            '$title: ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Expanded(
            // Added Expanded to handle long values
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis, // Added
            ),
          ),
        ],
      ),
    );
  }

  // ✅ بناء قائمة إحصائيات عامة (حسب الحالة/الدور)
  Widget _buildStatList(
    BuildContext context,
    String title,
    List<StatCount> stats,
  ) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          ...stats
              .map(
                (stat) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        // Added Expanded
                        child: Text(
                          stat.id,
                          style: const TextStyle(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ), // Added
                      ),
                      Text(
                        stat.count.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  // ✅ بناء قائمة إحصائيات الدفعات (تتضمن الإجمالي)
  Widget _buildPaymentStatList(
    BuildContext context,
    String title,
    List<PaymentStat> stats,
  ) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          ...stats
              .map(
                (stat) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        // Added Expanded
                        child: Text(
                          '${stat.id} (${stat.count})',
                          style: const TextStyle(fontSize: 15),
                          overflow: TextOverflow.ellipsis, // Added
                        ),
                      ),
                      Text(
                        '\$${stat.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}

// ✅ شريط التنقل الجانبي (Drawer) للأدمن
class _AdminDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  final String? adminName;
  final Color primaryGreen;

  const _AdminDrawer({
    required this.onLogout,
    this.adminName,
    required this.primaryGreen,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              adminName ?? 'Admin User',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            accountEmail: const Text(
              'admin@shaqati.com',
              style: TextStyle(color: Colors.white70),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: primaryGreen, size: 40),
            ),
            decoration: BoxDecoration(color: primaryGreen),
          ),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard Home',
            onTap: () {
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.people_alt_outlined,
            title: 'User Management',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminUserManagementScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.apartment_outlined,
            title: 'Property Management',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPropertyManagementScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.description_outlined,
            title: 'Contract Management',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminContractManagementScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.credit_card_outlined,
            title: 'Payments & Transactions',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPaymentsTransactionsScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.report_problem_outlined,
            title: 'Maintenance & Complaints',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminMaintenanceComplaintsScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.star_outline,
            title: 'Reviews Management',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminReviewsManagementScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.notifications_none_outlined,
            title: 'Notifications Management',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminNotificationsManagementScreen(),
                ),
              );
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'System Settings',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminSystemSettingsScreen(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: onLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryGreen),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}

// ✅ Badge Widget for Pie Chart labels
class _Badge extends StatelessWidget {
  const _Badge(
    this.text, {
    required this.size,
    required this.borderColor,
    super.key,
  });
  final String text;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.5),
            offset: const Offset(3, 3),
            blurRadius: 3,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(
        child: Text(
          text[0].toUpperCase(),
          style: TextStyle(color: borderColor, fontSize: size * 0.7),
        ),
      ),
    );
  }
}
