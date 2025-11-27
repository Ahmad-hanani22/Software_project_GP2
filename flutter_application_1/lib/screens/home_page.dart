import 'dart:ui'; // For Glassmorphism
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/admin_dashboard_screen.dart';
import 'package:flutter_application_1/screens/landlord_dashboard_screen.dart';
// FIX: Hidden conflicting classes
import 'package:flutter_application_1/screens/tenant_dashboard_screen.dart'
    hide HelpSupportScreen, ContactUsScreen;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/property_details_screen.dart';
import 'package:flutter_application_1/screens/map_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'service_pages.dart';
import 'lifestyle_screen.dart';

// --- Constants for Design ---
const kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)], // Deep Green to Light Green
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // --- User State ---
  String? _token;
  String? _role;
  String? _userName;

  // --- Data State ---
  bool _isLoading = true;
  List<dynamic> _allProperties = [];
  List<dynamic> _displayedProperties = [];
  String? _errorMessage;

  // --- Advanced Filter State ---
  String _searchQuery = "";
  String _selectedCategory = "All";
  RangeValues _priceRange = const RangeValues(0, 1000000);
  String _sortOption = "Newest";
  int _minBedrooms = 0;
  String? _operationType; // Rent or Sale

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
      _userName = prefs.getString('userName');
    });
  }

  Future<void> _fetchProperties() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final (ok, data) = await ApiService.getAllProperties();

      if (!mounted) return;

      setState(() {
        if (ok) {
          _allProperties = (data as List<dynamic>)
              .where((p) => p['status'] == 'available')
              .toList();
          _applyFilters();
        } else {
          _errorMessage = data.toString();
          _allProperties = [];
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

  void _applyFilters() {
    setState(() {
      var temp = _allProperties.where((p) {
        final title = p['title'].toString().toLowerCase().trim();
        final city = p['city'].toString().toLowerCase().trim();
        final address = p['address'].toString().toLowerCase().trim();
        final price = (p['price'] as num).toDouble();
        final type = p['type'].toString().toLowerCase().trim();
        final operation = p['operation'].toString().toLowerCase().trim();
        final bedrooms = (p['bedrooms'] as num?)?.toInt() ?? 0;

        // Search
        final matchesSearch = title.contains(_searchQuery.toLowerCase()) ||
            city.contains(_searchQuery.toLowerCase()) ||
            address.contains(_searchQuery.toLowerCase());

        // Numeric Filters
        final matchesPrice =
            price >= _priceRange.start && price <= _priceRange.end;
        final matchesBedrooms = bedrooms >= _minBedrooms;

        // Categories & Operation
        final matchesType = _selectedCategory == "All" ||
            type == _selectedCategory.toLowerCase();

        final matchesOperation = _operationType == null ||
            operation == _operationType!.toLowerCase();

        return matchesSearch &&
            matchesPrice &&
            matchesType &&
            matchesBedrooms &&
            matchesOperation;
      }).toList();

      // Sorting
      if (_sortOption == "Price: Low to High") {
        temp.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
      } else if (_sortOption == "Price: High to Low") {
        temp.sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
      }

      _displayedProperties = temp;
    });
  }

  // --- 🧠 IMPROVED AI LOGIC ---
  void _handleAIAction(String command) {
    command = command.toLowerCase();
    String feedback = "Understanding your request...";

    setState(() {
      bool actionTaken = false;

      // 1. Reset
      if (command.contains("reset") || command.contains("clear")) {
        _selectedCategory = "All";
        _searchQuery = "";
        _priceRange = const RangeValues(0, 1000000);
        _minBedrooms = 0;
        _operationType = null;
        _sortOption = "Newest";
        feedback = "🔄 Resetting all filters for you.";
        actionTaken = true;
      }

      // 2. Property Type
      if (!actionTaken) {
        if (command.contains("villa")) {
          _selectedCategory = "villa";
          feedback = "🏰 Showing Villas.";
        } else if (command.contains("apartment") || command.contains("flat")) {
          _selectedCategory = "apartment";
          feedback = "🏢 Showing Apartments.";
        } else if (command.contains("shop") || command.contains("store")) {
          _selectedCategory = "shop";
          feedback = "🏪 Showing Commercial/Shops.";
        }
      }

      // 3. Sorting (Cheap/Luxury)
      if (command.contains("cheap") ||
          command.contains("lowest") ||
          command.contains("budget")) {
        _sortOption = "Price: Low to High";
        feedback += " Sorted by lowest price.";
      } else if (command.contains("luxury") ||
          command.contains("expensive") ||
          command.contains("highest")) {
        _sortOption = "Price: High to Low";
        feedback += " Sorted by luxury/highest price.";
      }

      // 4. Operation (Rent/Sale)
      if (command.contains("rent")) {
        _operationType = "rent";
        feedback += " For Rent only.";
      } else if (command.contains("buy") ||
          command.contains("sale") ||
          command.contains("sell")) {
        _operationType = "sale";
        feedback += " For Sale only.";
      }

      // 5. Bedrooms
      if (command.contains("1 bed")) _minBedrooms = 1;
      if (command.contains("2 bed")) _minBedrooms = 2;
      if (command.contains("3 bed")) _minBedrooms = 3;
      if (command.contains("4 bed")) _minBedrooms = 4;

      _applyFilters();
    });

    if (command.contains("map")) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MapScreen(properties: _displayedProperties)));
      return; // UI handles feedback
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(feedback),
      backgroundColor: Colors.purple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showAdvancedFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // For custom rounding
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: StatefulBuilder(builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  const Text("Filter & Sort",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // Price
                  Text(
                      "Price: \$${_priceRange.start.round()} - \$${_priceRange.end.round()}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 1000000,
                    divisions: 100,
                    activeColor: const Color(0xFF2E7D32),
                    onChanged: (values) =>
                        setModalState(() => _priceRange = values),
                  ),

                  // Bedrooms
                  Text("Min Bedrooms: $_minBedrooms",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Slider(
                    value: _minBedrooms.toDouble(),
                    min: 0,
                    max: 6,
                    divisions: 6,
                    activeColor: const Color(0xFF2E7D32),
                    onChanged: (val) =>
                        setModalState(() => _minBedrooms = val.toInt()),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text("Apply Changes",
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Future<void> _logout() async {
    await ApiService.logout();
    _loadUserData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully!')));
  }

  void _navigateToDashboard() {
    final navigator = Navigator.of(context);
    if (_role == 'admin')
      navigator.push(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    else if (_role == 'landlord')
      navigator.push(
          MaterialPageRoute(builder: (_) => const LandlordDashboardScreen()));
    else if (_role == 'tenant')
      navigator.push(
          MaterialPageRoute(builder: (_) => const TenantDashboardScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _HomeDrawer(
          isLoggedIn: _token != null,
          userName: _userName,
          role: _role,
          onLogout: _logout,
          onDashboard: _navigateToDashboard),
      appBar: _HomeNavbar(
        isLoggedIn: _token != null,
        onLogin: () =>
            Navigator.pushNamed(context, '/login').then((_) => _loadUserData()),
        onRegister: () => Navigator.pushNamed(context, '/register'),
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      backgroundColor: const Color(0xFFF5F6F8), // Very clean light grey
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
            context: context,
            builder: (context) => AIAssistantDialog(onAction: _handleAIAction)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: Colors.purple.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ]),
          child: const Row(children: [
            Icon(Icons.auto_awesome, color: Colors.white),
            SizedBox(width: 8),
            Text("Smart Agent",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ]),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProperties,
        child: CustomScrollView(
          slivers: [
            // 1. New Glassmorphism Search Section
            SliverToBoxAdapter(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const _HeroSection(),
                  // The "Glass" Search Bar
                  Positioned(
                    bottom: 30,
                    left: 20,
                    right: 20,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 5),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5))
                              ]),
                          child: TextField(
                            onChanged: (val) {
                              _searchQuery = val;
                              _applyFilters();
                            },
                            style: const TextStyle(color: Colors.black87),
                            decoration: const InputDecoration(
                              hintText: "Search for city, address...",
                              hintStyle: TextStyle(color: Colors.black54),
                              icon:
                                  Icon(Icons.search, color: Color(0xFF2E7D32)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),

            // 2. Filter Chips (Improved Design)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    IconButton(
                      onPressed: _showAdvancedFilterDialog,
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 5)
                            ]),
                        child: const Icon(Icons.tune, color: Color(0xFF2E7D32)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ...["All", "Apartment", "Villa", "House", "Shop"]
                        .map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedCategory = cat;
                            _applyFilters();
                          }),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2E7D32)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? null
                                    : Border.all(color: Colors.transparent),
                                boxShadow: [
                                  BoxShadow(
                                      color: isSelected
                                          ? Colors.green.withOpacity(0.4)
                                          : Colors.grey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3))
                                ]),
                            child: Center(
                              child: Text(cat,
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            // 3. Map Section
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: _MiniMapSection(properties: _displayedProperties),
              ),
            ),

            // 4. Header
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Latest Properties",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A))),
                    // Removed popular cities, just showing all recent
                  ],
                ),
              ),
            ),

            // 5. Grid
            _buildContent(),

            // 6. Services Banner
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Moving? Cleaning?",
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 8),
                          const Text(
                              "Get professional services at your doorstep.",
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 15),
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LifestyleScreen())),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blue[800],
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10))),
                            child: const Text("Explore Services",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.cleaning_services,
                            size: 50, color: Colors.white)),
                  ],
                ),
              ),
            ),

            // 7. 🦶 PROFESSIONAL FOOTER (ADDED)
            const SliverToBoxAdapter(child: _ProfessionalFooter()),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading)
      return const SliverFillRemaining(
          child: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32))));
    if (_errorMessage != null)
      return SliverToBoxAdapter(
          child: Center(
              child: Text('Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red))));
    if (_displayedProperties.isEmpty) {
      return const SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.all(60),
              child: Center(
                  child: Column(children: [
                Icon(Icons.search_off, size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text('No results found.', style: TextStyle(color: Colors.grey))
              ]))));
    }
    return _PropertyGrid(properties: _displayedProperties);
  }
}

