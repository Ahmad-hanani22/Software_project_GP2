import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/home_page.dart';
import 'package:flutter_application_1/screens/service_pages.dart';

// 👇 استيراد الصفحات الجديدة (سننشئها في الخطوات التالية)
import 'tenant_contracts_screen.dart';
import 'tenant_payments_screen.dart';
import 'tenant_maintenance_screen.dart';

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

class _TenantDashboardScreenState extends State<TenantDashboardScreen> {
  String _userName = "Tenant";
  String? _userId;
  bool _isLoading = true;
  
  // Stats
  int _activeContracts = 0;
  int _duePayments = 0;
  List<dynamic> _recentPayments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final (conOk, conData) = await ApiService.getUserContracts(_userId!);
      final (payOk, payData) = await ApiService.getUserPayments(_userId!);

      if (mounted) {
        setState(() {
          if (conOk && conData is List) {
  _activeContracts = conData.where((c) => c['status'] == 'rented' || c['status'] == 'active').length;
          }
          if (payOk && payData is List) {
            _duePayments = payData.where((p) => p['status'] == 'pending').length;
            _recentPayments = List.from(payData);
            _recentPayments.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
            if (_recentPayments.length > 5) _recentPayments = _recentPayments.sublist(0, 5);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
          ? const Center(child: CircularProgressIndicator(color: DashboardTheme.primary))
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
                        _buildStatsRow(),
                        const SizedBox(height: 25),
                        const Text("Quick Actions",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildActionGrid(context),
                        const SizedBox(height: 25),
                        const Text("Recent Activity",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        _buildRecentActivityList(),
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
                  right: -30, top: -30,
                  child: Icon(Icons.home_work, size: 200, color: Colors.white.withOpacity(0.1))),
              Positioned(
                bottom: 20,
                left: 20,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Text(_userName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: DashboardTheme.primary)),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            "Active\nContracts",
            "$_activeContracts",
            Icons.description,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildInfoCard(
            "Pending\nPayments",
            "$_duePayments",
            Icons.payment,
            _duePayments > 0 ? Colors.red : Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantContractsScreen())),
        ),
        _ActionBtn(
          icon: Icons.credit_card_outlined,
          label: "Payments",
          color: Colors.orange,
          badge: _duePayments,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantPaymentsScreen())),
        ),
        _ActionBtn(
          icon: Icons.build_circle_outlined,
          label: "Maintenance",
          color: Colors.purple,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantMaintenanceScreen())),
        ),
        _ActionBtn(
          icon: Icons.search,
          label: "Find Home",
          color: Colors.indigo,
          onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomePage()), (r) => false),
        ),
      ],
    );
  }

  Widget _buildRecentActivityList() {
    if (_recentPayments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text("No recent activity.", style: TextStyle(color: Colors.grey))),
      );
    }
    return Column(
      children: _recentPayments.map((p) {
        final amount = p['amount'] ?? 0;
        final date = DateTime.parse(p['date']);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.check, color: Colors.green, size: 18),
            ),
            title: const Text("Rent Payment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(DateFormat.yMMMd().format(date), style: const TextStyle(fontSize: 12)),
            trailing: Text("-\$$amount", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;

  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text("$badge", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
            accountName: Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: const Text("Tenant Account"),
            decoration: const BoxDecoration(color: DashboardTheme.primary),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: DashboardTheme.primary)),
          ),
          ListTile(leading: const Icon(Icons.dashboard), title: const Text("Dashboard"), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.description), title: const Text("My Contracts"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantContractsScreen()))),
          ListTile(leading: const Icon(Icons.payment), title: const Text("Payments"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantPaymentsScreen()))),
          const Divider(),
          ListTile(leading: const Icon(Icons.support_agent), title: const Text("Contact Us"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactUsScreen()))),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout"), onTap: onLogout),
        ],
      ),
    );
  }
}