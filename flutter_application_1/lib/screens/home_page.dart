import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/admin_dashboard_screen.dart';
import 'package:flutter_application_1/screens/landlord_dashboard_screen.dart';
import 'package:flutter_application_1/screens/tenant_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/screens/property_details_screen.dart';
import 'package:flutter_application_1/screens/map_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'service_pages.dart';
import 'lifestyle_screen.dart';
import 'chat_list_screen.dart';
import 'package:flutter_application_1/screens/chat_screen.dart';
import 'tenant_contracts_screen.dart';
import 'tenant_payments_screen.dart';
import 'tenant_maintenance_screen.dart';
import 'my_home_screen.dart';
import 'buy_screen.dart';
import 'sell_screen.dart';
import 'rent_screen.dart';
import 'deposits_management_screen.dart';
import 'expenses_management_screen.dart' hide Container;
import 'buildings_management_screen.dart';
import 'properties_by_type_screen.dart';
import 'all_properties_screen.dart';
import 'package:flutter_application_1/screens/occupancy_history_screen.dart';
import 'package:flutter_application_1/screens/property_selection_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/widgets/floating_smart_button.dart';

Future<void> _launchExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Could not launch $url');
  }
}

// ---------------------------------------------------------------------------
// 🎨 THEME COLORS
// ---------------------------------------------------------------------------
const Color kShaqatiPrimary = Color(0xFF2E7D32); // Green 800
const Color kShaqatiDark = Color(0xFF1B5E20); // Green 900
const Color kShaqatiAccent = Color(0xFFFFA000); // Amber 700
const Color kTextDark = Color(0xFF263238); // BlueGrey 900
const Color kTextLight = Color(0xFF78909C); // BlueGrey 400

const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [kShaqatiDark, kShaqatiPrimary],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ---------------------------------------------------------------------------
// 🧠 SHAQATI AI BRAIN (Enhanced Intelligent Logic Core)
// ---------------------------------------------------------------------------
class ShaqatiAIBrain {
  // قاعدة المعرفة الموسعة "المدربة" (محاكاة لبيانات ضخمة ومعرفة بالسوق الفلسطيني)
  static final Map<String, String> _knowledgeBase = {
    "invest_advice":
        "For investment, I recommend looking at 2-bedroom apartments near universities in Nablus (Rafidia) or city centers in Ramallah. They have the highest rental yield (approx 5-7% annually).",
    "market_trend":
        "Currently, the market in Palestine is seeing a high demand for rentals due to university seasons. Buying prices are stable.",
    "contract_info":
        "Standard rental contracts are usually for 12 months. Make sure to check if utility bills are included in the rent.",
    "nablus":
        "Nablus is excellent for student housing investments, especially near An-Najah University. Prices are generally lower than Ramallah. Average rent: 200-400 USD/month for apartments.",
    "ramallah":
        "Ramallah is the economic hub. Prices are higher, but appreciation value is the best in the country. Look for properties in Al-Masyoun or Al-Tireh. Average rent: 400-800 USD/month.",
    "hebron":
        "Hebron has a strong family-oriented market. Large villas and spacious apartments are in high demand. Average rent: 250-500 USD/month.",
    "jenin":
        "Jenin is growing rapidly. It's a hidden gem for affordable land and residential investment. Average rent: 150-350 USD/month.",
    "fees":
        "Usually, there is a brokerage fee of 2% to 5% depending on the deal type (Sale/Rent).",
    "price_ranges":
        "In Palestine, rental prices typically range from 150-800 USD/month depending on location and property type. Sale prices range from 30,000-500,000 USD.",
  };

  // استخراج السعر من النص (Price Extraction)
  static Map<String, dynamic>? _extractPriceRange(String input) {
    // البحث عن أرقام في النص
    final priceRegex = RegExp(
        r'(\d+)\s*(?:usd|dollar|dollars|nis|shekel|shekels|₪|\$)?',
        caseSensitive: false);
    final matches = priceRegex.allMatches(input);

    if (matches.isEmpty) {
      // البحث عن كلمات وصفية للسعر
      if (input.contains('cheap') ||
          input.contains('low') ||
          input.contains('affordable') ||
          input.contains('رخيص') ||
          input.contains('رخيصة') ||
          input.contains('ز cheap')) {
        return {'min': 0, 'max': 300, 'type': 'rent'};
      }
      if (input.contains('expensive') ||
          input.contains('high') ||
          input.contains('luxury') ||
          input.contains('غالي') ||
          input.contains('غالية')) {
        return {'min': 500, 'max': 10000, 'type': 'rent'};
      }
      if (input.contains('medium') ||
          input.contains('average') ||
          input.contains('moderate') ||
          input.contains('متوسط') ||
          input.contains('متوسطة')) {
        return {'min': 300, 'max': 600, 'type': 'rent'};
      }
      return null;
    }

    List<int> prices = [];
    for (var match in matches) {
      final price = int.tryParse(match.group(1) ?? '');
      if (price != null && price > 0) prices.add(price);
    }

    if (prices.isEmpty) return null;

    // تحديد نوع العملية (بيع/إيجار) بناءً على السياق
    String operationType = 'rent';
    if (input.contains('buy') ||
        input.contains('sale') ||
        input.contains('purchase')) {
      operationType = 'sale';
    }

    if (prices.length == 1) {
      // سعر واحد - نستخدمه كحد أقصى
      return {'min': 0, 'max': prices[0], 'type': operationType};
    } else {
      // سعران - نستخدمهما كمدى
      prices.sort();
      return {'min': prices[0], 'max': prices[1], 'type': operationType};
    }
  }

  // اقتراحات ذكية للشقق (Smart Property Suggestions)
  static List<dynamic> _getSmartSuggestions(
    List<dynamic> properties, {
    String? city,
    String? type,
    String? operation,
    int? maxPrice,
    int? minPrice,
  }) {
    List<dynamic> filtered = properties;

    // فلترة حسب المدينة
    if (city != null) {
      filtered = filtered
          .where((p) =>
              p['city']
                  ?.toString()
                  .toLowerCase()
                  .contains(city.toLowerCase()) ??
              false)
          .toList();
    }

    // فلترة حسب النوع
    if (type != null) {
      filtered = filtered
          .where((p) =>
              p['type']
                  ?.toString()
                  .toLowerCase()
                  .contains(type.toLowerCase()) ??
              false)
          .toList();
    }

    // فلترة حسب العملية
    if (operation != null) {
      filtered = filtered
          .where((p) =>
              p['operation']?.toString().toLowerCase() ==
              operation.toLowerCase())
          .toList();
    }

    // فلترة حسب السعر
    if (minPrice != null || maxPrice != null) {
      filtered = filtered.where((p) {
        final price = (p['price'] as num?)?.toInt() ?? 0;
        if (minPrice != null && price < minPrice) return false;
        if (maxPrice != null && price > maxPrice) return false;
        return true;
      }).toList();
    }

    // ترتيب حسب السعر (الأقل أولاً)
    filtered.sort((a, b) {
      final priceA = (a['price'] as num?)?.toInt() ?? 0;
      final priceB = (b['price'] as num?)?.toInt() ?? 0;
      return priceA.compareTo(priceB);
    });

    return filtered.take(10).toList(); // أفضل 10 اقتراحات
  }

  // تحليل نية المستخدم المحسّن (Enhanced Intent Recognition)
  static Map<String, dynamic> processQuery(
      String input, List<dynamic> properties,
      {List<Map<String, dynamic>>? conversationHistory}) {
    input = input.toLowerCase();

    // 1. طلبات فتح الخريطة (Navigation Intent)
    if (input.contains("map") ||
        input.contains("location") ||
        input.contains("where")) {
      return {
        "type": "action_map",
        "response":
            "🌍 Opening the interactive map for you. You can see all available properties based on their location.",
      };
    }

    // 2. طلبات نصيحة أو رأي (Consultation Intent)
    if (input.contains("think") ||
        input.contains("advice") ||
        input.contains("suggest") ||
        input.contains("invest") ||
        input.contains("good")) {
      String advice = _knowledgeBase['invest_advice']!;
      if (input.contains("nablus")) advice = _knowledgeBase['nablus']!;
      if (input.contains("ramallah")) advice = _knowledgeBase['ramallah']!;
      if (input.contains("hebron")) advice = _knowledgeBase['hebron']!;

      return {
        "type": "chat",
        "response":
            "💡 Here is my expert advice:\n$advice\n\nWould you like to see listing specifically for this?",
      };
    }

    // 3. محادثة عامة (General Chat)
    if (input.contains("hello") ||
        input.contains("hi") ||
        input.contains("salam")) {
      return {
        "type": "chat",
        "response":
            "👋 Hello! I am Shaqati AI, your real estate expert in Palestine. \nI can help you buy, rent, or analyze market trends. Try asking: 'Find me a villa in Nablus' or 'Is it good to invest in Ramallah?'",
      };
    }

    // 4. البحث المتقدم المحسّن (Enhanced Advanced Filter Logic)
    // استخراج المدينة
    String? detectedCity;
    final cityKeywords = {
      "nablus": "Nablus",
      "ramallah": "Ramallah",
      "hebron": "Hebron",
      "jenin": "Jenin",
      "gaza": "Gaza",
      "bethlehem": "Bethlehem",
      "jerusalem": "Jerusalem",
      "tulkarm": "Tulkarm",
      "qalqilya": "Qalqilya",
      "salfit": "Salfit",
      "tubas": "Tubas",
    };
    for (var entry in cityKeywords.entries) {
      if (input.contains(entry.key)) {
        detectedCity = entry.value;
        break;
      }
    }

    // استخراج العملية
    String? operation;
    if (input.contains("rent") ||
        input.contains("rental") ||
        input.contains("إيجار")) {
      operation = "rent";
    }
    if (input.contains("buy") ||
        input.contains("sale") ||
        input.contains("purchase") ||
        input.contains("شراء") ||
        input.contains("بيع")) {
      operation = "sale";
    }

    // استخراج النوع
    String? type;
    if (input.contains("apartment") ||
        input.contains("شقة") ||
        input.contains("شقق")) {
      type = "Apartment";
    }
    if (input.contains("villa") ||
        input.contains("فيلا") ||
        input.contains("فيلات")) {
      type = "Villa";
    }
    if (input.contains("office") ||
        input.contains("commercial") ||
        input.contains("مكتب") ||
        input.contains("تجاري")) {
      type = "Commercial";
    }
    if (input.contains("land") ||
        input.contains("أرض") ||
        input.contains("أراضي")) {
      type = "Land";
    }
    if (input.contains("house") ||
        input.contains("منزل") ||
        input.contains("بيت")) {
      type = "House";
    }

    // استخراج السعر (Price Extraction)
    final priceRange = _extractPriceRange(input);
    int? minPrice = priceRange?['min'] as int?;
    int? maxPrice = priceRange?['max'] as int?;
    String? priceType = priceRange?['type'] as String?;

    // إذا تم تحديد نوع سعر، نستخدمه كعملية
    if (priceType != null && operation == null) {
      operation = priceType;
    }

    // طلبات الاقتراحات الذكية (Smart Suggestions)
    if (input.contains("suggest") ||
        input.contains("recommend") ||
        input.contains("best") ||
        input.contains("اقترح") ||
        input.contains("أنصح") ||
        input.contains("أفضل")) {
      final suggestions = _getSmartSuggestions(
        properties,
        city: detectedCity,
        type: type,
        operation: operation,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );

      if (suggestions.isEmpty) {
        return {
          "type": "chat",
          "response":
              "😔 I couldn't find properties matching your criteria. Try adjusting your budget or location preferences, and I'll help you find something perfect!",
        };
      }

      String responseText =
          "✨ I found ${suggestions.length} great properties for you!\n\n";
      responseText += "Here are my top recommendations:\n\n";

      final topSuggestions = suggestions.take(3).toList();
      for (int i = 0; i < topSuggestions.length; i++) {
        final p = topSuggestions[i];
        final price = p['price'] ?? 'N/A';
        final city = p['city'] ?? 'Unknown';
        final title = p['title'] ?? 'Property';
        responseText += "${i + 1}. $title in $city - \$$price\n";
      }

      if (suggestions.length > 3) {
        responseText +=
            "\n... and ${suggestions.length - 3} more! Check them out below 👇";
      }

      return {
        "type": "filter_action",
        "response": responseText,
        "filter": {
          "city": detectedCity,
          "operation": operation == "sale"
              ? "Sale"
              : (operation == "rent" ? "Rent" : null),
          "type": type,
          "minPrice": minPrice,
          "maxPrice": maxPrice,
        },
        "suggestions": suggestions,
      };
    }

    // تنفيذ المنطق إذا تم اكتشاف أي معيار للبحث
    if (detectedCity != null ||
        operation != null ||
        type != null ||
        minPrice != null ||
        maxPrice != null ||
        input.contains("all") ||
        input.contains("reset") ||
        input.contains("find") ||
        input.contains("search") ||
        input.contains("show") ||
        input.contains("أبحث") ||
        input.contains("أعرض") ||
        input.contains("دور")) {
      // حالة إعادة التعيين
      if (input.contains("reset") ||
          input.contains("clear") ||
          input.contains("show all") ||
          input.contains("أعد") ||
          input.contains("امسح")) {
        return {
          "type": "filter_action",
          "response":
              "🔄 I have reset all filters. Showing you all properties in Palestine.",
          "filter": {"reset": true}
        };
      }

      // فلترة وعد النتائج
      final filtered = _getSmartSuggestions(
        properties,
        city: detectedCity,
        type: type,
        operation: operation,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );

      int count = filtered.length;

      // بناء رد ذكي وطبيعي
      String responseText = "";
      if (count == 0) {
        responseText =
            "😔 I couldn't find any properties matching your criteria.";
        if (maxPrice != null) {
          responseText +=
              " Try increasing your budget a bit, or check other cities.";
        } else {
          responseText += " Would you like me to suggest similar properties?";
        }
      } else {
        responseText =
            "✅ Great! I found $count propert${count == 1 ? 'y' : 'ies'}";
        if (detectedCity != null) responseText += " in $detectedCity";
        if (operation != null) {
          responseText += " for ${operation == 'rent' ? 'rent' : 'sale'}";
        }
        if (maxPrice != null) {
          responseText += " under \$${maxPrice}";
        }
        if (minPrice != null && maxPrice == null) {
          responseText += " above \$${minPrice}";
        }
        responseText += ".\n\nI've updated the list for you! 🏠";
      }

      return {
        "type": "filter_action",
        "response": responseText,
        "filter": {
          "city": detectedCity,
          "operation": operation == "sale"
              ? "Sale"
              : (operation == "rent" ? "Rent" : null),
          "type": type,
          "minPrice": minPrice,
          "maxPrice": maxPrice,
        }
      };
    }

    // 5. ردود طبيعية أكثر (More Natural Responses)
    if (input.contains("thank") ||
        input.contains("thanks") ||
        input.contains("شكر")) {
      return {
        "type": "chat",
        "response":
            "😊 You're very welcome! I'm here to help you find your perfect home. Anything else you'd like to know?",
      };
    }

    if (input.contains("help") ||
        input.contains("مساعدة") ||
        input.contains("مساعده")) {
      return {
        "type": "chat",
        "response":
            "🤝 I can help you:\n• Find properties by city, type, or price\n• Get investment advice\n• Search on the map\n• Get smart recommendations\n\nTry: 'Find me a cheap apartment in Nablus' or 'Suggest properties under 300 dollars'",
      };
    }

    if (input.contains("price") ||
        input.contains("cost") ||
        input.contains("سعر") ||
        input.contains("تكلفة")) {
      return {
        "type": "chat",
        "response":
            "💰 Prices vary by location and property type:\n• Nablus: 200-400 USD/month (rent)\n• Ramallah: 400-800 USD/month (rent)\n• Hebron: 250-500 USD/month (rent)\n\nTell me your budget and I'll find the perfect match!",
      };
    }

    // 6. الرد الافتراضي المحسّن (Enhanced Fallback)
    return {
      "type": "chat",
      "response":
          "🤔 I'd love to help! You can ask me:\n• 'Find apartments in Nablus under 300 dollars'\n• 'Suggest cheap properties'\n• 'Show me villas for sale'\n• 'Open the map'\n\nWhat are you looking for?",
    };
  }
}