// ========== ✨ FOOTER COMPONENT (NEW) ==========
class _ProfessionalFooter extends StatelessWidget {
  const _ProfessionalFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1B1B1B), // Dark footer background
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Desc
          const Row(
            children: [
              Icon(Icons.home_work_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Text("SHAQATI",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 15),
          const Text(
              "The #1 Real Estate Platform in Palestine.\nFind your dream home with AI-powered search.",
              style: TextStyle(color: Colors.grey, height: 1.5)),
          const SizedBox(height: 30),

          // Links Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Company",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _footerLink("About Us"),
                    _footerLink("Careers"),
                    _footerLink("Privacy Policy"),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Support",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _footerLink("Help Center"),
                    _footerLink("Terms of Service"),
                    _footerLink("Contact Us"),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
          const Divider(color: Colors.white24),
          const SizedBox(height: 20),

          // Bottom Copyright
          const Center(
              child: Text("© 2025 SHAQATI Inc. All rights reserved.",
                  style: TextStyle(color: Colors.white38, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _footerLink(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }
}

// ========== ✨ IMPROVED WIDGETS ==========

class _PulsatingMapButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PulsatingMapButton({required this.onTap});
  @override
  State<_PulsatingMapButton> createState() => _PulsatingMapButtonState();
}

class _PulsatingMapButtonState extends State<_PulsatingMapButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
              gradient: kPrimaryGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: Colors.green.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 5))
              ],
              border:
                  Border.all(color: Colors.white.withOpacity(0.8), width: 1.5)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.map_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text("Open Full Map",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16))
          ]),
        ),
      ),
    );
  }
}

