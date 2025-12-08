import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/admin_dashboard_screen.dart';
import 'package:flutter_application_1/screens/landlord_dashboard_screen.dart';
import 'package:flutter_application_1/screens/tenant_dashboard_screen.dart'
    hide HelpSupportScreen, ContactUsScreen;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/property_details_screen.dart';
import 'package:flutter_application_1/screens/map_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'service_pages.dart';
import 'lifestyle_screen.dart';
import 'chat_list_screen.dart';
const Color kShaqatiPrimary = Color(0xFF2E7D32);
const Color kShaqatiDark = Color(0xFF1B5E20);
const Color kShaqatiAccent = Color(0xFFFFA000);
const Color kTextDark = Color(0xFF263238);
const Color kTextLight = Color(0xFF78909C);

const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [kShaqatiDark, kShaqatiPrimary],
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

  // --- Filter State ---
  String _searchQuery = "";
  String _selectedOperation = "All"; // All, Rent, Sale
  String _selectedType = "All"; // All, Apartment, Villa, etc.

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
          // Initially show all properties
          _displayedProperties = List.from(_allProperties);
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

  // --- 🔍 نظام الفلترة الذكي ---
  void _applyFilters() {
    setState(() {
      _displayedProperties = _allProperties.where((p) {
        // Data Preparation
        final title = p['title'].toString().toLowerCase().trim();
        final city = p['city'].toString().toLowerCase().trim();
        final address = p['address'].toString().toLowerCase().trim();
        final type = p['type'].toString().toLowerCase().trim();
        final operation = p['operation'].toString().toLowerCase().trim();

        // 1. Search Query
        final matchesSearch = _searchQuery.isEmpty ||
            title.contains(_searchQuery.toLowerCase()) ||
            city.contains(_searchQuery.toLowerCase()) ||
            address.contains(_searchQuery.toLowerCase());

        // 2. Operation Filter (Buy/Rent)
        bool matchesOperation = true;
        if (_selectedOperation != "All") {
          // Backend usually uses "sale" and "rent" lowercase
          String target = _selectedOperation.toLowerCase();
          if (target == "buy") target = "sale"; // Handle synonym
          matchesOperation = operation == target;
        }

        // 3. Type Filter
        bool matchesType = true;
        if (_selectedType != "All") {
          matchesType = type.contains(_selectedType.toLowerCase());
        }

        return matchesSearch && matchesOperation && matchesType;
      }).toList();
    });
  }

  // --- AI Handler ---
  void _handleAIAction(String command) {
    command = command.toLowerCase();
    String feedback = "Updating results...";
    setState(() {
      if (command.contains("rent")) _selectedOperation = "Rent";
      if (command.contains("buy") || command.contains("sale"))
        _selectedOperation = "Sale";
      if (command.contains("apartment")) _selectedType = "Apartment";
      if (command.contains("villa")) _selectedType = "Villa";
      if (command.contains("reset") || command.contains("all")) {
        _selectedOperation = "All";
        _selectedType = "All";
        _searchQuery = "";
      }
      _applyFilters();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(feedback),
      backgroundColor: kShaqatiPrimary,
      behavior: SnackBarBehavior.floating,
    ));
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
    if (_role == 'admin') {
      navigator.push(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
    } else if (_role == 'landlord') {
      navigator.push(
          MaterialPageRoute(builder: (_) => const LandlordDashboardScreen()));
    } else if (_role == 'tenant') {
      navigator.push(
          MaterialPageRoute(builder: (_) => const TenantDashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,

      // --- 1. Custom Responsive Navbar ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(85),
        child: _ShaqatiNavbar(
          isLoggedIn: _token != null,
          onLogin: () => Navigator.pushNamed(context, '/login')
              .then((_) => _loadUserData()),
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),

      drawer: _HomeDrawer(
          isLoggedIn: _token != null,
          userName: _userName,
          role: _role,
          onLogout: _logout,
          onDashboard: _navigateToDashboard),

      // --- 2. AI Floating Action Button ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
            context: context,
            builder: (context) => AIAssistantDialog(onAction: _handleAIAction)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              gradient: kPrimaryGradient,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: kShaqatiPrimary.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ]),
          child: const Row(children: [
            Icon(Icons.smart_toy_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text("Smart Assistant",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
          ]),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _fetchProperties,
        color: kShaqatiPrimary,
        child: CustomScrollView(
          slivers: [
            // --- 3. Hero Section with Smart Filter ---
            SliverToBoxAdapter(
              child: _ShaqatiHero(
                onSearchChanged: (val) {
                  _searchQuery = val;
                  _applyFilters();
                },
                onOperationChanged: (val) {
                  setState(() {
                    _selectedOperation = val;
                    _applyFilters();
                  });
                },
                onTypeChanged: (val) {
                  setState(() {
                    _selectedType = val;
                    _applyFilters();
                  });
                },
                selectedOperation: _selectedOperation,
                selectedType: _selectedType,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- 4. Section Title & Count ---
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Latest Listings",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: kTextDark)),
                    Text("${_displayedProperties.length} found",
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kShaqatiPrimary)),
                  ],
                ),
              ),
            ),

            // --- 5. Map Preview ---
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _MiniMapSection(properties: _displayedProperties),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // --- 6. Properties Grid ---
            _buildContent(),

            // --- 7. Footer ---
            const SliverToBoxAdapter(child: _ShaqatiFooter()),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SliverFillRemaining(
          child:
              Center(child: CircularProgressIndicator(color: kShaqatiPrimary)));
    }
    if (_errorMessage != null) {
      return SliverToBoxAdapter(
          child: Center(
              child: Text('Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red))));
    }
    if (_displayedProperties.isEmpty) {
      return const SliverToBoxAdapter(
          child: Padding(
              padding: EdgeInsets.all(60),
              child: Center(
                  child: Column(
                children: [
                  Icon(Icons.home_work_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('No properties found.',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  Text('Try changing filters.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ))));
    }
    return _PropertyGrid(properties: _displayedProperties);
  }
}

// ---------------------------------------------------------------------------
// 🟢 1. Navbar (Clean Green Theme)
// ---------------------------------------------------------------------------
class _ShaqatiNavbar extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onOpenDrawer;

  const _ShaqatiNavbar({
    required this.isLoggedIn,
    required this.onLogin,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      height: 85, // 👈👈 لازم هذا الرقم يطابق الرقم اللي فوق عشان يملأ المساحة
      alignment: Alignment.center, // 👈👈 هذا السطر مهم جداً للتوسيط العمودي
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: 24), // زدنا الـ padding الجانبي شوي
      child: SafeArea(
        child: Row(
          children: [
            // Logo
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      kPrimaryGradient.createShader(bounds),
                  child: const Icon(Icons.home_work_rounded,
                      color: Colors.white, size: 36), // كبرنا الأيقونة
                ),
                const SizedBox(width: 10),
                const Text("SHAQATI",
                    style: TextStyle(
                        color: kShaqatiDark,
                        fontSize: 28, // كبرنا الخط
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ],
            ),

            const Spacer(),

            // Desktop Links
            if (isDesktop) ...[
              _navLink("Buy"),
              _navLink("Rent"),
              _navLink("Sell"),
              _navLink("Services"),
              _navLink("Agents"),
              const SizedBox(width: 30),
            ],
// داخل _ShaqatiNavbar
// ... 

// ✅ شرط: إذا كان مسجلاً للدخول، نعرض أيقونة الرسائل
if (isLoggedIn) ...[
  IconButton(
    onPressed: () {
       Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
    },
    icon: const Icon(Icons.message_outlined, color: kShaqatiDark, size: 28),
    tooltip: "Messages",
  ),
  const SizedBox(width: 15),
],

// ... زر القائمة (Menu) أو تسجيل الدخول
            // Right Actions
            if (!isLoggedIn)
              Container(
                decoration: BoxDecoration(
                  gradient: kPrimaryGradient,
                  borderRadius: BorderRadius.circular(10), // حواف أنعم
                ),
                child: ElevatedButton(
                  onPressed: onLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20), // زر أكبر
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Sign In",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16)),
                ),
              )
            else
              IconButton(
                onPressed: onOpenDrawer,
                icon: const Icon(Icons.menu,
                    color: kShaqatiDark, size: 34), // أيقونة أكبر
              ),

            if (!isLoggedIn && !isDesktop) ...[
              const SizedBox(width: 15),
              IconButton(
                onPressed: onOpenDrawer,
                icon: const Icon(Icons.menu, color: kShaqatiDark, size: 34),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _navLink(String text) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16), // مسافة أكبر بين الروابط
      child: Text(text,
          style: const TextStyle(
            color: kTextDark,
            fontWeight: FontWeight.w700, // خط أسمك
            fontSize: 16, // خط أكبر
          )),
    );
  }
}

// ---------------------------------------------------------------------------
// 🟢 2. Hero Section & Smart Filter (Dynamic)
// ---------------------------------------------------------------------------
class _ShaqatiHero extends StatelessWidget {
  final Function(String) onSearchChanged;
  final Function(String) onOperationChanged;
  final Function(String) onTypeChanged;
  final String selectedOperation;
  final String selectedType;

  const _ShaqatiHero({
    required this.onSearchChanged,
    required this.onOperationChanged,
    required this.onTypeChanged,
    required this.selectedOperation,
    required this.selectedType,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 480,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image (Natural)
          Image.asset(
            'assets/images/hero_image.png',
            fit: BoxFit.cover,
          ),

          // 2. Light Dark Overlay (لتحسين قراءة النص فقط بدون لون أخضر)
          // إذا أردت الصورة كما هي تماماً بدون أي تعتيم، احذف هذا الكونتينر
          Container(
            color: Colors.black.withOpacity(0.2), // تعتيم أسود خفيف جداً
          ),

          // 3. Content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Find Your Perfect Home",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        // ظل للنص ليظهر بوضوح فوق الصورة الطبيعية
                        shadows: [
                          Shadow(
                              color: Colors.black54,
                              blurRadius: 15,
                              offset: Offset(0, 4))
                        ]),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Search properties for sale and rent in Palestine",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, // جعلنا اللون أبيض ناصع
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 2))
                        ]),
                  ),
                  const SizedBox(height: 30),

                  // --- Smart Search Card ---
                  Container(
                    width: 700,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 20,
                              offset: Offset(0, 10))
                        ]),
                    child: Column(
                      children: [
                        // Row 1: Search Input
                        TextField(
                          onChanged: onSearchChanged,
                          decoration: InputDecoration(
                            hintText: "Search by City, Address, or ID...",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon: const Icon(Icons.search,
                                color: kShaqatiPrimary),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 15, horizontal: 10),
                          ),
                        ),

                        const Divider(height: 1),

                        // Row 2: Filters (Operation & Type)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 10),
                          child: Row(
                            children: [
                              // Operation Toggle
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _FilterChip(
                                        label: "All",
                                        isSelected: selectedOperation == "All",
                                        onTap: () => onOperationChanged("All"),
                                      ),
                                      _FilterChip(
                                        label: "For Sale",
                                        isSelected: selectedOperation == "Sale",
                                        onTap: () => onOperationChanged("Sale"),
                                      ),
                                      _FilterChip(
                                        label: "For Rent",
                                        isSelected: selectedOperation == "Rent",
                                        onTap: () => onOperationChanged("Rent"),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Vertical Divider
                              Container(
                                  height: 20,
                                  width: 1,
                                  color: Colors.grey[300],
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 10)),

                              // Type Dropdown
                              PopupMenuButton<String>(
                                onSelected: onTypeChanged,
                                child: Row(
                                  children: [
                                    Text(
                                        selectedType == "All"
                                            ? "Property Type"
                                            : selectedType,
                                        style: const TextStyle(
                                            color: kTextDark,
                                            fontWeight: FontWeight.w600)),
                                    const Icon(Icons.arrow_drop_down,
                                        color: kShaqatiPrimary),
                                  ],
                                ),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                      value: "All", child: Text("All Types")),
                                  const PopupMenuItem(
                                      value: "Apartment",
                                      child: Text("Apartment")),
                                  const PopupMenuItem(
                                      value: "Villa", child: Text("Villa")),
                                  const PopupMenuItem(
                                      value: "Commercial",
                                      child: Text("Commercial")),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected
                ? kShaqatiPrimary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? kShaqatiPrimary : Colors.transparent,
            )),
        child: Text(
          label,
          style: TextStyle(
              color: isSelected ? kShaqatiPrimary : kTextLight,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🟢 3. Property Grid & Map & Footer
// ---------------------------------------------------------------------------

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
      alignment: Alignment.bottomCenter,
      children: [
        Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 10)
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                              width: 30,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                    color: kShaqatiPrimary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2)),
                                child: const Icon(Icons.home,
                                    color: Colors.white, size: 16),
                              ));
                        } catch (e) {
                          return const Marker(
                              point: LatLng(0, 0), child: SizedBox());
                        }
                      }).toList()),
                    ]))),
        Positioned(
          bottom: 16,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MapScreen(properties: properties))),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text("Explore on Map"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kShaqatiPrimary,
                elevation: 4,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30))),
          ),
        )
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
                childAspectRatio: 0.90), // Adjusted aspect ratio
            delegate: SliverChildBuilderDelegate((context, index) {
              final p = properties[index];
              final imageUrl = (p['images'] != null && p['images'].isNotEmpty)
                  ? p['images'][0]
                  : 'https://via.placeholder.com/300x200?text=No+Image';
              return Card(
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                            // Image Section
                            Expanded(
                                flex: 6,
                                child: Stack(fit: StackFit.expand, children: [
                                  Image.network(imageUrl, fit: BoxFit.cover),
                                  // Gradient Overlay at bottom of image
                                  Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 60,
                                        decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: [
                                              Colors.black.withOpacity(0.6),
                                              Colors.transparent
                                            ])),
                                      )),
                                  // Badges
                                  Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                              gradient: kPrimaryGradient,
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text(
                                              p['operation'] == 'rent'
                                                  ? "FOR RENT"
                                                  : "FOR SALE",
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10)))),
                                  Positioned(
                                      bottom: 10,
                                      right: 12,
                                      child: Text(
                                        "\$${p['price']}",
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            shadows: [
                                              Shadow(
                                                  color: Colors.black,
                                                  blurRadius: 4)
                                            ]),
                                      ))
                                ])),
                            // Details Section
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
                                                Text(p['title'] ?? 'Untitled',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                        color: kTextDark)),
                                                const SizedBox(height: 6),
                                                Row(children: [
                                                  const Icon(
                                                      Icons
                                                          .location_on_outlined,
                                                      size: 14,
                                                      color: kTextLight),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                      child: Text(
                                                          "${p['city']}, ${p['address']}",
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              fontSize: 13,
                                                              color:
                                                                  kTextLight)))
                                                ])
                                              ]),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              _InfoBadge(Icons.bed,
                                                  "${p['bedrooms']} Beds"),
                                              _InfoBadge(Icons.bathtub,
                                                  "${p['bathrooms']} Baths"),
                                              _InfoBadge(Icons.square_foot,
                                                  "${p['area']} m²"),
                                            ],
                                          )
                                        ])))
                          ])));
            }, childCount: properties.length)));
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBadge(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: kShaqatiPrimary),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: kTextDark)),
      ],
    );
  }
}

