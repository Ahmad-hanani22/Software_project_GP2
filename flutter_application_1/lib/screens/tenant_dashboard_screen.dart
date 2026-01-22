import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/firebase_notification_service.dart';
import 'package:flutter_application_1/screens/home_page.dart';
import 'package:flutter_application_1/screens/service_pages.dart';

import 'package:flutter_application_1/utils/tenant_theme.dart';
import 'contract_details_screen.dart';
import 'tenant_contracts_screen.dart';
import 'tenant_payments_screen.dart';
import 'tenant_maintenance_screen.dart';
import 'expenses_management_screen.dart';
import 'deposits_management_screen.dart';
import 'chat_list_screen.dart';
import 'ai_assistant_screen.dart';

class TenantDashboardScreen extends StatefulWidget {
  const TenantDashboardScreen({super.key});

  @override
  State<TenantDashboardScreen> createState() => _TenantDashboardScreenState();
}

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
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

  // Message and Notification counters
  int _messagePeopleCount = 0; // Number of people who sent messages
  int _unreadNotificationsCount = 0;
  Timer? _refreshTimer;

// Realtime notifications system
  StreamSubscription? _firebaseNotificationSubscription;
  List<Map<String, dynamic>> _apiNotifications = [];
  int _previousApiNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchMessageAndNotificationCounts();

    _firebaseNotificationSubscription =
        FirebaseNotificationService().messageStream.listen((message) {
      debugPrint(
          '🔔 [Tenant Dashboard] Firebase notification received: ${message.notification?.title}');
      if (mounted) {
        _fetchMessageAndNotificationCounts();
        _fetchNewNotifications();
      }
    });

    // Periodic refresh for notifications
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        _fetchMessageAndNotificationCounts();
        _fetchNewNotifications();
      }
    });
  }

  /// Build a short insight string about next payment for header
  String _computeNextPaymentInsight() {
    if (_allPayments.isEmpty) {
      return 'No payments yet';
    }

    final now = DateTime.now();
    DateTime? nextDate;
    String? nextCycle;

    for (final p in _allPayments) {
      try {
        final status = (p['status'] ?? '').toString().toLowerCase();
        if (status != 'pending') continue;
        final d = DateTime.parse(p['date']);
        if (nextDate == null || d.isBefore(nextDate!)) {
          nextDate = d;
          // read paymentCycle from populated contract if exists
          final contract = p['contractId'];
          if (contract is Map && contract['paymentCycle'] != null) {
            nextCycle = contract['paymentCycle'].toString().toLowerCase();
          } else {
            nextCycle = null;
          }
        }
      } catch (_) {}
    }

    if (nextDate == null) {
      return 'No pending payments 🎉';
    }

    final diff = nextDate.difference(now);
    final cycle = (nextCycle ?? 'monthly').toLowerCase();

    if (cycle == 'daily') {
      final hours = diff.inHours;
      if (hours < 0) {
        return 'You have an overdue payment (${hours.abs()} hour(s))';
      }
      return 'Your next payment is due in $hours hour(s)';
    }

    final days = diff.inDays;
    if (days < 0) {
      return 'You have an overdue payment (${days.abs()} day(s))';
    }

    return 'Your next payment is due in $days day(s)';
  }

  /// Simple financial charts: payments over last 6 months + maintenance status
  Widget _buildFinancialChartsSection() {
    // Prepare last 6 months labels and totals
    final now = DateTime.now();
    final List<DateTime> months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - (5 - i), 1),
    );

    final Map<String, double> monthTotals = {
      for (final m in months) DateFormat('yyyy-MM').format(m): 0.0
    };

    for (final p in _allPayments) {
      try {
        final date = DateTime.parse(p['date']);
        final key = DateFormat('yyyy-MM').format(date);
        if (monthTotals.containsKey(key)) {
          final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
          monthTotals[key] = monthTotals[key]! + amount;
        }
      } catch (_) {
        // ignore invalid dates
      }
    }

    final values = monthTotals.values.toList();
    final maxValue = values
        .fold<double>(0.0, (prev, v) => v > prev ? v : prev)
        .clamp(0, double.infinity);

    // Maintenance distribution
    final open = _maintenancePending;
    final completed = _maintenanceCompleted;
    final other =
        (_maintenanceTotal - open - completed).clamp(0, _maintenanceTotal);
    final totalForPie = (open + completed + other);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSectionTitle('Insights'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bar chart
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TenantTheme.cardBg,
                  borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
                  boxShadow: TenantTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bar_chart,
                            size: 18, color: TenantTheme.primary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Payments (last 6 months)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: TenantTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(months.length, (index) {
                          final m = months[index];
                          final key = DateFormat('yyyy-MM').format(m);
                          final value = monthTotals[key] ?? 0.0;
                          final ratio = maxValue > 0 ? (value / maxValue) : 0.0;

                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Tooltip(
                                  message:
                                      '${DateFormat.MMM().format(m)}: \$${value.toStringAsFixed(0)}',
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: 90 * ratio,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          TenantTheme.primary.withOpacity(0.8),
                                          TenantTheme.primaryLight
                                              .withOpacity(0.6),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat.MMM().format(m),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: TenantTheme.textHint,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Pie chart (maintenance)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TenantTheme.cardBg,
                  borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
                  boxShadow: TenantTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pie_chart,
                            size: 18, color: TenantTheme.warning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Maintenance status',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: TenantTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: Center(
                        child: totalForPie == 0
                            ? Text(
                                'No requests yet',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: TenantTheme.textHint,
                                ),
                              )
                            : CustomPaint(
                                size: const Size(80, 80),
                                painter: _MaintenancePiePainter(
                                  open: open.toDouble(),
                                  completed: completed.toDouble(),
                                  other: other.toDouble(),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildLegendDot(TenantTheme.warning, 'Open'),
                        _buildLegendDot(TenantTheme.success, 'Completed'),
                        _buildLegendDot(TenantTheme.textHint, 'Other'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: TenantTheme.textHint),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _firebaseNotificationSubscription?.cancel();
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

      final startDateThisMonth =
          DateFormat('yyyy-MM-dd').format(firstDayOfMonth);
      final startDateLastMonth =
          DateFormat('yyyy-MM-dd').format(firstDayLastMonth);
      final endDateLastMonth =
          DateFormat('yyyy-MM-dd').format(lastDayLastMonth);

      final results = await Future.wait([
        ApiService.getUserContracts(_userId!),
        ApiService.getUserPayments(_userId!),
        ApiService.getAllExpenses(startDate: startDateThisMonth),
        ApiService.getAllExpenses(
            startDate: startDateLastMonth, endDate: endDateLastMonth),
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
                .where(
                    (c) => c['status'] == 'rented' || c['status'] == 'active')
                .length;
            // Check for expiring contracts (within 30 days)
            _contractExpiryAlerts = _checkContractExpiry(conData);
          }

          // Payments
          final (payOk, payData) = results[1] as (bool, dynamic);
          if (payOk && payData is List) {
            _allPayments = payData;
            _duePayments =
                payData.where((p) => p['status'] == 'pending').length;
            _recentPayments = List.from(payData);
            _recentPayments.sort((a, b) =>
                DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
            if (_recentPayments.length > 5)
              _recentPayments = _recentPayments.sublist(0, 5);
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
                return DateTime.parse(b['date'])
                    .compareTo(DateTime.parse(a['date']));
              } catch (e) {
                return 0;
              }
            });
            if (_recentExpenses.length > 5)
              _recentExpenses = _recentExpenses.sublist(0, 5);
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
                .fold(
                    0.0,
                    (sum, d) =>
                        sum + ((d['amount'] as num?)?.toDouble() ?? 0.0));
          }

          // Maintenance Requests
          final (maintOk, maintData) = results[5] as (bool, dynamic);
          if (maintOk && maintData is List) {
            _maintenanceTotal = maintData.length;
            _maintenancePending = maintData
                .where((m) =>
                    m['status'] == 'pending' || m['status'] == 'in_progress')
                .length;
            _maintenanceCompleted =
                maintData.where((m) => m['status'] == 'completed').length;

            _recentMaintenance = List.from(maintData);
            _recentMaintenance.sort((a, b) {
              try {
                return DateTime.parse(b['createdAt'] ??
                        b['date'] ??
                        DateTime.now().toString())
                    .compareTo(DateTime.parse(a['createdAt'] ??
                        a['date'] ??
                        DateTime.now().toString()));
              } catch (e) {
                return 0;
              }
            });
            if (_recentMaintenance.length > 3)
              _recentMaintenance = _recentMaintenance.sublist(0, 3);
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

  // Fetch notifications from API to show instant alerts (fallback if FCM fails)
  Future<void> _fetchNewNotifications() async {
    try {
      if (_userId == null) return;

      final (ok, notifications) = await ApiService.getUserNotifications();
      if (ok && mounted) {
        final notificationsList = notifications as List<dynamic>? ?? [];
        final currentNotifications =
            notificationsList.cast<Map<String, dynamic>>();
        final currentCount = currentNotifications.length;

        if (currentCount > _previousApiNotificationsCount &&
            _previousApiNotificationsCount > 0) {
          final newNotificationsCount =
              currentCount - _previousApiNotificationsCount;
          final unreadNotifications =
              currentNotifications.where((n) => n['isRead'] == false).toList();

          if (unreadNotifications.isNotEmpty) {
            final latestUnread = unreadNotifications.first;
            final title = latestUnread['title'] ?? 'New notification';
            final message =
                latestUnread['message'] ?? 'You have a new notification';

            _showNewItemNotification(title, message, Icons.notifications);
          } else if (newNotificationsCount > 0) {
            _showNewItemNotification(
              'New notifications',
              'You have $newNotificationsCount new notification(s)',
              Icons.notifications,
            );
          }
        } else if (_previousApiNotificationsCount == 0 && currentCount > 0) {
          final unreadNotifications =
              currentNotifications.where((n) => n['isRead'] == false).toList();
          if (unreadNotifications.isNotEmpty) {
            final latestUnread = unreadNotifications.first;
            final title = latestUnread['title'] ?? 'New notification';
            final message =
                latestUnread['message'] ?? 'You have a new notification';

            _showNewItemNotification(title, message, Icons.notifications);
          }
        }

        setState(() {
          _apiNotifications = currentNotifications;
          _previousApiNotificationsCount = currentCount;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching new notifications: $e');
    }
  }

  // Show SnackBar for new notifications
  void _showNewItemNotification(String title, String message, IconData icon) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
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
    final brightness = MediaQuery.of(context).platformBrightness;
    final bool isDark = brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : TenantTheme.scaffoldBg,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TenantTheme.primary))
          : RefreshIndicator(
              onRefresh: () async {
                await _fetchDashboardStats();
                _fetchMessageAndNotificationCounts();
                _fetchNewNotifications();
              },
              color: TenantTheme.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  _buildSliverAppBar(isDark: isDark),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickStatsGrid(),
                          const SizedBox(height: 25),
                          _buildFinancialChartsSection(),
                          const SizedBox(height: 25),
                          _buildTenantTipsCard(),
                          const SizedBox(height: 25),
                          if (_contractExpiryAlerts.isNotEmpty) ...[
                            _buildContractExpiryAlerts(),
                            const SizedBox(height: 25),
                          ],
                          _buildMaintenanceQuickView(),
                          const SizedBox(height: 25),
                          _buildSectionTitle('Quick actions'),
                          const SizedBox(height: 15),
                          _buildActionGrid(context),
                          const SizedBox(height: 25),
                          _buildSectionTitle('Recent activity'),
                          const SizedBox(height: 15),
                          _buildRecentActivityTimeline(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      drawer: _TenantDrawer(userName: _userName, onLogout: _logout),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: TenantTheme.textPrimary,
      ),
    );
  }

  /// Helpful tips for tenant
  Widget _buildTenantTipsCard() {
    final tips = [
      {
        'icon': Icons.gavel,
        'text':
            'Know your rights: proper maintenance, prior notice before visits, and fair deposit refund on good handover.',
        'color': TenantTheme.primary
      },
      {
        'icon': Icons.security,
        'text':
            'Deposits: refunded within the agreed period after contract end and good handover of the unit.',
        'color': TenantTheme.accent
      },
      {
        'icon': Icons.build_circle,
        'text':
            'Maintenance: report issues early. Essential repairs are typically the landlord’s responsibility.',
        'color': TenantTheme.warning
      },
      {
        'icon': Icons.article,
        'text':
            'Keep a copy of your contract, rent receipts, and communication with the landlord.',
        'color': TenantTheme.success
      },
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TenantTheme.cardBg,
        borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
        boxShadow: TenantTheme.cardShadow,
        border: Border.all(color: TenantTheme.primaryLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: TenantTheme.accent, size: 22),
              const SizedBox(width: 8),
              Text('Helpful tips for tenants',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TenantTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(t['icon'] as IconData,
                        size: 18, color: t['color'] as Color),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(t['text'] as String,
                            style: TextStyle(
                                fontSize: 12,
                                color: TenantTheme.textSecondary,
                                height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  SliverAppBar _buildSliverAppBar({bool isDark = false}) {
    String greeting;
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    final nextPaymentInfo = _computeNextPaymentInsight();

    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: isDark ? Colors.black : TenantTheme.primary,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
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
              icon:
                  const Icon(Icons.notifications_outlined, color: Colors.white),
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
                    _unreadNotificationsCount > 9
                        ? '9+'
                        : '$_unreadNotificationsCount',
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
            gradient: TenantTheme.headerGradient,
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
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'T',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: TenantTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$greeting, $_userName",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            nextPaymentInfo,
                            key: ValueKey(nextPaymentInfo),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        ),
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

  Widget _buildQuickStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Overview'),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Active contracts',
              '$_activeContracts',
              Icons.description,
              TenantTheme.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TenantContractsScreen(),
                  ),
                );
              },
            ),
            _buildStatCard(
              'Pending payments',
              '$_duePayments',
              Icons.payment,
              _duePayments > 0 ? TenantTheme.error : TenantTheme.success,
              badge: _duePayments > 0 ? _duePayments : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TenantPaymentsScreen(),
                  ),
                );
              },
            ),
            _buildStatCard(
              'Expenses this month',
              '\$${_totalExpensesThisMonth.toStringAsFixed(0)}',
              Icons.receipt_long,
              TenantTheme.accentOrange,
              subtitle: _totalExpensesLastMonth > 0
                  ? '${((_totalExpensesThisMonth - _totalExpensesLastMonth) / _totalExpensesLastMonth * 100).toStringAsFixed(1)}% ${_totalExpensesThisMonth > _totalExpensesLastMonth ? '↑' : '↓'} vs last month'
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExpensesManagementScreen(),
                  ),
                );
              },
            ),
            _buildStatCard(
              'Total deposits',
              '\$${_depositsTotal.toStringAsFixed(0)}',
              Icons.security,
              TenantTheme.accent,
              subtitle: '$_depositsCount deposits',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DepositsManagementScreen(),
                  ),
                );
              },
            ),
            _buildStatCard(
              'Open maintenance',
              '$_maintenancePending',
              Icons.build_circle,
              TenantTheme.warning,
              badge: _maintenancePending > 0 ? _maintenancePending : null,
              subtitle: _maintenanceTotal > 0
                  ? '$_maintenanceCompleted of $_maintenanceTotal completed'
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TenantMaintenanceScreen(),
                  ),
                );
              },
            ),
            _buildStatCard(
              'Contract expiry alerts',
              '${_contractExpiryAlerts.length}',
              Icons.warning_amber_rounded,
              _contractExpiryAlerts.isEmpty
                  ? TenantTheme.textHint
                  : (_contractExpiryAlerts.length > 5
                      ? TenantTheme.error
                      : TenantTheme.warning),
              badge: _contractExpiryAlerts.isNotEmpty
                  ? _contractExpiryAlerts.length
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TenantContractsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    int? badge,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TenantTheme.cardBg,
          borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
          boxShadow: TenantTheme.cardShadow,
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          value,
                          key: ValueKey(value),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          color: TenantTheme.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 9,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                    color: TenantTheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    "$badge",
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
          label: 'My contracts',
          color: TenantTheme.primary,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TenantContractsScreen())),
        ),
        _ActionBtn(
          icon: Icons.credit_card_outlined,
          label: 'Payments',
          color: TenantTheme.accent,
          badge: _duePayments,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const TenantPaymentsScreen())),
        ),
        _ActionBtn(
          icon: Icons.build_circle_outlined,
          label: 'Maintenance',
          color: TenantTheme.warning,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TenantMaintenanceScreen())),
        ),
        _ActionBtn(
          icon: Icons.receipt_long_outlined,
          label: 'Expenses',
          color: TenantTheme.accentOrange,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ExpensesManagementScreen())),
        ),
        _ActionBtn(
          icon: Icons.security,
          label: 'Deposits',
          color: TenantTheme.success,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DepositsManagementScreen())),
        ),
        _ActionBtn(
          icon: Icons.search,
          label: 'Search unit',
          color: TenantTheme.primaryDark,
          onTap: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
              (r) => false),
        ),
      ],
    );
  }

  Widget _buildContractExpiryAlerts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TenantTheme.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
        border: Border.all(color: TenantTheme.warning.withOpacity(0.3)),
        boxShadow: TenantTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: TenantTheme.warning),
              const SizedBox(width: 8),
              Text('Contract expiry alerts',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: TenantTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'The following contracts are expiring in the next 30 days. Review details or contact your landlord to renew.',
              style: TextStyle(fontSize: 12, color: TenantTheme.textSecondary)),
          const SizedBox(height: 12),
          ..._contractExpiryAlerts.map((alert) {
            final contract = alert['contract'];
            final daysLeft = alert['daysLeft'] as int;
            final propertyTitle = contract['propertyId']?['title'] ??
                contract['propertyId']?['address'] ??
                'Property';
            final contractId = contract['_id']?.toString() ?? '';
            String endDateStr = '—';
            try {
              final e = contract['endDate'];
              if (e != null)
                endDateStr = DateFormat('yyyy-MM-dd')
                    .format(DateTime.tryParse(e.toString()) ?? DateTime.now());
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TenantTheme.cardBg,
                borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
                boxShadow: TenantTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    color: daysLeft <= 15
                        ? TenantTheme.error
                        : TenantTheme.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(propertyTitle,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Expires in $daysLeft day(s)',
                            style: TextStyle(
                                fontSize: 12,
                                color: daysLeft <= 15
                                    ? TenantTheme.error
                                    : TenantTheme.warning)),
                        Text('End date: $endDateStr',
                            style: TextStyle(
                                fontSize: 11, color: TenantTheme.textHint)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (contractId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ContractDetailsScreen(
                                  contractId: contractId)),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TenantContractsScreen()),
                        );
                      }
                    },
                    child: const Text('View contract'),
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
    final totalPaidThisMonth =
        _allPayments.where((p) => p['status'] == 'paid').where((p) {
      try {
        final date = DateTime.parse(p['date']);
        final now = DateTime.now();
        return date.year == now.year && date.month == now.month;
      } catch (e) {
        return false;
      }
    }).fold(0.0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0.0));

    final balance = totalPaidThisMonth - _totalExpensesThisMonth;
    final depositRefundedPercent =
        _depositsTotal > 0 ? (_depositsRefunded / _depositsTotal * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TenantTheme.primary, TenantTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
        boxShadow: [
          ...TenantTheme.cardShadow,
          BoxShadow(
              color: TenantTheme.primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial summary',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildFinancialItem(
                  'Rent paid this month',
                  '\$${totalPaidThisMonth.toStringAsFixed(0)}',
                  Icons.payment,
                  Colors.white,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFinancialItem(
                  'Expenses',
                  '\$${_totalExpensesThisMonth.toStringAsFixed(0)}',
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
                  'Balance',
                  '\$${balance.toStringAsFixed(0)}',
                  Icons.account_balance_wallet,
                  balance >= 0 ? TenantTheme.success : TenantTheme.error,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildFinancialItem(
                  'Refunded deposits %',
                  '${depositRefundedPercent.toStringAsFixed(0)}%',
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
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.8), fontSize: 11)),
        ],
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
        color: TenantTheme.cardBg,
        borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
        boxShadow: TenantTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Recent maintenance",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: TenantTheme.textPrimary)),
                  if (_maintenanceTotal > 0)
                    Text(
                        '$_maintenanceCompleted of $_maintenanceTotal completed',
                        style: TextStyle(
                            fontSize: 12, color: TenantTheme.textHint)),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TenantMaintenanceScreen()),
                  );
                },
                child: const Text("View all"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentMaintenance.map((req) {
            final status = req['status']?.toString() ?? 'pending';
            final description =
                req['description']?.toString() ?? 'No description';
            final date =
                req['createdAt'] ?? req['date'] ?? DateTime.now().toString();

            Color statusColor;
            String statusAr;
            switch (status) {
              case 'pending':
                statusColor = TenantTheme.warning;
                statusAr = 'Pending';
                break;
              case 'in_progress':
                statusColor = TenantTheme.primary;
                statusAr = 'In progress';
                break;
              case 'completed':
                statusColor = TenantTheme.success;
                statusAr = 'Completed';
                break;
              default:
                statusColor = TenantTheme.textHint;
                statusAr = status;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TenantTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
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
                        Text(
                            description.length > 40
                                ? '${description.substring(0, 40)}...'
                                : description,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(
                              DateTime.tryParse(date) ?? DateTime.now()),
                          style: TextStyle(
                              fontSize: 11, color: TenantTheme.textHint),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusAr,
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

  Widget _buildRecentActivityTimeline() {
    final allActivities = <Map<String, dynamic>>[];

    // Add payments
    for (var payment in _recentPayments.take(3)) {
      try {
        allActivities.add({
          'type': 'payment',
          'title': payment['status'] == 'paid'
              ? 'Payment completed'
              : 'Payment pending',
          'description': '\$${payment['amount']}',
          'date': DateTime.parse(payment['date']),
          'icon': Icons.payment,
          'color': payment['status'] == 'paid'
              ? TenantTheme.success
              : TenantTheme.warning,
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
          'title': 'New expense',
          'description': '${expense['type']} - \$${expense['amount']}',
          'date': DateTime.parse(expense['date']),
          'icon': Icons.receipt_long,
          'color': TenantTheme.accentOrange,
        });
      } catch (e) {
        // Skip invalid dates
      }
    }

    // Add maintenance
    for (var maint in _recentMaintenance.take(2)) {
      try {
        final dateStr =
            maint['createdAt'] ?? maint['date'] ?? DateTime.now().toString();
        allActivities.add({
          'type': 'maintenance',
          'title': 'Maintenance request',
          'description': maint['description']?.toString() ?? 'Maintenance',
          'date': DateTime.tryParse(dateStr) ?? DateTime.now(),
          'icon': Icons.build_circle,
          'color': TenantTheme.warning,
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
          color: TenantTheme.cardBg,
          borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
          boxShadow: TenantTheme.cardShadow,
        ),
        child: Center(
            child: Text(
                "No recent activity yet. Your payments, expenses and maintenance requests will appear here.",
                style: TextStyle(color: TenantTheme.textHint),
                textAlign: TextAlign.center)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TenantTheme.cardBg,
        borderRadius: BorderRadius.circular(TenantTheme.radiusLg),
        boxShadow: TenantTheme.cardShadow,
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
                      color: TenantTheme.textHint.withOpacity(0.3),
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
                          style: TextStyle(
                              fontSize: 12, color: TenantTheme.textHint)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat.yMMMd().add_jm().format(activity['date']),
                        style: TextStyle(
                            fontSize: 11, color: TenantTheme.textHint),
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
                          color: isRead
                              ? TenantTheme.textHint
                              : TenantTheme.primary,
                        ),
                        title: Text(
                          n['message'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
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
          child: Text('Close', style: TextStyle(color: TenantTheme.primary)),
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
          color: TenantTheme.cardBg,
          borderRadius: BorderRadius.circular(TenantTheme.radiusMd),
          boxShadow: TenantTheme.cardShadow,
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
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: TenantTheme.textPrimary))),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: TenantTheme.error, shape: BoxShape.circle),
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
          Container(
            decoration: const BoxDecoration(
              gradient: TenantTheme.headerGradient,
            ),
            child: UserAccountsDrawerHeader(
              accountName: Text(userName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              accountEmail: const Text("Tenant account",
                  style: TextStyle(color: Colors.white70)),
              decoration: const BoxDecoration(color: Colors.transparent),
              currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: TenantTheme.primary)),
            ),
          ),
          ListTile(
              leading: const Icon(Icons.dashboard, color: TenantTheme.primary),
              title: Text('Dashboard',
                  style: TextStyle(color: TenantTheme.textPrimary)),
              onTap: () => Navigator.pop(context)),
          ListTile(
              leading:
                  const Icon(Icons.description, color: TenantTheme.primary),
              title: Text('My Contracts',
                  style: TextStyle(color: TenantTheme.textPrimary)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TenantContractsScreen()))),
          ListTile(
              leading: const Icon(Icons.payment, color: TenantTheme.primary),
              title: Text('Payments',
                  style: TextStyle(color: TenantTheme.textPrimary)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TenantPaymentsScreen()))),
          ListTile(
              leading:
                  const Icon(Icons.build_circle, color: TenantTheme.primary),
              title: Text('Maintenance and Complaints',
                  style: TextStyle(color: TenantTheme.textPrimary)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TenantMaintenanceScreen()))),
          ListTile(
              leading: const Icon(Icons.receipt_long_outlined,
                  color: TenantTheme.primary),
              title: Text('Expenses',
                  style: TextStyle(color: TenantTheme.textPrimary)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ExpensesManagementScreen()))),
          ListTile(
              leading: const Icon(Icons.security, color: TenantTheme.primary),
              title: Text('Deposits',
                  style: TextStyle(color: TenantTheme.textPrimary)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DepositsManagementScreen()))),
          ListTile(
              leading: const Icon(Icons.smart_toy, color: TenantTheme.accent),
              title: Text('AI Assistant',
                  style: TextStyle(color: TenantTheme.textPrimary)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AIAssistantScreen()))),
          const Divider(),
          ListTile(
              leading:
                  const Icon(Icons.support_agent, color: TenantTheme.primary),
              title: Text('Contact us',
                  style: TextStyle(color: TenantTheme.textPrimary)),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()))),
          ListTile(
              leading: const Icon(Icons.logout, color: TenantTheme.error),
              title: Text('Logout',
                  style: TextStyle(
                      color: TenantTheme.error, fontWeight: FontWeight.w600)),
              onTap: onLogout),
        ],
      ),
    );
  }
}

class _MaintenancePiePainter extends CustomPainter {
  final double open;
  final double completed;
  final double other;

  _MaintenancePiePainter({
    required this.open,
    required this.completed,
    required this.other,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = open + completed + other;
    if (total <= 0) {
      return;
    }

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final startAngle = -3.14 / 2; // start from top

    double currentAngle = startAngle;

    final segments = [
      {'value': open, 'color': TenantTheme.warning},
      {'value': completed, 'color': TenantTheme.success},
      {'value': other, 'color': TenantTheme.textHint},
    ];

    for (final seg in segments) {
      final value = seg['value'] as double;
      if (value <= 0) continue;
      final sweepAngle = (value / total) * 3.14 * 2;
      final paint = Paint()
        ..color = (seg['color'] as Color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        rect.deflate(size.width * 0.16),
        currentAngle,
        sweepAngle,
        false,
        paint,
      );

      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _MaintenancePiePainter oldDelegate) {
    return open != oldDelegate.open ||
        completed != oldDelegate.completed ||
        other != oldDelegate.other;
  }
}
