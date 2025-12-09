import 'dart:async';
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
// 🧠 SHAQATI AI BRAIN (The Intelligent Logic Core)
// ---------------------------------------------------------------------------
class ShaqatiAIBrain {
  // قاعدة المعرفة "المدربة" (محاكاة لبيانات ضخمة ومعرفة بالسوق الفلسطيني)
  static final Map<String, String> _knowledgeBase = {
    "invest_advice":
        "For investment, I recommend looking at 2-bedroom apartments near universities in Nablus (Rafidia) or city centers in Ramallah. They have the highest rental yield (approx 5-7% annually).",
    "market_trend":
        "Currently, the market in Palestine is seeing a high demand for rentals due to university seasons. Buying prices are stable.",
    "contract_info":
        "Standard rental contracts are usually for 12 months. Make sure to check if utility bills are included in the rent.",
    "nablus":
        "Nablus is excellent for student housing investments, especially near An-Najah University. Prices are generally lower than Ramallah.",
    "ramallah":
        "Ramallah is the economic hub. Prices are higher, but appreciation value is the best in the country. Look for properties in Al-Masyoun or Al-Tireh.",
    "hebron":
        "Hebron has a strong family-oriented market. Large villas and spacious apartments are in high demand.",
    "jenin":
        "Jenin is growing rapidly. It's a hidden gem for affordable land and residential investment.",
    "fees":
        "Usually, there is a brokerage fee of 2% to 5% depending on the deal type (Sale/Rent).",
  };