class _MiniMapSection extends StatelessWidget {
  final List<dynamic> properties;
  const _MiniMapSection({required this.properties});
  @override
  Widget build(BuildContext context) {
    LatLng center = const LatLng(32.2211, 35.2544);
    if (properties.isNotEmpty) {
      try {
        final firstLoc = properties.first['location']['coordinates'];
        center = LatLng(firstLoc[1], firstLoc[0]);
      } catch (_) {}
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: FlutterMap(
                    options: MapOptions(
                        initialCenter: center,
                        initialZoom: 12.0,
                        interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none)),
                    children: [
                      TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'),
                      MarkerLayer(
                          markers: properties.take(5).map((p) {
                        try {
                          final coords = p['location']['coordinates'];
                          return Marker(
                              point: LatLng(coords[1], coords[0]),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on,
                                  color: Color(0xFF2E7D32), size: 35));
                        } catch (e) {
                          return const Marker(
                              point: LatLng(0, 0), child: SizedBox());
                        }
                      }).toList()),
                      Container(color: Colors.black.withOpacity(0.15)),
                    ]))),
        _PulsatingMapButton(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MapScreen(properties: properties)))),
      ],
    );
  }
}

class _PropertyGrid extends StatelessWidget {
  final List<dynamic> properties;
  const _PropertyGrid({required this.properties});
  @override
  Widget build(BuildContext context) {
    return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 900
                    ? 3
                    : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.82),
            delegate: SliverChildBuilderDelegate((context, index) {
              final p = properties[index];
              final imageUrl = (p['images'] != null && p['images'].isNotEmpty)
                  ? p['images'][0]
                  : 'https://via.placeholder.com/300x200?text=No+Image';
              return Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ]),
                  child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      clipBehavior: Clip.hardEdge,
                      child: InkWell(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      PropertyDetailsScreen(property: p))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    flex: 5,
                                    child:
                                        Stack(fit: StackFit.expand, children: [
                                      Image.network(imageUrl,
                                          fit: BoxFit.cover),
                                      Positioned(
                                          top: 12,
                                          left: 12,
                                          child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20)),
                                              child: Text(
                                                  p['operation']
                                                      .toString()
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11)))),
                                    ])),
                                Expanded(
                                    flex: 4,
                                    child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        p['title'] ??
                                                            'Untitled',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                            color: Color(
                                                                0xFF2C3E50))),
                                                    const SizedBox(height: 6),
                                                    Row(children: [
                                                      const Icon(
                                                          Icons
                                                              .location_on_rounded,
                                                          size: 14,
                                                          color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                          child: Text(
                                                              '${p['city'] ?? ''}, ${p['country'] ?? ''}',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                  fontSize:
                                                                      13)))
                                                    ])
                                                  ]),
                                              Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text("\$${p['price']}",
                                                        style: const TextStyle(
                                                            color: Color(
                                                                0xFF2E7D32),
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            fontSize: 18)),
                                                    Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(5),
                                                        decoration: BoxDecoration(
                                                            color: Colors
                                                                .green[50],
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8)),
                                                        child: const Icon(
                                                            Icons
                                                                .arrow_forward_ios_rounded,
                                                            size: 14,
                                                            color: Color(
                                                                0xFF2E7D32)))
                                                  ])
                                            ])))
                              ]))));
            }, childCount: properties.length)));
  }
}

