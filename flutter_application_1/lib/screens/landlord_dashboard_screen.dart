import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

// --- Color Palette ---
const Color _primaryColor = Color(0xFF1976D2);
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
    final latest = _dashboardData!['latest'] ?? {};

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeCard(_landlordName ?? 'Landlord'),
          const SizedBox(height: 24),
          _buildSectionHeader('My Stats'),
          const SizedBox(height: 16),
          _buildStatsGrid(summary),
          const SizedBox(height: 24),
          _buildSectionHeader('Latest Activities'),
          const SizedBox(height: 16),
          _buildLatestContracts(latest['contracts'] ?? []),
          const SizedBox(height: 16),
          _buildLatestPayments(latest['payments'] ?? []),
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

  Widget _buildLatestContracts(List<dynamic> contracts) {
    if (contracts.isEmpty) return const SizedBox.shrink();
    return _ActivityCard(
      title: 'Recent Contracts',
      icon: Icons.description_outlined,
      items: contracts.map((c) {
        final tenant = c['tenantId'] ?? {};
        final property = c['propertyId'] ?? {};
        return ListTile(
          title: Text(property['title'] ?? 'N/A'),
          subtitle: Text('With: ${tenant['name'] ?? 'N/A'}'),
          trailing:
              Text(DateFormat.yMd().format(DateTime.parse(c['createdAt']))),
        );
      }).toList(),
    );
  }

  Widget _buildLatestPayments(List<dynamic> payments) {
    if (payments.isEmpty) return const SizedBox.shrink();
    return _ActivityCard(
      title: 'Recent Payments',
      icon: Icons.payment_outlined,
      items: payments.map((p) {
        final contract = p['contractId'] ?? {};
        final tenant = contract['tenantId'] ?? {};
        return ListTile(
          title: Text(
              NumberFormat.simpleCurrency(name: 'USD').format(p['amount'])),
          subtitle: Text('From: ${tenant['name'] ?? 'N/A'}'),
          trailing: Text(DateFormat.yMd().format(DateTime.parse(p['date']))),
        );
      }).toList(),
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

class _ActivityCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> items;

  const _ActivityCard(
      {required this.title, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _textSecondary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary)),
              ],
            ),
            const Divider(height: 20),
            ...items,
          ],
        ),
      ),
    );
  }
}