// ---------------------------------------------------------------------------
// 🏠 MAIN HOME PAGE
// ---------------------------------------------------------------------------
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
  int? _minPrice;
  int? _maxPrice;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _listingsKey = GlobalKey();
  final GlobalKey _servicesKey = GlobalKey();
  final GlobalKey _tenantToolsKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();
  final GlobalKey _helpKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

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
          // Show all properties (available, rented, pending_approval)
          // Rented/purchased properties will be marked with status badges
          _allProperties = data as List<dynamic>;
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

  // --- 🔍 Core Filtering Logic (Enhanced with Price) ---
  void _applyFilters() {
    setState(() {
      _displayedProperties = _allProperties.where((p) {
        // Data Preparation
        final title = p['title'].toString().toLowerCase().trim();
        final city = p['city'].toString().toLowerCase().trim();
        final address = p['address'].toString().toLowerCase().trim();
        final type = p['type'].toString().toLowerCase().trim();
        final operation = p['operation'].toString().toLowerCase().trim();
        final price = (p['price'] as num?)?.toInt() ?? 0;

        // 1. Search Query
        final matchesSearch = _searchQuery.isEmpty ||
            title.contains(_searchQuery.toLowerCase()) ||
            city.contains(_searchQuery.toLowerCase()) ||
            address.contains(_searchQuery.toLowerCase());

        // 2. Operation Filter (Buy/Rent)
        bool matchesOperation = true;
        if (_selectedOperation != "All") {
          String target = _selectedOperation.toLowerCase();
          if (target == "buy") target = "sale";
          matchesOperation = operation == target;
        }

        // 3. Type Filter
        bool matchesType = true;
        if (_selectedType != "All") {
          matchesType = type.contains(_selectedType.toLowerCase());
        }

        // 4. Price Filter
        bool matchesPrice = true;
        if (_minPrice != null && price < _minPrice!) matchesPrice = false;
        if (_maxPrice != null && price > _maxPrice!) matchesPrice = false;

        return matchesSearch && matchesOperation && matchesType && matchesPrice;
      }).toList();
    });
  }

  // --- 🤖 AI Action Handler (Enhanced with Price Support) ---
  void _handleAIAction(Map<String, dynamic> aiResult) {
    // CASE 1: Filter Action
    if (aiResult['type'] == 'filter_action') {
      final filters = aiResult['filter'];

      if (filters['reset'] == true) {
        setState(() {
          _selectedOperation = "All";
          _selectedType = "All";
          _searchQuery = "";
          _minPrice = null;
          _maxPrice = null;
          _applyFilters();
        });
      } else {
        setState(() {
          if (filters['operation'] != null)
            _selectedOperation = filters['operation'];
          if (filters['type'] != null) _selectedType = filters['type'];
          // If city is mentioned, we put it in search query
          if (filters['city'] != null) _searchQuery = filters['city'];
          // Price filters
          if (filters['minPrice'] != null)
            _minPrice = filters['minPrice'] as int?;
          if (filters['maxPrice'] != null)
            _maxPrice = filters['maxPrice'] as int?;

          _applyFilters();
        });
      }
    }

    // CASE 2: Map Action
    if (aiResult['type'] == 'action_map') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MapScreen(properties: _displayedProperties)));
    }
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

  Future<void> _scrollTo(GlobalKey key) async {
    final context = key.currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1);
    }
  }

  void _openTenantContracts() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const TenantContractsScreen()));
  }

  void _openTenantPayments() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const TenantPaymentsScreen()));
  }

  void _openTenantMaintenance() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const TenantMaintenanceScreen()));
  }

  void _openTenantDeposits() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const DepositsManagementScreen()));
  }

  void _openTenantExpenses() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ExpensesManagementScreen()));
  }

  void _openBuildings() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const BuildingsManagementScreen()));
  }

  void _openOccupancyHistory() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const OccupancyHistoryScreen()));
  }

  void _openOwnership() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PropertySelectionScreen(screenType: 'ownership'),
      ),
    );
  }

  void _openUnits() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PropertySelectionScreen(screenType: 'units'),
      ),
    );
  }

  void _openPropertyHistory() {
    if (_token == null) {
      Navigator.pushNamed(context, '/login').then((_) => _loadUserData());
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PropertySelectionScreen(screenType: 'history'),
      ),
    );
  }

  void _openHelpCenter() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
  }

  void _openContact() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ContactUsScreen()));
  }

  void _openServices() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const LifestyleScreen()));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,

      // --- Navbar ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: _ShaqatiNavbar(
          isLoggedIn: _token != null,
          onLogin: () => Navigator.pushNamed(context, '/login')
              .then((_) => _loadUserData()),
          onSignUp: () => Navigator.pushNamed(context, '/register')
              .then((_) => _loadUserData()),
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onListings: () => _scrollTo(_listingsKey),
          onServices: () => _scrollTo(_servicesKey),
          onContracts: _openTenantContracts,
          onPayments: _openTenantPayments,
          onMaintenance: _openTenantMaintenance,
          onDeposits: _openTenantDeposits,
          onExpenses: _openTenantExpenses,
          onBuildings: _openBuildings,
          onOccupancyHistory: _openOccupancyHistory,
          onOwnership: _openOwnership,
          onUnits: _openUnits,
          onPropertyHistory: _openPropertyHistory,
          onContact: () => _scrollTo(_contactKey),
          onHelp: () => _scrollTo(_helpKey),
          onDashboard: _navigateToDashboard,
          onBuy: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const BuyScreen())),
          onSell: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const SellScreen())),
          onRent: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const RentScreen())),
          onMyHome: () {
            if (_token == null) {
              Navigator.pushNamed(context, '/login')
                  .then((_) => _loadUserData());
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyHomeScreen()));
            }
          },
          onFindAgent: () => _scrollTo(_contactKey),
          onNews: () => _scrollTo(_servicesKey),
          onRefresh: _fetchProperties,
        ),
      ),

      drawer: _HomeDrawer(
          isLoggedIn: _token != null,
          userName: _userName,
          role: _role,
          onLogout: _logout,
          onDashboard: _navigateToDashboard),

      // --- 🧠 النظام الذكي FAB ---
      floatingActionButton: const FloatingSmartButton(),

      body: RefreshIndicator(
        onRefresh: _fetchProperties,
        color: kShaqatiPrimary,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // --- Hero Section ---
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

            // --- Smart Suggestions Section ---
            SliverToBoxAdapter(
              child: _SmartSuggestionsSection(
                properties: _allProperties,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Tenant Quick Tools ---
            SliverToBoxAdapter(
              key: _tenantToolsKey,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Tenant Dashboard Shortcuts",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: kTextDark)),
                      const SizedBox(height: 6),
                      const Text(
                          "Access your essentials directly from the homepage.",
                          style: TextStyle(color: kTextLight)),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          _QuickActionCard(
                            icon: Icons.description_outlined,
                            title: "Contracts",
                            subtitle: "View and download active leases",
                            color: kShaqatiPrimary,
                            onTap: _openTenantContracts,
                          ),
                          _QuickActionCard(
                            icon: Icons.credit_card,
                            title: "Payments",
                            subtitle: "Track dues and history",
                            color: kShaqatiAccent,
                            onTap: _openTenantPayments,
                          ),
                          _QuickActionCard(
                            icon: Icons.build_circle_outlined,
                            title: "Maintenance",
                            subtitle: "Submit and follow requests",
                            color: Colors.purple,
                            onTap: _openTenantMaintenance,
                          ),
                          _QuickActionCard(
                            icon: Icons.support_agent,
                            title: "Help Center",
                            subtitle: "Guides and FAQs",
                            color: Colors.indigo,
                            onTap: _openHelpCenter,
                          ),
                          _QuickActionCard(
                            icon: Icons.chat_bubble_outline,
                            title: "Contact Us",
                            subtitle: "Reach our support team",
                            color: Colors.teal,
                            onTap: _openContact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Browse Properties by Type ---
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Browse Properties",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PropertyTypeGrid(
                      properties: _allProperties,
                      onTypeTap: (type, displayName) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PropertiesByTypeScreen(
                              propertyType: type,
                              displayName: displayName,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Title & Count ---
            SliverToBoxAdapter(
              key: _listingsKey,
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

            // --- Mini Map ---
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: _MiniMapSection(properties: _displayedProperties),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // --- Grid ---
            _buildContent(),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Featured Properties ---
            SliverToBoxAdapter(
              child: _FeaturedPropertiesSection(properties: _allProperties),
            ),

            // --- Helpful Tools & Resources ---
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner
                    const SizedBox(height: 24),
                    // Title
                    const Text(
                      "Discover how we can help",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: "Buying",
                            isActive: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const BuyScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: "Renting",
                            isActive: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RentScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: "Services",
                            isActive: false,
                            onTap: _openServices,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Help Cards
                    _HelpfulToolsGrid(),
                    const SizedBox(height: 40),
                    // Recommended Neighborhoods
                    _RecommendedNeighborhoods(properties: _allProperties),
                    const SizedBox(height: 40),
                    // Cities/Neighborhoods Section
                    _CitiesSection(properties: _allProperties),
                    const SizedBox(height: 40),
                    // Investment Tips Section
                    _InvestmentTipsSection(),
                    const SizedBox(height: 40),
                    // News & Insights
                    _NewsInsightsSection(),
                    const SizedBox(height: 40),
                    // Local Info & Pre-Approval Section
                    _LocalInfoAndPreApprovalSection(),
                    const SizedBox(height: 50),
                    // Promotional Banner Section
                    _PromotionalBannerSection(),
                  ],
                ),
              ),
            ),

            // --- Services & Lifestyle ---
            SliverToBoxAdapter(
              key: _servicesKey,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF7FDF7),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: kShaqatiPrimary.withOpacity(0.2))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Lifestyle & Services",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: kShaqatiDark)),
                            SizedBox(height: 8),
                            Text(
                                "Book cleaning, moving, tourism experiences, or premium add-ons in one place.",
                                style: TextStyle(color: kTextLight)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _openServices,
                        icon: const Icon(Icons.explore_outlined,
                            color: Colors.white),
                        label: const Text("Explore Services"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kShaqatiPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Testimonials Section ---
            SliverToBoxAdapter(
              child: _TestimonialsSection(),
            ),

            // --- Help & Support ---
            SliverToBoxAdapter(
              key: _helpKey,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]),
                  child: Row(
                    children: [
                      const Icon(Icons.support_agent,
                          color: kShaqatiPrimary, size: 30),
                      const SizedBox(width: 14),
                      const Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Need help?",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: kTextDark)),
                          SizedBox(height: 4),
                          Text(
                              "Visit our Help Center for FAQs, guides, and policies tailored for tenants.",
                              style: TextStyle(color: kTextLight)),
                        ],
                      )),
                      OutlinedButton.icon(
                        onPressed: _openHelpCenter,
                        icon:
                            const Icon(Icons.open_in_new, color: kShaqatiDark),
                        label: const Text("Help Center",
                            style: TextStyle(color: kShaqatiDark)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kShaqatiPrimary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Video Section ---
            SliverToBoxAdapter(
              child: _VideoSection(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- FAQ Section ---
            SliverToBoxAdapter(
              child: _FAQSection(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Latest News/Blog Section ---
            SliverToBoxAdapter(
              child: _LatestNewsSection(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Partners/Agents Section ---
            SliverToBoxAdapter(
              child: _PartnersSection(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),

            // --- Contact & Social ---
            SliverToBoxAdapter(
              key: _contactKey,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Contact & Social",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: kTextDark)),
                      const SizedBox(height: 8),
                      const Text(
                          "We are here 24/7. Reach us anytime or follow our updates.",
                          style: TextStyle(color: kTextLight)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ContactCard(
                            icon: Icons.phone,
                            title: "Call Us",
                            subtitle: "+970 599 123 456",
                            onTap: () =>
                                _launchExternalUrl("tel:+970599123456"),
                          ),
                          _ContactCard(
                            icon: Icons.email_outlined,
                            title: "Email",
                            subtitle: "support@shaqati.com",
                            onTap: () => _launchExternalUrl(
                                "mailto:support@shaqati.com"),
                          ),
                          _ContactCard(
                            icon: Icons.location_on_outlined,
                            title: "Location",
                            subtitle: "Nablus, Palestine",
                            onTap: () => _launchExternalUrl(
                                "https://maps.google.com/?q=Nablus"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text("Follow us:",
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark)),
                          const SizedBox(width: 10),
                          IconButton(
                              tooltip: "Facebook",
                              onPressed: () => _launchExternalUrl(
                                  "https://www.facebook.com"),
                              icon: const Icon(Icons.facebook,
                                  color: kShaqatiPrimary)),
                          IconButton(
                              tooltip: "Instagram",
                              onPressed: () => _launchExternalUrl(
                                  "https://www.instagram.com"),
                              icon: const Icon(Icons.camera_alt_outlined,
                                  color: Colors.pink)),
                          IconButton(
                              tooltip: "WhatsApp",
                              onPressed: () => _launchExternalUrl(
                                  "https://wa.me/970599123456"),
                              icon: const Icon(Icons.chat_rounded,
                                  color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _openContact,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kShaqatiPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 14)),
                        child: const Text("Open Contact Page"),
                      )
                    ],
                  ),
                ),
              ),
            ),

            // --- Footer ---
            SliverToBoxAdapter(
                child: _ShaqatiFooter(
              onListings: () => _scrollTo(_listingsKey),
              onServices: () => _scrollTo(_servicesKey),
              onContact: () => _scrollTo(_contactKey),
              onHelp: () => _scrollTo(_helpKey),
              onContracts: _openTenantContracts,
              onPayments: _openTenantPayments,
              onMaintenance: _openTenantMaintenance,
            )),
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
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _fetchProperties,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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
                  Text('Try asking the AI Assistant!',
                      style: TextStyle(color: kShaqatiPrimary)),
                ],
              ))));
    }
    return _PropertyGrid(properties: _displayedProperties);
  }
}

// ---------------------------------------------------------------------------
// 💬 AI DIALOG INTERFACE (The Chat UI)
// ---------------------------------------------------------------------------
class AIAssistantDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAction;
  final List<dynamic> availableProperties;

  const AIAssistantDialog(
      {super.key, required this.onAction, required this.availableProperties});

  @override
  State<AIAssistantDialog> createState() => _AIAssistantDialogState();
}

