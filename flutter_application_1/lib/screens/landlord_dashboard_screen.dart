import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

// Import the new screens that now exist
import 'landlord_property_management_screen.dart';
import 'lib/screens/landlord_maintenance_screen.dart';

// --- Color Palette ---
const Color _primaryColor = Color(0xFF1976D2); // Blue for Landlord
const Color _scaffoldBackground = Color(0xFFF5F5F5);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class LandlordDashboardScreen extends StatefulWidget {
  const LandlordDashboardScreen({super.key});

  @override
  State<LandlordDashboardScreen> createState() =>
      _LandlordDashboardScreenState();
}

class _LandlordDashboardScreenState extends State<LandlordDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _errorMessage;
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
        if (ok) {
          _dashboardData = data as Map<String, dynamic>;
        } else {
          _errorMessage = data.toString();
        }
        _isLoading = false;
      });
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
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('Landlord Dashboard'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              onPressed: _fetchDashboardData, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _primaryColor));
    }
    if (_errorMessage != null) {
      return Center(
          child: Text('Error: $_errorMessage',
              style: const TextStyle(color: Colors.red)));
    }
    if (_dashboardData == null) {
      return const Center(child: Text('No data available.'));
    }

    final summary = _dashboardData!['summary'] ?? {};

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(_landlordName ?? 'Landlord'),
          const SizedBox(height: 24),
          _buildSectionHeader('Management Tools'),
          const SizedBox(height: 16),
          _buildManagementGrid(context, summary['pendingMaintenance'] ?? 0),
          const SizedBox(height: 24),
          _buildSectionHeader('Quick Stats'),
          const SizedBox(height: 16),
          _buildStatsGrid(summary),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(String name) {
    return Card(
      color: _primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text('Welcome back, $name!',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary));
  }

  Widget _buildManagementGrid(
      BuildContext context, int pendingMaintenanceCount) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _ManagementCard(
          title: 'My Properties',
          icon: Icons.home_work_outlined,
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LandlordPropertyManagementScreen()));
          },
        ),
        _ManagementCard(
          title: 'Maintenance',
          icon: Icons.build_outlined,
          notificationCount: pendingMaintenanceCount,
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LandlordMaintenanceScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildStatsGrid(Map<String, dynamic> summary) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _StatCard(
            title: 'Total Properties',
            value: summary['totalProperties'].toString(),
            icon: Icons.home_work,
            color: Colors.blue),
        _StatCard(
            title: 'Active Contracts',
            value: summary['activeContracts'].toString(),
            icon: Icons.description,
            color: Colors.green),
        _StatCard(
            title: 'Total Revenue',
            value: NumberFormat.simpleCurrency(name: 'USD')
                .format(summary['totalRevenue']),
            icon: Icons.monetization_on,
            color: Colors.amber.shade700),
      ],
    );
  }
}

class _ManagementCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int notificationCount;
  final VoidCallback onTap;

  const _ManagementCard(
      {required this.title,
      required this.icon,
      this.notificationCount = 0,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 40, color: _primaryColor),
                  const SizedBox(height: 8),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary)),
                ],
              ),
            ),
            if (notificationCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    notificationCount.toString(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            const SizedBox(height: 4),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSecondary)),
          ],
        ),
      ),
    );
  }
}