class _ShaqatiFooter extends StatelessWidget {
  const _ShaqatiFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.home_work_rounded, color: kShaqatiPrimary, size: 28),
              SizedBox(width: 8),
              Text("SHAQATI",
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: kShaqatiDark))
            ],
          ),
          const SizedBox(height: 20),
          const Text("Empowering your real estate journey in Palestine.",
              style: TextStyle(color: kTextLight, fontSize: 13)),
          const SizedBox(height: 10),
          const Text("Copyright © 2025 SHAQATI. All rights reserved.",
              style: TextStyle(color: kTextLight, fontSize: 12)),
        ],
      ),
    );
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
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text(isLoggedIn
                ? (role?.toUpperCase() ?? "TENANT")
                : "Welcome to SHAQATI"),
            currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(isLoggedIn ? Icons.person : Icons.person_outline,
                    color: kShaqatiPrimary, size: 40))),
        if (isLoggedIn)
          ListTile(
              leading:
                  const Icon(Icons.dashboard_customize, color: kShaqatiPrimary),
              title: const Text('My Dashboard'),
              onTap: () {
                Navigator.pop(context);
                onDashboard();
              }),
        if (!isLoggedIn)
          ListTile(
              leading: const Icon(Icons.login, color: kShaqatiPrimary),
              title: const Text('Login / Join'),
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
          "👋 Hi! I'm SHAQATI AI.\nTell me what you are looking for?\n\nExample: 'Find 2 bed apartments in Ramallah'"
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
            height: 450,
            child: Column(children: [
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                      gradient: kPrimaryGradient,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16))),
                  child: Row(children: [
                    const Icon(Icons.smart_toy, color: Colors.white),
                    const SizedBox(width: 10),
                    const Text("SHAQATI AI",
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
                                      : kShaqatiPrimary.withOpacity(0.1),
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
                                  color: kShaqatiPrimary),
                              onPressed: _sendMessage),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none))))
            ])));
  }
}