class _HomeNavbar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin, onRegister, onOpenDrawer;
  const _HomeNavbar(
      {required this.isLoggedIn,
      required this.onLogin,
      required this.onRegister,
      required this.onOpenDrawer});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    return AppBar(
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: kPrimaryGradient)),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: onOpenDrawer),
        title: const Row(children: [
          Icon(Icons.home_work_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text('SHAQATI',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0))
        ]),
        actions: isLoggedIn
            ? []
            : [
                TextButton(
                    onPressed: onLogin,
                    child: const Text('Login',
                        style: TextStyle(color: Colors.white))),
                TextButton(
                    onPressed: onRegister,
                    child: const Text('Register',
                        style: TextStyle(color: Colors.white)))
              ]);
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection();
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 320, // Taller Hero
        width: double.infinity,
        decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage('assets/images/hero_image.png'),
                fit: BoxFit.cover,
                colorFilter:
                    ColorFilter.mode(Colors.black38, BlendMode.darken))),
        child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Find Your Dream Home",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 10)
                      ])),
              SizedBox(height: 10),
              Text("Buy • Rent • Invest • Live",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500))
            ]));
  }
}

class _HomeDrawer extends StatelessWidget {
  final bool isLoggedIn;
  final String? userName;
  final String? role;
  final VoidCallback onLogout, onDashboard;
  const _HomeDrawer(
      {required this.isLoggedIn,
      this.userName,
      this.role,
      required this.onLogout,
      required this.onDashboard});
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(padding: EdgeInsets.zero, children: [
        UserAccountsDrawerHeader(
            decoration: const BoxDecoration(gradient: kPrimaryGradient),
            accountName: Text(isLoggedIn ? (userName ?? "User") : "Guest User",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            accountEmail: Text(isLoggedIn
                ? (role?.toUpperCase() ?? "TENANT")
                : "Welcome to SHAQATI"),
            currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(isLoggedIn ? Icons.person : Icons.person_outline,
                    color: const Color(0xFF2E7D32), size: 45))),
        if (isLoggedIn)
          ListTile(
              leading: const Icon(Icons.dashboard_customize,
                  color: Color(0xFF2E7D32)),
              title: const Text('My Dashboard'),
              onTap: () {
                Navigator.pop(context);
                onDashboard();
              }),
        if (!isLoggedIn)
          ListTile(
              leading: const Icon(Icons.login, color: Color(0xFF2E7D32)),
              title: const Text('Login / Register'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/login');
              }),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.pool, color: Colors.purple),
            title: const Text('Lifestyle & Services'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LifestyleScreen()));
            }),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & FAQ'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
            }),
        ListTile(
            leading: const Icon(Icons.contact_support_outlined),
            title: const Text('Contact Us'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ContactUsScreen()));
            }),
        if (isLoggedIn) ...[
          const Divider(),
          ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onLogout();
              })
        ]
      ]),
    );
  }
}