  // تحليل نية المستخدم (Intent Recognition Logic)
  static Map<String, dynamic> processQuery(
      String input, List<dynamic> properties) {
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

    // 4. البحث المتقدم (Advanced Filter Logic)
    // استخراج المدينة
    String? detectedCity;
    if (input.contains("nablus")) detectedCity = "Nablus";
    if (input.contains("ramallah")) detectedCity = "Ramallah";
    if (input.contains("hebron")) detectedCity = "Hebron";
    if (input.contains("jenin")) detectedCity = "Jenin";
    if (input.contains("gaza")) detectedCity = "Gaza";
    if (input.contains("bethlehem")) detectedCity = "Bethlehem";

    // استخراج العملية
    String? operation;
    if (input.contains("rent")) operation = "rent";
    if (input.contains("buy") || input.contains("sale")) operation = "sale";

    // استخراج النوع
    String? type;
    if (input.contains("apartment")) type = "Apartment";
    if (input.contains("villa")) type = "Villa";
    if (input.contains("office") || input.contains("commercial"))
      type = "Commercial";
    if (input.contains("land")) type = "Land";

    // تنفيذ المنطق إذا تم اكتشاف أي معيار للبحث
    if (detectedCity != null ||
        operation != null ||
        type != null ||
        input.contains("all") ||
        input.contains("reset")) {
      // حالة إعادة التعيين
      if (input.contains("reset") ||
          input.contains("clear") ||
          input.contains("show all")) {
        return {
          "type": "filter_action",
          "response":
              "🔄 I have reset all filters. Showing you all properties in Palestine.",
          "filter": {"reset": true}
        };
      }

      // حساب عدد النتائج المتوقعة لإعطاء رد ذكي
      int count = properties.where((p) {
        bool cityMatch = detectedCity == null ||
            (p['city']
                    ?.toString()
                    .toLowerCase()
                    .contains(detectedCity.toLowerCase()) ??
                false);
        bool opMatch = operation == null ||
            (p['operation']?.toString().toLowerCase() == operation);
        bool typeMatch = type == null ||
            (p['type']?.toString().toLowerCase().contains(type.toLowerCase()) ??
                false);
        return cityMatch && opMatch && typeMatch;
      }).length;

      String responseText = "✅ I found $count properties matching your request";
      if (detectedCity != null) responseText += " in $detectedCity";
      if (operation != null) responseText += " for $operation";
      responseText += ".\n\nI have updated the list behind this chat.";

      return {
        "type": "filter_action",
        "response": responseText,
        "filter": {
          "city": detectedCity,
          "operation": operation == "sale"
              ? "Sale"
              : (operation == "rent" ? "Rent" : null),
          "type": type
        }
      };
    }

    // 5. الرد الافتراضي (Fallback)
    return {
      "type": "chat",
      "response":
          "🤔 I understand you're interested in real estate, but could you be more specific? \nTry saying: 'Show me apartments in Ramallah' or 'Open Map'.",
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

  // --- 🔍 Core Filtering Logic ---
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
          String target = _selectedOperation.toLowerCase();
          if (target == "buy") target = "sale";
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

  // --- 🤖 AI Action Handler (The Bridge between AI and UI) ---
  void _handleAIAction(Map<String, dynamic> aiResult) {
    // CASE 1: Filter Action
    if (aiResult['type'] == 'filter_action') {
      final filters = aiResult['filter'];

      if (filters['reset'] == true) {
        setState(() {
          _selectedOperation = "All";
          _selectedType = "All";
          _searchQuery = "";
          _applyFilters();
        });
      } else {
        setState(() {
          if (filters['operation'] != null)
            _selectedOperation = filters['operation'];
          if (filters['type'] != null) _selectedType = filters['type'];
          // If city is mentioned, we put it in search query
          if (filters['city'] != null) _searchQuery = filters['city'];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,

      // --- Navbar ---
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

      // --- AI FAB ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
            context: context,
            builder: (context) => AIAssistantDialog(
                  onAction: _handleAIAction,
                  availableProperties: _allProperties, // Pass data to AI
                )),
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

            // --- Title & Count ---
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

            // --- Footer ---
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
          "🤖 Hello! I'm Shaqati AI.\nI am trained on the Palestinian market.\n\nAsk me anything! Examples:\n• 'Find a cheap apartment in Nablus'\n• 'Is Ramallah good for investment?'\n• 'Show me the map'"
    }
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

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

      // 🔥 Process with AI Brain
      final result =
          ShaqatiAIBrain.processQuery(userText, widget.availableProperties);

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

            // Input Area
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
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
  final VoidCallback onOpenDrawer;

  const _ShaqatiNavbar({
    required this.isLoggedIn,
    required this.onLogin,
    required this.onOpenDrawer,
  });

  @override
  State<_ShaqatiNavbar> createState() => _ShaqatiNavbarState();
}

class _ShaqatiNavbarState extends State<_ShaqatiNavbar> {
  int _unreadCount = 0;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _checkNotifications();
    }
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
      height: 85,
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SafeArea(
        child: Row(
          children: [
            Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      kPrimaryGradient.createShader(bounds),
                  child: const Icon(Icons.home_work_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(width: 10),
                const Text("SHAQATI",
                    style: TextStyle(
                        color: kShaqatiDark,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5)),
              ],
            ),
            const Spacer(),
            if (isDesktop) ...[
              _navLink("Buy"),
              _navLink("Rent"),
              _navLink("Sell"),
              _navLink("Services"),
              _navLink("Agents"),
              const SizedBox(width: 30),
            ],
            if (widget.isLoggedIn) ...[
              IconButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ChatListScreen())),
                icon: const Icon(Icons.message_outlined,
                    color: kShaqatiDark, size: 28),
                tooltip: "Messages",
              ),
              const SizedBox(width: 15),
              Stack(
                children: [
                  IconButton(
                    onPressed: _showNotificationsDialog,
                    icon: const Icon(Icons.notifications_outlined,
                        color: kShaqatiDark, size: 28),
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
              const SizedBox(width: 15),
              IconButton(
                  onPressed: widget.onOpenDrawer,
                  icon: const Icon(Icons.menu, color: kShaqatiDark, size: 34)),
            ] else
              Container(
                decoration: BoxDecoration(
                    gradient: kPrimaryGradient,
                    borderRadius: BorderRadius.circular(10)),
                child: ElevatedButton(
                  onPressed: widget.onLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Sign In",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16)),
                ),
              ),
            if (!widget.isLoggedIn && !isDesktop) ...[
              const SizedBox(width: 15),
              IconButton(
                  onPressed: widget.onOpenDrawer,
                  icon: const Icon(Icons.menu, color: kShaqatiDark, size: 34)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _navLink(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(text,
          style: const TextStyle(
              color: kTextDark, fontWeight: FontWeight.w700, fontSize: 16)),
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
    return SizedBox(
      height: 480,
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
                  const Text("Search properties for sale and rent in Palestine",
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
                childAspectRatio: 0.90),
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
