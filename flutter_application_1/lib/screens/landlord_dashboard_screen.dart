import 'package:fl_chart/fl_chart.dart'; // ✅ مكتبة الرسوم البيانية
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

// Import screens
import 'landlord_property_management_screen.dart';
import 'landlord_maintenance_screen.dart';
import 'landlord_contracts_screen.dart';
import 'landlord_payments_screen.dart';

// --- Color Palette ---
const Color _primaryColor = Color(0xFF1976D2); // Blue
const Color _accentColor = Color(0xFF42A5F5);
const Color _backgroundColor = Color(0xFFF5F7FA);
const Color _cardColor = Colors.white;
const Color _textPrimary = Color(0xFF2C3E50);
const Color _textSecondary = Color(0xFF7F8C8D);

class LandlordDashboardScreen extends StatefulWidget {
  const LandlordDashboardScreen({super.key});

  @override
  State<LandlordDashboardScreen> createState() =>
      _LandlordDashboardScreenState();
}

class _LandlordDashboardScreenState extends State<LandlordDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _landlordName;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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
        if (ok) _dashboardData = data as Map<String, dynamic>;
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
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Welcome, $_landlordName',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              onPressed: _fetchDashboardData, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : _dashboardData == null
              ? const Center(child: Text("No data available"))
              : RefreshIndicator(
                  onRefresh: _fetchDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Financial Overview Cards
                        _buildFinancialOverview(
                            _dashboardData!['summary'] ?? {}),
                        const SizedBox(height: 24),

                        // 2. Property Statistics (Charts)
                        const Text("Property Overview",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary)),
                        const SizedBox(height: 16),
                        _buildChartsSection(_dashboardData!['summary'] ?? {}),
                        const SizedBox(height: 24),

                        // 3. Management Tools (Grid)
                        const Text("Quick Actions",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary)),
                        const SizedBox(height: 16),
                        _buildManagementGrid(_dashboardData!['summary'] ?? {}),
                        const SizedBox(height: 24),

                        // 4. Recent Activity List
                        const Text("Recent Payments",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary)),
                        const SizedBox(height: 16),
                        _buildRecentActivity(_dashboardData!['latest'] ?? {}),
                      ],
                    ),
                  ),
                ),
    );
  }

  // --- WIDGETS ---

  Widget _buildFinancialOverview(Map<String, dynamic> summary) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            title: "Total Revenue",
            value: NumberFormat.compactSimpleCurrency(name: 'USD')
                .format(summary['totalRevenue'] ?? 0),
            icon: Icons.account_balance_wallet,
            color: Colors.amber[700]!,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            title: "Active Contracts",
            value: "${summary['activeContracts'] ?? 0}",
            icon: Icons.assignment_turned_in,
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
      {required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(fontSize: 14, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildChartsSection(Map<String, dynamic> summary) {
    int rented = summary['rentedProperties'] ?? 0;
    int available = summary['availableProperties'] ?? 0;
    int total = summary['totalProperties'] ?? 0;

    // Prevent division by zero
    if (total == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: _cardColor, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No properties added yet.")),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
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
          // Pie Chart
          Expanded(
            flex: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    color: _primaryColor,
                    value: rented.toDouble(),
                    title: '${((rented / total) * 100).toStringAsFixed(0)}%',
                    radius: 40,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: Colors.grey[300],
                    value: available.toDouble(),
                    title: '${((available / total) * 100).toStringAsFixed(0)}%',
                    radius: 30,
                    titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Legend / Details
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem("Total Properties", "$total", Colors.black),
                const SizedBox(height: 8),
                _buildLegendItem("Rented", "$rented", _primaryColor),
                const SizedBox(height: 8),
                _buildLegendItem("Available", "$available", Colors.grey[400]!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, String value, Color color) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 12, color: _textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _textPrimary)),
      ],
    );
  }

  Widget _buildManagementGrid(Map<String, dynamic> summary) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildActionCard(
          title: 'Properties',
          icon: Icons.home_work_outlined,
          color: Colors.blue,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const LandlordPropertyManagementScreen())),
        ),
        _buildActionCard(
          title: 'Contracts',
          icon: Icons.description_outlined,
          color: Colors.teal,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const LandlordContractsScreen())),
        ),
        _buildActionCard(
          title: 'Maintenance',
          icon: Icons.build_outlined,
          color: Colors.orange,
          count: summary['pendingMaintenance'],
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const LandlordMaintenanceScreen())),
        ),
        _buildActionCard(
          title: 'Payments',
          icon: Icons.payment_outlined,
          color: Colors.purple,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const LandlordPaymentsScreen())),
        ),
      ],
    );
  }

  Widget _buildActionCard(
      {required String title,
      required IconData icon,
      required Color color,
      int? count,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(icon, size: 30, color: color),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textPrimary))),
              ],
            ),
            if (count != null && count > 0)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: Text('$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(Map<String, dynamic> latest) {
    final payments = latest['payments'] as List<dynamic>? ?? [];

    if (payments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: _cardColor, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No recent payments found.")),
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
            leading: CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.1),
              child: const Icon(Icons.attach_money, color: Colors.green),
            ),
            title: Text(tenant['name'] ?? 'Unknown Tenant',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle:
                Text(DateFormat.yMMMd().format(DateTime.parse(p['date']))),
            trailing: Text(
              NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0)
                  .format(p['amount']),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}