class _AIAssistantDialogState extends State<AIAssistantDialog> {
  final List<Map<String, dynamic>> _messages = [
    {
      "role": "ai",
      "text":
          "🤖 Hello! I'm Shaqati AI.\nI am trained on the Palestinian market.\n\nAsk me anything! Examples:\n• 'Find a cheap apartment in Nablus'\n• 'Is Ramallah good for investment?'\n• 'Show me the map'\n\n💬 You can also talk to me using voice!"
    }
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  // 🎤 Voice Recognition & Speech
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _spokenText = "";

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  Future<void> _initializeVoice() async {
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();

    // Initialize Speech to Text
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (error) {
        debugPrint('Speech recognition error: $error');
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );

    if (!available) {
      debugPrint('Speech recognition not available');
    }

    // Configure Text to Speech
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    });
  }

  Future<void> _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _spokenText = "";
        });
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _spokenText = result.recognizedWords;
            });
            if (result.finalResult) {
              _controller.text = result.recognizedWords;
              _stopListening();
              _sendMessage();
            }
          },
        );
      }
    }
  }

  Future<void> _stopListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _speak(String text) async {
    if (!_isSpeaking) {
      setState(() => _isSpeaking = true);
      // Remove emojis and special characters for better TTS
      String cleanText = text.replaceAll(RegExp(r'[^\w\s.,!?]'), '');
      await _flutterTts.speak(cleanText);
    }
  }

  Future<void> _stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _flutterTts.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    String userText = _controller.text;

    setState(() {
      _messages.add({"role": "user", "text": userText});
      _controller.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    // Simulate thinking delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      // 🔥 Process with AI Brain (with conversation history)
      final result = ShaqatiAIBrain.processQuery(
          userText, widget.availableProperties,
          conversationHistory: _messages);

      setState(() {
        _isTyping = false;
        _messages.add({
          "role": "ai",
          "text": result['response'],
          "actionType": result['type']
        });
      });
      _scrollToBottom();

      // Trigger App Action
      widget.onAction(result);

      // 🎤 Auto-speak AI response (optional - can be disabled)
      // _speak(result['response']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        height: 600,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: kPrimaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.psychology,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Shaqati Genius AI",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text("Online • Expert Agent",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),

            // Chat Body
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 10, bottom: 10),
                        child: Text("AI is thinking...",
                            style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic)),
                      ),
                    );
                  }

                  final msg = _messages[index];
                  final isAi = msg['role'] == 'ai';

                  return Align(
                    alignment:
                        isAi ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isAi ? const Color(0xFFF0F2F5) : kShaqatiPrimary,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: isAi
                              ? const Radius.circular(4)
                              : const Radius.circular(20),
                          bottomRight: isAi
                              ? const Radius.circular(20)
                              : const Radius.circular(4),
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg['text'],
                            style: TextStyle(
                                color: isAi ? Colors.black87 : Colors.white,
                                fontSize: 15,
                                height: 1.4),
                          ),
                          if (isAi && msg['actionType'] == 'action_map')
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  widget.onAction({'type': 'action_map'});
                                },
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text("Open Map Now"),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: kShaqatiPrimary,
                                    elevation: 0,
                                    minimumSize:
                                        const Size(double.infinity, 36)),
                              ),
                            )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Input Area with Voice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  // Voice indicator when listening
                  if (_isListening)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.mic, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _spokenText.isEmpty
                                  ? "Listening..."
                                  : _spokenText,
                              style: TextStyle(
                                color: Colors.red,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      // 🎤 Voice Input Button
                      CircleAvatar(
                        backgroundColor: _isListening
                            ? Colors.red
                            : kShaqatiPrimary.withOpacity(0.1),
                        child: IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color:
                                _isListening ? Colors.white : kShaqatiPrimary,
                            size: 22,
                          ),
                          onPressed:
                              _isListening ? _stopListening : _startListening,
                          tooltip:
                              _isListening ? "Stop recording" : "Voice input",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: "Ask about Nablus, rent prices...",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 🔊 Text-to-Speech Toggle
                      CircleAvatar(
                        backgroundColor: _isSpeaking
                            ? kShaqatiAccent
                            : kShaqatiPrimary.withOpacity(0.1),
                        child: IconButton(
                          icon: Icon(
                            _isSpeaking ? Icons.volume_up : Icons.volume_down,
                            color: _isSpeaking ? Colors.white : kShaqatiPrimary,
                            size: 20,
                          ),
                          onPressed: _isSpeaking
                              ? _stopSpeaking
                              : () {
                                  if (_messages.isNotEmpty) {
                                    final lastAiMessage = _messages.reversed
                                        .firstWhere((m) => m['role'] == 'ai');
                                    _speak(lastAiMessage['text'] ?? '');
                                  }
                                },
                          tooltip: _isSpeaking
                              ? "Stop speaking"
                              : "Read last message",
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send Button
                      CircleAvatar(
                        backgroundColor: kShaqatiPrimary,
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                          onPressed: _sendMessage,
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
    );
  }
}

// ---------------------------------------------------------------------------
// 🟢 NAVBAR
// ---------------------------------------------------------------------------
class _ShaqatiNavbar extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  final VoidCallback onOpenDrawer;
  final VoidCallback onListings;
  final VoidCallback onServices;
  final VoidCallback onContracts;
  final VoidCallback onPayments;
  final VoidCallback onMaintenance;
  final VoidCallback onDeposits;
  final VoidCallback onExpenses;
  final VoidCallback onBuildings;
  final VoidCallback onOccupancyHistory;
  final VoidCallback onOwnership;
  final VoidCallback onUnits;
  final VoidCallback onPropertyHistory;
  final VoidCallback onContact;
  final VoidCallback onHelp;
  final VoidCallback onDashboard;
  final VoidCallback onBuy;
  final VoidCallback onSell;
  final VoidCallback onRent;
  final VoidCallback onMyHome;
  final VoidCallback onFindAgent;
  final VoidCallback onNews;
  final VoidCallback onRefresh;

  _ShaqatiNavbar({
    required this.isLoggedIn,
    required this.onLogin,
    required this.onSignUp,
    required this.onOpenDrawer,
    required this.onListings,
    required this.onServices,
    required this.onContracts,
    required this.onPayments,
    required this.onMaintenance,
    required this.onDeposits,
    required this.onExpenses,
    required this.onBuildings,
    required this.onOccupancyHistory,
    required this.onOwnership,
    required this.onUnits,
    required this.onPropertyHistory,
    required this.onContact,
    required this.onHelp,
    required this.onDashboard,
    required this.onBuy,
    required this.onSell,
    required this.onRent,
    required this.onMyHome,
    required this.onFindAgent,
    required this.onNews,
    required this.onRefresh,
  });

  @override
  State<_ShaqatiNavbar> createState() => _ShaqatiNavbarState();
}

