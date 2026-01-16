import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/api_service.dart';

// --- Screens Imports ---
import 'home_page.dart';
import 'landlord_property_management_screen.dart';
import 'landlord_maintenance_screen.dart';
import 'landlord_contracts_screen.dart';
import 'landlord_payments_screen.dart';
import 'expenses_management_screen.dart' hide Container;
import 'deposits_management_screen.dart';
import 'invoices_screen.dart';
import 'chat_list_screen.dart';
import 'landlord_report_screen.dart';

// --- Color Palette (Beige & Green Theme) ---
const Color _primaryBeige = Color(0xFFD4B996); // لون بيج/رملي أساسي
const Color _accentGreen = Color(0xFF2E7D32); // أخضر للأزرار والأيقونات
const Color _lightGreen = Color(0xFFE8F5E9); // أخضر فاتح للخلفيات الصغيرة
const Color _backgroundColor = Color(0xFFFAF9F6); // لون كريمي للخلفية العامة
const Color _cardColor = Colors.white;
const Color _textPrimary = Color(0xFF4E342E); // بني غامق للنصوص الأساسية
const Color _textSecondary = Color(0xFF8D8D8D);

// --- Models ---
class LandlordDashboardData {
  final Map<String, dynamic> summary;
  final List<dynamic> latestPayments;

  LandlordDashboardData({required this.summary, required this.latestPayments});

  factory LandlordDashboardData.fromJson(Map<String, dynamic> json) {
    return LandlordDashboardData(
      summary: json['summary'] ?? {},
      latestPayments: (json['latest']?['payments'] as List?) ?? [],
    );
  }
}

class LandlordDashboardScreen extends StatefulWidget {
  const LandlordDashboardScreen({super.key});

  @override
  State<LandlordDashboardScreen> createState() =>
      _LandlordDashboardScreenState();
}

