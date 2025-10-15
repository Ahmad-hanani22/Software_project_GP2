import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/admin_dashboard_screen.dart';
import 'package:flutter_application_1/screens/landlord_dashboard_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

// ========= Dummy Data (مؤقتًا) =========
class Property {
  final String id;
  final String title;
  final String city;
  final int bedrooms;
  final int price; // USD/Month
  final String image;
  final String propertyType; // 'Ready', 'Off-Plan'
  final String residentialType; // 'Residential', 'Commercial', 'Land'

  Property({
    required this.id,
    required this.title,
    required this.city,
    required this.bedrooms,
    required this.price,
    required this.image,
    this.propertyType = 'Ready',
    this.residentialType = 'Residential',
  });
}

final _allCities = <String>['All', 'Nablus', 'Ramallah', 'Hebron', 'Jerusalem'];
final _allPropertyTypes = <String>['All', 'Ready', 'Off-Plan'];
final _allResidentialTypes = <String>[
  'All',
  'Residential',
  'Commercial',
  'Land',
];
final _allBedroomOptions = <int>[0, 1, 2, 3, 4, 5];
final _allPriceOptions = <double>[0, 500, 1000, 2000, 5000, 10000, 20000];

final _dummyProps = <Property>[
  Property(
    id: 'p1',
    title: 'Modern Apartment • City Center',
    city: 'Ramallah',
    bedrooms: 2,
    price: 650,
    image:
        'https://images.unsplash.com/photo-1501183638710-841dd1904471?q=80&w=1200',
    propertyType: 'Ready',
    residentialType: 'Residential',
  ),
  Property(
    id: 'p2',
    title: 'Cozy Studio • Near University',
    city: 'Nablus',
    bedrooms: 1,
    price: 350,
    image:
        'https://images.unsplash.com/photo-1505691938895-1758d7feb511?q=80&w=1200',
    propertyType: 'Off-Plan',
    residentialType: 'Residential',
  ),
  Property(
    id: 'p3',
    title: 'Spacious Family Flat',
    city: 'Hebron',
    bedrooms: 3,
    price: 800,
    image:
        'https://images.unsplash.com/photo-1494526585095-c41746248156?q=80&w=1200',
    propertyType: 'Ready',
    residentialType: 'Residential',
  ),
  Property(
    id: 'p4',
    title: 'Luxury Penthouse • Skyline View',
    city: 'Jerusalem',
    bedrooms: 4,
    price: 1900,
    image:
        'https://images.unsplash.com/photo-1502005229762-cf1b2da7c52f?q=80&w=1200',
    propertyType: 'Ready',
    residentialType: 'Commercial',
  ),
  Property(
    id: 'p5',
    title: 'Bright 2BR • Quiet Area',
    city: 'Ramallah',
    bedrooms: 2,
    price: 700,
    image:
        'https://images.unsplash.com/photo-1524758631624-e2822e304c36?q=80&w=1200',
    propertyType: 'Off-Plan',
    residentialType: 'Residential',
  ),
];

// ========= Home Page =========
class _HomePageState extends State<HomePage> {
  String? _token;
  String? _userRole;

  // Search & Filters
  final _searchCtrl = TextEditingController();
  bool _isBuying = true;
  String _propertyStatus = 'All';
  String _propertyCategory = 'Residential';
  String _cityFilter = 'All';
  int _minBedrooms = 0;
  RangeValues _priceRange = const RangeValues(0, 20000);