class _ShaqatiNavbarState extends State<_ShaqatiNavbar>
    with SingleTickerProviderStateMixin {
  int _unreadCount = 0;
  List<dynamic> _notifications = [];
  OverlayEntry? _hoverOverlay;
  final LayerLink _layerLink = LayerLink();
  late AnimationController _refreshAnimationController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isLoggedIn) {
      _checkNotifications();
    }
  }

  @override
  void dispose() {
    _refreshAnimationController.dispose();
    _removeHoverOverlay();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    // Start rotation animation
    _refreshAnimationController.repeat();

    // Call the refresh callback
    widget.onRefresh();

    // Wait for refresh to complete and then stop rotation
    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
      _refreshAnimationController.stop();
      _refreshAnimationController.reset();
    }
  }

  void _removeHoverOverlay() {
    _hoverOverlay?.remove();
    _hoverOverlay = null;
  }

  Future<void> _checkNotifications() async {
    final (ok, data) = await ApiService.getUserNotifications();
    if (ok && mounted) {
      setState(() {
        _notifications = data;
        _unreadCount = data.where((n) => n['isRead'] == false).length;
      });
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Notifications"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _notifications.isEmpty
              ? const Center(child: Text("No notifications yet."))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    final bool isRead = n['isRead'] ?? false;
                    final bool isWarning = n['type'] == 'contract_expiry';

                    return ListTile(
                      leading: Icon(
                        isWarning
                            ? Icons.warning_amber_rounded
                            : Icons.notifications,
                        color: isWarning ? Colors.red : kShaqatiPrimary,
                      ),
                      title: Text(n['message'] ?? '',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold)),
                      trailing: isRead
                          ? null
                          : const Icon(Icons.circle,
                              color: Colors.red, size: 10),
                      onTap: () async {
                        await ApiService.markNotificationRead(n['_id']);
                        Navigator.pop(context);
                        _checkNotifications();
                        _showNotificationsDialog();
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      height: isDesktop ? 90 : 75,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
      child: SafeArea(
        child: Row(
          children: [
            // Logo
            InkWell(
              onTap: () {
                // Navigate to home
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        kPrimaryGradient.createShader(bounds),
                    child: Icon(Icons.home_work_rounded,
                        color: Colors.white, size: isDesktop ? 38 : 32),
                  ),
                  const SizedBox(width: 10),
                  Text("SHAQATI",
                      style: TextStyle(
                          color: kShaqatiDark,
                          fontSize: isDesktop ? 28 : 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            const Spacer(),
            // Desktop Navigation
            if (isDesktop) ...[
              _navLink("Buy", widget.onBuy, isActive: false),
              _navLink("Rent", widget.onRent, isActive: false),
              if (widget.isLoggedIn)
                _navLink("My Home", widget.onMyHome, isActive: false),
              if (widget.isLoggedIn) _dashboardDropdown(isDesktop),
              _navLink("Services", widget.onServices, isActive: false),
              _navLink("Contact Us", widget.onContact, isActive: false),
              _navLink("News & Insights", widget.onNews, isActive: false),
              const SizedBox(width: 20),
            ],
            // Mobile/Tablet Menu Button
            if (!isDesktop) ...[
              IconButton(
                onPressed: () => _showMobileMenu(context),
                icon: const Icon(Icons.menu, color: kShaqatiDark, size: 28),
              ),
            ],
            // Right side buttons
            // Refresh button (always visible) with rotation animation
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0)
                  .animate(_refreshAnimationController),
              child: IconButton(
                onPressed: _handleRefresh,
                icon: Icon(
                  Icons.refresh,
                  color: kShaqatiDark,
                  size: 24,
                ),
                tooltip: "Refresh",
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isLoggedIn) ...[
              if (isDesktop) ...[
                IconButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ChatListScreen())),
                  icon: const Icon(Icons.message_outlined,
                      color: kShaqatiDark, size: 24),
                  tooltip: "Messages",
                ),
                const SizedBox(width: 8),
                Stack(
                  children: [
                    IconButton(
                      onPressed: _showNotificationsDialog,
                      icon: const Icon(Icons.notifications_outlined,
                          color: kShaqatiDark, size: 24),
                      tooltip: "Notifications",
                    ),
                    if (_unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          constraints:
                              const BoxConstraints(minWidth: 12, minHeight: 12),
                        ),
                      )
                  ],
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                  onPressed: widget.onOpenDrawer,
                  icon: Icon(Icons.account_circle,
                      color: kShaqatiDark, size: isDesktop ? 28 : 24)),
            ] else ...[
              // Login and Sign Up buttons
              if (isDesktop) ...[
                TextButton(
                  onPressed: widget.onLogin,
                  child: Text("Log in",
                      style: TextStyle(
                          color: kShaqatiDark,
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 15 : 13)),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                      color: kShaqatiPrimary, // Green primary color
                      borderRadius: BorderRadius.circular(8)),
                  child: ElevatedButton(
                    onPressed: widget.onSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 20 : 18,
                          vertical: isDesktop ? 10 : 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text("Sign up",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: isDesktop ? 15 : 13)),
                  ),
                ),
              ] else ...[
                IconButton(
                  onPressed: widget.onLogin,
                  icon: const Icon(Icons.login, color: kShaqatiDark, size: 24),
                  tooltip: "Login",
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _mobileMenuItem("Buy", widget.onBuy, Icons.shopping_bag),
                    _mobileMenuItem("Rent", widget.onRent, Icons.home),
                    if (widget.isLoggedIn)
                      _mobileMenuItem(
                          "My Home", widget.onMyHome, Icons.home_outlined),
                    _mobileMenuItem("Services", widget.onServices, Icons.build),
                    _mobileMenuItem(
                        "Contact Us", widget.onContact, Icons.contact_support),
                    _mobileMenuItem(
                        "News & Insights", widget.onNews, Icons.newspaper),
                    _mobileMenuItem("Listings", widget.onListings, Icons.list),
                    if (widget.isLoggedIn) ...[
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text("Dashboard",
                            style: TextStyle(
                                color: kShaqatiPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                      _mobileMenuItem(
                          "Contracts", widget.onContracts, Icons.description),
                      _mobileMenuItem(
                          "Payments", widget.onPayments, Icons.payment),
                      _mobileMenuItem("Maintenance and Complaints",
                          widget.onMaintenance, Icons.build_circle),
                      _mobileMenuItem(
                          "Expenses", widget.onExpenses, Icons.receipt),
                      _mobileMenuItem("Deposits", widget.onDeposits,
                          Icons.account_balance_wallet),
                      _mobileMenuItem(
                          "Dashboard", widget.onDashboard, Icons.dashboard),
                    ],
                    _mobileMenuItem("Help", widget.onHelp, Icons.help),
                    _mobileMenuItem(
                        "Contact", widget.onContact, Icons.contact_support),
                    if (!widget.isLoggedIn) ...[
                      const Divider(height: 32),
                      _mobileMenuItem("Log in", widget.onLogin, Icons.login),
                      _mobileMenuItem(
                          "Sign up", widget.onSignUp, Icons.person_add),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileMenuItem(String title, VoidCallback onTap, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: kShaqatiDark),
      title: Text(title,
          style: const TextStyle(
              color: kTextDark, fontWeight: FontWeight.w600, fontSize: 16)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _dashboardDropdown(bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: InkWell(
          onTap: () {
            // Toggle menu on tap
            if (_hoverOverlay != null) {
              _removeHoverOverlay();
            } else {
              _showDashboardMenu();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Dashboard",
                    style: TextStyle(
                        color: kTextDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: kTextDark, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDashboardMenu() {
    _removeHoverOverlay();

    _hoverOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Invisible full-screen tap detector to close menu when clicking outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _removeHoverOverlay(),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu positioned below Dashboard button
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(-100, 45),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 250,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dashboardMenuItem(
                        "Contracts", widget.onContracts, Icons.description),
                    _dashboardMenuItem(
                        "Payments", widget.onPayments, Icons.payment),
                    _dashboardMenuItem("Maintenance and Complaints",
                        widget.onMaintenance, Icons.build_circle),
                    _dashboardMenuItem(
                        "Expenses", widget.onExpenses, Icons.receipt),
                    _dashboardMenuItem("Deposits", widget.onDeposits,
                        Icons.account_balance_wallet),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_hoverOverlay!);
  }

  Widget _dashboardMenuItem(String title, VoidCallback onTap, IconData icon) {
    return InkWell(
      onTap: () {
        _removeHoverOverlay();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: kShaqatiPrimary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: kTextDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navLink(String text, VoidCallback onTap, {bool isActive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: isActive
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: kShaqatiPrimary, width: 2),
                  ),
                )
              : null,
          child: Text(text,
              style: TextStyle(
                  color: isActive ? kShaqatiPrimary : kTextDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🟢 HERO SECTION
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
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight =
        screenHeight * 0.85; // 85% of screen height for larger hero

    return Column(
      children: [
        SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/hero_image.png', fit: BoxFit.cover),
              Container(color: Colors.black.withOpacity(0.2)),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Find Your Perfect Home",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 15,
                                    offset: Offset(0, 4))
                              ])),
                      const SizedBox(height: 10),
                      const Text(
                          "Search properties for sale and rent in Palestine",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                    offset: Offset(0, 2))
                              ])),
                      const SizedBox(height: 30),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          _FilterChip(
                                              label: "All",
                                              isSelected:
                                                  selectedOperation == "All",
                                              onTap: () =>
                                                  onOperationChanged("All")),
                                          _FilterChip(
                                              label: "For Sale",
                                              isSelected:
                                                  selectedOperation == "Sale",
                                              onTap: () =>
                                                  onOperationChanged("Sale")),
                                          _FilterChip(
                                              label: "For Rent",
                                              isSelected:
                                                  selectedOperation == "Rent",
                                              onTap: () =>
                                                  onOperationChanged("Rent")),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                      height: 20,
                                      width: 1,
                                      color: Colors.grey[300],
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 10)),
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
                                          value: "All",
                                          child: Text("All Types")),
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
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 🏠 PROPERTY TYPE GRID
// ---------------------------------------------------------------------------
class _PropertyTypeGrid extends StatelessWidget {
  final List<dynamic> properties;
  final Function(String type, String displayName) onTypeTap;

  const _PropertyTypeGrid({
    required this.properties,
    required this.onTypeTap,
  });

  int _getCountForType(String type) {
    return properties.where((p) => p['type'] == type).length;
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'apartment':
        return Icons.apartment;
      case 'house':
        return Icons.home;
      case 'villa':
        return Icons.villa;
      case 'shop':
        return Icons.store;
      case 'land':
        return Icons.landscape;
      case 'office':
        return Icons.business;
      default:
        return Icons.home;
    }
  }

  String _getDisplayName(String type) {
    switch (type) {
      case 'apartment':
        return 'Apartments';
      case 'house':
        return 'Houses';
      case 'villa':
        return 'Villas';
      case 'shop':
        return 'Shops';
      case 'land':
        return 'Land';
      case 'office':
        return 'Offices';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    // أنواع العقارات المتاحة
    final propertyTypes = [
      'apartment',
      'house',
      'villa',
      'shop',
      'land',
      'office',
    ];

    // فلترة فقط الأنواع التي يوجد بها عقارات
    final availableTypes =
        propertyTypes.where((type) => _getCountForType(type) > 0).toList();

    if (availableTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    // إذا كانت أكثر من 8، نأخذ أول 8
    final displayTypes = availableTypes.take(8).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: displayTypes.length,
      itemBuilder: (context, index) {
        final type = displayTypes[index];
        final count = _getCountForType(type);
        final displayName = _getDisplayName(type);
        final icon = _getIconForType(type);

        return InkWell(
          onTap: () => onTypeTap(type, displayName),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background with gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kShaqatiPrimary.withOpacity(0.15),
                          kShaqatiPrimary.withOpacity(0.08),
                          kShaqatiDark.withOpacity(0.12),
                        ],
                      ),
                    ),
                  ),
                  // Pattern overlay
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PatternPainter(),
                    ),
                  ),
                  // Icon in center-background
                  Positioned.fill(
                    child: Center(
                      child: Icon(
                        icon,
                        size: 80,
                        color: kShaqatiPrimary.withOpacity(0.15),
                      ),
                    ),
                  ),
                  // Dark overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Title and count
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$count properties',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Pattern painter for background decoration
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw diagonal lines pattern
    for (double i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// 🛠️ HELPFUL TOOLS SECTION
// ---------------------------------------------------------------------------
class _ActionButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? Colors.grey[200] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.black : Colors.grey[300]!,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: kTextDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpfulToolsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: _HelpCard(
                  icon: Icons.calculate_outlined,
                  iconColor: kShaqatiPrimary,
                  title: "Calculate your budget",
                  description:
                      "Estimate how much you can afford for rent or purchase. Get personalized budget recommendations based on your income.",
                  actionText: "Try our calculator",
                  onTap: () => _showCalculatorDialog(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HelpCard(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: kShaqatiPrimary,
                  title: "Understand monthly costs",
                  description:
                      "Get detailed breakdown of monthly expenses including rent, utilities, maintenance, and other costs for your property.",
                  actionText: "View cost breakdown",
                  onTap: () => _showCostBreakdownDialog(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _HelpCard(
                  icon: Icons.help_outline,
                  iconColor: kShaqatiPrimary,
                  title: "Get help with deposits",
                  description:
                      "Learn about deposit requirements, payment plans, and available assistance programs to help you secure your property.",
                  actionText: "Find deposit help",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DepositsManagementScreen()),
                    );
                  },
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _HelpCard(
                icon: Icons.calculate_outlined,
                iconColor: kShaqatiPrimary,
                title: "Calculate your budget",
                description:
                    "Estimate how much you can afford for rent or purchase. Get personalized budget recommendations based on your income.",
                actionText: "Try our calculator",
                onTap: () => _showCalculatorDialog(context),
              ),
              const SizedBox(height: 16),
              _HelpCard(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: kShaqatiPrimary,
                title: "Understand monthly costs",
                description:
                    "Get detailed breakdown of monthly expenses including rent, utilities, maintenance, and other costs for your property.",
                actionText: "View cost breakdown",
                onTap: () => _showCostBreakdownDialog(context),
              ),
              const SizedBox(height: 16),
              _HelpCard(
                icon: Icons.help_outline,
                iconColor: kShaqatiPrimary,
                title: "Get help with deposits",
                description:
                    "Learn about deposit requirements, payment plans, and available assistance programs to help you secure your property.",
                actionText: "Find deposit help",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DepositsManagementScreen()),
                  );
                },
              ),
            ],
          );
        }
      },
    );
  }

  void _showCalculatorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Budget Calculator"),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Calculate Your Budget",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                "General Rule: Your monthly rent should not exceed 30% of your monthly income.",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                "Example:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text("• Monthly Income: \$2,000"),
              Text("• Recommended Rent: \$600/month (30%)"),
              Text("• Maximum Budget: \$800/month (40%)"),
              SizedBox(height: 16),
              Text(
                "For Purchase:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text("• Down Payment: 10-20% of property value"),
              Text("• Monthly Payment: Should not exceed 28% of income"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showCostBreakdownDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Monthly Cost Breakdown"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Typical Monthly Costs:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const _CostItem("Rent/Mortgage", "Main monthly payment"),
              const _CostItem("Utilities", "Electricity, water, gas"),
              const _CostItem("Internet & Phone", "Communication services"),
              const _CostItem("Maintenance", "Repairs and upkeep"),
              const _CostItem("Insurance", "Property/rental insurance"),
              const _CostItem("Property Tax", "If applicable"),
              const SizedBox(height: 16),
              Text(
                "Tip: Always budget 10-15% extra for unexpected expenses.",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}

class _CostItem extends StatelessWidget {
  final String title;
  final String description;

  const _CostItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: kShaqatiPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String actionText;
  final VoidCallback onTap;

  const _HelpCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onTap,
            child: Text(
              actionText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kShaqatiPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🗺️ RECOMMENDED NEIGHBORHOODS
// ---------------------------------------------------------------------------
class _RecommendedNeighborhoods extends StatelessWidget {
  final List<dynamic> properties;

  const _RecommendedNeighborhoods({required this.properties});

  List<Map<String, dynamic>> _getCityStats() {
    final Map<String, List<dynamic>> cityGroups = {};

    for (var property in properties) {
      if (property['status'] == 'available' && property['city'] != null) {
        final city = property['city'].toString();
        if (!cityGroups.containsKey(city)) {
          cityGroups[city] = [];
        }
        cityGroups[city]!.add(property);
      }
    }

    return cityGroups.entries.map((entry) {
      final cityProperties = entry.value;
      final prices = cityProperties
          .where((p) => p['price'] != null)
          .map((p) => (p['price'] as num).toDouble())
          .toList();

      double medianPrice = 0;
      if (prices.isNotEmpty) {
        prices.sort();
        final mid = prices.length ~/ 2;
        medianPrice = prices.length.isOdd
            ? prices[mid]
            : (prices[mid - 1] + prices[mid]) / 2;
      }

      // Get first property location for map
      final firstProperty = cityProperties.first;
      final location = firstProperty['location'];
      double? lat, lng;
      if (location != null && location['coordinates'] != null) {
        final coords = location['coordinates'] as List;
        if (coords.length >= 2) {
          lng = coords[0].toDouble();
          lat = coords[1].toDouble();
        }
      }

      return {
        'city': entry.key,
        'count': cityProperties.length,
        'medianPrice': medianPrice,
        'lat': lat,
        'lng': lng,
      };
    }).toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  }

  @override
  Widget build(BuildContext context) {
    final cityStats = _getCityStats();

    if (cityStats.isEmpty) {
      return const SizedBox.shrink();
    }

    // Take top 4 cities
    final topCities = cityStats.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recommended neighborhoods",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Based on available properties",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return isWide
                ? Row(
                    children: topCities
                        .map((city) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _NeighborhoodCard(
                                  city: city['city'] as String,
                                  count: city['count'] as int,
                                  medianPrice: city['medianPrice'] as double,
                                  lat: city['lat'] as double?,
                                  lng: city['lng'] as double?,
                                ),
                              ),
                            ))
                        .toList(),
                  )
                : Column(
                    children: topCities
                        .map((city) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _NeighborhoodCard(
                                city: city['city'] as String,
                                count: city['count'] as int,
                                medianPrice: city['medianPrice'] as double,
                                lat: city['lat'] as double?,
                                lng: city['lng'] as double?,
                              ),
                            ))
                        .toList(),
                  );
          },
        ),
      ],
    );
  }
}

class _NeighborhoodCard extends StatelessWidget {
  final String city;
  final int count;
  final double medianPrice;
  final double? lat;
  final double? lng;

