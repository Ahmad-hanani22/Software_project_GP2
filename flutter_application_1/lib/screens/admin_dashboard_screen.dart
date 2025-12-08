import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart'; // Import for image picker
import 'package:flutter_application_1/screens/chat_list_screen.dart';
// تأكد من صحة مسارات الاستيراد الخاصة بمشروعك
import 'package:flutter_application_1/screens/home_page.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/admin_user_management_screen.dart';
import 'package:flutter_application_1/screens/admin_property_management_screen.dart';
import 'package:flutter_application_1/screens/admin_contract_management_screen.dart';
import 'package:flutter_application_1/screens/admin_payments_transactions_screen.dart';
import 'package:flutter_application_1/screens/admin_maintenance_complaints_screen.dart';
import 'package:flutter_application_1/screens/admin_reviews_management_screen.dart';
import 'package:flutter_application_1/screens/admin_notifications_management_screen.dart';
import 'package:flutter_application_1/screens/admin_system_settings_screen.dart';

// --- Models ---

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

const double _kMobileBreakpoint = 600.0;

// --- Screens ---

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

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
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: iconColor)),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
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
                      borderRadius: BorderRadius.circular(12)),
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
  final Color _primaryGreen = const Color(0xFF2E7D32);
  final Color _lightGreenAccent = const Color(0xFFE8F5E9);
  final Color _darkGreenAccent = const Color(0xFF1B5E20);
  final Color _scaffoldBackground = const Color(0xFFFAFAFA);
  final Color _cardBackground = Colors.white;
  final Color _textPrimary = const Color(0xFF424242);
  final Color _textSecondary = const Color(0xFF757575);
  final Color _borderColor = const Color(0xFFE0E0E0);

  final List<Color> _chartAndStatColors = [
    const Color(0xFF4CAF50),
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
  String? _adminEmail;
  String? _adminProfilePic; // ✅ تم إضافة المتغير هنا

  AdminDashboardData? _dashboardData;
  bool _isLoading = true;
  String? _errorMessage;
  late final AnimationController _welcomeAnimController;

  // --- Badge Logic Variables ---
  int _seenContracts = 0;
  int _seenPayments = 0;
  int _seenMaintenanceComplaints = 0;
  int _seenReviews = 0;
  int _seenNotifications = 0;

  @override
  void initState() {
    super.initState();
    _welcomeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadAdminData();
    // Load local 'seen' counts first, then fetch server data
    _loadSeenCounts().then((_) => _fetchDashboardStats());
  }

  @override
  void dispose() {
    _welcomeAnimController.dispose();
    super.dispose();
  }

  // 1. Load Last Seen Counts from SharedPreferences
  Future<void> _loadSeenCounts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _seenContracts = prefs.getInt('seen_contracts') ?? 0;
      _seenPayments = prefs.getInt('seen_payments') ?? 0;
      _seenMaintenanceComplaints =
          prefs.getInt('seen_maintenance_complaints') ?? 0;
      _seenReviews = prefs.getInt('seen_reviews') ?? 0;
      _seenNotifications = prefs.getInt('seen_notifications') ?? 0;
    });
  }

  // 2. Mark Section as Seen (Update SharedPreferences)
  Future<void> _markSectionAsSeen(String key, int currentTotal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, currentTotal);

    setState(() {
      if (key == 'seen_contracts') _seenContracts = currentTotal;
      if (key == 'seen_payments') _seenPayments = currentTotal;
      if (key == 'seen_maintenance_complaints')
        _seenMaintenanceComplaints = currentTotal;
      if (key == 'seen_reviews') _seenReviews = currentTotal;
      if (key == 'seen_notifications') _seenNotifications = currentTotal;
    });
  }

  // 3. Calculate Unread Items
  int _getUnreadCount(int currentTotal, int seenTotal) {
    int unread = currentTotal - seenTotal;
    return unread > 0 ? unread : 0;
  }

  Future<void> _loadAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _adminName = prefs.getString('userName') ?? 'Admin';
      // نحاول نجيب الايميل من الكاش مبدئياً اذا كنت مخزنه، او نتركه فارغ
    });
    
    // جلب البيانات من السيرفر
    final (ok, userData) = await ApiService.getMe();
    if (ok && userData != null) {
      setState(() {
        _adminName = userData['name'] ?? 'Admin';
        _adminEmail = userData['email'] ?? 'admin@shaqati.com';
        _adminProfilePic = userData['profilePicture']; // ✅ جلب الصورة
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
          _welcomeAnimController.forward(from: 0);
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

    // --- Stats & Badges Logic ---
    final stats = _dashboardData?.summary;
    final int totalContracts = stats?.totalContracts ?? 0;
    final int totalPayments = stats?.totalPayments ?? 0;
    final int totalMaintComplaints =
        (stats?.totalComplaints ?? 0) + (stats?.totalMaintenances ?? 0);
    final int totalReviews = stats?.totalReviews ?? 0;
    final int totalNotifications = stats?.totalNotifications ?? 0;

    final int newContracts = _getUnreadCount(totalContracts, _seenContracts);
    final int newPayments = _getUnreadCount(totalPayments, _seenPayments);
    final int newMaintComplaints =
        _getUnreadCount(totalMaintComplaints, _seenMaintenanceComplaints);
    final int newReviews = _getUnreadCount(totalReviews, _seenReviews);
    final int newNotifications =
        _getUnreadCount(totalNotifications, _seenNotifications);

    Widget commonBodyContent = _isLoading
        ? Center(child: CircularProgressIndicator(color: _primaryGreen))
        : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text('Error loading data: $_errorMessage',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _fetchDashboardStats,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchDashboardStats,
                color: _primaryGreen,
                child: ListView(
                  padding: EdgeInsets.symmetric(
                      horizontal: screenWidth > _kMobileBreakpoint ? 24 : 16,
                      vertical: 24),
                  children: [
                    _buildWelcomeSection(context),
                    const SizedBox(height: 30),
                    _buildSectionHeader(context, 'System Summary'),
                    const SizedBox(height: 20),
                    _buildSummaryGrid(
                        context, _dashboardData!.summary, screenWidth),
                    const SizedBox(height: 40),
                    _buildSectionHeader(context, 'Latest Activities'),
                    const SizedBox(height: 20),
                    _buildLatestActivities(context, _dashboardData!.latest),
                    const SizedBox(height: 40),
                    _buildSectionHeader(context, 'Performance Analytics'),
                    const SizedBox(height: 20),
                    _buildAnalyticsSection(
                        context, _dashboardData!.analytics, screenWidth),
                    const SizedBox(height: 40),
                  ],
                ),
              );

    if (isMobile) {
      return Scaffold(
        backgroundColor: _scaffoldBackground,
        appBar: _buildMobileAppBar(screenWidth),
        drawer: _AdminDrawer(
          onLogout: _logout,
          adminName: _adminName,
          primaryGreen: _primaryGreen,
          textPrimary: _textPrimary,

          // Badge Counts
          badgeContracts: newContracts,
          badgePayments: newPayments,
          badgeMaintComplaints: newMaintComplaints,
          badgeReviews: newReviews,
          badgeNotifications: newNotifications,

          // Callbacks to clear badges
          onTapContracts: () =>
              _markSectionAsSeen('seen_contracts', totalContracts),
          onTapPayments: () =>
              _markSectionAsSeen('seen_payments', totalPayments),
          onTapMaintComplaints: () => _markSectionAsSeen(
              'seen_maintenance_complaints', totalMaintComplaints),
          onTapReviews: () => _markSectionAsSeen('seen_reviews', totalReviews),
          onTapNotifications: () =>
              _markSectionAsSeen('seen_notifications', totalNotifications),
        ),
        body: commonBodyContent,
      );
    } else {
      return Scaffold(
        backgroundColor: _scaffoldBackground,
        body: Row(
          children: [
            _WebSidebar(
              onLogout: _logout,
              adminName: _adminName,
              adminEmail: _adminEmail,
              adminProfilePic: _adminProfilePic, // ✅ تمرير الصورة
              primaryGreen: _primaryGreen,
              textPrimary: _textPrimary,
              darkGreenAccent: _darkGreenAccent,
              cardBackground: _cardBackground,
              borderColor: _borderColor,

              // Badge Counts
              badgeContracts: newContracts,
              badgePayments: newPayments,
              badgeMaintComplaints: newMaintComplaints,
              badgeReviews: newReviews,
              badgeNotifications: newNotifications,

              // Callbacks to clear badges
              onTapContracts: () =>
                  _markSectionAsSeen('seen_contracts', totalContracts),
              onTapPayments: () =>
                  _markSectionAsSeen('seen_payments', totalPayments),
              onTapMaintComplaints: () => _markSectionAsSeen(
                  'seen_maintenance_complaints', totalMaintComplaints),
              onTapReviews: () =>
                  _markSectionAsSeen('seen_reviews', totalReviews),
              onTapNotifications: () =>
                  _markSectionAsSeen('seen_notifications', totalNotifications),
            ),
            Expanded(
              child: Column(
                children: [
                  _buildWebHeader(screenWidth, _fetchDashboardStats, _logout),
                  Expanded(child: commonBodyContent),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(fontWeight: FontWeight.bold, color: _textPrimary),
    );
  }

  AppBar _buildMobileAppBar(double screenWidth) {
    return AppBar(
      elevation: 1,
      backgroundColor: _cardBackground,
      foregroundColor: _textPrimary,
      titleSpacing: 0,
      iconTheme: IconThemeData(color: _textPrimary),
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: _lightGreenAccent,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.dashboard, color: _primaryGreen, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Admin Dashboard',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
            tooltip: 'Refresh Data',
            icon: Icon(Icons.refresh, color: _textPrimary),
            onPressed: _fetchDashboardStats),
        IconButton(
            icon: Icon(Icons.logout, color: _darkGreenAccent),
            tooltip: 'Logout',
            onPressed: _logout),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWebHeader(
      double screenWidth, VoidCallback onRefresh, VoidCallback onLogout) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth > _kMobileBreakpoint ? 24 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBackground,
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 2,
              offset: const Offset(0, 2))
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
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.dashboard, color: _primaryGreen, size: 28),
              ),
              const SizedBox(width: 14),
              Text(
                'Admin Dashboard',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: _textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Row(
            children: [

                // داخل actions في الـ AppBar
                // ... الأيقونات السابقة ...
                // ✅ أيقونة الرسائل الجديدة
                IconButton(
                icon: const Icon(Icons.message_outlined, color: Colors.green),
                tooltip: "Messages",
                onPressed: () {
                Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
                );
                },
                ),
                const SizedBox(width: 16), // مسافة
              IconButton(
                  tooltip: 'Refresh Data',
                  icon: Icon(Icons.refresh, color: _textPrimary),
                  onPressed: onRefresh),
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
                      borderRadius: BorderRadius.circular(10)),
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
          parent: _welcomeAnimController, curve: Curves.easeOut),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: _primaryGreen,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back, ${_adminName ?? 'Admin'}!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 28),
              ),
              const SizedBox(height: 10),
              const Text(
                'Here\'s a quick overview of your system today.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 30),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminSystemSettingsScreen()));
                  },
                  icon: Icon(Icons.settings, color: _primaryGreen),
                  label: Text('Manage System',
                      style: TextStyle(
                          color: _primaryGreen, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
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

 Widget _buildSummaryGrid(
    BuildContext context, SummaryStats stats, double screenWidth) {
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

  final List<Color> statCardColors = [
    _chartAndStatColors[0],
    Colors.blueAccent.shade400,
    _primaryGreen,
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
      childAspectRatio: 0.85,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
    ),
    itemCount: 10,
    itemBuilder: (context, index) {
      String title;
      int value;
      IconData icon;
      Color color = statCardColors[index % statCardColors.length];
      
      // 👇👇 تعريف الصفحة التي سننتقل إليها
      Widget? destinationScreen;

      switch (index) {
        case 0:
          title = 'Total Users';
          value = stats.totalUsers;
          icon = Icons.people_alt_outlined;
          destinationScreen = const AdminUserManagementScreen(); // 👈 انتقال للمستخدمين
          break;
        case 1:
          title = 'Landlords';
          value = stats.totalLandlords;
          icon = Icons.business_center_outlined;
          destinationScreen = const AdminUserManagementScreen(); // 👈 انتقال للمستخدمين
          break;
        case 2:
          title = 'Tenants';
          value = stats.totalTenants;
          icon = Icons.person_pin_outlined;
          destinationScreen = const AdminUserManagementScreen(); // 👈 انتقال للمستخدمين
          break;
        case 3:
          title = 'Properties';
          value = stats.totalProperties;
          icon = Icons.home_work_outlined;
          destinationScreen = const AdminPropertyManagementScreen(); // 👈 انتقال للعقارات
          break;
        case 4:
          title = 'Contracts';
          value = stats.totalContracts;
          icon = Icons.description_outlined;
          // تحديث شارة التنبيهات للعقود عند الضغط
          destinationScreen = const AdminContractManagementScreen(); // 👈 انتقال للعقود
          break;
        case 5:
          title = 'Payments';
          value = stats.totalPayments;
          icon = Icons.credit_card_outlined;
          destinationScreen = const AdminPaymentsTransactionsScreen(); // 👈 انتقال للدفعات
          break;
        case 6:
          title = 'Maintenance';
          value = stats.totalMaintenances;
          icon = Icons.build_outlined;
          destinationScreen = const AdminMaintenanceComplaintsScreen(); // 👈 انتقال للصيانة
          break;
        case 7:
          title = 'Complaints';
          value = stats.totalComplaints;
          icon = Icons.warning_amber_rounded;
          destinationScreen = const AdminMaintenanceComplaintsScreen(); // 👈 انتقال للشكاوى
          break;
        case 8:
          title = 'Reviews';
          value = stats.totalReviews;
          icon = Icons.star_outline;
          destinationScreen = const AdminReviewsManagementScreen(); // 👈 انتقال للتقييمات
          break;
        case 9:
          title = 'Notifications';
          value = stats.totalNotifications;
          icon = Icons.notifications_none_outlined;
          destinationScreen = const AdminNotificationsManagementScreen(); // 👈 انتقال للإشعارات
          break;
        default:
          title = 'N/A';
          value = 0;
          icon = Icons.info_outline;
      }

      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 500 + index * 100),
        builder: (context, opacity, child) {
          return Transform.scale(
            scale: opacity,
            child: Opacity(
                opacity: opacity,
                // 👇👇 نمرر وظيفة الانتقال هنا
                child: _buildStatCard(context, title, value, icon, color, () {
                  if (destinationScreen != null) {
                    // منطق خاص لتصفير العدادات عند الضغط (اختياري، مأخوذ من الكود السابق)
                    if (index == 4) _markSectionAsSeen('seen_contracts', stats.totalContracts);
                    if (index == 5) _markSectionAsSeen('seen_payments', stats.totalPayments);
                    if (index == 6 || index == 7) {
                       int total = (stats.totalComplaints) + (stats.totalMaintenances);
                       _markSectionAsSeen('seen_maintenance_complaints', total);
                    }
                    if (index == 8) _markSectionAsSeen('seen_reviews', stats.totalReviews);
                    if (index == 9) _markSectionAsSeen('seen_notifications', stats.totalNotifications);

                    // الانتقال للصفحة
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => destinationScreen!),
                    );
                  }
                })),
          );
        },
      );
    },
  );
}

 Widget _buildStatCard(BuildContext context, String title, int value,
    IconData icon, Color color, VoidCallback onTap) { // 👈 أضفنا onTap هنا
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _borderColor, width: 0.8)),
    color: _cardBackground,
    child: InkWell( // 👈 أضفنا هذا لجعل الكرت قابلاً للضغط
      onTap: onTap, // 👈 استدعاء دالة الانتقال
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                radius: 26,
                child: Icon(icon, color: color, size: 30)),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontSize: 15,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 1200),
              builder: (context, val, child) {
                return Text(
                  val.toInt().toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                      fontSize: 30),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

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
                    builder: (_) => const AdminUserManagementScreen()));
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
                    builder: (_) => const AdminPropertyManagementScreen()));
          },
        ),
        const SizedBox(height: 20),
        _buildAnimatedLatestSection<LatestContract>(
          context,
          title: 'Latest Contracts',
          items: latest.contracts,
          itemBuilder: (contract) => _buildLatestActivityTile(
            icon: Icons.description,
            iconColor: _chartAndStatColors[3],
            title: 'Contract Status: ${contract.status}',
            subtitle:
                'Starts: ${DateFormat('yyyy-MM-dd').format(contract.startDate)} - Ends: ${DateFormat('yyyy-MM-dd').format(contract.endDate)}',
            trailing: DateFormat('yyyy-MM-dd').format(contract.createdAt),
          ),
          onViewAll: () {
            // Mark contracts as seen
            _markSectionAsSeen(
                'seen_contracts', _dashboardData?.summary.totalContracts ?? 0);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminContractManagementScreen()));
          },
        ),
        const SizedBox(height: 20),
        _buildAnimatedLatestSection<LatestPayment>(
          context,
          title: 'Latest Payments',
          items: latest.payments,
          itemBuilder: (payment) => _buildLatestActivityTile(
            icon: Icons.credit_card,
            iconColor: _chartAndStatColors[5],
            title: 'Amount: \$${payment.amount.toStringAsFixed(2)}',
            subtitle: 'Status: ${payment.status}',
            trailing: DateFormat('yyyy-MM-dd').format(payment.createdAt),
          ),
          onViewAll: () {
            _markSectionAsSeen(
                'seen_payments', _dashboardData?.summary.totalPayments ?? 0);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminPaymentsTransactionsScreen()));
          },
        ),
        const SizedBox(height: 20),
        _buildAnimatedLatestSection<LatestComplaint>(
          context,
          title: 'Latest Complaints',
          items: latest.complaints,
          itemBuilder: (complaint) => _buildLatestActivityTile(
            icon: Icons.report,
            iconColor: _chartAndStatColors[4],
            title: complaint.description,
            subtitle: complaint.status,
            trailing: DateFormat('yyyy-MM-dd').format(complaint.createdAt),
          ),
          onViewAll: () {
            int total = (_dashboardData?.summary.totalComplaints ?? 0) +
                (_dashboardData?.summary.totalMaintenances ?? 0);
            _markSectionAsSeen('seen_maintenance_complaints', total);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminMaintenanceComplaintsScreen()));
          },
        ),
        const SizedBox(height: 20),
        _buildAnimatedLatestSection<LatestReview>(
          context,
          title: 'Latest Reviews',
          items: latest.reviews,
          itemBuilder: (review) => _buildLatestActivityTile(
            icon: Icons.star,
            iconColor: _chartAndStatColors[6],
            title: review.comment,
            subtitle:
                'By ${review.reviewerName ?? 'Anonymous'} for ${review.propertyTitle ?? 'N/A'} (Rating: ${review.rating})',
            trailing: DateFormat('yyyy-MM-dd').format(review.createdAt),
          ),
          onViewAll: () {
            _markSectionAsSeen(
                'seen_reviews', _dashboardData?.summary.totalReviews ?? 0);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminReviewsManagementScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildLatestActivityTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor, width: 0.6),
      ),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.15),
              radius: 20,
              child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: _textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(trailing,
              style: TextStyle(
                  color: _textSecondary.withOpacity(0.7), fontSize: 13)),
        ],
      ),
    );
  }

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: _cardBackground,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold, color: _textPrimary)),
                if (onViewAll != null)
                  TextButton(
                    onPressed: onViewAll,
                    style:
                        TextButton.styleFrom(foregroundColor: _darkGreenAccent),
                    child: const Text('View All',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
              ],
            ),
            Divider(height: 28, color: _borderColor),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length > 3 ? 3 : items.length,
              itemBuilder: (context, index) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + index * 100),
                  builder: (context, opacity, child) {
                    return Transform.translate(
                      offset: Offset(0, 30 * (1 - opacity)),
                      child: Opacity(
                          opacity: opacity, child: itemBuilder(items[index])),
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

  Widget _buildAnalyticsSection(
      BuildContext context, AnalyticsData analytics, double screenWidth) {
    final List<PieChartSectionData> userPieChartSections =
        analytics.userStats.map((stat) {
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
      return PieChartSectionData(
        color: color,
        value: stat.count.toDouble(),
        title: '${stat.id} (${stat.count})',
        radius: screenWidth > _kMobileBreakpoint ? 90 : 70,
        titleStyle: TextStyle(
            fontSize: screenWidth > _kMobileBreakpoint ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: Colors.white),
        badgeWidget: _Badge(stat.id,
            size: screenWidth > _kMobileBreakpoint ? 24 : 20,
            borderColor: color),
        badgePositionPercentageOffset: .98,
      );
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: _cardBackground,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Analytics',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: _textPrimary),
            ),
            Divider(height: 32, color: _borderColor),
            _buildRevenueCard(analytics.totalRevenue),
            const SizedBox(height: 30),
            Text('User Distribution by Role',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 20),
            SizedBox(
              height: screenWidth > _kMobileBreakpoint ? 340 : 300,
              child: PieChart(
                PieChartData(
                  sections: userPieChartSections,
                  centerSpaceRadius: screenWidth > _kMobileBreakpoint ? 50 : 40,
                  sectionsSpace: 4,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event,
                          PieTouchResponse? pieTouchResponse) {}),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 20,
              runSpacing: 12,
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
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6))),
                    const SizedBox(width: 10),
                    Text(stat.id,
                        style: TextStyle(fontSize: 16, color: _textPrimary)),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            _buildStatList(
                context, 'Properties by Status', analytics.propertyStats),
            _buildPaymentStatList(
                context, 'Payments by Status', analytics.paymentStats),
            _buildStatList(
                context, 'Contracts by Status', analytics.contractStats),
            _buildStatList(
                context, 'Maintenance by Status', analytics.maintenanceStats),
            _buildStatList(
                context, 'Complaints by Status', analytics.complaintStats),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueCard(double totalRevenue) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: _lightGreenAccent,
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
                  Text('Total Revenue',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary)),
                  const SizedBox(height: 4),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: totalRevenue),
                    duration: const Duration(milliseconds: 1500),
                    builder: (context, val, child) {
                      return Text('\$${val.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 24,
                              color: _primaryGreen,
                              fontWeight: FontWeight.w700));
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

  Widget _buildStatList(
      BuildContext context, String title, List<StatCount> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 25.0, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 12),
          ...stats
              .map((stat) => Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(stat.id,
                                style: TextStyle(
                                    fontSize: 16, color: _textPrimary),
                                overflow: TextOverflow.ellipsis)),
                        Text(stat.count.toString(),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _primaryGreen)),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildPaymentStatList(
      BuildContext context, String title, List<PaymentStat> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 25.0, bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 12),
          ...stats
              .map((stat) => Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text('${stat.id} (${stat.count})',
                                style: TextStyle(
                                    fontSize: 16, color: _textPrimary),
                                overflow: TextOverflow.ellipsis)),
                        Text('\$${stat.total.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _primaryGreen)),
                      ],
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }
}