  List<Property> _results = List.of(_dummyProps);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _applyFilters();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('token');
      _userRole = prefs.getString('role');
    });
  }

  void _applyFilters() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _dummyProps.where((p) {
      final matchQuery =
          q.isEmpty ||
          p.title.toLowerCase().contains(q) ||
          p.city.toLowerCase().contains(q);
      final matchCity = _cityFilter == 'All' || p.city == _cityFilter;
      final matchBed = p.bedrooms >= _minBedrooms;
      final matchPrice =
          p.price >= _priceRange.start && p.price <= _priceRange.end;
      final matchPropertyStatus =
          _propertyStatus == 'All' || p.propertyType == _propertyStatus;
      final matchPropertyCategory =
          _propertyCategory == 'All' || p.residentialType == _propertyCategory;

      return matchQuery &&
          matchCity &&
          matchBed &&
          matchPrice &&
          matchPropertyStatus &&
          matchPropertyCategory;
    }).toList();

    setState(() => _results = filtered);
  }

  Future<void> _logout() async {
    await ApiService.logout();
    setState(() {
      _token = null;
      _userRole = null;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logged out successfully!')));
  }

  void _navigateToDashboard() {
    if (_userRole == 'admin') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else if (_userRole == 'landlord') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LandlordDashboardScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No specific dashboard for your role.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _HomeNavbar(
        isLoggedIn: _token != null,
        onLogin: () =>
            Navigator.pushNamed(context, '/login').then((_) => _loadUserData()),
        onRegister: () => Navigator.pushNamed(context, '/register'),
        onDashboard: _navigateToDashboard,
        onLogout: _logout,
      ),
      // ✅ الخلفية العامة للصفحة يمكن أن تكون شفافة الآن أو بيضاء
      backgroundColor: Colors.white,
      body: ListView(
        children: [
          _HeroSectionReimagined(
            searchCtrl: _searchCtrl,
            isBuying: _isBuying,
            onBuyRentToggle: (isBuy) {
              setState(() {
                _isBuying = isBuy;
                _applyFilters();
              });
            },
            propertyStatus: _propertyStatus,
            onPropertyStatusChanged: (v) {
              setState(() {
                _propertyStatus = v ?? 'All';
                _applyFilters();
              });
            },
            propertyCategory: _propertyCategory,
            onPropertyCategoryChanged: (v) {
              setState(() {
                _propertyCategory = v ?? 'Residential';
                _applyFilters();
              });
            },
            minBedrooms: _minBedrooms,
            onBedroomsChanged: (v) {
              _minBedrooms = v;
              _applyFilters();
            },
            priceRange: _priceRange,
            onPriceChanged: (rv) {
              _priceRange = rv;
              _applyFilters();
            },
            onSearch: _applyFilters,
          ),
          _PropertiesGrid(properties: _results),
          const _HomeFooter(),
        ],
      ),
    );
  }
}







// ========= Navbar - تصميم جديد ومحسّن =========
class _HomeNavbar extends StatelessWidget implements PreferredSizeWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onDashboard;
  final Future<void> Function() onLogout;

  const _HomeNavbar({
    super.key,
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
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: const [
          Text(
            'SHAQATI',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Color(0xFF2E7D32),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {},
          child: const Text(
            'Find my Agent',
            style: TextStyle(color: Colors.black87),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Sell My Property',
            style: TextStyle(color: Colors.black87),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'TruEstimate™',
            style: TextStyle(color: Colors.black87),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'Dubai Transactions',
            style: TextStyle(color: Colors.black87),
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'New Projects',
            style: TextStyle(color: Colors.black87),
          ),
        ),
        const SizedBox(width: 16),
        if (!isLoggedIn) ...[
          ElevatedButton.icon(
            onPressed: onLogin,
            icon: const Icon(Icons.person),
            label: const Text('Sign up or Log in'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ] else ...[
          IconButton(
            tooltip: 'Dashboard',
            onPressed: onDashboard,
            icon: const Icon(Icons.dashboard_outlined, color: Colors.black54),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Colors.black54),
          ),
        ],
        const SizedBox(width: 16),
      ],
    );
  }
}

// ========= Hero Section - تم إعادة تصميمها بالكامل مع صورة خلفية =========
class _HeroSectionReimagined extends StatefulWidget {
  final TextEditingController searchCtrl;
  final bool isBuying;
  final ValueChanged<bool> onBuyRentToggle;
  final String propertyStatus;
  final ValueChanged<String?> onPropertyStatusChanged;
  final String propertyCategory;
  final ValueChanged<String?> onPropertyCategoryChanged;
  final int minBedrooms;
  final ValueChanged<int> onBedroomsChanged;
  final RangeValues priceRange;
  final ValueChanged<RangeValues> onPriceChanged;
  final VoidCallback onSearch;

  const _HeroSectionReimagined({
    super.key,
    required this.searchCtrl,
    required this.isBuying,
    required this.onBuyRentToggle,
    required this.propertyStatus,
    required this.onPropertyStatusChanged,
    required this.propertyCategory,
    required this.onPropertyCategoryChanged,
    required this.minBedrooms,
    required this.onBedroomsChanged,
    required this.priceRange,
    required this.onPriceChanged,
    required this.onSearch,
  });

  @override
  State<_HeroSectionReimagined> createState() => _HeroSectionReimaginedState();
}