  const _NeighborhoodCard({
    required this.city,
    required this.count,
    required this.medianPrice,
    this.lat,
    this.lng,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 150,
              color: Colors.grey[200],
              child: lat != null && lng != null
                  ? FlutterMap(
                      options: MapOptions(
                        initialCenter: latlng.LatLng(lat!, lng!),
                        initialZoom: 13.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: latlng.LatLng(lat!, lng!),
                              width: 30,
                              height: 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kShaqatiPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Center(
                      child: Icon(
                        Icons.map_outlined,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                    ),
            ),
          ),
          // City info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$count Listings for sale',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  medianPrice > 0
                      ? '\$${medianPrice.toStringAsFixed(0)} Median Listing Home Price'
                      : 'Price information available',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kShaqatiPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 📰 NEWS & INSIGHTS SECTION
// ---------------------------------------------------------------------------
class _NewsInsightsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Real Estate Insights",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: kTextDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Tips, guides, and market insights to help you make informed decisions",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _InsightCard(
                          title: "First-Time Buyer's Guide",
                          description:
                              "Everything you need to know about buying your first property in Palestine. From financing to legal requirements.",
                          imagePath: "assets/images/buyers_guide.jpg",
                          onTap: () => _showBuyersGuide(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _InsightCard(
                          title: "Rental Market Trends 2024",
                          description:
                              "Discover the latest trends in the Palestinian rental market. Which cities offer the best value?",
                          imagePath: "assets/images/market_trends.jpg",
                          onTap: () => _showMarketTrends(context),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _InsightCard(
                        title: "First-Time Buyer's Guide",
                        description:
                            "Everything you need to know about buying your first property in Palestine. From financing to legal requirements.",
                        imagePath: "assets/images/buyers_guide.jpg",
                        onTap: () => _showBuyersGuide(context),
                      ),
                      const SizedBox(height: 16),
                      _InsightCard(
                        title: "Rental Market Trends 2024",
                        description:
                            "Discover the latest trends in the Palestinian rental market. Which cities offer the best value?",
                        imagePath: "assets/images/market_trends.jpg",
                        onTap: () => _showMarketTrends(context),
                      ),
                    ],
                  );
          },
        ),
      ],
    );
  }

  void _showBuyersGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("First-Time Buyer's Guide"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Buying Your First Property in Palestine",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _GuideItem(
                "1. Determine Your Budget",
                "Calculate how much you can afford. Consider down payment (usually 10-20%), monthly mortgage payments, and additional costs.",
              ),
              _GuideItem(
                "2. Get Pre-Approved",
                "Visit a bank to get pre-approved for a mortgage. This shows sellers you're serious and helps you know your price range.",
              ),
              _GuideItem(
                "3. Choose the Right Location",
                "Consider proximity to work, schools, hospitals, and amenities. Research neighborhood safety and future development plans.",
              ),
              _GuideItem(
                "4. Work with a Real Estate Agent",
                "A good agent can help you find properties, negotiate prices, and handle paperwork. Use SHAQATI to find trusted agents.",
              ),
              _GuideItem(
                "5. Property Inspection",
                "Always inspect the property thoroughly. Check for structural issues, plumbing, electrical systems, and legal documentation.",
              ),
              _GuideItem(
                "6. Legal Documentation",
                "Ensure all property documents are in order. Verify ownership, check for any liens, and complete all legal transfers properly.",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showMarketTrends(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rental Market Trends 2024"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Palestinian Real Estate Market Overview",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _TrendItem(
                "Ramallah",
                "High demand, premium prices. Average rent: \$400-800/month. Best for professionals and families.",
                Icons.trending_up,
                Colors.green,
              ),
              _TrendItem(
                "Nablus",
                "Student-friendly, affordable. Average rent: \$200-400/month. Great for university students.",
                Icons.trending_up,
                Colors.blue,
              ),
              _TrendItem(
                "Hebron",
                "Family-oriented, spacious properties. Average rent: \$250-500/month. Ideal for large families.",
                Icons.trending_flat,
                Colors.orange,
              ),
              _TrendItem(
                "Jenin",
                "Emerging market, great value. Average rent: \$150-350/month. Growing investment opportunity.",
                Icons.trending_up,
                Colors.purple,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "💡 Tip: The market is currently favorable for renters. Take time to compare options and negotiate terms.",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String description;
  final String? imagePath;
  final VoidCallback onTap;

  const _InsightCard({
    required this.title,
    required this.description,
    this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or gradient
              if (imagePath != null)
                Image.asset(
                  imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to gradient if image not found
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            kShaqatiPrimary.withOpacity(0.1),
                            kShaqatiDark.withOpacity(0.15),
                          ],
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kShaqatiPrimary.withOpacity(0.1),
                        kShaqatiDark.withOpacity(0.15),
                      ],
                    ),
                  ),
                ),
              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 13,
                          height: 1.4,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Text(
                          "Read Article",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  final String title;
  final String description;

  const _GuideItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: kShaqatiPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 📍 LOCAL INFO & PRE-APPROVAL SECTION
// ---------------------------------------------------------------------------
class _LocalInfoAndPreApprovalSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Get Local Info Section
                  Expanded(
                    flex: 2,
                    child: _LocalInfoCard(),
                  ),
                  const SizedBox(width: 20),
                  // Pre-Approval Section
                  Expanded(
                    flex: 1,
                    child: _PreApprovalCard(),
                  ),
                ],
              )
            : Column(
                children: [
                  _LocalInfoCard(),
                  const SizedBox(height: 20),
                  _PreApprovalCard(),
                ],
              );
      },
    );
  }
}

class _LocalInfoCard extends StatefulWidget {
  @override
  State<_LocalInfoCard> createState() => _LocalInfoCardState();
}

class _LocalInfoCardState extends State<_LocalInfoCard> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Get Local Info",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Does it have pet-friendly rentals? How are the schools? Get important local information on the area you're most interested in.",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search city or neighborhood...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _showLocalInfo(context, value);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search, color: kShaqatiPrimary),
                  onPressed: () {
                    if (_searchController.text.isNotEmpty) {
                      _showLocalInfo(context, _searchController.text);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Quick City Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickCityButton(
                  "Ramallah", () => _showLocalInfo(context, "Ramallah")),
              _QuickCityButton(
                  "Nablus", () => _showLocalInfo(context, "Nablus")),
              _QuickCityButton(
                  "Hebron", () => _showLocalInfo(context, "Hebron")),
              _QuickCityButton("Jenin", () => _showLocalInfo(context, "Jenin")),
            ],
          ),
        ],
      ),
    );
  }

  void _showLocalInfo(BuildContext context, String city) {
    final cityInfo = _getCityInfo(city);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Local Information: $city"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoItem(Icons.school, "Schools", cityInfo['schools']!),
              _InfoItem(
                  Icons.local_hospital, "Hospitals", cityInfo['hospitals']!),
              _InfoItem(Icons.pets, "Pet-Friendly", cityInfo['petFriendly']!),
              _InfoItem(Icons.shopping_cart, "Shopping", cityInfo['shopping']!),
              _InfoItem(Icons.directions_transit, "Transportation",
                  cityInfo['transportation']!),
              _InfoItem(Icons.security, "Safety", cityInfo['safety']!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Map<String, String> _getCityInfo(String city) {
    final cityLower = city.toLowerCase();
    if (cityLower.contains('ramallah')) {
      return {
        'schools':
            'Excellent educational facilities including Birzeit University. Many international and private schools available.',
        'hospitals':
            'Multiple hospitals including Ramallah Hospital and private medical centers. Good healthcare access.',
        'petFriendly':
            'Many properties allow pets. Check with landlords for specific pet policies.',
        'shopping':
            'Modern shopping centers and markets. Central business district with various retail options.',
        'transportation':
            'Well-connected with public transport. Easy access to other cities.',
        'safety':
            'Generally safe area with good security. Popular among professionals and families.',
      };
    } else if (cityLower.contains('nablus')) {
      return {
        'schools':
            'An-Najah National University and various schools. Strong educational infrastructure.',
        'hospitals':
            'Rafidia Hospital and other medical facilities. Good healthcare services.',
        'petFriendly':
            'Some properties allow pets. Always confirm with property owner.',
        'shopping':
            'Traditional markets (souq) and modern shopping areas. Affordable shopping options.',
        'transportation':
            'Central location with good transport links. University town with student-friendly areas.',
        'safety':
            'Safe city with active community. Popular with students and families.',
      };
    } else if (cityLower.contains('hebron')) {
      return {
        'schools':
            'Good schools and educational institutions. Family-oriented community.',
        'hospitals':
            'Hebron Government Hospital and private clinics. Adequate healthcare.',
        'petFriendly': 'Pet policies vary. Check with individual properties.',
        'shopping':
            'Traditional markets and local shops. Known for glass and pottery industries.',
        'transportation':
            'Connected to major cities. Traditional city with cultural heritage.',
        'safety': 'Safe residential areas. Strong family community values.',
      };
    } else if (cityLower.contains('jenin')) {
      return {
        'schools':
            'Educational institutions including schools and colleges. Growing student population.',
        'hospitals':
            'Jenin Government Hospital and medical centers. Healthcare services available.',
        'petFriendly':
            'Some properties accommodate pets. Verify with landlords.',
        'shopping': 'Local markets and shops. Affordable living costs.',
        'transportation':
            'Good road connections. Emerging market with growth potential.',
        'safety': 'Safe residential areas. Developing city with opportunities.',
      };
    }
    return {
      'schools':
          'Educational facilities available. Contact local authorities for specific information.',
      'hospitals': 'Medical services available in the area.',
      'petFriendly':
          'Pet policies vary by property. Check with individual landlords.',
      'shopping': 'Shopping options available in the area.',
      'transportation': 'Transportation services accessible.',
      'safety': 'Contact local authorities for safety information.',
    };
  }
}

class _QuickCityButton extends StatelessWidget {
  final String city;
  final VoidCallback onTap;

  const _QuickCityButton(this.city, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kShaqatiPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kShaqatiPrimary.withOpacity(0.3)),
        ),
        child: Text(
          city,
          style: TextStyle(
            color: kShaqatiPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoItem(this.icon, this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kShaqatiPrimary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreApprovalCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Need a home loan?",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Get pre-approved",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kShaqatiPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Find a lender who can offer competitive mortgage rates and help you with pre-approval.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showPreApprovalInfo(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Get pre-approved now",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Advertising disclosure",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  void _showPreApprovalInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Home Loan Pre-Approval"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Steps to Get Pre-Approved:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _PreApprovalStep(
                "1. Gather Documents",
                "Prepare: ID, proof of income, bank statements, employment letter, and property documents if available.",
              ),
              _PreApprovalStep(
                "2. Choose a Bank",
                "Contact major Palestinian banks: Bank of Palestine, Arab Bank, or Cairo Amman Bank. Compare interest rates and terms.",
              ),
              _PreApprovalStep(
                "3. Submit Application",
                "Fill out the mortgage application form. The bank will review your financial situation and credit history.",
              ),
              _PreApprovalStep(
                "4. Get Pre-Approval Letter",
                "Once approved, you'll receive a pre-approval letter showing your maximum loan amount and interest rate.",
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "💡 Tip: Pre-approval makes you a stronger buyer and helps you know your budget range.",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}

class _PreApprovalStep extends StatelessWidget {
  final String title;
  final String description;

  const _PreApprovalStep(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kShaqatiPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.check_circle, color: kShaqatiPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🎯 PROMOTIONAL BANNER SECTION
// ---------------------------------------------------------------------------
class _PromotionalBannerSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            Image.asset(
              'assets/images/promotional_banner.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kShaqatiPrimary.withOpacity(0.8),
                        kShaqatiDark.withOpacity(0.9),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Dark overlay for better text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
            // Content
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return isWide
                    ? Row(
                        children: [
                          // Left side - Image/Visual (if needed)
                          Expanded(
                            flex: 1,
                            child: Container(),
                          ),
                          // Right side - Text Content
                          Expanded(
                            flex: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(50),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      const Text(
                                        "Over",
                                        style: TextStyle(
                                          fontSize: 64,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "500k",
                                        style: TextStyle(
                                          fontSize: 80,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red[400],
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          "new",
                                          style: TextStyle(
                                            fontSize: 64,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            height: 1.0,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "listings every",
                                          style: TextStyle(
                                            fontSize: 64,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            height: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "month",
                                      style: TextStyle(
                                        fontSize: 64,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  Text(
                                    "Avg new for sale and rental listings",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                const Text(
                                  "Over",
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "500k",
                                  style: TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[400],
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    "new",
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "listings every",
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "month",
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "Avg new for sale and rental listings",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendItem extends StatelessWidget {
  final String city;
  final String description;
  final IconData icon;
  final Color color;

  const _TrendItem(this.city, this.description, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
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
                color: isSelected ? kShaqatiPrimary : Colors.transparent)),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? kShaqatiPrimary : kTextLight,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🟢 MAP & GRID COMPONENTS
// ---------------------------------------------------------------------------

class _MiniMapSection extends StatelessWidget {
  final List<dynamic> properties;
  const _MiniMapSection({required this.properties});
  @override
  Widget build(BuildContext context) {
    latlng.LatLng center = const latlng.LatLng(32.2211, 35.2544);
    if (properties.isNotEmpty) {
      try {
        final firstLoc = properties.first['location']['coordinates'];
        center = latlng.LatLng(firstLoc[1], firstLoc[0]);
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
                              point: latlng.LatLng(coords[1], coords[0]),
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
                          return Marker(
                              point: const latlng.LatLng(0, 0),
                              child: const SizedBox());
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

class _PropertyGrid extends StatefulWidget {
  final List<dynamic> properties;
  const _PropertyGrid({required this.properties});

  @override
  State<_PropertyGrid> createState() => _PropertyGridState();
}

class _PropertyGridState extends State<_PropertyGrid> {
  int _currentPage = 0;
  static const int _itemsPerPage = 8;

  int get _totalPages => (widget.properties.length / _itemsPerPage).ceil();
  List<dynamic> get _currentPageProperties {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex =
        (startIndex + _itemsPerPage).clamp(0, widget.properties.length);
    return widget.properties.sublist(startIndex, endIndex);
  }

  // Format date for display
  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';

    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return months == 1 ? '1 month ago' : '$months months ago';
      } else {
        final years = (difference.inDays / 365).floor();
        return years == 1 ? '1 year ago' : '$years years ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Open chat with property owner
  Future<void> _openChatWithOwner(
      BuildContext context, Map<String, dynamic> property) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final currentUserId = prefs.getString('userId');

    if (token == null || currentUserId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please login to chat with the owner"),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    // Get owner ID
    String? ownerId;
    String ownerName = 'Property Owner';

    if (property['ownerId'] != null) {
      if (property['ownerId'] is Map) {
        ownerId = property['ownerId']['_id']?.toString();
        ownerName = property['ownerId']['name']?.toString() ?? 'Property Owner';
      } else if (property['ownerId'] is String) {
        ownerId = property['ownerId'];
      }
    }

    if (ownerId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Owner information not available"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Don't allow chatting with yourself
    if (ownerId == currentUserId) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You cannot chat with yourself"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            receiverId: ownerId!,
            receiverName: ownerName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMoreThan8 = widget.properties.length > _itemsPerPage;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Property Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 900
                  ? 4
                  : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio:
                  0.75, // Reduced from 0.90 to accommodate more content
            ),
            itemCount: _currentPageProperties.length,
            itemBuilder: (context, index) {
              final p = _currentPageProperties[index];
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
                            Expanded(
                                flex: 6,
                                child: Stack(fit: StackFit.expand, children: [
                                  Image.network(imageUrl, fit: BoxFit.cover),
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
                                  // Operation badge (FOR RENT / FOR SALE)
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
                                  // Status badge (RENTED / PURCHASED) - shown when property is not available
                                  if (p['status'] != 'available')
                                    Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                                color: p['status'] == 'rented'
                                                    ? Colors.orange
                                                    : Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(6)),
                                            child: Text(
                                                p['status'] == 'rented'
                                                    ? (p['operation'] == 'rent'
                                                        ? "RENTED"
                                                        : "SOLD")
                                                    : p['status'] == 'pending_approval'
                                                        ? "PENDING"
                                                        : p['status']
                                                            .toString()
                                                            .toUpperCase(),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10)))),
                                  Positioned(
                                      bottom: 10,
                                      right: 12,
                                      child: Text("\$${p['price']}",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              shadows: [
                                                Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 4)
                                              ])))
                                ])),
                            Expanded(
                                flex: 4,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(p['title'] ?? 'Untitled',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                          color: kTextDark)),
                                                  const SizedBox(height: 4),
                                                  Row(children: [
                                                    const Icon(
                                                        Icons
                                                            .location_on_outlined,
                                                        size: 13,
                                                        color: kTextLight),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                        child: Text(
                                                            "${p['city'] ?? ''}, ${p['address'] ?? ''}",
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: const TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    kTextLight)))
                                                  ]),
                                                  const SizedBox(height: 4),
                                                  // Publisher/Owner information
                                                  if (p['ownerId'] != null) ...[
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.person_outline,
                                                          size: 11,
                                                          color: kTextLight,
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            p['ownerId'] is Map
                                                                ? (p['ownerId'][
                                                                        'name'] ??
                                                                    'Unknown')
                                                                : 'Published by Owner',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 10,
                                                              color: kTextLight,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                  ],
                                                  // Publication date
                                                  if (p['createdAt'] !=
                                                      null) ...[
                                                    Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .calendar_today_outlined,
                                                          size: 11,
                                                          color: kTextLight,
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            _formatDate(
                                                                p['createdAt']),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 10,
                                                              color: kTextLight,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ]),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              _InfoBadge(Icons.bed,
                                                  "${p['bedrooms'] ?? 0} Beds"),
                                              _InfoBadge(Icons.bathtub,
                                                  "${p['bathrooms'] ?? 0} Baths"),
                                              _InfoBadge(Icons.square_foot,
                                                  "${p['area'] ?? 0} m²"),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Chat button row
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              InkWell(
                                                onTap: () => _openChatWithOwner(
                                                    context, p),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: kShaqatiPrimary
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                      color: kShaqatiPrimary
                                                          .withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .chat_bubble_outline,
                                                        size: 14,
                                                        color: kShaqatiPrimary,
                                                      ),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        'Chat',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              kShaqatiPrimary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ])))
                          ])));
            },
          ),
          // Pagination Controls & View All Button
          if (hasMoreThan8) ...[
            const SizedBox(height: 30),
            // Pagination
            if (_totalPages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                    color: _currentPage > 0 ? kShaqatiPrimary : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  ...List.generate(_totalPages, (index) {
                    return GestureDetector(
                      onTap: () => setState(() => _currentPage = index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? kShaqatiPrimary
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: _currentPage == index
                                  ? Colors.white
                                  : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _currentPage < _totalPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                    color: _currentPage < _totalPages - 1
                        ? kShaqatiPrimary
                        : Colors.grey,
                  ),
                ],
              ),
            const SizedBox(height: 20),
            // View All Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllPropertiesScreen(
                        allProperties: widget.properties,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.grid_view, color: Colors.white),
                label: const Text(
                  "View All Properties",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kShaqatiPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ]),
      ),
    );
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: kTextDark)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(color: kTextLight, height: 1.3)),
              ],
            ))
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kShaqatiPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: kTextDark)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(color: kTextLight, height: 1.3)),
                  ]),
            )
          ],
        ),
      ),
    );
  }
}