// ✅ Admin Drawer - With Smart Badge Counters
class _AdminDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  final String? adminName;
  final Color primaryGreen;
  final Color textPrimary;

  // Badge Counts (New Only)
  final int badgeContracts;
  final int badgePayments;
  final int badgeMaintComplaints;
  final int badgeReviews;
  final int badgeNotifications;

  // OnTap Callbacks (To clear badges)
  final VoidCallback onTapContracts;
  final VoidCallback onTapPayments;
  final VoidCallback onTapMaintComplaints;
  final VoidCallback onTapReviews;
  final VoidCallback onTapNotifications;

  const _AdminDrawer({
    required this.onLogout,
    this.adminName,
    required this.primaryGreen,
    required this.textPrimary,
    required this.badgeContracts,
    required this.badgePayments,
    required this.badgeMaintComplaints,
    required this.badgeReviews,
    required this.badgeNotifications,
    required this.onTapContracts,
    required this.onTapPayments,
    required this.onTapMaintComplaints,
    required this.onTapReviews,
    required this.onTapNotifications,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(adminName ?? 'Admin User',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            accountEmail: const Text('admin@shaqati.com',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: primaryGreen, size: 45)),
            decoration: BoxDecoration(color: primaryGreen),
            margin: EdgeInsets.zero,
            otherAccountsPictures: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminSystemSettingsScreen()));
                },
              ),
            ],
          ),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard Home',
            onTap: () => Navigator.pop(context),
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
                      builder: (_) => const AdminUserManagementScreen()));
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
                      builder: (_) => const AdminPropertyManagementScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.description_outlined,
            title: 'Contract Management',
            badgeCount: badgeContracts,
            onTap: () {
              onTapContracts();
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminContractManagementScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.credit_card_outlined,
            title: 'Payments & Transactions',
            badgeCount: badgePayments,
            onTap: () {
              onTapPayments();
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminPaymentsTransactionsScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.report_problem_outlined,
            title: 'Maintenance & Complaints',
            badgeCount: badgeMaintComplaints,
            onTap: () {
              onTapMaintComplaints();
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AdminMaintenanceComplaintsScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.star_outline,
            title: 'Reviews Management',
            badgeCount: badgeReviews,
            onTap: () {
              onTapReviews();
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminReviewsManagementScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.notifications_none_outlined,
            title: 'Notifications Management',
            badgeCount: badgeNotifications,
            onTap: () {
              onTapNotifications();
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AdminNotificationsManagementScreen()));
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
                      builder: (_) => const AdminSystemSettingsScreen()));
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
    int badgeCount = 0,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryGreen),
      title: Text(title, style: TextStyle(fontSize: 16, color: textPrimary)),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            )
          : null,
      onTap: onTap,
      hoverColor: primaryGreen.withOpacity(0.1),
      splashColor: primaryGreen.withOpacity(0.2),
    );
  }
}