class _HeroSectionReimaginedState extends State<_HeroSectionReimagined> {
  final List<String> _propertyStatusOptions = ['All', 'Ready', 'Off-Plan'];
  final List<String> _propertyCategoryOptions = [
    'Residential',
    'Commercial',
    'Land',
  ];
  final List<int> _bedroomOptions = [0, 1, 2, 3, 4, 5];
  final List<double> _priceOptions = [
    0,
    2000,
    5000,
    10000,
    20000,
    50000,
    100000,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 600, // يمكن تعديل الارتفاع حسب الحاجة
      // ✅ إعادة إضافة الصورة كخلفية
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/hero_image.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
        ),
      ),

      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Real homes live here',
              style: theme.textTheme.displaySmall?.copyWith(
                // استخدام displaySmall ليكون أكبر
                fontWeight: FontWeight.bold,
                color: Colors.white, // لون أبيض ليتناسب مع الخلفية الداكنة
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 8),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Real Data. Real Brokers. Real Properties.',
              style: theme.textTheme.titleLarge?.copyWith(
                // استخدام titleLarge ليكون أكبر
                color: Colors.white.withOpacity(0.9), // لون أبيض مع شفافية
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 8),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _FilterActionButton(
                        label: 'Buy',
                        isSelected: widget.isBuying,
                        onPressed: () => widget.onBuyRentToggle(true),
                      ),
                      const SizedBox(width: 10),
                      _FilterActionButton(
                        label: 'Rent',
                        isSelected: !widget.isBuying,
                        onPressed: () => widget.onBuyRentToggle(false),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: widget.searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Enter location',
                            prefixIcon: const Icon(
                              Icons.location_on_outlined,
                              color: Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: widget.onSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.start,
                    children: [
                      _FilterChipWidget(
                        label: 'All',
                        isSelected: widget.propertyStatus == 'All',
                        onSelected: (selected) =>
                            widget.onPropertyStatusChanged('All'),
                      ),
                      _FilterChipWidget(
                        label: 'Ready',
                        isSelected: widget.propertyStatus == 'Ready',
                        onSelected: (selected) =>
                            widget.onPropertyStatusChanged('Ready'),
                      ),
                      _FilterChipWidget(
                        label: 'Off-Plan',
                        isSelected: widget.propertyStatus == 'Off-Plan',
                        onSelected: (selected) =>
                            widget.onPropertyStatusChanged('Off-Plan'),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: widget.propertyCategory,
                          decoration: _dropdownInputDecoration('Residential'),
                          items: _propertyCategoryOptions
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: widget.onPropertyCategoryChanged,
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<int>(
                          value: widget.minBedrooms,
                          decoration: _dropdownInputDecoration('Beds & Baths'),
                          items: _bedroomOptions
                              .map(
                                (b) => DropdownMenuItem<int>(
                                  value: b,
                                  child: Text(b == 0 ? 'Any' : '$b+'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => widget.onBedroomsChanged(v ?? 0),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<double>(
                          value: widget.priceRange.end == 0
                              ? _priceOptions.first
                              : widget.priceRange.end,
                          decoration: _dropdownInputDecoration('Price (AED)'),
                          items: _priceOptions
                              .map(
                                (p) => DropdownMenuItem<double>(
                                  value: p,
                                  child: Text(p == 0 ? 'Any' : '${p.toInt()}+'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => widget.onPriceChanged(
                            RangeValues(widget.priceRange.start, v ?? 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              constraints: const BoxConstraints(maxWidth: 800),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: const Color(0xFF2E7D32)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Want to find out more about UAE real estate using AI?',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('BayutGPT functionality coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_forward,
                      color: Color(0xFF2E7D32),
                    ),
                    label: const Text(
                      'Try BayutGPT',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey[50],
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: const TextStyle(color: Colors.grey),
    );
  }
}

// ويدجت زر التصفية (Buy/Rent)
class _FilterActionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _FilterActionButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? const Color(0xFF2E7D32)
            : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isSelected
              ? BorderSide.none
              : BorderSide(color: Colors.grey[400]!, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}

// ويدجت Filter Chip (All, Ready, Off-Plan)
class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _FilterChipWidget({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: const Color(0xFFD4EDDA),
      backgroundColor: Colors.grey[50],
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF2E7D32) : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: isSelected
          ? BorderSide.none
          : BorderSide(color: Colors.grey[400]!, width: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

// ========= Properties Grid =========
class _PropertiesGrid extends StatelessWidget {
  final List<Property> properties;
  const _PropertiesGrid({super.key, required this.properties});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        int cross = 1;
        if (w >= 1200) {
          cross = 4;
        } else if (w >= 900) {
          cross = 3;
        } else if (w >= 600) {
          cross = 2;
        }

        if (properties.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No results found')),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: properties.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3 / 2,
            ),
            itemBuilder: (context, i) => _PropertyCard(p: properties[i]),
          ),
        );
      },
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Property p;
  const _PropertyCard({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      elevation: 1,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Open details for: ${p.title}')),
          );
        },
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(p.image, fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '\$${p.price}/mo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      Text(p.city),
                      const SizedBox(width: 12),
                      const Icon(Icons.bed_outlined, size: 16),
                      Text('${p.bedrooms}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========= Footer =========
class _HomeFooter extends StatelessWidget {
  const _HomeFooter({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      child: Column(
        children: const [
          Divider(),
          SizedBox(height: 8),
          Text(
            '© 2025 SHAQATI Real Estate — About • Contact • FAQ',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
