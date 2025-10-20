import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/home_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// ✅ Import all new Admin Management Screens
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
      reviewerName: json['reviewerId']?['name'],
      propertyTitle: json['propertyId']?['title'],
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

const double _kMobileBreakpoint = 600.0; // Mobile breakpoint for responsiveness

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

enum AppAlertType {
  success,
  error,
  info,
}

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

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  // --- UPDATED COLOR PALETTE (matching LoginScreen's green) ---
  final Color _primaryGreen =
      const Color(0xFF2E7D32); // The exact green from LoginScreen
  final Color _lightGreenAccent =
      const Color(0xFFE8F5E9); // A very light tint of green for accents
  final Color _darkGreenAccent =
      const Color(0xFF1B5E20); // A darker shade of green

  final Color _scaffoldBackground = const Color(0xFFFAFAFA); // Grey 50
  final Color _cardBackground = Colors.white;
  final Color _textPrimary = const Color(0xFF424242); // Grey 800
  final Color _textSecondary = const Color(0xFF757575); // Grey 600
  final Color _borderColor = const Color(0xFFE0E0E0); // Grey 300

  // Diverse colors for charts and stat cards, complementary to green
  final List<Color> _chartAndStatColors = [
    const Color(0xFF4CAF50), // A slightly brighter green for variety
    Colors.blueAccent.shade400,
    Colors.orange.shade600,
    Colors.purple.shade400,
    Colors.redAccent.shade400,
    Colors.teal.shade400,
    Colors.amber.shade600,
    Colors.indigo.shade400,
    Colors.brown.shade400,
    Colors.cyan.shade400,
  ];

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
              from: 0); // Play animation on successful load
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
    final bool isMobile = screenWidth < _kMobileBreakpoint;

    // Common body for both mobile and web (except navigation)
    Widget commonBodyContent = _isLoading
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
                        style: const TextStyle(color: Colors.red, fontSize: 16),
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
            : RefreshIndicator(
                onRefresh: _fetchDashboardStats, // Added pull-to-refresh
                color: _primaryGreen,
                child: ListView(
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
                    const SizedBox(height: 40),
                  ],
                ),
              );

    if (isMobile) {
      return Scaffold(
        backgroundColor: _scaffoldBackground, // Set Scaffold background
        appBar: _buildMobileAppBar(screenWidth), // Mobile specific AppBar
        drawer: _AdminDrawer(
          onLogout: _logout,
          adminName: _adminName,
          primaryGreen: _primaryGreen,
          textPrimary: _textPrimary,
        ),
        body: commonBodyContent,
      );
    } else {
      // Web Layout
      return Scaffold(
        backgroundColor: _scaffoldBackground,
        // No AppBar for web Scaffold, it's replaced by _buildWebHeader
        body: Row(
          children: [
            // Persistent Sidebar for Web
            _WebSidebar(
              onLogout: _logout,
              adminName: _adminName,
              primaryGreen: _primaryGreen,
              textPrimary: _textPrimary,
              darkGreenAccent: _darkGreenAccent,
              cardBackground: _cardBackground,
              borderColor: _borderColor,
            ),
            Expanded(
              child: Column(
                children: [
                  // Custom header for the main content area (replaces AppBar for web)
                  _buildWebHeader(
                    screenWidth,
                    _fetchDashboardStats,
                    _logout,
                  ),
                  Expanded(
                    child: commonBodyContent, // Main content for web
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // Common Section Header
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
    );
  }

  // Mobile AppBar
  AppBar _buildMobileAppBar(double screenWidth) {
    return AppBar(
      elevation: 1, // Slightly raised for better separation
      backgroundColor: _cardBackground, // White background for a clean look
      foregroundColor: _textPrimary,
      titleSpacing: 0, // No extra title spacing for mobile
      iconTheme: IconThemeData(color: _textPrimary), // Drawer icon color
      title: Row(
        children: [
          Container(
            width: 44, // Slightly larger icon container
            height: 44,
            decoration: BoxDecoration(
              color: _lightGreenAccent, // Softer green background
              borderRadius: BorderRadius.circular(12), // More rounded
            ),
            child: Icon(Icons.dashboard,
                color: _primaryGreen, size: 28), // Larger icon
          ),
          const SizedBox(width: 14), // Increased spacing
          Expanded(
            child: Text(
              'Admin Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18, // Fixed font size for mobile
                color: _textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh Data',
          icon: Icon(Icons.refresh, color: _textPrimary),
          onPressed: _fetchDashboardStats,
        ),
        IconButton(
          icon: Icon(Icons.logout,
              color: _darkGreenAccent), // Dark green icon for mobile
          tooltip: 'Logout',
          onPressed: _logout,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // New: Custom Web Header (replaces AppBar for web)
  Widget _buildWebHeader(
      double screenWidth, VoidCallback onRefresh, VoidCallback onLogout) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth > _kMobileBreakpoint ? 24 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBackground, // White background for the header
        border: Border(
            bottom: BorderSide(
                color: _borderColor, width: 1)), // Subtle bottom border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02), // Very light shadow
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _lightGreenAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.dashboard, color: _primaryGreen, size: 28),
              ),
              const SizedBox(width: 14),
              Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: _textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Refresh Data',
                icon: Icon(Icons.refresh, color: _textPrimary),
                onPressed: onRefresh,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkGreenAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _welcomeAnimController,
        curve: Curves.easeOut,
      ),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)), // More rounded
        color: _primaryGreen, // Primary green for welcome card
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(32.0), // More padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back, ${_adminName ?? 'Admin'}!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28, // Larger font
                    ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Here\'s a quick overview of your system today.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 30), // More spacing
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
                  icon: Icon(Icons.settings, color: _primaryGreen),
                  label: Text(
                    'Manage System',
                    style: TextStyle(
                        color: _primaryGreen, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14), // More padding
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Build Summary Stats Grid with animations
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
      crossAxisCount = 3;
    } else {
      crossAxisCount = 2;
    }

    // Use a subset of _chartAndStatColors or define specific ones
    final List<Color> statCardColors = [
      _chartAndStatColors[0], // Slightly brighter green for variety
      Colors.blueAccent.shade400,
      _primaryGreen, // Primary Green for some cards
      Colors.orange.shade600,
      Colors.purple.shade400,
      Colors.redAccent.shade400,
      Colors.teal.shade400,
      Colors.amber.shade600,
      Colors.indigo.shade400,
      Colors.cyan.shade400,
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.1,
        crossAxisSpacing: 20, // Increased spacing
        mainAxisSpacing: 20, // Increased spacing
      ),
      itemCount: 10, // Total number of stat cards
      itemBuilder: (context, index) {
        // Define data for each card dynamically
        String title;
        int value;
        IconData icon;
        Color color = statCardColors[
            index % statCardColors.length]; // Cycle through colors

        switch (index) {
          case 0:
            title = 'Total Users';
            value = stats.totalUsers;
            icon = Icons.people_alt_outlined;
            break;
          case 1:
            title = 'Landlords';
            value = stats.totalLandlords;
            icon = Icons.business_center_outlined;
            break;
          case 2:
            title = 'Tenants';
            value = stats.totalTenants;
            icon = Icons.person_pin_outlined;
            break;
          case 3:
            title = 'Properties';
            value = stats.totalProperties;
            icon = Icons.home_work_outlined;
            break;
          case 4:
            title = 'Contracts';
            value = stats.totalContracts;
            icon = Icons.description_outlined;
            break;
          case 5:
            title = 'Payments';
            value = stats.totalPayments;
            icon = Icons.credit_card_outlined;
            break;
          case 6:
            title = 'Maintenance';
            value = stats.totalMaintenances;
            icon = Icons.build_outlined;
            break;
          case 7:
            title = 'Complaints';
            value = stats.totalComplaints;
            icon = Icons.warning_amber_rounded;
            break;
          case 8:
            title = 'Reviews';
            value = stats.totalReviews;
            icon = Icons.star_outline;
            break;
          case 9:
            title = 'Notifications';
            value = stats.totalNotifications;
            icon = Icons.notifications_none_outlined;
            break;
          default:
            title = 'N/A';
            value = 0;
            icon = Icons.info_outline;
        }

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration:
              Duration(milliseconds: 500 + index * 100), // Staggered animation
          builder: (context, opacity, child) {
            return Transform.scale(
              scale: opacity, // Scale from 0 to 1
              child: Opacity(
                opacity: opacity, // Fade from 0 to 1
                child: _buildStatCard(context, title, value, icon, color),
              ),
            );
          },
        );
      },
    );
  }

  // ✅ Build a single stat card with TweenAnimationBuilder for value and animation
  Widget _buildStatCard(
    BuildContext context,
    String title,
    int value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _borderColor, width: 0.8), // Subtle border
      ),
      color: _cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15), // Softer background
              radius: 26, // Larger icon background
              child: Icon(icon, color: color, size: 30), // Larger icon
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                color: _textSecondary, // Secondary text color
                fontWeight: FontWeight.w500,
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 1200),
              builder: (context, val, child) {
                return Text(
                  val.toInt().toString(), // Display as int
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _textPrimary, // Primary text color for numbers
                        fontSize: 30, // Larger number font
                      ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Build Latest Activities Section with animations
  Widget _buildLatestActivities(BuildContext context, LatestEntries latest) {
    return Column(
      children: [
        _buildAnimatedLatestSection<LatestUser>(
          context,
          title: 'Latest Users',
          items: latest.users,
          itemBuilder: (user) => _buildLatestActivityTile(
            icon: Icons.person,
            iconColor: _chartAndStatColors[0],
            title: user.name,
            subtitle: '${user.email} - ${user.role}',
            trailing: DateFormat('yyyy-MM-dd').format(user.createdAt),
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
        _buildAnimatedLatestSection<LatestProperty>(
          context,
          title: 'Latest Properties',
          items: latest.properties,
          itemBuilder: (property) => _buildLatestActivityTile(
            icon: Icons.home,
            iconColor: _primaryGreen,
            title: property.title,
            subtitle:
                '\$${property.price.toStringAsFixed(0)} - ${property.status}',
            trailing: DateFormat('yyyy-MM-dd').format(property.createdAt),
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
        _buildAnimatedLatestSection<LatestContract>(
          context,
          title: 'Latest Contracts',
          items: latest.contracts,
          itemBuilder: (contract) => _buildLatestActivityTile(
            icon: Icons.description,
            iconColor: _chartAndStatColors[3], // Purple
            title: 'Contract Status: ${contract.status}',
            subtitle:
                'Starts: ${DateFormat('yyyy-MM-dd').format(contract.startDate)} - Ends: ${DateFormat('yyyy-MM-dd').format(contract.endDate)}',
            trailing: DateFormat('yyyy-MM-dd').format(contract.createdAt),
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
        _buildAnimatedLatestSection<LatestPayment>(
          context,
          title: 'Latest Payments',
          items: latest.payments,
          itemBuilder: (payment) => _buildLatestActivityTile(
            icon: Icons.credit_card,
            iconColor: _chartAndStatColors[5], // Red
            title: 'Amount: \$${payment.amount.toStringAsFixed(2)}',
            subtitle: 'Status: ${payment.status}',
            trailing: DateFormat('yyyy-MM-dd').format(payment.createdAt),
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
        _buildAnimatedLatestSection<LatestComplaint>(
          context,
          title: 'Latest Complaints',
          items: latest.complaints,
          itemBuilder: (complaint) => _buildLatestActivityTile(
            icon: Icons.report,
            iconColor: _chartAndStatColors[4], // Blue Grey
            title: complaint.description,
            subtitle: complaint.status,
            trailing: DateFormat('yyyy-MM-dd').format(complaint.createdAt),
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
        _buildAnimatedLatestSection<LatestReview>(
          context,
          title: 'Latest Reviews',
          items: latest.reviews,
          itemBuilder: (review) => _buildLatestActivityTile(
            icon: Icons.star,
            iconColor: _chartAndStatColors[6], // Light Green
            title: review.comment,
            subtitle:
                'By ${review.reviewerName ?? 'Anonymous'} for ${review.propertyTitle ?? 'N/A'} (Rating: ${review.rating})',
            trailing: DateFormat('yyyy-MM-dd').format(review.createdAt),
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

  // Custom ListTile for latest activities with animation
  Widget _buildLatestActivityTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0), // Increased margin
      padding: const EdgeInsets.symmetric(
          vertical: 12, horizontal: 16), // Increased padding
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(14), // More rounded
        border: Border.all(color: _borderColor, width: 0.6), // Subtle border
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.15),
            radius: 20, // Slightly larger
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: _textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: _textSecondary, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style:
                TextStyle(color: _textSecondary.withOpacity(0.7), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // Helper function to build latest activity sections with staggered animation
  Widget _buildAnimatedLatestSection<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    VoidCallback? onViewAll,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18)), // More rounded
      color: _cardBackground,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Increased padding
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
                        color: _textPrimary,
                      ),
                ),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    style: TextButton.styleFrom(
                      foregroundColor:
                          _darkGreenAccent, // Darker green for text button
                    ),
                    child: const Text(
                      'View All',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
              ],
            ),
            Divider(height: 28, color: _borderColor), // Use border color
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length > 3
                  ? 3
                  : items.length, // Show max 3 latest items
              itemBuilder: (context, index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(
                      milliseconds: 400 + index * 100), // Staggered animation
                  builder: (context, opacity, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - opacity)), // Slide up effect
                      child: Opacity(
                        opacity: opacity,
                        child: itemBuilder(items[index]),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Build Analytics Section with improved visuals
  Widget _buildAnalyticsSection(
    BuildContext context,
    AnalyticsData analytics,
    double screenWidth,
  ) {
    final List<PieChartSectionData> userPieChartSections =
        analytics.userStats.map((stat) {
      Color color;
      switch (stat.id.toLowerCase()) {
        case 'admin':
          color = _chartAndStatColors[4]; // RedAccent
          break;
        case 'landlord':
          color = _chartAndStatColors[1]; // BlueAccent
          break;
        case 'tenant':
          color = _primaryGreen; // Primary Green
          break;
        default:
          color = _textSecondary.withOpacity(0.5); // Grey
      }
      return PieChartSectionData(
        color: color,
        value: stat.count.toDouble(),
        title: '${stat.id} (${stat.count})',
        radius: screenWidth > _kMobileBreakpoint ? 90 : 70, // Responsive radius
        titleStyle: TextStyle(
          fontSize: screenWidth > _kMobileBreakpoint
              ? 16
              : 14, // Responsive font size
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        badgeWidget: _Badge(
          stat.id,
          size: screenWidth > _kMobileBreakpoint ? 24 : 20,
          borderColor: color,
        ),
        badgePositionPercentageOffset: .98,
      );
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18)), // More rounded
      color: _cardBackground,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(28.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Analytics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
            ),
            Divider(height: 32, color: _borderColor),
            // Total Revenue Card
            _buildRevenueCard(analytics.totalRevenue),
            const SizedBox(height: 30),

            Text(
              'User Distribution by Role',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: screenWidth > _kMobileBreakpoint
                  ? 340
                  : 300, // Responsive height
              child: PieChart(
                PieChartData(
                  sections: userPieChartSections,
                  centerSpaceRadius: screenWidth > _kMobileBreakpoint
                      ? 50
                      : 40, // Responsive center space
                  sectionsSpace: 4, // Increased sections space
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (
                      FlTouchEvent event,
                      PieTouchResponse? pieTouchResponse,
                    ) {
                      // Add interaction here if needed
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Legend for the Pie Chart
            Wrap(
              spacing: 20, // Increased spacing
              runSpacing: 12, // Increased spacing
              children: analytics.userStats.map((stat) {
                Color color;
                switch (stat.id.toLowerCase()) {
                  case 'admin':
                    color = _chartAndStatColors[4];
                    break;
                  case 'landlord':
                    color = _chartAndStatColors[1];
                    break;
                  case 'tenant':
                    color = _primaryGreen;
                    break;
                  default:
                    color = _textSecondary.withOpacity(0.5);
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20, // Larger legend color box
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius:
                            BorderRadius.circular(6), // More rounded square
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      stat.id,
                      style: TextStyle(fontSize: 16, color: _textPrimary),
                    ),
                  ],
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
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

  // New: Dedicated Revenue Card
  Widget _buildRevenueCard(double totalRevenue) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: _lightGreenAccent, // Light green background
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          children: [
            Icon(Icons.monetization_on, color: _primaryGreen, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Revenue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: totalRevenue),
                    duration: const Duration(milliseconds: 1500),
                    builder: (context, val, child) {
                      return Text(
                        '\$${val.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          color: _primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build general stat list
  Widget _buildStatList(
    BuildContext context,
    String title,
    List<StatCount> stats,
  ) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 25.0, bottom: 5), // Increased spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
          ),
          const SizedBox(height: 12), // Spacing after title
          ...stats
              .map(
                (stat) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0, // More vertical padding
                    horizontal: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          stat.id,
                          style: TextStyle(fontSize: 16, color: _textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        stat.count.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryGreen,
                        ),
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

  // Build payment stat list (includes total)
  Widget _buildPaymentStatList(
    BuildContext context,
    String title,
    List<PaymentStat> stats,
  ) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 25.0, bottom: 5), // Increased spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
          ),
          const SizedBox(height: 12), // Spacing after title
          ...stats
              .map(
                (stat) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0, // More vertical padding
                    horizontal: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${stat.id} (${stat.count})',
                          style: TextStyle(fontSize: 16, color: _textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${stat.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _primaryGreen,
                        ),
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

// ✅ Admin Drawer - This now serves as the MOBILE Drawer
class _AdminDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  final String? adminName;
  final Color primaryGreen;
  final Color textPrimary;
  final Color darkGreenAccent =
      const Color(0xFF1B5E20); // Darker shade for accents

  const _AdminDrawer({
    required this.onLogout,
    this.adminName,
    required this.primaryGreen,
    required this.textPrimary,
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
                fontSize: 18,
              ),
            ),
            accountEmail: const Text(
              'admin@shaqati.com',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: primaryGreen, size: 45),
            ),
            decoration:
                BoxDecoration(color: primaryGreen), // Primary green background
            margin: EdgeInsets.zero,
            otherAccountsPictures: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminSystemSettingsScreen()),
                  );
                },
              ),
            ],
          ),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard Home',
            onTap: () {
              Navigator.pop(context);
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
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
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
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
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
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
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
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
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
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
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
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
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
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
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          Divider(
              color: Colors.grey.shade300,
              height: 25,
              indent: 15,
              endIndent: 15),
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
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: onLogout,
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color primaryGreen,
    required Color textPrimary,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryGreen),
      title: Text(title, style: TextStyle(fontSize: 16, color: textPrimary)),
      onTap: onTap,
      hoverColor: primaryGreen.withOpacity(0.1),
      splashColor: primaryGreen.withOpacity(0.2),
    );
  }
}

// ✅ Web Sidebar - New widget for persistent navigation on web
class _WebSidebar extends StatelessWidget {
  final VoidCallback onLogout;
  final String? adminName;
  final Color primaryGreen;
  final Color textPrimary;
  final Color darkGreenAccent;
  final Color cardBackground;
  final Color borderColor;

  const _WebSidebar({
    required this.onLogout,
    this.adminName,
    required this.primaryGreen,
    required this.textPrimary,
    required this.darkGreenAccent,
    required this.cardBackground,
    required this.borderColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280, // Fixed width for the web sidebar
      decoration: BoxDecoration(
        color: cardBackground, // Use cardBackground for consistency
        border: Border(
            right: BorderSide(color: borderColor, width: 0.6)), // Softer border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03), // Even lighter shadow
            blurRadius: 6, // Softer blur
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              adminName ?? 'Admin User',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            accountEmail: const Text(
              'admin@shaqati.com',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: primaryGreen, size: 45),
            ),
            decoration: BoxDecoration(color: primaryGreen),
            margin: EdgeInsets.zero,
            otherAccountsPictures: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminSystemSettingsScreen()),
                  );
                },
              ),
            ],
          ),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard Home',
            onTap: () {
              // On web, tapping dashboard home usually means staying on the dashboard.
              // For simplicity, do nothing as we are already on the dashboard.
              // Or scroll to top of the content if a scroll controller is available.
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.people_alt_outlined,
            title: 'User Management',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminUserManagementScreen(),
                ),
              );
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.apartment_outlined,
            title: 'Property Management',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPropertyManagementScreen(),
                ),
              );
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.description_outlined,
            title: 'Contract Management',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminContractManagementScreen(),
                ),
              );
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.credit_card_outlined,
            title: 'Payments & Transactions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPaymentsTransactionsScreen(),
                ),
              );
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.report_problem_outlined,
            title: 'Maintenance & Complaints',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminMaintenanceComplaintsScreen(),
                ),
              );
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.star_outline,
            title: 'Reviews Management',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminReviewsManagementScreen(),
                ),
              );
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.notifications_none_outlined,
            title: 'Notifications Management',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminNotificationsManagementScreen(),
                ),
              );
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          Divider(
              color: Colors.grey.shade300,
              height: 25,
              indent: 15,
              endIndent: 15),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'System Settings',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminSystemSettingsScreen(),
                ),
              );
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          // Logout button in the sidebar for web, as an alternative to the AppBar one
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Logout',
            onTap: onLogout,
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color primaryGreen,
    required Color textPrimary,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryGreen),
      title: Text(title, style: TextStyle(fontSize: 16, color: textPrimary)),
      onTap: onTap,
      hoverColor: primaryGreen.withOpacity(0.1),
      splashColor: primaryGreen.withOpacity(0.2),
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
            color: Colors.black.withOpacity(.3),
            offset: const Offset(2, 2),
            blurRadius: 2,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(
        child: Text(
          text[0].toUpperCase(),
          style: TextStyle(
              color: borderColor,
              fontSize: size * 0.7,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