class _LandlordDashboardScreenState extends State<LandlordDashboardScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String? _landlordName;
  LandlordDashboardData? _dashboardData;
  late AnimationController _animController;
  late TabController _tabController;
  final double _kMobileBreakpoint = 800.0;
  int _unreadMessagesCount = 0;
  Timer? _messagesTimer;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
    _fetchUnreadMessagesCount();
    _fetchNotifications();
    // Update unread count every 5 seconds
    _messagesTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _fetchUnreadMessagesCount();
        _fetchNotifications();
      }
    });
  }

  Future<void> _fetchUnreadMessagesCount() async {
    try {
      final (ok, users) = await ApiService.getChatUsers();
      if (ok) {
        int totalUnread = 0;
        for (var user in users) {
          final count = user['unreadCount'];
          if (count != null) {
            final countValue = count is int ? count : (count as num).toInt();
            totalUnread += countValue > 0 ? countValue : 0;
          }
        }
        if (mounted) {
          setState(() {
            _unreadMessagesCount = totalUnread;
          });
        }
      }
    } catch (e) {
      print("Error fetching unread count: $e");
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _tabController.dispose();
    _messagesTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final landlordId = prefs.getString('userId');
      
      if (landlordId == null) return;
      
      // Fetch landlord's properties first
      final (okProps, propsData) = await ApiService.getPropertiesByOwner(landlordId);
      if (!okProps || propsData is! List) return;
      
      final propertyIds = propsData.map((p) => p['_id']).toSet();
      
      // Fetch all contracts and filter by landlord's properties
      final (ok, contracts) = await ApiService.getAllContracts();
      final (okPayments, payments) = await ApiService.getAllPayments();
      final (okMaintenance, maintenance) = await ApiService.getAllMaintenance();
      
      List<Map<String, dynamic>> alerts = [];
      
      if (ok && contracts is List) {
        final now = DateTime.now();
        for (var contract in contracts) {
          // Filter by landlord's properties
          final propertyId = contract['propertyId'];
          bool isLandlordProperty = false;
          if (propertyId is Map) {
            isLandlordProperty = propertyIds.contains(propertyId['_id']);
          } else if (propertyId is String) {
            isLandlordProperty = propertyIds.contains(propertyId);
          }
          
          if (!isLandlordProperty) continue;
          
          final endDate = contract['endDate'];
          if (endDate != null) {
            try {
              final end = DateTime.parse(endDate);
              final daysUntilExpiry = end.difference(now).inDays;
              if (daysUntilExpiry <= 30 && daysUntilExpiry >= 0) {
                alerts.add({
                  'type': 'expired_contract',
                  'title': 'Contract Expiring Soon',
                  'message': 'Contract expires in $daysUntilExpiry days',
                  'icon': Icons.event,
                  'color': Colors.orange,
                });
              } else if (daysUntilExpiry < 0) {
                alerts.add({
                  'type': 'expired_contract',
                  'title': 'Expired Contract',
                  'message': 'Contract expired ${daysUntilExpiry.abs()} days ago',
                  'icon': Icons.event_busy,
                  'color': Colors.red,
                });
              }
            } catch (e) {
              // Skip invalid dates
            }
          }
        }
      }
      
      if (okPayments && payments is List) {
        // Filter payments by landlord's contracts
        final contractIds = (contracts as List?)
            ?.where((c) {
              final propertyId = c['propertyId'];
              if (propertyId is Map) {
                return propertyIds.contains(propertyId['_id']);
              } else if (propertyId is String) {
                return propertyIds.contains(propertyId);
              }
              return false;
            })
            .map((c) => c['_id'])
            .toSet() ?? {};
        
        final now = DateTime.now();
        for (var payment in payments) {
          final contractId = payment['contractId'];
          bool isLandlordPayment = false;
          if (contractId is Map) {
            isLandlordPayment = contractIds.contains(contractId['_id']);
          } else if (contractId is String) {
            isLandlordPayment = contractIds.contains(contractId);
          }
          
          if (!isLandlordPayment) continue;
          
          if (payment['status'] == 'pending' || payment['status'] == 'overdue') {
            final dueDate = payment['dueDate'] ?? payment['date'];
            if (dueDate != null) {
              try {
                final due = DateTime.parse(dueDate);
                if (due.isBefore(now)) {
                  alerts.add({
                    'type': 'overdue_payment',
                    'title': 'Overdue Payment',
                    'message': 'Payment overdue: \$${payment['amount'] ?? 0}',
                    'icon': Icons.payment,
                    'color': Colors.red,
                  });
                }
              } catch (e) {
                // Skip invalid dates
              }
            }
          }
        }
      }
      
      if (okMaintenance && maintenance is List) {
        for (var req in maintenance) {
          // Filter by landlord's properties
          final propertyId = req['propertyId'];
          bool isLandlordProperty = false;
          if (propertyId is Map) {
            isLandlordProperty = propertyIds.contains(propertyId['_id']);
          } else if (propertyId is String) {
            isLandlordProperty = propertyIds.contains(propertyId);
          }
          
          if (!isLandlordProperty) continue;
          
          if (req['priority'] == 'urgent' && req['status'] != 'resolved') {
            alerts.add({
              'type': 'urgent_maintenance',
              'title': 'Urgent Maintenance',
              'message': 'Urgent maintenance request pending',
              'icon': Icons.build,
              'color': Colors.red,
            });
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _notifications = alerts;
        });
      }
    } catch (e) {
      print("Error fetching notifications: $e");
    }
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _landlordName = prefs.getString('userName') ?? 'Landlord';
    });
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getLandlordDashboard();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (ok && data != null) {
          _dashboardData =
              LandlordDashboardData.fromJson(data as Map<String, dynamic>);
          _animController.forward(from: 0);
        }
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _kMobileBreakpoint;

    Widget bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator(color: _accentGreen))
        : _dashboardData == null
            ? const Center(child: Text("No data available"))
            : Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: _accentGreen,
                    unselectedLabelColor: _textSecondary,
                    indicatorColor: _accentGreen,
                    tabs: const [
                      Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
                      Tab(icon: Icon(Icons.bar_chart), text: 'Charts'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        RefreshIndicator(
                          onRefresh: _fetchDashboardData,
                          color: _accentGreen,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildWelcomeCard(),
                                const SizedBox(height: 20),
                                if (_notifications.isNotEmpty) ...[
                                  _buildNotificationsWidget(),
                                  const SizedBox(height: 20),
                                ],
                                _buildQuickActions(),
                                const SizedBox(height: 30),
                                Text("Overview", style: _headerStyle),
                                const SizedBox(height: 16),
                                _buildSummaryGrid(screenWidth),
                                const SizedBox(height: 30),
                                Text("Key Performance Indicators", style: _headerStyle),
                                const SizedBox(height: 16),
                                _buildKPIGrid(screenWidth),
                                const SizedBox(height: 30),
                                Text("Recent Transactions", style: _headerStyle),
                                const SizedBox(height: 16),
                                _buildRecentActivityList(),
                              ],
                            ),
                          ),
                        ),
                        _buildChartsTab(screenWidth),
                      ],
                    ),
                  ),
                ],
              );

    if (isMobile) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryBeige,
          elevation: 0,
          title: const Text('Landlord Dashboard',
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            // Notifications Button
            IconButton(
              onPressed: _showNotificationsDialog,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications, color: Colors.white),
                  // Badge for notifications
                  if (_notifications.isNotEmpty)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: _notifications.length > 9
                            ? const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2)
                            : const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            _notifications.length > 99
                                ? '99+'
                                : _notifications.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Notifications',
            ),
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatListScreen(),
                  ),
                );
                // تحديث العداد عند العودة من شاشة الدردشة
                _fetchUnreadMessagesCount();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat, color: Colors.white),
                  // Badge للرسائل غير المقروءة - Mobile AppBar
                  if (_unreadMessagesCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: _unreadMessagesCount > 9
                            ? const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2)
                            : const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            _unreadMessagesCount > 99
                                ? '99+'
                                : _unreadMessagesCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              tooltip: 'Messages',
            ),
            IconButton(
              onPressed: _fetchDashboardData,
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refresh Data',
            ),
          ],
        ),
        drawer: _buildDrawer(isMobile: true),
        body: bodyContent,
      );
    } else {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Row(
          children: [
            SizedBox(
              width: 260,
              child: _buildDrawer(isMobile: false),
            ),
            Expanded(
              child: Column(
                children: [
                  _buildWebHeader(),
                  Expanded(child: bodyContent),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  TextStyle get _headerStyle => const TextStyle(
      fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary);

  // --- WIDGETS ---

  Widget _buildWebHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize, color: _primaryBeige, size: 28),
              const SizedBox(width: 12),
              Text("Dashboard Overview",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary)),
            ],
          ),
          Row(
            children: [
              // Notifications Button
              Container(
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: _showNotificationsDialog,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined,
                          color: _accentGreen, size: 22),
                      // Badge for notifications
                      if (_notifications.isNotEmpty)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: _notifications.length > 9
                                ? const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2)
                                : const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              _notifications.length > 99
                                  ? '99+'
                                  : _notifications.length.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: "Notifications",
                ),
              ),
              const SizedBox(width: 8),
              // Chat/Messages Button
              Container(
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChatListScreen(),
                      ),
                    );
                    // تحديث العداد عند العودة من شاشة الدردشة
                    _fetchUnreadMessagesCount();
                  },
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          color: _accentGreen, size: 22),
                      // Badge للرسائل غير المقروءة
                      if (_unreadMessagesCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              _unreadMessagesCount > 99
                                  ? '99+'
                                  : _unreadMessagesCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: "Messages",
                ),
              ),
              const SizedBox(width: 8),
              // Refresh Button
              IconButton(
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh, color: _accentGreen),
                tooltip: "Refresh Data",
              ),
              const SizedBox(width: 16),
              // User Avatar & Name
              CircleAvatar(
                backgroundColor: _lightGreen,
                child: const Icon(Icons.person, color: _accentGreen),
              ),
              const SizedBox(width: 10),
              Text(_landlordName ?? "User",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDrawer({required bool isMobile}) {
    // Drawer Content
    final content = Column(
      children: [
        if (!isMobile)
          Container(
            height: 150,
            alignment: Alignment.center,
            color: _primaryBeige,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: _primaryBeige),
                ),
                const SizedBox(height: 10),
                Text(_landlordName ?? "Landlord",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          )
        else
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: _primaryBeige),
            accountName: Text(_landlordName ?? "Landlord"),
            accountEmail: const Text("landlord@shaqati.com"),
            currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: _primaryBeige)),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              _drawerItem(Icons.dashboard, "Dashboard", () {}, isActive: true),
              _drawerItem(Icons.home_work_outlined, "Properties",
                  () => _nav(const LandlordPropertyManagementScreen())),
              _drawerItem(Icons.description_outlined, "Contracts",
                  () => _nav(const LandlordContractsScreen())),
              _drawerItem(Icons.build_outlined, "Maintenance",
                  () => _nav(const LandlordMaintenanceScreen())),
              _drawerItem(Icons.payment_outlined, "Payments",
                  () => _nav(const LandlordPaymentsScreen())),
              _drawerItem(Icons.receipt_long_outlined, "Expenses",
                  () => _nav(const ExpensesManagementScreen())),
              _drawerItem(Icons.security, "Deposits",
                  () => _nav(const DepositsManagementScreen())),
              _drawerItem(Icons.description_outlined, "Invoices",
                  () => _nav(const InvoicesScreen())),
              const Divider(),
              _drawerItem(Icons.logout, "Logout", _logout, color: Colors.red),
            ],
          ),
        )
      ],
    );

    if (isMobile) return Drawer(child: content);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: content,
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap,
      {bool isActive = false, Color? color}) {
    return ListTile(
      leading: Icon(icon,
          color: color ?? (isActive ? _accentGreen : _textSecondary)),
      title: Text(title,
          style: TextStyle(
              color: color ?? (isActive ? _accentGreen : _textPrimary),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      tileColor: isActive ? _lightGreen : null,
      onTap: onTap,
    );
  }

  void _nav(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildWelcomeCard() {
    return FadeTransition(
      opacity: _animController,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryBeige, Color(0xFFE6D6C4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: _primaryBeige.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome back, $_landlordName!",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Manage your properties and tenants efficiently.",
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(double screenWidth) {
    final summary = _dashboardData?.summary ?? {};
    final totalRev = summary['totalRevenue'] ?? 0;

    // إعداد البيانات للشبكة
    final List<Map<String, dynamic>> items = [
      {
        'title': 'Total Revenue',
        'value': NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0)
            .format(totalRev),
        'icon': Icons.account_balance_wallet,
        'color': Colors.amber[700],
        'nav': const LandlordPaymentsScreen(),
      },
      {
        'title': 'Active Contracts',
        'value': '${summary['activeContracts'] ?? 0}',
        'icon': Icons.assignment_turned_in,
        'color': _accentGreen,
        'nav': const LandlordContractsScreen(),
      },
      {
        'title': 'Properties',
        'value': '${summary['totalProperties'] ?? 0}',
        'icon': Icons.home_work,
        'color': Colors.blue,
        'nav': const LandlordPropertyManagementScreen(),
      },
      {
        'title': 'Maintenance',
        'value': '${summary['pendingMaintenance'] ?? 0}',
        'icon': Icons.build_circle,
        'color': Colors.orange[800],
        'nav': const LandlordMaintenanceScreen(),
      },
    ];

    int crossAxisCount = screenWidth > 1100 ? 4 : (screenWidth > 600 ? 2 : 1);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: screenWidth > 600 ? 1.5 : 2.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildStatCard(
          item['title'],
          item['value'],
          item['icon'],
          item['color'],
          () => _nav(item['nav']),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary)),
                  const SizedBox(height: 4),
                  Text(title,
                      style:
                          const TextStyle(fontSize: 14, color: _textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: _textSecondary),
          ],
        ),
      ),
    );
  }


  Widget _chartLegend(String title, Color color, int value) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: _textSecondary)),
        const Spacer(),
        Text("$value", style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRecentActivityList() {
    final payments = _dashboardData?.latestPayments ?? [];

    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: _cardColor, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No recent transactions found.")),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final p = payments[index];
        final contract = p['contractId'] ?? {};
        final tenant = contract['tenantId'] ?? {};

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: _lightGreen,
              child: const Icon(Icons.attach_money, color: _accentGreen),
            ),
            title: Text(tenant['name'] ?? 'Unknown Tenant',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _textPrimary)),
            subtitle: Text(DateFormat.yMMMd().format(DateTime.parse(p['date'])),
                style: const TextStyle(color: _textSecondary)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accentGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0)
                    .format(p['amount']),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _accentGreen),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Actions", style: _headerStyle),
          const SizedBox(height: 16),
            Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  "Add Property",
                  Icons.add_home_work,
                  _accentGreen,
                  () => _nav(const LandlordPropertyManagementScreen()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  "View Reports",
                  Icons.assessment,
                  Colors.blue,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LandlordReportScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIGrid(double screenWidth) {
    final summary = _dashboardData?.summary ?? {};
    final totalProperties = summary['totalProperties'] ?? 0;
    final rentedProperties = summary['rentedProperties'] ?? 0;
    final totalRevenue = summary['totalRevenue'] ?? 0.0;
    final activeContracts = summary['activeContracts'] ?? 0;

    // Calculate KPIs
    final occupancyRate = totalProperties > 0
        ? ((rentedProperties / totalProperties) * 100).toStringAsFixed(1)
        : '0.0';
    final avgMonthlyRent = activeContracts > 0
        ? (totalRevenue / activeContracts).toStringAsFixed(0)
        : '0';
    final totalExpectedRevenue = totalRevenue; // This could be calculated differently

    final List<Map<String, dynamic>> kpiItems = [
      {
        'title': 'Occupancy Rate',
        'value': '$occupancyRate%',
        'icon': Icons.trending_up,
        'color': _accentGreen,
      },
      {
        'title': 'Average Monthly Rent',
        'value': NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0)
            .format(double.tryParse(avgMonthlyRent) ?? 0),
        'icon': Icons.attach_money,
        'color': Colors.blue,
      },
      {
        'title': 'Total Expected Revenue',
        'value': NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0)
            .format(totalExpectedRevenue),
        'icon': Icons.account_balance_wallet,
        'color': Colors.amber[700]!,
      },
    ];

    int crossAxisCount = screenWidth > 1100 ? 3 : (screenWidth > 600 ? 2 : 1);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: screenWidth > 600 ? 1.8 : 2.5,
      ),
      itemCount: kpiItems.length,
      itemBuilder: (context, index) {
        final item = kpiItems[index];
        return _buildKPICard(
          item['title'],
          item['value'],
          item['icon'],
          item['color'],
        );
      },
    );
  }

  Widget _buildKPICard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: _accentGreen),
            const SizedBox(width: 8),
            const Text('Important Notifications'),
            if (_notifications.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_notifications.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _notifications.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No important notifications at this time.',
                      style: TextStyle(color: _textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: notification['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: notification['color'].withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: notification['color'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              notification['icon'],
                              color: notification['color'],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification['title'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: notification['color'],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification['message'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _fetchNotifications();
              },
              child: const Text('Refresh'),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationsWidget() {
    if (_notifications.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                "Important Notifications",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._notifications.take(3).map((notification) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(notification['icon'], color: notification['color'], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: notification['color'],
                            ),
                          ),
                          Text(
                            notification['message'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildChartsTab(double screenWidth) {
    final summary = _dashboardData?.summary ?? {};
    final rentedProperties = summary['rentedProperties'] ?? 0;
    final availableProperties = summary['availableProperties'] ?? 0;
    final totalProperties = summary['totalProperties'] ?? 0;
    final pendingProperties = totalProperties - (rentedProperties + availableProperties);

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      color: _accentGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Property Distribution by Status", style: _headerStyle),
            const SizedBox(height: 16),
            _buildPropertyStatusPieChart(
                rentedProperties, availableProperties, pendingProperties),
            const SizedBox(height: 40),
            Text("Monthly Revenue Trend", style: _headerStyle),
            const SizedBox(height: 16),
            _buildMonthlyRevenueLineChart(),
            const SizedBox(height: 40),
            Text("Property Comparison by Revenue", style: _headerStyle),
            const SizedBox(height: 16),
            _buildPropertyRevenueBarChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyStatusPieChart(
      int rented, int available, int pending) {
    final total = rented + available + pending;
    if (total == 0) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text("No properties data available")),
      );
    }

    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: [
                  PieChartSectionData(
                    color: _accentGreen,
                    value: rented.toDouble(),
                    title: '${((rented / total) * 100).toStringAsFixed(0)}%',
                    radius: 80,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  PieChartSectionData(
                    color: _primaryBeige,
                    value: available.toDouble(),
                    title: '${((available / total) * 100).toStringAsFixed(0)}%',
                    radius: 70,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (pending > 0)
                    PieChartSectionData(
                      color: Colors.orange,
                      value: pending.toDouble(),
                      title: '${((pending / total) * 100).toStringAsFixed(0)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chartLegend("Rented", _accentGreen, rented),
                const SizedBox(height: 12),
                _chartLegend("Available", _primaryBeige, available),
                if (pending > 0) ...[
                  const SizedBox(height: 12),
                  _chartLegend("Pending", Colors.orange, pending),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyRevenueLineChart() {
    // Fetch payment data for monthly trend
    // For now, we'll create sample data based on available payments
    final payments = _dashboardData?.latestPayments ?? [];
    
    // Group payments by month
    Map<String, double> monthlyRevenue = {};
    for (var payment in payments) {
      try {
        final date = DateTime.parse(payment['date']);
        final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final amount = (payment['amount'] ?? 0).toDouble();
        monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + amount;
      } catch (e) {
        // Skip invalid dates
      }
    }

    // Get last 6 months
    final now = DateTime.now();
    final List<Map<String, dynamic>> monthlyData = [];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      monthlyData.add({
        'month': DateFormat('MMM').format(month),
        'revenue': monthlyRevenue[monthKey] ?? 0.0,
      });
    }

    if (monthlyData.every((d) => d['revenue'] == 0.0)) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text("No revenue data available")),
      );
    }

    final maxRevenue = monthlyData
        .map((d) => d['revenue'] as double)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compactCurrency(symbol: '\$')
                        .format(value),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < monthlyData.length) {
                    return Text(
                      monthlyData[index]['month'],
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          minX: 0,
          maxX: (monthlyData.length - 1).toDouble(),
          minY: 0,
          maxY: maxRevenue * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: monthlyData.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value['revenue'] as double,
                );
              }).toList(),
              isCurved: true,
              color: _accentGreen,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: _accentGreen.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyRevenueBarChart() {
    // This would ideally fetch property revenue data
    // For now, we'll use sample data based on contracts
    final summary = _dashboardData?.summary ?? {};
    final totalRevenue = (summary['totalRevenue'] ?? 0).toDouble();
    final activeContracts = summary['activeContracts'] ?? 0;
    // totalProperties is not used in this method, removed to fix warning

    // Create sample property revenue data
    final List<Map<String, dynamic>> propertyRevenue = [];
    if (activeContracts > 0) {
      final avgRevenue = totalRevenue / activeContracts;
      for (int i = 0; i < (activeContracts > 5 ? 5 : activeContracts); i++) {
        propertyRevenue.add({
          'property': 'Property ${i + 1}',
          'revenue': avgRevenue * (0.8 + (i * 0.1)),
        });
      }
    }

    if (propertyRevenue.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text("No property revenue data available")),
      );
    }

    final maxRevenue = propertyRevenue
        .map((d) => d['revenue'] as double)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRevenue * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < propertyRevenue.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        propertyRevenue[index]['property'],
                        style: const TextStyle(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compactCurrency(symbol: '\$')
                        .format(value),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: true),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          barGroups: propertyRevenue.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value['revenue'] as double,
                  color: _accentGreen,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
