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

// --- Color Palette (Beige & Green Theme) ---
const Color _primaryBeige = Color(0xFFD4B996); // لون بيج/رملي أساسي
const Color _darkBeige = Color(0xFF8D6E63); // بيج غامق للنصوص والعناوين
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
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _landlordName;
  LandlordDashboardData? _dashboardData;
  late AnimationController _animController;
  final double _kMobileBreakpoint = 800.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
            : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                color: _accentGreen,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 30),
                      Text("Overview", style: _headerStyle),
                      const SizedBox(height: 16),
                      _buildSummaryGrid(screenWidth),
                      const SizedBox(height: 30),
                      Text("Analytics & Properties", style: _headerStyle),
                      const SizedBox(height: 16),
                      _buildChartsSection(screenWidth),
                      const SizedBox(height: 30),
                      Text("Recent Transactions", style: _headerStyle),
                      const SizedBox(height: 16),
                      _buildRecentActivityList(),
                    ],
                  ),
                ),
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
            IconButton(
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh)),
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
              IconButton(
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh, color: _accentGreen),
                tooltip: "Refresh Data",
              ),
              const SizedBox(width: 16),
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
            ElevatedButton.icon(
              onPressed: () => _nav(const LandlordPropertyManagementScreen()),
              icon: const Icon(Icons.add_home_work),
              label: const Text("Add Property"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            )
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

  Widget _buildChartsSection(double screenWidth) {
    final summary = _dashboardData?.summary ?? {};
    int rented = summary['rentedProperties'] ?? 0;
    int available = summary['availableProperties'] ?? 0;
    int total = summary['totalProperties'] ?? 0;

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
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: total == 0
                ? const Center(child: Text("No properties added yet"))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: _accentGreen,
                          value: rented.toDouble(),
                          title:
                              '${((rented / total) * 100).toStringAsFixed(0)}%',
                          radius: 60,
                          titleStyle: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        PieChartSectionData(
                          color: _primaryBeige,
                          value: available.toDouble(),
                          title:
                              '${((available / total) * 100).toStringAsFixed(0)}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
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
              ],
            ),
          )
        ],
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
}