// ✅ Web Sidebar - With Smart Badge Counters
class _WebSidebar extends StatelessWidget {
  final VoidCallback onLogout;
  final String? adminName;
  final String? adminEmail; // ✅ استقبال الإيميل
  final String? adminProfilePic; // ✅ استقبال الصورة
  final Color primaryGreen;
  final Color textPrimary;
  final Color darkGreenAccent;
  final Color cardBackground;
  final Color borderColor;

  // Badge Counts
  final int badgeContracts;
  final int badgePayments;
  final int badgeMaintComplaints;
  final int badgeReviews;
  final int badgeNotifications;

  // OnTap Callbacks
  final VoidCallback onTapContracts;
  final VoidCallback onTapPayments;
  final VoidCallback onTapMaintComplaints;
  final VoidCallback onTapReviews;
  final VoidCallback onTapNotifications;

  const _WebSidebar({
    required this.onLogout,
    this.adminName,
    this.adminEmail,
    this.adminProfilePic,
    required this.primaryGreen,
    required this.textPrimary,
    required this.darkGreenAccent,
    required this.cardBackground,
    required this.borderColor,
    required this.badgeContracts,
    required this.badgePayments,
    required this.badgeMaintComplaints,
    required this.badgeReviews,
    required this.badgeNotifications,
    required this.onTapContracts,
    required this.onTapPayments,
    required this.onTapMaintComplaints,
    required this.onTapReviews,
    required this.onTapNotifications,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: cardBackground,
        border: Border(right: BorderSide(color: borderColor, width: 0.6)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(2, 0))
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
        fontSize: 18),
  ),
  // ✅ (1) التعديل الأول: وضع المتغير بدلاً من النص الثابت
  accountEmail: Text(
    adminEmail ?? 'loading...', 
    style: const TextStyle(color: Colors.white70, fontSize: 14),
  ),
  // ✅ (2) التعديل الثاني: استخدام Stack لإضافة أيقونة القلم
  currentAccountPicture: Stack(
    children: [
      Align(
        alignment: Alignment.center,
        child: CircleAvatar(
          backgroundColor: Colors.white,
          radius: 35,
          // ✅ إذا في صورة اعرضها، وإلا اعرض الأيقونة
          backgroundImage: (adminProfilePic != null && adminProfilePic!.isNotEmpty)
              ? NetworkImage(adminProfilePic!)
              : null,
          child: (adminProfilePic == null || adminProfilePic!.isEmpty)
              ? Icon(Icons.person, color: primaryGreen, size: 45)
              : null,
        ),
      ),
      // أيقونة القلم
      Positioned(
        bottom: 0,
        right: 0,
        child: InkWell(
          onTap: () async {
            // 1. فتح الاستوديو واختيار صورة
            final ImagePicker picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);

            if (image != null) {
              // تم اختيار الصورة بنجاح
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Uploading image..."))
              );

              // 2. رفع الصورة للسيرفر
              final (ok, imageUrl) = await ApiService.uploadImage(image);

              if (ok && imageUrl != null) {
                // 3. حفظ الرابط في قاعدة البيانات
                final (updateOk, msg) = await ApiService.updateUserProfileImage(imageUrl);
                
                if (updateOk) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profile updated! Refreshing..."), backgroundColor: Colors.green)
                  );
                  // لتحديث الواجهة فوراً قد تحتاج لإعادة تحميل البيانات
                  // _loadAdminData(); // لكن هذه الدالة غير متاحة هنا مباشرة
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red)
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Upload failed: $imageUrl"), backgroundColor: Colors.red)
                );
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: primaryGreen, width: 1.5),
            ),
            child: Icon(Icons.edit, color: primaryGreen, size: 14),
          ),
        ),
      ),
    ],
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
                builder: (_) => const AdminSystemSettingsScreen()));
      },
    ),
  ],
),
          _buildDrawerItem(
            icon: Icons.dashboard,
            title: 'Dashboard Home',
            onTap: () {},
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
                      builder: (_) => const AdminUserManagementScreen()));
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
                      builder: (_) => const AdminPropertyManagementScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.description_outlined,
            title: 'Contract Management',
            badgeCount: badgeContracts,
            onTap: () {
              onTapContracts();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminContractManagementScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.credit_card_outlined,
            title: 'Payments & Transactions',
            badgeCount: badgePayments,
            onTap: () {
              onTapPayments();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminPaymentsTransactionsScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.report_problem_outlined,
            title: 'Maintenance & Complaints',
            badgeCount: badgeMaintComplaints,
            onTap: () {
              onTapMaintComplaints();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AdminMaintenanceComplaintsScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.star_outline,
            title: 'Reviews Management',
            badgeCount: badgeReviews,
            onTap: () {
              onTapReviews();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminReviewsManagementScreen()));
            },
            primaryGreen: primaryGreen,
            textPrimary: textPrimary,
          ),
          _buildDrawerItem(
            icon: Icons.notifications_none_outlined,
            title: 'Notifications Management',
            badgeCount: badgeNotifications,
            onTap: () {
              onTapNotifications();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const AdminNotificationsManagementScreen()));
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
                      builder: (_) => const AdminSystemSettingsScreen()));
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
    int badgeCount = 0,
  }) {
    return ListTile(
      leading: Icon(icon, color: primaryGreen),
      title: Text(title, style: TextStyle(fontSize: 16, color: textPrimary)),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            )
          : null,
      onTap: onTap,
      hoverColor: primaryGreen.withOpacity(0.1),
      splashColor: primaryGreen.withOpacity(0.2),
    );
  }
}

// Badge Widget for Pie Chart (Helper)
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
              blurRadius: 2)
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