class _ShaqatiFooter extends StatelessWidget {
  final VoidCallback onListings;
  final VoidCallback onServices;
  final VoidCallback onContact;
  final VoidCallback onHelp;
  final VoidCallback onContracts;
  final VoidCallback onPayments;
  final VoidCallback onMaintenance;

  const _ShaqatiFooter(
      {required this.onListings,
      required this.onServices,
      required this.onContact,
      required this.onHelp,
      required this.onContracts,
      required this.onPayments,
      required this.onMaintenance});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 24),
      child: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 30,
              spacing: 30,
              children: [
                // Brand & About Section
                SizedBox(
                  width: isWide ? constraints.maxWidth * 0.25 : double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.home_work_rounded,
                              color: Colors.white, size: 28),
                          SizedBox(width: 8),
                          Text("SHAQATI",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                          "Professional real estate platform for tenants, landlords, and admins across Palestine.",
                          style: TextStyle(
                              color: Colors.white70,
                              height: 1.6,
                              fontSize: 14)),
                      const SizedBox(height: 20),
                      // Social Media Icons
                      Row(
                        children: [
                          _SocialIconButton(
                            icon: Icons.facebook,
                            color: const Color(0xFF1877F2),
                            onTap: () {
                              _launchExternalUrl(
                                  "https://www.facebook.com/share/14VTAn7Y7AX/?mibextid=wwXIfr");
                            },
                          ),
                          const SizedBox(width: 12),
                          _SocialIconButton(
                            icon: Icons.camera_alt,
                            color: const Color(0xFFE4405F),
                            onTap: () {
                              _launchExternalUrl(
                                  "https://www.instagram.com/ahmad.hananii?igsh=MWxtcjU0MHN0b2Rtaw%3D%3D&utm_source=qr");
                            },
                          ),
                          const SizedBox(width: 12),
                          _SocialIconButton(
                            icon: Icons.chat,
                            color: const Color(0xFF25D366),
                            onTap: () {
                              _launchExternalUrl("https://wa.me/972569630981");
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Explore Section
                SizedBox(
                  width: isWide ? constraints.maxWidth * 0.15 : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Explore",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const SizedBox(height: 16),
                      _FooterLink(
                          icon: Icons.search,
                          label: "Listings",
                          onTap: onListings),
                      _FooterLink(
                          icon: Icons.room_service,
                          label: "Services",
                          onTap: onServices),
                      _FooterLink(
                          icon: Icons.contact_mail,
                          label: "Contact",
                          onTap: onContact),
                      _FooterLink(
                          icon: Icons.help_outline,
                          label: "Help Center",
                          onTap: onHelp),
                    ],
                  ),
                ),
                // Tenant Section
                SizedBox(
                  width: isWide ? constraints.maxWidth * 0.15 : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Tenant",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const SizedBox(height: 16),
                      _FooterLink(
                          icon: Icons.description,
                          label: "Contracts",
                          onTap: onContracts),
                      _FooterLink(
                          icon: Icons.payment,
                          label: "Payments",
                          onTap: onPayments),
                      _FooterLink(
                          icon: Icons.build,
                          label: "Maintenance",
                          onTap: onMaintenance),
                    ],
                  ),
                ),
                // Connect & Contact Section
                SizedBox(
                  width: isWide ? constraints.maxWidth * 0.25 : double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Connect",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const SizedBox(height: 16),
                      _FooterContactItem(
                          icon: Icons.phone,
                          label: "+972 56 963 0981",
                          onTap: () => _launchExternalUrl("tel:+972569630981")),
                      _FooterContactItem(
                          icon: Icons.email,
                          label: "support@shaqati.com",
                          onTap: () =>
                              _launchExternalUrl("mailto:support@shaqati.com")),
                      _FooterContactItem(
                          icon: Icons.chat,
                          label: "WhatsApp: +972 56 963 0981",
                          onTap: () =>
                              _launchExternalUrl("https://wa.me/972569630981")),
                      _FooterContactItem(
                          icon: Icons.location_on,
                          label: "Palestine, West Bank",
                          onTap: null),
                      const SizedBox(height: 20),
                      const Text("Office Hours",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      const SizedBox(height: 8),
                      const Text("Sun - Thu: 9:00 AM - 5:00 PM",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5)),
                      const Text("Friday: Closed",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Divider(color: Colors.white12, thickness: 1),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("© 2025 SHAQATI. All rights reserved.",
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                Wrap(
                  spacing: 20,
                  children: [
                    _FooterLink(
                        icon: null, label: "Privacy Policy", onTap: () {}),
                    _FooterLink(
                        icon: null, label: "Terms of Service", onTap: () {}),
                    _FooterLink(icon: null, label: "About Us", onTap: () {}),
                  ],
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _FooterContactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FooterContactItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _FooterLink({required this.label, this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
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
        ListTile(
            leading: const Icon(Icons.help_outline, color: kShaqatiPrimary),
            title: const Text('Help & FAQ'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
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

// ---------------------------------------------------------------------------
// ⭐ FEATURED PROPERTIES SECTION
// ---------------------------------------------------------------------------
class _FeaturedPropertiesSection extends StatelessWidget {
  final List<dynamic> properties;

  const _FeaturedPropertiesSection({required this.properties});

  @override
  Widget build(BuildContext context) {
    final featuredProperties =
        properties.where((p) => p['featured'] == true).take(8).toList();

    if (featuredProperties.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Featured Properties",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kTextDark)),
              TextButton(
                onPressed: () {
                  final featured =
                      properties.where((p) => p['featured'] == true).toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AllPropertiesScreen(allProperties: featured)),
                  );
                },
                child: const Text("View All",
                    style: TextStyle(color: kShaqatiPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: featuredProperties.length,
              itemBuilder: (context, index) {
                final p = featuredProperties[index];
                final imageUrl = (p['images'] != null && p['images'].isNotEmpty)
                    ? p['images'][0]
                    : 'https://via.placeholder.com/300x200?text=No+Image';
                return Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Card(
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PropertyDetailsScreen(property: p))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 6,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(imageUrl, fit: BoxFit.cover),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: kShaqatiAccent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text("FEATURED",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                // Status badge for rented/sold properties
                                if (p['status'] != 'available')
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: p['status'] == 'rented'
                                            ? Colors.orange
                                            : Colors.red,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        p['status'] == 'rented'
                                            ? (p['operation'] == 'rent'
                                                ? "RENTED"
                                                : "SOLD")
                                            : p['status']
                                                .toString()
                                                .toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p['title'] ?? 'Property',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 14, color: Colors.grey[600]),
                                      Expanded(
                                        child: Text(
                                          p['address'] ?? 'Location',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "\$${p['price'] ?? '0'}",
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: kShaqatiPrimary),
                                      ),
                                      Text(
                                        p['operation']?.toUpperCase() ?? '',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: p['operation'] == 'rent'
                                                ? Colors.blue
                                                : Colors.green),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 📊 STATISTICS BANNER SECTION
// ---------------------------------------------------------------------------
class _StatisticsBannerSection extends StatelessWidget {
  final List<dynamic> properties;

  const _StatisticsBannerSection({required this.properties});

  @override
  Widget build(BuildContext context) {
    final totalProperties = properties.length;
    final cities = properties
        .map((p) => p['city']?.toString() ?? '')
        .where((city) => city.isNotEmpty)
        .toSet()
        .length;
    final activeContracts = properties
        .where((p) => p['status'] == 'rented' || p['status'] == 'active')
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kShaqatiPrimary,
              kShaqatiDark,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: kShaqatiPrimary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(Icons.home, "$totalProperties+", "Properties Available"),
            _StatItem(Icons.people, "1,500+", "Active Users"),
            _StatItem(
                Icons.check_circle, "$activeContracts+", "Completed Deals"),
            _StatItem(Icons.location_city, "$cities+", "Cities Covered"),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem(this.icon, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style:
                TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
            textAlign: TextAlign.center),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 🔄 HOW IT WORKS SECTION
// ---------------------------------------------------------------------------
class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("How It Works",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StepCard(
                  step: "1",
                  icon: Icons.search,
                  title: "Search & Browse",
                  description:
                      "Find your perfect property using our advanced search filters",
                  color: kShaqatiPrimary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StepCard(
                  step: "2",
                  icon: Icons.message,
                  title: "Contact & Negotiate",
                  description:
                      "Get in touch with property owners and discuss terms",
                  color: kShaqatiAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StepCard(
                  step: "3",
                  icon: Icons.description,
                  title: "Sign Contract",
                  description:
                      "Complete the rental process with digital contracts",
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StepCard(
                  step: "4",
                  icon: Icons.home,
                  title: "Move In",
                  description: "Enjoy your new home with full tenant support",
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String step;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 12),
          Text(step,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 💬 TESTIMONIALS SECTION
// ---------------------------------------------------------------------------
class _TestimonialsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final testimonials = [
      {
        'name': 'Ahmad Ali',
        'image': null,
        'text':
            'SHAQATI made finding my apartment so easy. The process was smooth and the support team was amazing!',
        'rating': 5,
        'location': 'Nablus',
      },
      {
        'name': 'Sara Mahmoud',
        'image': null,
        'text':
            'Best rental platform in Palestine. I found my dream home within a week!',
        'rating': 5,
        'location': 'Ramallah',
      },
      {
        'name': 'Mohammed Hasan',
        'image': null,
        'text':
            'Professional service and transparent pricing. Highly recommended!',
        'rating': 5,
        'location': 'Hebron',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("What Our Customers Say",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 20),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: testimonials.length,
              itemBuilder: (context, index) {
                final t = testimonials[index];
                return Container(
                  width: 320,
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(Icons.star,
                              color: i < (t['rating'] as int)
                                  ? Colors.amber
                                  : Colors.grey[300],
                              size: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(t['text'] as String,
                          style: const TextStyle(fontSize: 14, height: 1.5)),
                      const Spacer(),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: kShaqatiPrimary.withOpacity(0.1),
                            child: Text(
                              (t['name'] as String)[0],
                              style: const TextStyle(
                                  color: kShaqatiPrimary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['name'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text(t['location'] as String,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🏙️ CITIES SECTION
// ---------------------------------------------------------------------------
class _CitiesSection extends StatelessWidget {
  final List<dynamic> properties;

  const _CitiesSection({required this.properties});

  @override
  Widget build(BuildContext context) {
    final cityStats = <String, Map<String, dynamic>>{};

    for (var p in properties) {
      final city = p['city']?.toString() ?? 'Unknown';
      if (!cityStats.containsKey(city)) {
        cityStats[city] = {
          'count': 0,
          'totalPrice': 0.0,
          'avgPrice': 0.0,
        };
      }
      cityStats[city]!['count']++;
      final price = (p['price'] as num?)?.toDouble() ?? 0.0;
      cityStats[city]!['totalPrice'] += price;
    }

    cityStats.forEach((city, stats) {
      final count = stats['count'] as int;
      if (count > 0) {
        stats['avgPrice'] = (stats['totalPrice'] as double) / count;
      }
    });

    final cityList = cityStats.entries.take(4).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Explore Cities",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: cityList.length,
            itemBuilder: (context, index) {
              final entry = cityList[index];
              final city = entry.key;
              final stats = entry.value;
              return InkWell(
                onTap: () {
                  final cityProps = properties
                      .where((p) => p['city']?.toString() == city)
                      .toList();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AllPropertiesScreen(allProperties: cityProps)),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_city,
                            color: kShaqatiPrimary, size: 28),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(city,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(height: 4),
                        Text("${stats['count']} Properties",
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                        const SizedBox(height: 2),
                        Text("Avg: \$${stats['avgPrice'].toStringAsFixed(0)}",
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kShaqatiPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 💡 INVESTMENT TIPS SECTION
// ---------------------------------------------------------------------------
class _InvestmentTipsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tips = [
      {
        'icon': Icons.analytics,
        'title': 'Market Analysis',
        'description': 'Research local market trends before investing',
        'color': Colors.blue,
      },
      {
        'icon': Icons.location_on,
        'title': 'Location Matters',
        'description': 'Properties in city centers have higher value',
        'color': Colors.green,
      },
      {
        'icon': Icons.account_balance_wallet,
        'title': 'Budget Planning',
        'description': 'Set a clear budget including all costs',
        'color': Colors.orange,
      },
      {
        'icon': Icons.gavel,
        'title': 'Legal Considerations',
        'description': 'Verify ownership and legal documents',
        'color': Colors.purple,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Investment Tips",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: tips.length,
            itemBuilder: (context, index) {
              final tip = tips[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (tip['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(tip['icon'] as IconData,
                          color: tip['color'] as Color, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(tip['title'] as String,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(tip['description'] as String,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🎥 VIDEO SECTION
// ---------------------------------------------------------------------------
class _VideoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Watch Our Story",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 20),
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kShaqatiPrimary, kShaqatiDark],
                      ),
                    ),
                  ),
                  Center(
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow,
                            color: kShaqatiPrimary, size: 48),
                      ),
                      onPressed: () {
                        // Video playback can be implemented with video_player
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Video playback coming soon!')),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: const Text(
                      "Discover how SHAQATI is transforming real estate in Palestine",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
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

// ---------------------------------------------------------------------------
// ❓ FAQ SECTION
// ---------------------------------------------------------------------------
class _FAQSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'question': 'How do I search for a property?',
        'answer':
            'Use our search bar to filter by location, price, type, and operation. You can also browse by categories on the home page.',
      },
      {
        'question': 'How do I request a rental contract?',
        'answer':
            'Click on any property listing, then use the "Request Contract" button. Fill out the form and submit your request.',
      },
      {
        'question': 'What is the payment process?',
        'answer':
            'Payments are made through the dashboard. You can view pending payments, pay online, and download receipts.',
      },
      {
        'question': 'How do I submit a maintenance request?',
        'answer':
            'Go to your tenant dashboard, click on "Maintenance", then "New Request". Fill in the details and submit.',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Frequently Asked Questions",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 20),
          ...faqs.map((faq) => _FAQItem(
                question: faq['question'] as String,
                answer: faq['answer'] as String,
              )),
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({required this.question, required this.answer});

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ExpansionTile(
        title: Text(widget.question,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.answer,
                style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 📰 LATEST NEWS SECTION
// ---------------------------------------------------------------------------
class _LatestNewsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final news = [
      {
        'title': 'Real Estate Market Trends in Palestine 2024',
        'date': 'March 15, 2024',
        'image': null,
      },
      {
        'title': 'New Properties Added This Week',
        'date': 'March 10, 2024',
        'image': null,
      },
      {
        'title': 'Investment Opportunities in Nablus',
        'date': 'March 5, 2024',
        'image': null,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Latest News & Insights",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kTextDark)),
              TextButton(
                onPressed: () {
                  // Navigate to full news page
                },
                child: const Text("View All",
                    style: TextStyle(color: kShaqatiPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: news.length,
              itemBuilder: (context, index) {
                final article = news[index];
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kShaqatiPrimary.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Icon(Icons.article,
                              size: 50,
                              color: kShaqatiPrimary.withOpacity(0.3)),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(article['title'] as String,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(height: 4),
                              Text(article['date'] as String,
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🎯 SMART SUGGESTIONS SECTION (User Preferences Based)
// ---------------------------------------------------------------------------
class _SmartSuggestionsSection extends StatelessWidget {
  final List<dynamic> properties;

  const _SmartSuggestionsSection({required this.properties});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              kShaqatiPrimary.withOpacity(0.05),
              kShaqatiDark.withOpacity(0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: kShaqatiPrimary.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: kShaqatiPrimary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kShaqatiPrimary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kShaqatiPrimary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Smart Suggestions",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Set your preferences and find your perfect property",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Open Preferences Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _showPreferencesDialog(context, properties);
                },
                icon: const Icon(Icons.filter_list_rounded, size: 24),
                label: const Text(
                  "Set Your Preferences",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kShaqatiPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPreferencesDialog(BuildContext context, List<dynamic> properties) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PreferencesDialog(properties: properties),
    );
  }

}

// AI Smart Suggestions Dialog
class _AISuggestionsDialog extends StatefulWidget {
  final List<dynamic> properties;

  const _AISuggestionsDialog({required this.properties});

  @override
  State<_AISuggestionsDialog> createState() => _AISuggestionsDialogState();
}

class _AISuggestionsDialogState extends State<_AISuggestionsDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _suggestions = [];
  String _aiInsight = '';

  @override
  void initState() {
    super.initState();
    _generateAISuggestions();
  }

  void _generateAISuggestions() {
    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      final suggestions = <Map<String, dynamic>>[];

      // Analyze properties
      final analysis = _analyzePropertiesForAI();

      // ✅ Generate SIMPLE smart suggestions based on REAL database analysis
      // فقط الأشياء البسيطة والمعروفة في المشروع
      final typeCounts = analysis['typeCounts'] as Map<String, int>;
      final operationCounts = analysis['operationCounts'] as Map<String, int>;
      
      // تحليل عدد الغرف والحمامات
      final bedroomCounts = <int, int>{};
      final bathroomCounts = <int, int>{};
      
      for (var prop in widget.properties) {
        if (prop['status'] != 'available' || prop['verified'] != true) continue;
        
        final bedrooms = (prop['bedrooms'] as num?)?.toInt();
        if (bedrooms != null && bedrooms > 0) {
          bedroomCounts[bedrooms] = (bedroomCounts[bedrooms] ?? 0) + 1;
        }
        
        final bathrooms = (prop['bathrooms'] as num?)?.toInt();
        if (bathrooms != null && bathrooms > 0) {
          bathroomCounts[bathrooms] = (bathroomCounts[bathrooms] ?? 0) + 1;
        }
      }

      // 1. عدد الغرف (بسيط ومعروف)
      if (bedroomCounts.isNotEmpty) {
        final popularBedrooms = bedroomCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        // أفضل 2 خيارات للغرف
        for (var entry in popularBedrooms.take(2)) {
          final count = entry.value;
          final rooms = entry.key;
          if (count > 0) {
            suggestions.add({
              'title': 'شقق ب$rooms غرف',
              'description': '$count عقار متاح',
              'icon': Icons.bed_rounded,
              'color': Colors.blue,
              'filters': {
                'bedrooms': rooms,
              },
            });
          }
        }
      }

      // 2. عدد الحمامات (بسيط ومعروف)
      if (bathroomCounts.isNotEmpty) {
        final popularBathrooms = bathroomCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        // أفضل خيار للحمامات
        final topBathroom = popularBathrooms.first;
        if (topBathroom.value > 0) {
          suggestions.add({
            'title': 'شقق ب${topBathroom.key} حمام',
            'description': '${topBathroom.value} عقار متاح',
            'icon': Icons.bathtub_rounded,
            'color': Colors.teal,
            'filters': {
              'bathrooms': topBathroom.key,
            },
          });
        }
      }

      // 3. أنواع العقارات (بسيط ومعروف)
      if (typeCounts.isNotEmpty) {
        final popularTypes = typeCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        // أفضل نوعين
        for (var entry in popularTypes.take(2)) {
          final type = entry.key;
          final count = entry.value;
          if (count > 0) {
            final typeName = type == 'apartment' ? 'شقق' : 
                           type == 'house' ? 'بيوت' :
                           type == 'villa' ? 'فلل' : type;
            suggestions.add({
              'title': typeName,
              'description': '$count عقار متاح',
              'icon': Icons.home_rounded,
              'color': Colors.purple,
              'filters': {
                'type': type,
              },
            });
          }
        }
      }

      // 4. للإيجار / للبيع (بسيط ومعروف)
      if (operationCounts.isNotEmpty) {
        final rentCount = operationCounts['rent'] ?? 0;
        final saleCount = operationCounts['sale'] ?? 0;
        
        if (rentCount > 0) {
          suggestions.add({
            'title': 'للإيجار',
            'description': '$rentCount عقار متاح',
            'icon': Icons.assignment_rounded,
            'color': Colors.cyan,
            'filters': {
              'operation': 'rent',
            },
          });
        }
        
        if (saleCount > 0) {
          suggestions.add({
            'title': 'للبيع',
            'description': '$saleCount عقار متاح',
            'icon': Icons.sell_rounded,
            'color': Colors.deepOrange,
            'filters': {
              'operation': 'sale',
            },
          });
        }
      }

      // 5. المميزات البسيطة (بسيط ومعروف)
      if (analysis['withParking'] > 0) {
        suggestions.add({
          'title': 'بمواقف سيارات',
          'description': '${analysis['withParking']} عقار',
          'icon': Icons.local_parking_rounded,
          'color': Colors.green,
          'filters': {
            'amenities': 'Parking',
          },
        });
      }

      if (analysis['withElevator'] > 0) {
        suggestions.add({
          'title': 'بمصعد',
          'description': '${analysis['withElevator']} عقار',
          'icon': Icons.elevator_rounded,
          'color': Colors.indigo,
          'filters': {
            'amenities': 'Elevator',
          },
        });
      }

      if (analysis['furnished'] > 0) {
        suggestions.add({
          'title': 'مفروشة',
          'description': '${analysis['furnished']} عقار',
          'icon': Icons.chair_rounded,
          'color': Colors.brown,
          'filters': {
            'amenities': 'Furnished',
          },
        });
      }

      // Generate base insight from local analytics (من قاعدة البيانات الفعلية)
      final baseInsight = _generateAIInsight(analysis);

      setState(() {
        _suggestions = suggestions;
        _aiInsight = baseInsight;
        _isLoading = false;
      });
    });
  }

  Map<String, dynamic> _analyzePropertiesForAI() {
    final cityCounts = <String, int>{};
    final typeCounts = <String, int>{};
    final operationCounts = <String, int>{};
    final prices = <int>[];
    int withParking = 0;
    int withElevator = 0;
    int furnished = 0;

    for (var prop in widget.properties) {
      // ✅ فقط العقارات المتاحة والموافق عليها (من قاعدة البيانات الفعلية)
      if (prop['status'] != 'available' || prop['verified'] != true) {
        continue;
      }

      // Count cities
      if (prop['city'] != null) {
        final city = prop['city'].toString();
        cityCounts[city] = (cityCounts[city] ?? 0) + 1;
      }

      // Count types
      if (prop['type'] != null) {
        final type = prop['type'].toString();
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }

      // Count operations
      if (prop['operation'] != null) {
        final operation = prop['operation'].toString();
        operationCounts[operation] = (operationCounts[operation] ?? 0) + 1;
      }

      // Collect prices
      final price = (prop['price'] as num?)?.toInt();
      if (price != null && price > 0) {
        prices.add(price);
      }

      // ✅ تحليل المميزات من قاعدة البيانات الفعلية
      final amenities = (prop['amenities'] as List?) ?? [];
      final amenitiesLower = amenities.map((a) => a.toString().toLowerCase()).toList();
      
      if (amenitiesLower.contains('parking') || amenitiesLower.contains('garage')) {
        withParking++;
      }
      if (amenitiesLower.contains('elevator') || amenitiesLower.contains('lift')) {
        withElevator++;
      }
      if (amenitiesLower.contains('furnished')) {
        furnished++;
      }

      // ✅ لا نحتاج "near universities" - المستخدم يريد أشياء بسيطة
    }

    // Sort by count
    final popularTypes = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final avgPrice = prices.isNotEmpty
        ? prices.reduce((a, b) => a + b) / prices.length
        : 0.0;

    return {
      'cityCounts': cityCounts,
      'typeCounts': typeCounts,
      'operationCounts': operationCounts,
      'popularTypes': popularTypes.map((e) => e.key).toList(),
      'avgPrice': avgPrice,
      'withParking': withParking,
      'withElevator': withElevator,
      'furnished': furnished,
      'totalProperties': widget.properties.where((p) => 
        p['status'] == 'available' && p['verified'] == true
      ).length,
    };
  }

  String _generateAIInsight(Map<String, dynamic> analysis) {
    final total = analysis['totalProperties'] as int;
    final avgPrice = analysis['avgPrice'] as double;
    final popularType = analysis['popularTypes'].isNotEmpty
        ? analysis['popularTypes'][0] as String
        : '';

    if (total == 0) {
      return 'لا توجد عقارات متاحة حالياً في النظام.';
    }

    final insights = <String>[];

    insights.add('بناءً على ${total} عقار متاح في قاعدة البيانات:');

    if (avgPrice > 0) {
      insights.add('متوسط السعر: \$${avgPrice.toStringAsFixed(0)}');
    }

    if (popularType.isNotEmpty) {
      insights.add('أكثر الأنواع شيوعاً: $popularType');
    }

    final typeCounts = analysis['typeCounts'] as Map<String, int>;
    if (typeCounts.isNotEmpty) {
      final typeEntries = typeCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (typeEntries.length > 1) {
        insights.add('الأنواع المتاحة: ${typeEntries.take(3).map((e) => '${e.key} (${e.value})').join(', ')}');
      }
    }

    return insights.join('\n');
  }

  void _applySuggestion(Map<String, dynamic> suggestion) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FilteredPropertiesScreen(
          properties: widget.properties,
          filters: suggestion['filters'] as Map<String, dynamic>,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AI Smart Suggestions",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kTextDark,
                            ),
                          ),
                          Text(
                            "Personalized recommendations for you",
                            style: TextStyle(
                              fontSize: 14,
                              color: kTextLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Analyzing properties...'),
                          ],
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // AI Insight Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.purple.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lightbulb_rounded,
                                  color: Colors.purple,
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _aiInsight,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: kTextDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Suggestions
                          const Text(
                            "Recommended for You",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: kTextDark,
                            ),
                          ),
                          const SizedBox(height: 16),

                          ..._suggestions.map((suggestion) => _AISuggestionCard(
                                suggestion: suggestion,
                                onTap: () => _applySuggestion(suggestion),
                              )),

                          const SizedBox(height: 30),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// AI Suggestion Card
class _AISuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final VoidCallback onTap;

  const _AISuggestionCard({
    required this.suggestion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (suggestion['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  suggestion['icon'] as IconData,
                  color: suggestion['color'] as Color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion['title'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion['description'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Preferences Dialog Widget
class _PreferencesDialog extends StatefulWidget {
  final List<dynamic> properties;

  const _PreferencesDialog({required this.properties});

  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<_PreferencesDialog> {
  // User Preferences (بسيطة فقط)
  String? selectedType;
  String? selectedOperation;
  int? minPrice;
  int? maxPrice;
  int? minRooms;
  int? maxRooms;
  int? minBathrooms;
  int? minArea;
  int? maxArea;
  List<String> selectedServices = [];
  Set<String> selectedAmenities = {};

  // Available options (من قاعدة البيانات الفعلية)
  List<dynamic> availablePropertyTypes = []; // ✅ من قاعدة البيانات (PropertyType)
  List<String> availableOperations = [];
  List<String> availableAmenities = [];
  late int priceMin;
  late int priceMax;
  bool _isLoadingTypes = true;
  bool _isLoadingFacets = true;

  @override
  void initState() {
    super.initState();
    _analyzeProperties();
    _loadPropertyTypesFromDB();
    _loadFacetsFromDB();
  }

  // ✅ جلب أنواع العقارات من قاعدة البيانات (التي أضافها الأدمن)
  Future<void> _loadPropertyTypesFromDB() async {
    setState(() => _isLoadingTypes = true);
    try {
      final (success, result) = await ApiService.getPropertyTypes(activeOnly: true);
      if (success && result is List) {
        setState(() {
          availablePropertyTypes = result;
          _isLoadingTypes = false;
        });
      } else {
        // Fallback: استخدام الأنواع الموجودة في العقارات
        setState(() {
          _isLoadingTypes = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingTypes = false;
      });
    }
  }

  void _analyzeProperties() {
    final ops = <String>{};
    int? tempMinPrice;
    int tempMaxPrice = 0;
    for (var prop in widget.properties) {
      if (prop['operation'] != null) ops.add(prop['operation'].toString());
      final price = (prop['price'] as num?)?.toInt() ?? 0;
      if (price > 0) {
        tempMinPrice = tempMinPrice == null
            ? price
            : (price < tempMinPrice ? price : tempMinPrice);
        if (price > tempMaxPrice) tempMaxPrice = price;
      }
    }
    availableOperations = ops.toList()..sort();
    priceMin = tempMinPrice ?? 0;
    priceMax = tempMaxPrice;
  }

  Future<void> _loadFacetsFromDB() async {
    setState(() => _isLoadingFacets = true);
    try {
      final (ok, data) = await ApiService.getPropertyFacets();
      if (ok) {
        final ops = (data['operations'] as List?)?.map((e) => e.toString()).toList() ?? [];
        final am = (data['amenities'] as List?)?.map((e) => e.toString()).toList() ?? [];
        setState(() {
          if (ops.isNotEmpty) availableOperations = ops;
          availableAmenities = am;
          _isLoadingFacets = false;
        });
      } else {
        setState(() => _isLoadingFacets = false);
      }
    } catch (_) {
      setState(() => _isLoadingFacets = false);
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = widget.properties;

    // ✅ فقط الفلاتر البسيطة: النوع، العملية، السعر، الغرف، الحمامات، المميزات

    // Filter by type
    if (selectedType != null) {
      filtered = filtered
          .where((p) =>
              p['type']?.toString().toLowerCase() ==
              selectedType!.toLowerCase())
          .toList();
    }

    // Filter by operation
    if (selectedOperation != null) {
      filtered = filtered
          .where((p) =>
              p['operation']?.toString().toLowerCase() ==
              selectedOperation!.toLowerCase())
          .toList();
    }

    // Filter by price
    if (minPrice != null || maxPrice != null) {
      filtered = filtered.where((p) {
        final price = (p['price'] as num?)?.toInt() ?? 0;
        if (minPrice != null && price < minPrice!) return false;
        if (maxPrice != null && price > maxPrice!) return false;
        return true;
      }).toList();
    }

    // Filter by rooms (if property has rooms field)
    if (minRooms != null || maxRooms != null) {
      filtered = filtered.where((p) {
        final rooms =
            (p['rooms'] as num?)?.toInt() ?? (p['bedrooms'] as num?)?.toInt();
        if (rooms == null) return true; // Include if no room info
        if (minRooms != null && rooms < minRooms!) return false;
        if (maxRooms != null && rooms > maxRooms!) return false;
        return true;
      }).toList();
    }

    // Filter by bathrooms
    if (minBathrooms != null) {
      filtered = filtered.where((p) {
        final bathrooms = (p['bathrooms'] as num?)?.toInt();
        if (bathrooms == null) return true;
        return bathrooms >= minBathrooms!;
      }).toList();
    }

    // Filter by area
    if (minArea != null || maxArea != null) {
      filtered = filtered.where((p) {
        final area = (p['area'] as num?)?.toDouble();
        if (area == null) return true;
        if (minArea != null && area < minArea!) return false;
        if (maxArea != null && area > maxArea!) return false;
        return true;
      }).toList();
    }

    // Filter by amenities (ديناميكي من المحدد)
    for (final a in selectedAmenities) {
      filtered = filtered
          .where((p) => _propertyHasAmenity(p, a))
          .toList();
    }

    // Navigate to filtered results
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FilteredPropertiesScreen(
          properties: filtered,
          filters: {
            'type': selectedType,
            'operation': selectedOperation,
            'minPrice': minPrice,
            'maxPrice': maxPrice,
            'minRooms': minRooms,
            'maxRooms': maxRooms,
            'minBathrooms': minBathrooms,
            'minArea': minArea,
            'maxArea': maxArea,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kShaqatiPrimary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        color: kShaqatiPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Set Your Preferences",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kTextDark,
                            ),
                          ),
                          Text(
                            "Customize your property search",
                            style: TextStyle(
                              fontSize: 14,
                              color: kTextLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ✅ فقط الأشياء البسيطة: السعر، الغرف، الحمامات، النوع، العملية، المميزات
                    
                    // 1. Price Range (السعر - بسيط)
                    _buildSection(
                      title: "Price Range",
                      icon: Icons.attach_money_rounded,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildPriceField(
                                  label: "Min Price",
                                  value: minPrice,
                                  onChanged: (val) =>
                                      setState(() => minPrice = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPriceField(
                                  label: "Max Price",
                                  value: maxPrice,
                                  onChanged: (val) =>
                                      setState(() => maxPrice = val),
                                ),
                              ),
                            ],
                          ),
                          if (priceMin > 0 && priceMax > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                "Range: \$${priceMin.toStringAsFixed(0)} - \$${priceMax.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Operation Type (من قاعدة البيانات)
                    _buildSection(
                      title: "Operation Type",
                      icon: Icons.swap_horiz_rounded,
                      child: _isLoadingFacets
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          : Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildChip(
                                  label: "Any",
                                  isSelected: selectedOperation == null,
                                  onTap: () =>
                                      setState(() => selectedOperation = null),
                                ),
                                ...availableOperations.map((op) => _buildChip(
                                      label: op,
                                      isSelected: selectedOperation == op,
                                      onTap: () =>
                                          setState(() => selectedOperation = op),
                                    )),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Property Type (نوع العقار - من قاعدة البيانات)
                    _buildSection(
                      title: "Property Type",
                      icon: Icons.home_work_rounded,
                      child: _isLoadingTypes
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildChip(
                                  label: "Any",
                                  isSelected: selectedType == null,
                                  onTap: () => setState(() => selectedType = null),
                                ),
                                // ✅ استخدام الأنواع من قاعدة البيانات (التي أضافها الأدمن)
                                ...availablePropertyTypes.map((type) {
                                  final typeName = type['name']?.toString() ?? '';
                                  final displayName = type['displayName']?.toString() ?? typeName;
                                  return _buildChip(
                                    label: displayName,
                                    isSelected: selectedType == typeName,
                                    onTap: () => setState(() => selectedType = typeName),
                                  );
                                }),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Number of Rooms (عدد الغرف - بسيط)
                    _buildSection(
                      title: "Number of Rooms",
                      icon: Icons.bed_rounded,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              label: "Min Rooms",
                              value: minRooms,
                              onChanged: (val) =>
                                  setState(() => minRooms = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberField(
                              label: "Max Rooms",
                              value: maxRooms,
                              onChanged: (val) =>
                                  setState(() => maxRooms = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Number of Bathrooms Section
                    _buildSection(
                      title: "Number of Bathrooms",
                      icon: Icons.bathtub_rounded,
                      child: _buildNumberField(
                        label: "Minimum Bathrooms",
                        value: minBathrooms,
                        onChanged: (val) => setState(() => minBathrooms = val),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Area Section
                    _buildSection(
                      title: "Area (Square Meters)",
                      icon: Icons.square_foot_rounded,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildNumberField(
                              label: "Min Area (m²)",
                              value: minArea,
                              onChanged: (val) => setState(() => minArea = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNumberField(
                              label: "Max Area (m²)",
                              value: maxArea,
                              onChanged: (val) => setState(() => maxArea = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amenities Section (من قاعدة البيانات)
                    _buildSection(
                      title: "Amenities & Features",
                      icon: Icons.star_rounded,
                      child: _isLoadingFacets
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          : availableAmenities.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    "No amenities in database",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                )
                              : Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: availableAmenities.map((a) {
                                    final selected = selectedAmenities.contains(a);
                                    return _buildAmenityChip(
                                      label: a,
                                      icon: _amenityIcon(a),
                                      value: selected,
                                      onChanged: (val) => setState(() {
                                        if (val) {
                                          selectedAmenities.add(a);
                                        } else {
                                          selectedAmenities.remove(a);
                                        }
                                      }),
                                    );
                                  }).toList(),
                                ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
              // Apply Button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kShaqatiPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      "Find Properties",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: kShaqatiPrimary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: kShaqatiPrimary.withOpacity(0.2),
      checkmarkColor: kShaqatiPrimary,
      labelStyle: TextStyle(
        color: isSelected ? kShaqatiPrimary : kTextDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? kShaqatiPrimary : Colors.grey[300]!,
        width: isSelected ? 2 : 1,
      ),
    );
  }

  Widget _buildAmenityChip({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: kShaqatiPrimary.withOpacity(0.2),
      checkmarkColor: kShaqatiPrimary,
      labelStyle: TextStyle(
        color: value ? kShaqatiPrimary : kTextDark,
        fontWeight: value ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: value ? kShaqatiPrimary : Colors.grey[300]!,
        width: value ? 2 : 1,
      ),
    );
  }

  IconData _amenityIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('parking') || lower.contains('garage')) return Icons.local_parking_rounded;
    if (lower.contains('elevator') || lower.contains('lift')) return Icons.elevator_rounded;
    if (lower.contains('balcony')) return Icons.balcony_rounded;
    if (lower.contains('garden')) return Icons.grass_rounded;
    if (lower.contains('furnished')) return Icons.chair_rounded;
    if (lower.contains('air conditioning') || lower.contains('ac ') || lower == 'ac') return Icons.ac_unit_rounded;
    if (lower.contains('heating')) return Icons.thermostat_rounded;
    if (lower.contains('internet') || lower.contains('wifi') || lower.contains('wi-fi')) return Icons.wifi_rounded;
    if (lower.contains('pool')) return Icons.pool;
    if (lower.contains('pet')) return Icons.pets_rounded;
    return Icons.star_rounded;
  }

  bool _propertyHasAmenity(dynamic p, String amenity) {
    final list = (p['amenities'] as List?) ?? [];
    final lower = amenity.toLowerCase();
    final amenityLower = list.map((e) => e.toString().toLowerCase()).toList();
    if (amenityLower.any((a) => a.contains(lower) || lower.contains(a))) return true;
    if (p['parking'] == true && (lower.contains('parking') || lower.contains('garage'))) return true;
    if (p['elevator'] == true && (lower.contains('elevator') || lower.contains('lift'))) return true;
    if (p['balcony'] == true && lower.contains('balcony')) return true;
    if (p['garden'] == true && lower.contains('garden')) return true;
    if (p['furnished'] == true && lower.contains('furnished')) return true;
    if ((p['ac'] == true) && (lower.contains('ac') || lower.contains('air conditioning'))) return true;
    if (p['heating'] == true && lower.contains('heating')) return true;
    if (p['internet'] == true && (lower.contains('internet') || lower.contains('wifi'))) return true;
    return false;
  }

  Widget _buildPriceField({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: "0",
        prefixText: "\$ ",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: TextInputType.number,
      onChanged: (val) {
        final num = int.tryParse(val);
        onChanged(num);
      },
      controller: TextEditingController(
        text: value?.toString() ?? '',
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: "Any",
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: TextInputType.number,
      onChanged: (val) {
        final num = int.tryParse(val);
        onChanged(num);
      },
      controller: TextEditingController(
        text: value?.toString() ?? '',
      ),
    );
  }
}

// Filtered Properties Screen
class _FilteredPropertiesScreen extends StatelessWidget {
  final List<dynamic> properties;
  final Map<String, dynamic> filters;

  const _FilteredPropertiesScreen({
    required this.properties,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Found ${properties.length} Properties",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kShaqatiPrimary,
        foregroundColor: Colors.white,
      ),
      body: properties.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No properties found",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Try adjusting your preferences",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: properties.length,
              itemBuilder: (context, index) {
                final property = properties[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: property['images'] != null &&
                              (property['images'] as List).isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                property['images'][0],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.home_rounded,
                                  color: Colors.grey[400],
                                ),
                              ),
                            )
                          : Icon(Icons.home_rounded, color: Colors.grey[400]),
                    ),
                    title: Text(
                      property['title'] ?? 'Property',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (property['city'] != null)
                          Text('📍 ${property['city']}'),
                        if (property['price'] != null)
                          Text(
                            '\$${property['price']}',
                            style: TextStyle(
                              color: kShaqatiPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                      ],
                    ),
                    trailing:
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PropertyDetailsScreen(
                            property: property as Map<String, dynamic>,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🤝 PARTNERS SECTION
// ---------------------------------------------------------------------------
class _PartnersSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final partners = [
      {'name': 'Partner 1', 'logo': null},
      {'name': 'Partner 2', 'logo': null},
      {'name': 'Partner 3', 'logo': null},
      {'name': 'Partner 4', 'logo': null},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Our Partners & Agents",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: partners.length,
            itemBuilder: (context, index) {
              final partner = partners[index];
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 5,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Center(
                  child: Text(partner['name'] as String,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700])),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