// 🧠 SMARTER AI DIALOG
class AIAssistantDialog extends StatefulWidget {
  final Function(String) onAction;
  const AIAssistantDialog({super.key, required this.onAction});
  @override
  State<AIAssistantDialog> createState() => _AIAssistantDialogState();
}

class _AIAssistantDialogState extends State<AIAssistantDialog> {
  final List<Map<String, String>> _messages = [
    {
      "role": "ai",
      "text":
          "👋 Hi! I'm your Real Estate AI.\n\nTry asking:\n'Find cheap apartments'\n'Show villas for rent'\n'Reset filters'"
    }
  ];
  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    if (_controller.text.isEmpty) return;
    String txt = _controller.text;
    setState(() {
      _messages.add({"role": "user", "text": txt});
      _controller.clear();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        widget.onAction(txt);
        _messages.add({
          "role": "ai",
          "text": "✅ I've updated the listings based on your request."
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
            height: 450,
            child: Column(children: [
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                      gradient: kPrimaryGradient,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20))),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome, color: Colors.white),
                    const SizedBox(width: 10),
                    const Text("Smart Agent",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context))
                  ])),
              Expanded(
                  child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (c, i) => Align(
                          alignment: _messages[i]['role'] == 'ai'
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: _messages[i]['role'] == 'ai'
                                      ? Colors.grey[100]
                                      : const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.black12)),
                              child: Text(_messages[i]['text']!,
                                  style: const TextStyle(
                                      fontSize: 14, height: 1.4)))))),
              Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                          hintText: "Type your request...",
                          filled: true,
                          fillColor: Colors.grey[100],
                          suffixIcon: IconButton(
                              icon: const Icon(Icons.send_rounded,
                                  color: Color(0xFF2E7D32)),
                              onPressed: _sendMessage),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none))))
            ])));
  }
}
