// lib/screens/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/admin_dashboard_screen.dart';
import 'package:flutter_application_1/screens/landlord_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _token;
  String? _role;
  bool _isLoading = true;
  List<dynamic> _properties = [];
  String? _errorMessage; // To store any error message

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchProperties();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _token = prefs.getString('token');
      _role = prefs.getString('role');
    });
  }

  Future<void> _fetchProperties() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null; // Reset error on new fetch
      });

      // Destructure the tuple into 'ok' (the bool) and 'data' (the dynamic part)
      final (ok, data) = await ApiService.getAllProperties();

      if (!mounted) return;

      setState(() {
        if (ok) {
          // If the call was successful, assign the data (which is the list) to _properties.
          // We only show properties that are 'available' to the public.
          _properties = (data as List<dynamic>)
              .where((p) => p['status'] == 'available')
              .toList();
        } else {
          // If it failed, store the error message.
          _errorMessage = data.toString();
          _properties = []; // Clear properties on error
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading properties: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred.';
      });
    }
  }

  void _navigateToDashboard() {
    final navigator = Navigator.of(context);
    // ✅ FIX: Used the state variable _role instead of an undefined variable 'role'
    if (_role == 'admin') {
      navigator.push(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    } else if (_role == 'landlord') {
      navigator.push(
          MaterialPageRoute(builder: (_) => const LandlordDashboardScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No specific dashboard for your role.')),
      );
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    _loadUserData(); // Reload user data to update the UI
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged out successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _HomeNavbar(
        // ✅ FIX: Used the state variable _token instead of an undefined variable 'token'
        isLoggedIn: _token != null,
        onLogin: () =>
            Navigator.pushNamed(context, '/login').then((_) => _loadUserData()),
        onRegister: () => Navigator.pushNamed(context, '/register'),
        onDashboard: _navigateToDashboard,
        onLogout: _logout,
      ),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _fetchProperties,
        child: ListView(
          children: [
            const _HeroSection(),
            _buildContent(), // Helper widget to manage loading/error/data states
            const _AboutSection(),
            const _ContactSection(),
            const _HomeFooter(),
          ],
        ),
      ),
    );
  }

  /// A helper widget to decide what to show in the body based on the current state.
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'Failed to load properties: $_errorMessage',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return _PropertyGrid(properties: _properties);
  }
}

// ========== NAVBAR ==========
class _HomeNavbar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onDashboard;
  final Future<void> Function() onLogout;

  const _HomeNavbar({
    required this.isLoggedIn,
    required this.onLogin,
    required this.onRegister,
    required this.onDashboard,
    required this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF2E7D32),
      title: const Text(
        'SHAQATI Real Estate',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      actions: [
        if (!isLoggedIn)
          Row(
            children: [
              TextButton(
                onPressed: onLogin,
                child:
                    const Text('Login', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: onRegister,
                child: const Text('Register',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          )
        else
          Row(
            children: [
              IconButton(
                tooltip: 'Dashboard',
                onPressed: onDashboard,
                icon: const Icon(Icons.dashboard_outlined, color: Colors.white),
              ),
              IconButton(
                tooltip: 'Logout',
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Colors.white),
              ),
            ],
          ),
        const SizedBox(width: 16),
      ],
    );
  }
}

// ========== HERO SECTION ==========
class _HeroSection extends StatelessWidget {
  const _HeroSection();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/hero_image.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
        ),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Find Your Dream Home 🏡\nBuy • Rent • Invest',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}

// ========== PROPERTY GRID ==========
class _PropertyGrid extends StatelessWidget {
  final List<dynamic> properties;
  const _PropertyGrid({required this.properties});

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: Text('No available properties found.')),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = 3;
      if (constraints.maxWidth < 1200) crossAxisCount = 2;
      if (constraints.maxWidth < 800) crossAxisCount = 1;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: properties.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemBuilder: (context, i) {
            final p = properties[i];
            final imageUrl = (p['images'] != null && p['images'].isNotEmpty)
                ? p['images'][0]
                : 'https://via.placeholder.com/300x200?text=No+Image';
            return Card(
              clipBehavior: Clip.hardEdge,
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () {}, // TODO: Navigate to property details screen
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (c, e, s) => const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.grey, size: 40)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(p['title'] ?? 'Untitled',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              '${p['city'] ?? ''}, ${p['country'] ?? ''}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text(
                              "\$${p['price'] ?? 'N/A'} ${p['operation'] == 'rent' ? '/ month' : ''}",
                              style: const TextStyle(
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

// ========== ABOUT SECTION ==========
class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F8F8),
      padding: const EdgeInsets.all(40),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'About SHAQATI',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'SHAQATI Real Estate connects landlords and tenants in a smart, transparent platform. '
            'We provide tools for property management, payments, and maintenance — all in one place.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ========== CONTACT SECTION ==========
class _ContactSection extends StatelessWidget {
  const _ContactSection();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Contact Us',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text('We would love to hear from you!'),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.email),
            label: const Text('Send us an Email'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ========== FOOTER ==========
class _HomeFooter extends StatelessWidget {
  const _HomeFooter();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2E7D32),
      padding: const EdgeInsets.all(20),
      child: const Center(
        child: Text(
          '© 2025 SHAQATI Real Estate — All rights reserved',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
