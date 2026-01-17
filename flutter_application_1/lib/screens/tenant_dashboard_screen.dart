import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/home_page.dart';
import 'package:flutter_application_1/screens/service_pages.dart';

// 👇 استيراد الصفحات الجديدة (سننشئها في الخطوات التالية)
import 'tenant_contracts_screen.dart';
import 'tenant_payments_screen.dart';
import 'tenant_maintenance_screen.dart';
import 'expenses_management_screen.dart';
import 'deposits_management_screen.dart';
import 'chat_list_screen.dart';

class DashboardTheme {
  static const Color primary = Color(0xFF00695C);
  static const Color secondary = Color(0xFFFFA000);
  static const Color background = Color(0xFFF4F6F8);
}

class TenantDashboardScreen extends StatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen>
    with TickerProviderStateMixin {
  String _userName = "Tenant";
  String? _userId;
  bool _isLoading = true;

  // Enhanced Stats
  int _activeContracts = 0;
  int _duePayments = 0;
  double _totalExpensesThisMonth = 0.0;
  double _totalExpensesLastMonth = 0.0;
  int _depositsCount = 0;
  double _depositsTotal = 0.0;
  double _depositsRefunded = 0.0;
  int _maintenancePending = 0;
  int _maintenanceCompleted = 0;
  int _maintenanceTotal = 0;
  List<dynamic> _contractExpiryAlerts = [];
  
  // Recent Data
  List<dynamic> _recentPayments = [];
  List<dynamic> _recentExpenses = [];
  List<dynamic> _recentMaintenance = [];
  List<dynamic> _allContracts = [];
  List<dynamic> _allPayments = [];
  
  // Charts Data
  Map<String, double> _expensesByType = {};
  Map<String, double> _paymentsByMonth = {};
  Map<String, double> _paymentsPendingByMonth = {};
  Map<String, int> _maintenanceByStatus = {};

  // Message and Notification counters
  int _messagePeopleCount = 0; // Number of people who sent messages
  int _unreadNotificationsCount = 0;
  Timer? _refreshTimer;
  
  // Tab Controller for Charts
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _fetchMessageAndNotificationCounts();
    // Refresh counters every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchMessageAndNotificationCounts();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? "Tenant";
      _userId = prefs.getString('userId');
    });

    if (_userId != null) await _fetchDashboardStats();
  }

  Future<void> _fetchDashboardStats() async {
    try {
      // Fetch all data in parallel
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final firstDayLastMonth = DateTime(now.year, now.month - 1, 1);
      final lastDayLastMonth = DateTime(now.year, now.month, 0);
      
      final startDateThisMonth = DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
      final startDateLastMonth = DateFormat('yyyy-MM-dd').format(firstDayLastMonth);
      final endDateLastMonth = DateFormat('yyyy-MM-dd').format(lastDayLastMonth);

      final results = await Future.wait([
        ApiService.getUserContracts(_userId!),
        ApiService.getUserPayments(_userId!),
        ApiService.getAllExpenses(startDate: startDateThisMonth),
        ApiService.getAllExpenses(startDate: startDateLastMonth, endDate: endDateLastMonth),
        ApiService.getAllDeposits(),
        ApiService.getTenantRequests(_userId!),
      ]);

      if (mounted) {
        setState(() {
          // Contracts
          final (conOk, conData) = results[0] as (bool, dynamic);
          if (conOk && conData is List) {
            _allContracts = conData;
            _activeContracts = conData
                .where((c) => c['status'] == 'rented' || c['status'] == 'active')
                .length;
            // Check for expiring contracts (within 30 days)
            _contractExpiryAlerts = _checkContractExpiry(conData);
          }

          // Payments
          final (payOk, payData) = results[1] as (bool, dynamic);
          if (payOk && payData is List) {
            _allPayments = payData;
            _duePayments = payData.where((p) => p['status'] == 'pending').length;
            _recentPayments = List.from(payData);
            _recentPayments.sort((a, b) =>
                DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
            if (_recentPayments.length > 5)
              _recentPayments = _recentPayments.sublist(0, 5);
            
            // Prepare payments chart data
            _preparePaymentsChartData(payData);
          }

          // Expenses (This Month)
          final (expOk, expData) = results[2] as (bool, dynamic);
          if (expOk && expData is Map) {
            final expenses = expData['expenses'] as List? ?? [];
            _totalExpensesThisMonth = expenses.fold(0.0, 
                (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
            
            _recentExpenses = List.from(expenses);
            _recentExpenses.sort((a, b) {
              try {
                return DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));
              } catch (e) {
                return 0;
              }
            });
            if (_recentExpenses.length > 5)
              _recentExpenses = _recentExpenses.sublist(0, 5);
            
            // Prepare expenses chart data
            _prepareExpensesChartData(expenses);
          }

          // Expenses (Last Month)
          final (expLastOk, expLastData) = results[3] as (bool, dynamic);
          if (expLastOk && expLastData is Map) {
            final expenses = expLastData['expenses'] as List? ?? [];
            _totalExpensesLastMonth = expenses.fold(0.0, 
                (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
          }

          // Deposits
          final (depOk, depData) = results[4] as (bool, dynamic);
          if (depOk && depData is List) {
            _depositsCount = depData.length;
            _depositsTotal = depData.fold(0.0, 
                (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0.0));
            _depositsRefunded = depData
                .where((d) => d['status'] == 'refunded')
                .fold(0.0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0.0));
          }

          // Maintenance Requests
          final (maintOk, maintData) = results[5] as (bool, dynamic);
          if (maintOk && maintData is List) {
            _maintenanceTotal = maintData.length;
            _maintenancePending = maintData.where((m) => 
                m['status'] == 'pending' || m['status'] == 'in_progress').length;
            _maintenanceCompleted = maintData.where((m) => 
                m['status'] == 'completed').length;
            
            _recentMaintenance = List.from(maintData);
            _recentMaintenance.sort((a, b) {
              try {
                return DateTime.parse(b['createdAt'] ?? b['date'] ?? DateTime.now().toString())
                    .compareTo(DateTime.parse(a['createdAt'] ?? a['date'] ?? DateTime.now().toString()));
              } catch (e) {
                return 0;
              }
            });
            if (_recentMaintenance.length > 3)
              _recentMaintenance = _recentMaintenance.sublist(0, 3);
            
            // Prepare maintenance chart data
            _prepareMaintenanceChartData(maintData);
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _checkContractExpiry(List<dynamic> contracts) {
    final now = DateTime.now();
    final alerts = <dynamic>[];
    
    for (var contract in contracts) {
      if (contract['status'] == 'active' || contract['status'] == 'rented') {
        final endDate = contract['endDate'];
        if (endDate != null) {
          try {
            final end = DateTime.parse(endDate);
            final daysUntilExpiry = end.difference(now).inDays;
            if (daysUntilExpiry <= 30 && daysUntilExpiry >= 0) {
              alerts.add({
                'contract': contract,
                'daysLeft': daysUntilExpiry,
              });
            }
          } catch (e) {
            // Skip invalid dates
          }
        }
      }
    }
    
    return alerts;
  }

  void _preparePaymentsChartData(List<dynamic> payments) {
    final paidMap = <String, double>{};
    final pendingMap = <String, double>{};
    
    for (var payment in payments) {
      try {
        final date = DateTime.parse(payment['date']);
        final monthKey = DateFormat('MMM').format(date);
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
        
        if (payment['status'] == 'paid') {
          paidMap[monthKey] = (paidMap[monthKey] ?? 0.0) + amount;
        } else if (payment['status'] == 'pending') {
          pendingMap[monthKey] = (pendingMap[monthKey] ?? 0.0) + amount;
        }
      } catch (e) {
        // Skip invalid dates
      }
    }
    
    _paymentsByMonth = paidMap;
    _paymentsPendingByMonth = pendingMap;
  }

  void _prepareExpensesChartData(List<dynamic> expenses) {
    final map = <String, double>{};
    for (var expense in expenses) {
      final type = expense['type']?.toString() ?? 'Other';
      final amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
      map[type] = (map[type] ?? 0.0) + amount;
    }
    _expensesByType = map;
  }

  void _prepareMaintenanceChartData(List<dynamic> maintenance) {
    final map = <String, int>{};
    for (var req in maintenance) {
      final status = req['status']?.toString() ?? 'pending';
      map[status] = (map[status] ?? 0) + 1;
    }
    _maintenanceByStatus = map;
  }

  Future<void> _fetchMessageAndNotificationCounts() async {
    try {
      // Fetch message count (number of people who sent messages)
      final (msgOk, msgData) = await ApiService.getChatUsers();
      if (msgOk) {
        // Count number of people with unread messages
        int peopleCount = 0;
        for (var user in msgData) {
          final unreadCount = user['unreadCount'] ?? 0;
          if (unreadCount > 0) {
            peopleCount++;
          }
        }
        if (mounted) {
          setState(() {
            _messagePeopleCount = peopleCount;
          });
        }
      }

      // Fetch notification count
      final (notifOk, notifData) = await ApiService.getUserNotifications();
      if (notifOk) {
        final unreadCount = notifData.where((n) => n['isRead'] == false).length;
        if (mounted) {
          setState(() {
            _unreadNotificationsCount = unreadCount;
          });
        }
      }
    } catch (e) {
      print("Error fetching counts: $e");
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardTheme.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DashboardTheme.primary))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Stats Grid (6 cards)
                        _buildQuickStatsGrid(),
                        const SizedBox(height: 25),
                        
                        // Contract Expiry Alerts
                        if (_contractExpiryAlerts.isNotEmpty)
                          ...[
                            _buildContractExpiryAlerts(),
                            const SizedBox(height: 25),
                          ],
                        
                        // Financial Summary Card
                        _buildFinancialSummaryCard(),
                        const SizedBox(height: 25),
                        
                        // Charts Section
                        _buildChartsSection(),
                        const SizedBox(height: 25),
                        
                        // Maintenance Quick View
                        _buildMaintenanceQuickView(),
                        const SizedBox(height: 25),
                        
                        // Quick Actions
                        const Text("Quick Actions",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildActionGrid(context),
                        const SizedBox(height: 25),
                        
                        // Recent Activity Timeline
                        const Text("Recent Activity",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildRecentActivityTimeline(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      drawer: _TenantDrawer(userName: _userName, onLogout: _logout),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: DashboardTheme.primary,
      actions: [
        // Messages icon with counter
        // Counter shows number of people who sent unread messages
        // When you open a message from a person, their messages are marked as read
        // and the counter decreases by 1 (one less person with unread messages)
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.message_outlined, color: Colors.white),
              tooltip: 'Messages',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatListScreen()),
                );
                // Refresh message counter after returning from chat list
                // This updates the counter when messages are read
                _fetchMessageAndNotificationCounts();
              },
            ),
            if (_messagePeopleCount > 0)
              Positioned(
                right: 8,
                top: 8,
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
                    _messagePeopleCount > 9 ? '9+' : '$_messagePeopleCount',
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
        // Notifications icon with counter
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              tooltip: 'Notifications',
              onPressed: () {
                _showNotificationsDialog();
              },
            ),
            if (_unreadNotificationsCount > 0)
              Positioned(
                right: 8,
                top: 8,
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
                    _unreadNotificationsCount > 9 ? '9+' : '$_unreadNotificationsCount',
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
        // Home icon
        IconButton(
          icon: const Icon(Icons.home, color: Colors.white),
          tooltip: 'Go to Home',
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF004D40), Color(0xFF00695C)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                  right: -30,
                  top: -30,
                  child: Icon(Icons.home_work,
                      size: 200, color: Colors.white.withOpacity(0.1))),
              Positioned(
                bottom: 20,
                left: 20,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(_userName[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: DashboardTheme.primary)),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Welcome back,",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(_userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Quick Stats Grid (6 cards)
  Widget _buildQuickStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Dashboard Overview",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1.8,
          children: [
            _buildStatCard(
              "Active Contracts",
              "$_activeContracts",
              Icons.description,
              Colors.blue,
            ),
            _buildStatCard(
              "Pending Payments",
              "$_duePayments",
              Icons.payment,
              _duePayments > 0 ? Colors.red : Colors.green,
              badge: _duePayments > 0 ? _duePayments : null,
            ),
            _buildStatCard(
              "This Month Expenses",
              "\$${_totalExpensesThisMonth.toStringAsFixed(0)}",
              Icons.receipt_long,
              Colors.orange,
              subtitle: _totalExpensesLastMonth > 0
                  ? "${((_totalExpensesThisMonth - _totalExpensesLastMonth) / _totalExpensesLastMonth * 100).toStringAsFixed(1)}% ${_totalExpensesThisMonth > _totalExpensesLastMonth ? '↑' : '↓'}"
                  : null,
            ),
            _buildStatCard(
              "Total Deposits",
              "\$${_depositsTotal.toStringAsFixed(0)}",
              Icons.security,
              Colors.green,
              subtitle: "$_depositsCount deposits",
            ),
            _buildStatCard(
              "Maintenance Pending",
              "$_maintenancePending",
              Icons.build_circle,
              Colors.purple,
              badge: _maintenancePending > 0 ? _maintenancePending : null,
            ),
            _buildStatCard(
              "Contract Alerts",
              "${_contractExpiryAlerts.length}",
              Icons.warning_amber_rounded,
              _contractExpiryAlerts.isEmpty
                  ? Colors.grey
                  : (_contractExpiryAlerts.length > 5 ? Colors.red : Colors.orange),
              badge: _contractExpiryAlerts.isNotEmpty ? _contractExpiryAlerts.length : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {String? subtitle, int? badge}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(title,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    if (subtitle != null)
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          if (badge != null && badge > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text("$badge",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        _ActionBtn(
          icon: Icons.description_outlined,
          label: "My Contracts",
          color: Colors.teal,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TenantContractsScreen())),
        ),
        _ActionBtn(
          icon: Icons.credit_card_outlined,
          label: "Payments",
          color: Colors.orange,
          badge: _duePayments,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TenantPaymentsScreen())),
        ),
        _ActionBtn(
          icon: Icons.build_circle_outlined,
          label: "Maintenance",
          color: Colors.purple,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TenantMaintenanceScreen())),
        ),
        _ActionBtn(
          icon: Icons.receipt_long_outlined,
          label: "Expenses",
          color: Colors.blue,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ExpensesManagementScreen())),
        ),
        _ActionBtn(
          icon: Icons.security,
          label: "Deposits",
          color: Colors.green,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DepositsManagementScreen())),
        ),
        _ActionBtn(
          icon: Icons.search,
          label: "Find Home",
          color: Colors.indigo,
          onTap: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (r) => false),
        ),
      ],
    );
  }

  // Contract Expiry Alerts Widget
  Widget _buildContractExpiryAlerts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              const Text("Contract Expiry Alerts",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ..._contractExpiryAlerts.map((alert) {
            final contract = alert['contract'];
            final daysLeft = alert['daysLeft'] as int;
            final propertyTitle = contract['propertyId']?['title'] ?? 
                contract['propertyId']?['address'] ?? 'Property';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    color: daysLeft <= 15 ? Colors.red : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(propertyTitle,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("$daysLeft days remaining",
                            style: TextStyle(
                                fontSize: 12,
                                color: daysLeft <= 15 ? Colors.red : Colors.orange)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TenantContractsScreen()),
                      );
                    },
                    child: const Text("View"),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Financial Summary Card
  Widget _buildFinancialSummaryCard() {
    final totalPaidThisMonth = _allPayments
        .where((p) => p['status'] == 'paid')
        .where((p) {
          try {
            final date = DateTime.parse(p['date']);
            final now = DateTime.now();
            return date.year == now.year && date.month == now.month;
          } catch (e) {
            return false;
          }
        })
        .fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));
    
    final balance = totalPaidThisMonth - _totalExpensesThisMonth;
    final depositRefundedPercent = _depositsTotal > 0
        ? (_depositsRefunded / _depositsTotal * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DashboardTheme.primary,
            DashboardTheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: DashboardTheme.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Financial Summary",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildFinancialItem(
                  "Paid This Month",
                  "\$${totalPaidThisMonth.toStringAsFixed(0)}",
                  Icons.payment,
                  Colors.white,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFinancialItem(
                  "Expenses",
                  "\$${_totalExpensesThisMonth.toStringAsFixed(0)}",
                  Icons.receipt_long,
                  Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildFinancialItem(
                  "Balance",
                  "\$${balance.toStringAsFixed(0)}",
                  Icons.account_balance_wallet,
                  balance >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFinancialItem(
                  "Deposits",
                  "${depositRefundedPercent.toStringAsFixed(0)}% refunded",
                  Icons.security,
                  Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 11)),
        ],
      ),
    );
  }

  // Charts Section
  Widget _buildChartsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Analytics",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "Expenses", icon: Icon(Icons.pie_chart)),
              Tab(text: "Payments", icon: Icon(Icons.show_chart)),
              Tab(text: "Maintenance", icon: Icon(Icons.bar_chart)),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 250,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExpensesPieChart(),
                _buildPaymentsLineChart(),
                _buildMaintenanceBarChart(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesPieChart() {
    if (_expensesByType.isEmpty) {
      return const Center(
          child: Text("No expenses data available",
              style: TextStyle(color: Colors.grey)));
    }

    final total = _expensesByType.values.fold(0.0, (sum, val) => sum + val);
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    int colorIndex = 0;
    final sections = _expensesByType.entries.map((entry) {
      final percent = (entry.value / total * 100);
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      
      return PieChartSectionData(
        value: entry.value,
        title: '${percent.toStringAsFixed(1)}%',
        color: color,
        radius: 80,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 60,
      ),
    );
  }

  Widget _buildPaymentsLineChart() {
    if (_paymentsByMonth.isEmpty && _paymentsPendingByMonth.isEmpty) {
      return const Center(
          child: Text("No payments data available",
              style: TextStyle(color: Colors.grey)));
    }

    final allMonths = {
      ..._paymentsByMonth.keys,
      ..._paymentsPendingByMonth.keys,
    }.toList()..sort();

    final spots = allMonths.asMap().entries.map((entry) {
      final monthIndex = entry.key.toDouble();
      final amount = _paymentsByMonth[entry.value] ?? 0.0;
      return FlSpot(monthIndex, amount);
    }).toList();

    final pendingSpots = allMonths.asMap().entries.map((entry) {
      final monthIndex = entry.key.toDouble();
      final amount = _paymentsPendingByMonth[entry.value] ?? 0.0;
      return FlSpot(monthIndex, amount);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < allMonths.length) {
                  return Text(allMonths[value.toInt()],
                      style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: pendingSpots,
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceBarChart() {
    if (_maintenanceByStatus.isEmpty) {
      return const Center(
          child: Text("No maintenance data available",
              style: TextStyle(color: Colors.grey)));
    }

    final groups = _maintenanceByStatus.entries.map((entry) {
      final status = entry.key;
      final count = entry.value;
      
      Color color;
      switch (status) {
        case 'pending':
          color = Colors.orange;
          break;
        case 'in_progress':
          color = Colors.blue;
          break;
        case 'completed':
          color = Colors.green;
          break;
        default:
          color = Colors.grey;
      }

      return BarChartGroupData(
        x: _maintenanceByStatus.keys.toList().indexOf(status),
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: color,
            width: 20,
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (_maintenanceByStatus.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
        barGroups: groups,
      ),
    );
  }

  // Maintenance Quick View
  Widget _buildMaintenanceQuickView() {
    if (_recentMaintenance.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Recent Maintenance",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TenantMaintenanceScreen()),
                  );
                },
                child: const Text("View All"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentMaintenance.map((req) {
            final status = req['status']?.toString() ?? 'pending';
            final description = req['description']?.toString() ?? 'No description';
            final date = req['createdAt'] ?? req['date'] ?? DateTime.now().toString();
            
            Color statusColor;
            switch (status) {
              case 'pending':
                statusColor = Colors.orange;
                break;
              case 'in_progress':
                statusColor = Colors.blue;
                break;
              case 'completed':
                statusColor = Colors.green;
                break;
              default:
                statusColor = Colors.grey;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 50,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(description.length > 40
                            ? '${description.substring(0, 40)}...'
                            : description,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(DateTime.tryParse(date) ?? DateTime.now()),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // Recent Activity Timeline
  Widget _buildRecentActivityTimeline() {
    final allActivities = <Map<String, dynamic>>[];

    // Add payments
    for (var payment in _recentPayments.take(3)) {
      try {
        allActivities.add({
          'type': 'payment',
          'title': 'Payment ${payment['status'] == 'paid' ? 'Paid' : 'Pending'}',
          'description': '\$${payment['amount']}',
          'date': DateTime.parse(payment['date']),
          'icon': Icons.payment,
          'color': payment['status'] == 'paid' ? Colors.green : Colors.orange,
        });
      } catch (e) {
        // Skip invalid dates
      }
    }

    // Add expenses
    for (var expense in _recentExpenses.take(2)) {
      try {
        allActivities.add({
          'type': 'expense',
          'title': 'Expense Added',
          'description': '${expense['type']} - \$${expense['amount']}',
          'date': DateTime.parse(expense['date']),
          'icon': Icons.receipt_long,
          'color': Colors.blue,
        });
      } catch (e) {
        // Skip invalid dates
      }
    }

    // Add maintenance
    for (var maint in _recentMaintenance.take(2)) {
      try {
        final dateStr = maint['createdAt'] ?? maint['date'] ?? DateTime.now().toString();
        allActivities.add({
          'type': 'maintenance',
          'title': 'Maintenance Request',
          'description': maint['description']?.toString() ?? 'Maintenance',
          'date': DateTime.tryParse(dateStr) ?? DateTime.now(),
          'icon': Icons.build_circle,
          'color': Colors.purple,
        });
      } catch (e) {
        // Skip invalid dates
      }
    }

    // Sort by date (newest first)
    allActivities.sort((a, b) => b['date'].compareTo(a['date']));

    if (allActivities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Center(
            child: Text("No recent activity.",
                style: TextStyle(color: Colors.grey))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: allActivities.asMap().entries.map((entry) {
          final index = entry.key;
          final activity = entry.value;
          final isLast = index == allActivities.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: activity['color'].withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(activity['icon'],
                        color: activity['color'], size: 20),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 50,
                      color: Colors.grey[300],
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(activity['title'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(activity['description'],
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(activity['date']),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => _NotificationsDialog(
        onNotificationRead: () {
          _fetchMessageAndNotificationCounts();
        },
      ),
    );
  }
}

class _NotificationsDialog extends StatefulWidget {
  final VoidCallback onNotificationRead;
  const _NotificationsDialog({required this.onNotificationRead});

  @override
  State<_NotificationsDialog> createState() => _NotificationsDialogState();
}

class _NotificationsDialogState extends State<_NotificationsDialog> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getUserNotifications();
    if (mounted) {
      setState(() {
        if (ok) {
          _notifications = data;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Notifications"),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? const Center(child: Text("No notifications yet."))
                : ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      final bool isRead = n['isRead'] ?? false;

                      return ListTile(
                        leading: Icon(
                          Icons.notifications,
                          color: isRead ? Colors.grey : DashboardTheme.primary,
                        ),
                        title: Text(
                          n['message'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        trailing: isRead
                            ? null
                            : const Icon(Icons.circle,
                                color: Colors.red, size: 10),
                        onTap: () async {
                          if (!isRead) {
                            await ApiService.markNotificationRead(n['_id']);
                            widget.onNotificationRead();
                            _fetchNotifications();
                          }
                        },
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 5,
                offset: const Offset(0, 3))
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Center(
                    child: Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14))),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: Text("$badge",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class _TenantDrawer extends StatelessWidget {
  final String userName;
  final VoidCallback onLogout;
  const _TenantDrawer({required this.userName, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(userName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: const Text("Tenant Account"),
            decoration: const BoxDecoration(color: DashboardTheme.primary),
            currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: DashboardTheme.primary)),
          ),
          ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Dashboard"),
              onTap: () => Navigator.pop(context)),
          ListTile(
              leading: const Icon(Icons.description),
              title: const Text("My Contracts"),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TenantContractsScreen()))),
          ListTile(
              leading: const Icon(Icons.payment),
              title: const Text("Payments"),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TenantPaymentsScreen()))),
          ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text("Expenses"),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ExpensesManagementScreen()))),
          ListTile(
              leading: const Icon(Icons.security),
              title: const Text("Deposits"),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DepositsManagementScreen()))),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text("Contact Us"),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()))),
          ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout"),
              onTap: onLogout),
        ],
      ),
    );
  }
}
