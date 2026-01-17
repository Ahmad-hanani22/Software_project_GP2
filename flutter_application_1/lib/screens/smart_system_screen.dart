import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/smart_system_service.dart';
import 'package:flutter_application_1/screens/property_details_screen.dart';
import 'package:flutter_application_1/screens/map_screen.dart';
import 'package:flutter_application_1/screens/enhanced_map_screen.dart';
import 'package:flutter_application_1/services/smart_system_preferences.dart';
import 'package:flutter_application_1/widgets/smart_system_tutorial.dart';
import 'package:flutter_application_1/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartSystemScreen extends StatefulWidget {
  const SmartSystemScreen({super.key});

  @override
  State<SmartSystemScreen> createState() => _SmartSystemScreenState();
}

class _SmartSystemScreenState extends State<SmartSystemScreen> {
  List<dynamic> _recommendations = [];
  bool _isLoading = true;
  String? _error;
  dynamic _behaviorAnalysis;
  bool _isLoggedIn = false;

  // Filter variables
  String _searchQuery = '';
  String _sortBy = 'score'; // 'score', 'price_asc', 'price_desc', 'date'
  String? _filterCity;
  String? _filterType;
  String? _filterOperation;
  double? _minPrice;
  double? _maxPrice;
  int? _minBedrooms;
  int? _minBathrooms;
  double? _minArea;
  double? _maxArea;
  double? _minScore;

  // View Mode: 'list', 'grid', 'map', 'compact'
  String _viewMode = 'list';

  // Statistics
  Map<String, dynamic> _statistics = {};
  bool _isStatisticsExpanded = false; // For collapsible statistics

  // Saved Searches
  List<Map<String, dynamic>> _savedSearches = [];

  // Chatbot
  bool _isChatbotOpen = false;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<ChatMessage> _chatMessages = [];
  bool _isChatLoading = false;

  // Available options for filters
  List<String> _availableCities = [];
  final List<String> _propertyTypes = [
    'Apartment',
    'House',
    'Villa',
    'Studio',
    'Townhouse',
    'Penthouse'
  ];

  // Keys for tutorial
  final GlobalKey _filterButtonKey = GlobalKey();
  final GlobalKey _sortButtonKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _recommendationsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadSavedPreferences();
    _loadViewMode();
    _loadSavedSearches();
    _checkTutorial();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    setState(() {
      _isLoggedIn = token != null;
    });
    if (_isLoggedIn) {
      _loadRecommendations();
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Please login to get personalized recommendations';
      });
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final (success, recommendations, extraData) =
          await SmartSystemService.getSmartRecommendations(limit: 50);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (success) {
            _recommendations = recommendations;
            if (extraData != null) {
              _behaviorAnalysis = extraData['behaviorAnalysis'];
            }
            _loadAvailableCities();
            _calculateStatistics();
          } else {
            _error = extraData is String
                ? extraData
                : 'Failed to load recommendations. Please try again.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Connection error: ${e.toString()}';
        });
      }
    }
  }

  void _calculateStatistics() {
    if (_recommendations.isEmpty) return;

    // Calculate average recommendation score
    double totalScore = 0;
    int scoreCount = 0;
    Map<String, int> typeCount = {};
    Map<String, int> cityCount = {};
    int savedCount = 0; // This would come from backend

    for (var prop in _recommendations) {
      final score = (prop['recommendationScore'] as num?)?.toDouble() ?? 0.0;
      if (score > 0) {
        totalScore += score;
        scoreCount++;
      }

      final type = prop['type']?.toString() ?? 'Unknown';
      typeCount[type] = (typeCount[type] ?? 0) + 1;

      final city = prop['city']?.toString() ?? 'Unknown';
      cityCount[city] = (cityCount[city] ?? 0) + 1;
    }

    setState(() {
      _statistics = {
        'totalProperties': _recommendations.length,
        'averageScore': scoreCount > 0 ? (totalScore / scoreCount) : 0.0,
        'mostViewedType': typeCount.entries.isNotEmpty
            ? typeCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
            : 'N/A',
        'preferredCity': cityCount.entries.isNotEmpty
            ? cityCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
            : 'N/A',
        'savedCount': savedCount,
        'searchHistoryCount': 0, // Would come from backend
      };
    });
  }

  Future<void> _loadViewMode() async {
    final viewMode = await SmartSystemPreferences.loadViewMode();
    setState(() => _viewMode = viewMode);
  }

  Future<void> _loadSavedSearches() async {
    final searches = await SmartSystemPreferences.loadSavedSearches();
    setState(() => _savedSearches = searches);
  }

  void _loadAvailableCities() {
    final cities = _recommendations
        .map((p) => p['city']?.toString())
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    setState(() => _availableCities = cities);
  }

  Future<void> _loadSavedPreferences() async {
    final filters = await SmartSystemPreferences.loadFilters();
    final sortBy = await SmartSystemPreferences.loadSortBy();

    setState(() {
      _sortBy = sortBy;
      _filterCity = filters['city'];
      _filterType = filters['type'];
      _filterOperation = filters['operation'];
      _minPrice = filters['minPrice']?.toDouble();
      _maxPrice = filters['maxPrice']?.toDouble();
      _minBedrooms = filters['minBedrooms']?.toInt();
      _minBathrooms = filters['minBathrooms']?.toInt();
      _minArea = filters['minArea']?.toDouble();
      _maxArea = filters['maxArea']?.toDouble();
      _minScore = filters['minScore']?.toDouble();
    });
  }

  Future<void> _saveFiltersToPreferences() async {
    final filters = {
      'city': _filterCity,
      'type': _filterType,
      'operation': _filterOperation,
      'minPrice': _minPrice,
      'maxPrice': _maxPrice,
      'minBedrooms': _minBedrooms,
      'minBathrooms': _minBathrooms,
      'minArea': _minArea,
      'maxArea': _maxArea,
      'minScore': _minScore,
    };

    await SmartSystemPreferences.saveFilters(filters);
    await SmartSystemPreferences.saveSortBy(_sortBy);
  }

  Future<void> _checkTutorial() async {
    final shouldShow = await SmartSystemTutorial.shouldShowTutorial();
    if (shouldShow && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startTutorial());
    }
  }

  void _startTutorial() {
    final steps = [
      TutorialStep(
        targetKey: _searchKey,
        title: 'Search Recommendations',
        description:
            'Use the search bar to quickly find properties by name, city, or address.',
      ),
      TutorialStep(
        targetKey: _sortButtonKey,
        title: 'Sort Results',
        description:
            'Sort recommendations by best match, price, or date to find exactly what you need.',
      ),
      TutorialStep(
        targetKey: _filterButtonKey,
        title: 'Advanced Filters',
        description:
            'Apply detailed filters like city, type, price range, bedrooms, and more for precise results.',
      ),
      TutorialStep(
        targetKey: _recommendationsKey,
        title: 'View Recommendations',
        description:
            'Browse personalized property recommendations based on your preferences and behavior.',
      ),
    ];

    _showTutorialStep(0, steps);
  }

  void _showTutorialStep(int index, List<TutorialStep> steps) {
    if (index >= steps.length) {
      TutorialOverlayManager.hideTutorial();
      SmartSystemTutorial.markTutorialCompleted();
      return;
    }

    TutorialOverlayManager.showTutorialStep(
      context,
      steps[index],
      index + 1,
      steps.length,
      () => _showTutorialStep(index + 1, steps),
      () {
        TutorialOverlayManager.hideTutorial();
        SmartSystemTutorial.markTutorialCompleted();
      },
    );
  }

  List<dynamic> get _filteredRecommendations {
    var filtered = List<dynamic>.from(_recommendations);

    // Text search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        final city = (p['city'] ?? '').toString().toLowerCase();
        final address = (p['address'] ?? '').toString().toLowerCase();
        return title.contains(query) ||
            city.contains(query) ||
            address.contains(query);
      }).toList();
    }

    // City filter
    if (_filterCity != null && _filterCity!.isNotEmpty) {
      filtered = filtered.where((p) => p['city'] == _filterCity).toList();
    }

    // Type filter
    if (_filterType != null && _filterType!.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p['type']?.toString().toLowerCase() == _filterType!.toLowerCase())
          .toList();
    }

    // Operation filter (buy/rent)
    if (_filterOperation != null && _filterOperation!.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p['operation']?.toString().toLowerCase() ==
              _filterOperation!.toLowerCase())
          .toList();
    }

    // Price filter
    if (_minPrice != null) {
      filtered = filtered.where((p) {
        final price = (p['price'] as num?)?.toDouble() ?? 0.0;
        return price >= _minPrice!;
      }).toList();
    }
    if (_maxPrice != null) {
      filtered = filtered.where((p) {
        final price = (p['price'] as num?)?.toDouble() ?? 0.0;
        return price <= _maxPrice!;
      }).toList();
    }

    // Bedrooms filter
    if (_minBedrooms != null) {
      filtered = filtered.where((p) {
        final bedrooms = (p['bedrooms'] as num?)?.toInt() ?? 0;
        return bedrooms >= _minBedrooms!;
      }).toList();
    }

    // Bathrooms filter
    if (_minBathrooms != null) {
      filtered = filtered.where((p) {
        final bathrooms = (p['bathrooms'] as num?)?.toInt() ?? 0;
        return bathrooms >= _minBathrooms!;
      }).toList();
    }

    // Area filter
    if (_minArea != null) {
      filtered = filtered.where((p) {
        final area = (p['area'] as num?)?.toDouble() ?? 0.0;
        return area >= _minArea!;
      }).toList();
    }
    if (_maxArea != null) {
      filtered = filtered.where((p) {
        final area = (p['area'] as num?)?.toDouble() ?? 0.0;
        return area <= _maxArea!;
      }).toList();
    }

    // Score filter
    if (_minScore != null) {
      filtered = filtered.where((p) {
        final score = (p['recommendationScore'] as num?)?.toDouble() ?? 0.0;
        return score >= _minScore!;
      }).toList();
    }

    // Sorting
    switch (_sortBy) {
      case 'score':
        filtered.sort((a, b) {
          final scoreA = (a['recommendationScore'] as num?)?.toDouble() ?? 0.0;
          final scoreB = (b['recommendationScore'] as num?)?.toDouble() ?? 0.0;
          return scoreB.compareTo(scoreA);
        });
        break;
      case 'price_asc':
        filtered.sort((a, b) {
          final priceA = (a['price'] as num?)?.toDouble() ?? 0.0;
          final priceB = (b['price'] as num?)?.toDouble() ?? 0.0;
          return priceA.compareTo(priceB);
        });
        break;
      case 'price_desc':
        filtered.sort((a, b) {
          final priceA = (a['price'] as num?)?.toDouble() ?? 0.0;
          final priceB = (b['price'] as num?)?.toDouble() ?? 0.0;
          return priceB.compareTo(priceA);
        });
        break;
      case 'date':
        filtered.sort((a, b) {
          final dateA = (a['createdAt'] ?? '').toString();
          final dateB = (b['createdAt'] ?? '').toString();
          return dateB.compareTo(dateA);
        });
        break;
    }

    return filtered;
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _filterCity = null;
      _filterType = null;
      _filterOperation = null;
      _minPrice = null;
      _maxPrice = null;
      _minBedrooms = null;
      _minBathrooms = null;
      _minArea = null;
      _maxArea = null;
      _minScore = null;
      _sortBy = 'score';
    });
    _saveFiltersToPreferences();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_filterCity != null) count++;
    if (_filterType != null) count++;
    if (_filterOperation != null) count++;
    if (_minPrice != null) count++;
    if (_maxPrice != null) count++;
    if (_minBedrooms != null) count++;
    if (_minBathrooms != null) count++;
    if (_minArea != null) count++;
    if (_maxArea != null) count++;
    if (_minScore != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          '🧠 Smart System',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          // View Mode Toggle
          PopupMenuButton<String>(
            icon: Icon(_getViewModeIcon(_viewMode)),
            tooltip: 'View Mode',
            onSelected: (mode) {
              setState(() => _viewMode = mode);
              SmartSystemPreferences.saveViewMode(mode);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'list',
                child: Row(
                  children: [
                    Icon(Icons.list, size: 20),
                    SizedBox(width: 8),
                    Text('List View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'grid',
                child: Row(
                  children: [
                    Icon(Icons.grid_view, size: 20),
                    SizedBox(width: 8),
                    Text('Grid View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'compact',
                child: Row(
                  children: [
                    Icon(Icons.view_compact, size: 20),
                    SizedBox(width: 8),
                    Text('Compact View'),
                  ],
                ),
              ),
            ],
          ),
          // Tutorial reset button
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Show Tutorial',
            onPressed: () async {
              await SmartSystemTutorial.resetTutorial();
              _startTutorial();
            },
          ),
          // Sort button
          IconButton(
            key: _sortButtonKey,
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onPressed: () => _showSortDialog(),
          ),
          // Filter button
          Stack(
            key: _filterButtonKey,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Filter',
                onPressed: () => _showAdvancedFilters(),
              ),
              if (_activeFiltersCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_activeFiltersCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? _buildLoadingState()
              : _error != null
                  ? _buildErrorState()
                  : _buildContentWithFilters(),
          // Chatbot overlay
          if (_isChatbotOpen) _buildChatbotWidget(),
        ],
      ),
      floatingActionButton: _isChatbotOpen
          ? null
          : Stack(
              alignment: Alignment.bottomRight,
              children: [
                // Quick Actions Bar
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _buildQuickActionsBar(),
                ),
                // Chatbot button
                Positioned(
                  bottom: 80,
                  right: 0,
                  child: FloatingActionButton(
                    heroTag: 'chatbot',
                    backgroundColor: const Color(0xFF2E7D32),
                    onPressed: () {
                      setState(() {
                        _isChatbotOpen = true;
                        if (_chatMessages.isEmpty) {
                          _initializeChatbot();
                        }
                      });
                    },
                    child: const Icon(Icons.chat, color: Colors.white),
                  ),
                ),
              ],
            ),
    );
  }

  IconData _getViewModeIcon(String mode) {
    switch (mode) {
      case 'grid':
        return Icons.grid_view;
      case 'compact':
        return Icons.view_compact;
      case 'map':
        return Icons.map;
      default:
        return Icons.list;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing your preferences...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Finding the best properties for you',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _error ?? 'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (!_isLoggedIn)
              Text(
                'Login to get personalized property recommendations',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoggedIn
                  ? _loadRecommendations
                  : () {
                      Navigator.pushNamed(context, '/login');
                    },
              icon: Icon(_isLoggedIn ? Icons.refresh : Icons.login),
              label: Text(_isLoggedIn ? 'Retry' : 'Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentWithFilters() {
    return Column(
      children: [
        // Statistics Dashboard (Collapsible)
        if (_statistics.isNotEmpty && _isLoggedIn)
          _buildCollapsibleStatistics(),

        // Search bar with Saved Searches
        Container(
          key: _searchKey,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search recommendations...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              const SizedBox(width: 8),
              // Saved Searches button
              IconButton(
                icon: const Icon(Icons.bookmark),
                tooltip: 'Saved Searches',
                onPressed: () => _showSavedSearchesDialog(),
                color: _savedSearches.isNotEmpty
                    ? const Color(0xFF2E7D32)
                    : Colors.grey,
              ),
            ],
          ),
        ),

        // Results count
        if (_searchQuery.isNotEmpty || _activeFiltersCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '${_filteredRecommendations.length} result${_filteredRecommendations.length != 1 ? 's' : ''} found',
                  style: TextStyle(
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Clear Filters'),
                ),
              ],
            ),
          ),

        // Recommendations list
        Expanded(
          key: _recommendationsKey,
          child: RefreshIndicator(
            onRefresh: _loadRecommendations,
            color: const Color(0xFF2E7D32),
            child: _filteredRecommendations.isEmpty
                ? _buildEmptyFilteredState()
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Header Section
                      _buildHeaderSection(),

                      // List/Grid/Compact based on view mode
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: _buildPropertiesView(),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2E7D32),
              const Color(0xFF1B5E20),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
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
                        'Personalized Recommendations',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'AI-powered property suggestions based on your preferences',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_behaviorAnalysis != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getUserTypeIcon(_behaviorAnalysis['userType']),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Profile',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getUserTypeText(_behaviorAnalysis['userType']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildSortOption('score', 'Best Match', Icons.star),
            _buildSortOption(
                'price_asc', 'Price: Low to High', Icons.arrow_upward),
            _buildSortOption(
                'price_desc', 'Price: High to Low', Icons.arrow_downward),
            _buildSortOption('date', 'Newest First', Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading:
          Icon(icon, color: isSelected ? const Color(0xFF2E7D32) : Colors.grey),
      title: Text(label),
      trailing:
          isSelected ? const Icon(Icons.check, color: Color(0xFF2E7D32)) : null,
      onTap: () {
        setState(() => _sortBy = value);
        SmartSystemPreferences.saveSortBy(value);
        Navigator.pop(context);
      },
    );
  }

  void _showAdvancedFilters() {
    final minPriceController =
        TextEditingController(text: _minPrice?.toStringAsFixed(0));
    final maxPriceController =
        TextEditingController(text: _maxPrice?.toStringAsFixed(0));
    final minBedroomsController =
        TextEditingController(text: _minBedrooms?.toString());
    final minBathroomsController =
        TextEditingController(text: _minBathrooms?.toString());
    final minAreaController =
        TextEditingController(text: _minArea?.toStringAsFixed(0));
    final maxAreaController =
        TextEditingController(text: _maxArea?.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Advanced Filters',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _resetFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('Reset All'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // City
              _buildFilterSection(
                'City',
                DropdownButtonFormField<String>(
                  value: _filterCity,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Cities')),
                    ..._availableCities.map((city) =>
                        DropdownMenuItem(value: city, child: Text(city))),
                  ],
                  onChanged: (value) => setState(() => _filterCity = value),
                ),
              ),

              // Property Type
              _buildFilterSection(
                'Property Type',
                DropdownButtonFormField<String>(
                  value: _filterType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Types')),
                    ..._propertyTypes.map((type) =>
                        DropdownMenuItem(value: type, child: Text(type))),
                  ],
                  onChanged: (value) => setState(() => _filterType = value),
                ),
              ),

              // Operation
              _buildFilterSection(
                'Operation',
                DropdownButtonFormField<String>(
                  value: _filterOperation,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'sale', child: Text('Buy')),
                    DropdownMenuItem(value: 'rent', child: Text('Rent')),
                  ],
                  onChanged: (value) =>
                      setState(() => _filterOperation = value),
                ),
              ),

              // Price Range
              _buildFilterSection(
                'Price Range',
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Min Price',
                          border: OutlineInputBorder(),
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() => _minPrice = double.tryParse(value));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Max Price',
                          border: OutlineInputBorder(),
                          prefixText: '\$',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() => _maxPrice = double.tryParse(value));
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Bedrooms & Bathrooms
              _buildFilterSection(
                'Bedrooms & Bathrooms',
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minBedroomsController,
                        decoration: const InputDecoration(
                          labelText: 'Min Bedrooms',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() => _minBedrooms = int.tryParse(value));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minBathroomsController,
                        decoration: const InputDecoration(
                          labelText: 'Min Bathrooms',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() => _minBathrooms = int.tryParse(value));
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Area
              _buildFilterSection(
                'Area (m²)',
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: minAreaController,
                        decoration: const InputDecoration(
                          labelText: 'Min Area',
                          border: OutlineInputBorder(),
                          suffixText: 'm²',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() => _minArea = double.tryParse(value));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: maxAreaController,
                        decoration: const InputDecoration(
                          labelText: 'Max Area',
                          border: OutlineInputBorder(),
                          suffixText: 'm²',
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() => _maxArea = double.tryParse(value));
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Match Score
              _buildFilterSection(
                'Minimum Match Score (%)',
                Column(
                  children: [
                    Slider(
                      value: _minScore ?? 0,
                      min: 0,
                      max: 100,
                      divisions: 10,
                      label: '${(_minScore ?? 0).toInt()}%',
                      onChanged: (value) => setState(() => _minScore = value),
                    ),
                    Text(
                      '${(_minScore ?? 0).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Apply/Cancel buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _saveFiltersToPreferences();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 24),
            const Text(
              'No properties match your filters',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your search criteria',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _resetFilters,
              child: const Text('Clear All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getUserTypeIcon(String? userType) {
    switch (userType) {
      case 'student':
        return Icons.school_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      case 'employee':
        return Icons.work_rounded;
      case 'investor':
        return Icons.trending_up_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _getUserTypeText(String? userType) {
    switch (userType) {
      case 'student':
        return 'Student';
      case 'family':
        return 'Family';
      case 'employee':
        return 'Employee';
      case 'investor':
        return 'Investor';
      default:
        return 'User';
    }
  }

  Widget _buildPropertyCard(dynamic property) {
    final reasons = property['reasons'] as List<dynamic>? ?? [];
    final recommendationScore = property['recommendationScore'] ?? 0.0;
    final score =
        recommendationScore is num ? recommendationScore.toDouble() : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailsScreen(property: property),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Score Badge
            Stack(
              children: [
                if (property['images'] != null &&
                    (property['images'] as List).isNotEmpty)
                  ClipRRect(
                    child: Image.network(
                      property['images'][0],
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 220,
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 220,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                // Score Badge
                if (score > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2E7D32),
                            const Color(0xFF1B5E20),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${score.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16), // Reduced from 20
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    property['title'] ?? 'Property',
                    style: const TextStyle(
                      fontSize: 16, // Reduced from 20
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8), // Reduced from 12

                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${property['city'] ?? 'Unknown'}${property['address'] != null ? ' - ${property['address']}' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price
                  Row(
                    children: [
                      Text(
                        '\$${property['price'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 18, // Reduced from 24
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (property['operation'] == 'rent')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '/month',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12), // Reduced from 16

                  // Property Details
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (property['bedrooms'] != null)
                        _buildDetailChip(
                          Icons.bed_rounded,
                          '${property['bedrooms']} Bed${property['bedrooms'] > 1 ? 's' : ''}',
                        ),
                      if (property['bathrooms'] != null)
                        _buildDetailChip(
                          Icons.bathtub_rounded,
                          '${property['bathrooms']} Bath${property['bathrooms'] > 1 ? 's' : ''}',
                        ),
                      if (property['area'] != null)
                        _buildDetailChip(
                          Icons.square_foot_rounded,
                          '${property['area']} m²',
                        ),
                    ],
                  ),

                  // Recommendation Reasons (Compact)
                  if (reasons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: reasons.take(3).map((reason) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: const Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                reason.toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================
  // New Features
  // ========================================================

  Widget _buildCollapsibleStatistics() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Collapsible Header
            InkWell(
              onTap: () {
                setState(() {
                  _isStatisticsExpanded = !_isStatisticsExpanded;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.analytics,
                        color: Color(0xFF2E7D32),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your Statistics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isStatisticsExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expandable Content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Properties',
                            '${_statistics['totalProperties'] ?? 0}',
                            Icons.home,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Avg Score',
                            '${((_statistics['averageScore'] ?? 0.0) as double).toStringAsFixed(0)}%',
                            Icons.star,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Preferred Type',
                            _statistics['mostViewedType'] ?? 'N/A',
                            Icons.category,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Preferred City',
                            _statistics['preferredCity'] ?? 'N/A',
                            Icons.location_city,
                          ),
                        ),
                      ],
                    ),
                    if (_statistics['totalContracts'] != null ||
                        _statistics['totalPayments'] != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_statistics['totalContracts'] != null)
                            Expanded(
                              child: _buildStatCard(
                                'Contracts',
                                '${_statistics['totalContracts']}',
                                Icons.description,
                              ),
                            ),
                          if (_statistics['totalContracts'] != null &&
                              _statistics['totalPayments'] != null)
                            const SizedBox(width: 8),
                          if (_statistics['totalPayments'] != null)
                            Expanded(
                              child: _buildStatCard(
                                'Payments',
                                '${_statistics['totalPayments']}',
                                Icons.payment,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              crossFadeState: _isStatisticsExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsDashboard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2E7D32).withOpacity(0.1),
            const Color(0xFF1B5E20).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E7D32).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Your Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Properties',
                  '${_statistics['totalProperties'] ?? 0}',
                  Icons.home,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Avg Score',
                  '${((_statistics['averageScore'] ?? 0.0) as double).toStringAsFixed(0)}%',
                  Icons.star,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Preferred Type',
                  _statistics['mostViewedType'] ?? 'N/A',
                  Icons.category,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Preferred City',
                  _statistics['preferredCity'] ?? 'N/A',
                  Icons.location_city,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'favorites',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () => _showFavoritesScreen(),
            tooltip: 'Favorites',
            child: const Icon(Icons.favorite, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'analytics',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () => _showAnalyticsDialog(),
            tooltip: 'Analytics',
            child: const Icon(Icons.analytics, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'notifications',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () => _showNotificationsScreen(),
            tooltip: 'Notifications',
            child: const Icon(Icons.notifications, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'settings',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () => _showPreferencesDialog(),
            tooltip: 'Settings',
            child: const Icon(Icons.settings, color: Color(0xFF2E7D32)),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesView() {
    if (_filteredRecommendations.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    switch (_viewMode) {
      case 'grid':
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final property = _filteredRecommendations[index];
              return _buildPropertyCardGrid(property);
            },
            childCount: _filteredRecommendations.length,
          ),
        );
      case 'compact':
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final property = _filteredRecommendations[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPropertyCardCompact(property),
              );
            },
            childCount: _filteredRecommendations.length,
          ),
        );
      default: // 'list'
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final property = _filteredRecommendations[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPropertyCard(property),
              );
            },
            childCount: _filteredRecommendations.length,
          ),
        );
    }
  }

  Widget _buildPropertyCardGrid(dynamic property) {
    final score = (property['recommendationScore'] as num?)?.toDouble() ?? 0.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailsScreen(property: property),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (property['images'] != null &&
                    (property['images'] as List).isNotEmpty)
                  Image.network(
                    property['images'][0],
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_outlined, size: 32),
                      );
                    },
                  )
                else
                  Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_outlined, size: 32),
                  ),
                if (score > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${score.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property['title'] ?? 'Property',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property['city'] ?? 'Unknown',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${property['price'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
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

  Widget _buildPropertyCardCompact(dynamic property) {
    final score = (property['recommendationScore'] as num?)?.toDouble() ?? 0.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PropertyDetailsScreen(property: property),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: property['images'] != null &&
                        (property['images'] as List).isNotEmpty
                    ? Image.network(
                        property['images'][0],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_outlined),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_outlined),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property['title'] ?? 'Property',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property['city'] ?? 'Unknown',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${property['price'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
              if (score > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${score.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSavedSearchesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved Searches'),
        content: SizedBox(
          width: double.maxFinite,
          child: _savedSearches.isEmpty
              ? const Text('No saved searches yet')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _savedSearches.length,
                  itemBuilder: (context, index) {
                    final search = _savedSearches[index];
                    return ListTile(
                      leading:
                          const Icon(Icons.bookmark, color: Color(0xFF2E7D32)),
                      title: Text(search['name'] ?? 'Unnamed Search'),
                      subtitle: Text(
                        'Saved ${_formatDate(search['savedAt'])}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () async {
                          await SmartSystemPreferences.deleteSavedSearch(
                              search['name']);
                          _loadSavedSearches();
                          Navigator.pop(context);
                          _showSavedSearchesDialog();
                        },
                      ),
                      onTap: () {
                        final filters =
                            search['filters'] as Map<String, dynamic>?;
                        if (filters != null) {
                          setState(() {
                            _filterCity = filters['city'];
                            _filterType = filters['type'];
                            _filterOperation = filters['operation'];
                            _minPrice = filters['minPrice']?.toDouble();
                            _maxPrice = filters['maxPrice']?.toDouble();
                            _minBedrooms = filters['minBedrooms']?.toInt();
                            _minBathrooms = filters['minBathrooms']?.toInt();
                            _minArea = filters['minArea']?.toDouble();
                            _maxArea = filters['maxArea']?.toDouble();
                            _minScore = filters['minScore']?.toDouble();
                            _searchQuery = search['searchQuery'] ?? '';
                          });
                          _saveFiltersToPreferences();
                        }
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => _showSaveSearchDialog(),
            child: const Text('Save Current Search'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSaveSearchDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Search'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Search Name',
            hintText: 'e.g., "Apartments in Ramallah"',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final filters = {
                  'city': _filterCity,
                  'type': _filterType,
                  'operation': _filterOperation,
                  'minPrice': _minPrice,
                  'maxPrice': _maxPrice,
                  'minBedrooms': _minBedrooms,
                  'minBathrooms': _minBathrooms,
                  'minArea': _minArea,
                  'maxArea': _maxArea,
                  'minScore': _minScore,
                };
                await SmartSystemPreferences.saveSearch(
                  name: nameController.text,
                  filters: filters,
                  searchQuery: _searchQuery,
                );
                _loadSavedSearches();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search saved successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_statistics.isNotEmpty) ...[
                _buildStatRow(
                    'Total Properties', '${_statistics['totalProperties']}'),
                _buildStatRow('Average Score',
                    '${((_statistics['averageScore'] ?? 0.0) as double).toStringAsFixed(1)}%'),
                _buildStatRow(
                    'Preferred Type', _statistics['mostViewedType'] ?? 'N/A'),
                _buildStatRow(
                    'Preferred City', _statistics['preferredCity'] ?? 'N/A'),
              ] else
                const Text('No statistics available'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  void _showFavoritesScreen() {
    // Show saved searches as favorites
    if (_savedSearches.isNotEmpty) {
      _showSavedSearchesDialog();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.favorite, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text('Favorites'),
            ],
          ),
          content: const Text(
              'You don\'t have any saved searches yet. Save a search to add it to your favorites.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showSaveSearchDialog();
              },
              child: const Text('Save Search'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  void _showNotificationsScreen() {
    // Try to navigate to notifications screen, or show dialog
    Navigator.pushNamed(context, '/notifications').catchError((error) {
      // If notifications screen doesn't exist, show dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.notifications, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text('Notifications'),
            ],
          ),
          content: const Text(
              'Use the chatbot to get smart updates and recommendations.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isChatbotOpen = true);
                if (_chatMessages.isEmpty) {
                  _initializeChatbot();
                }
              },
              child: const Text('Open Chatbot'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return null;
    });
  }

  void _handleMapControl(String command, dynamic data) {
    // Handle map control commands from chatbot
    // This will be called when map is opened
  }

  void _showPreferencesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Settings'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.view_module, color: Color(0xFF2E7D32)),
                title: const Text('View Mode'),
                subtitle: Text('Current: ${_viewMode.toUpperCase()}'),
                onTap: () {
                  Navigator.pop(context);
                  _showViewModeDialog();
                },
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.filter_list, color: Color(0xFF2E7D32)),
                title: const Text('Filters'),
                subtitle: Text('Active: $_activeFiltersCount'),
                onTap: () {
                  Navigator.pop(context);
                  _showAdvancedFilters();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.bookmark, color: Color(0xFF2E7D32)),
                title: const Text('Saved Searches'),
                subtitle: Text('Count: ${_savedSearches.length}'),
                onTap: () {
                  Navigator.pop(context);
                  _showSavedSearchesDialog();
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showViewModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select View Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('List'),
              value: 'list',
              groupValue: _viewMode,
              onChanged: (value) {
                setState(() => _viewMode = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Grid'),
              value: 'grid',
              groupValue: _viewMode,
              onChanged: (value) {
                setState(() => _viewMode = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Compact'),
              value: 'compact',
              groupValue: _viewMode,
              onChanged: (value) {
                setState(() => _viewMode = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      } else {
        return '${(difference.inDays / 30).floor()} months ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // ========================================================
  // Chatbot Widget
  // ========================================================

  void _initializeChatbot() {
    setState(() {
      _chatMessages.add(ChatMessage(
        text: '''مرحباً! أنا مساعدك الذكي في نظام Smart System 🧠

يمكنني مساعدتك في:
• 🏠 البحث عن العقارات المناسبة
• 📊 تحليل إحصائياتك الشخصية
• 📄 متابعة عقودك ودفعاتك
• 🔧 طلبات الصيانة والشكاوى
• 🗺️ عرض العقارات على الخريطة
• 💰 الفواتير والودائع
• 📱 شرح جميع ميزات التطبيق
• ⚙️ استخدام الفلاتر والبحث المتقدم

اكتب سؤالك أو اختر أحد الخيارات السريعة...''',
        isUser: false,
      ));
      _chatMessages.add(ChatMessage(
        text: '',
        isUser: false,
        showQuickActions: true,
      ));
    });
    _scrollChatToBottom();
  }

  Widget _buildChatbotWidget() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E7D32),
                    const Color(0xFF1B5E20),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.psychology,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart System Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'مساعدك الذكي',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() => _isChatbotOpen = false);
                    },
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: _chatMessages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _chatScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          _chatMessages.length + (_isChatLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _chatMessages.length && _isChatLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2E7D32)),
                              ),
                            ),
                          );
                        }

                        final message = _chatMessages[index];

                        if (message.showQuickActions == true) {
                          return _buildChatQuickActions();
                        }

                        return _buildChatMessageBubble(message);
                      },
                    ),
            ),
            // Input field
            _buildChatInputField(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF2E7D32) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (message.actions != null && message.actions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...message.actions!.map((action) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ElevatedButton.icon(
                      onPressed: () => _handleChatAction(action),
                      icon: Icon(action.icon, size: 16),
                      label: Text(action.label),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatQuickActions() {
    // Dynamic quick actions based on available data and user role
    List<String> quickQuestions = [];

    if (_filteredRecommendations.isNotEmpty) {
      quickQuestions = [
        'ما هي أفضل عقار بالنسبة لي؟',
        'ما هو أرخص عقار متاح؟',
        'ما هي إحصائياتي؟',
        'ما هي عقودي الحالية؟',
        'ما هي دفعاتي المعلقة؟',
        'ما هي طلبات الصيانة الخاصة بي؟',
        'عرض العقارات على الخريطة',
        'ما هي الشكاوى المفتوحة؟',
        'كيف أستخدم الفلاتر؟',
        'ما هي التوصيات الذكية؟',
        'شرح نظام Smart System',
        'ما هي الفواتير المستحقة؟',
      ];
    } else {
      quickQuestions = [
        'ما هي التوصيات الذكية؟',
        'كيف يعمل نظام التوصيات؟',
        'ما هي إحصائياتي؟',
        'ما هي عقودي؟',
        'ما هي دفعاتي؟',
        'ما هي طلبات الصيانة؟',
        'كيف أستخدم الفلاتر؟',
        'كيف أبحث عن عقار؟',
        'شرح نظام Smart System',
        'ما هي الميزات المتاحة؟',
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: quickQuestions.map((q) {
          return ActionChip(
            label: Text(q),
            onPressed: () => _sendChatMessage(quickQuestion: q),
            backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
            labelStyle: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12),
            avatar: const Icon(
              Icons.bolt,
              size: 16,
              color: Color(0xFF2E7D32),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: 'اكتب سؤالك...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendChatMessage(),
              enabled: !_isChatLoading,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor:
                _isChatLoading ? Colors.grey : const Color(0xFF2E7D32),
            child: IconButton(
              icon: _isChatLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isChatLoading ? null : () => _sendChatMessage(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendChatMessage({String? quickQuestion}) async {
    final question = quickQuestion ?? _chatController.text.trim();
    if (question.isEmpty || _isChatLoading) return;

    // Check if question is about properties/recommendations - handle locally
    if (_shouldHandleLocally(question)) {
      _handleLocalQuestion(question);
      return;
    }

    // Note: Context is now built in backend with full database access

    setState(() {
      _chatMessages.add(ChatMessage(text: question, isUser: true));
      _isChatLoading = true;
      _chatController.clear();
      // Remove quick actions
      _chatMessages.removeWhere((msg) => msg.showQuickActions == true);
    });
    _scrollChatToBottom();

    // Extract filters from question or use current filters
    final extractedFilters = _extractFiltersFromQuestion(question);
    final filters = {
      'budget': extractedFilters['budget'] ?? _maxPrice?.toInt(),
      'city': extractedFilters['city'] ?? _filterCity,
      'rooms': extractedFilters['rooms'] ?? _minBedrooms,
      'type': extractedFilters['type'] ?? _filterType,
      'operation': extractedFilters['operation'] ?? _filterOperation,
    };

    // Use new endpoint with database integration
    final (success, response, extraData) = await AIService.askAIWithData(
      question: question,
      filters: filters,
    );

    // Parse response for actions and handle fallback
    List<ChatAction>? actions;
    String responseText = success ? response : '❌ خطأ: $response';

    // Smart fallback if AI says "not available"
    if (responseText.contains('not available') ||
        responseText.contains('غير موجودة') ||
        responseText.isEmpty) {
      responseText = _getSmartFallback(question);
    }

    // Check if response contains actionable items
    if (responseText.contains('عقار') ||
        responseText.contains('property') ||
        question.contains('عقار') ||
        question.contains('property')) {
      actions = [
        ChatAction(
          label: 'عرض العقارات',
          icon: Icons.home,
          action: 'show_properties',
        ),
        ChatAction(
          label: 'فتح الفلاتر',
          icon: Icons.tune,
          action: 'open_filters',
        ),
      ];
    } else if (responseText.contains('إحصائيات') ||
        responseText.contains('statistics')) {
      actions = [
        ChatAction(
          label: 'عرض الإحصائيات',
          icon: Icons.analytics,
          action: 'show_statistics',
        ),
      ];
    } else if (responseText.contains('بحث') ||
        responseText.contains('search')) {
      actions = [
        ChatAction(
          label: 'حفظ البحث',
          icon: Icons.bookmark,
          action: 'save_search',
        ),
      ];
    }

    // Check if we got data from backend
    Map<String, dynamic>? dataFromAI;
    List<dynamic>? propertiesFromAI;
    Map<String, dynamic>? summaryFromAI;

    if (extraData != null) {
      dataFromAI = extraData['data'] as Map<String, dynamic>?;
      summaryFromAI = extraData['summary'] as Map<String, dynamic>?;

      // Update statistics with backend data
      if (summaryFromAI != null) {
        final summary = summaryFromAI;
        setState(() {
          _statistics['totalContracts'] =
              (summary['totalContracts'] as num?)?.toInt() ?? 0;
          _statistics['totalPayments'] =
              (summary['totalPayments'] as num?)?.toInt() ?? 0;
          _statistics['totalMaintenance'] =
              (summary['totalMaintenance'] as num?)?.toInt() ?? 0;
          _statistics['totalComplaints'] =
              (summary['totalComplaints'] as num?)?.toInt() ?? 0;
        });
      }

      if (dataFromAI != null) {
        propertiesFromAI = dataFromAI['properties'] as List<dynamic>?;
        final contracts = dataFromAI['contracts'] as List<dynamic>?;
        final payments = dataFromAI['payments'] as List<dynamic>?;
        final maintenance = dataFromAI['maintenance'] as List<dynamic>?;
        final complaints = dataFromAI['complaints'] as List<dynamic>?;

        // Build comprehensive actions based on available data
        if (actions == null) {
          actions = [];
        }

        if (propertiesFromAI != null && propertiesFromAI.isNotEmpty) {
          actions.add(ChatAction(
            label: 'عرض ${propertiesFromAI.length} عقار',
            icon: Icons.home,
            action: 'show_properties',
          ));
          actions.add(ChatAction(
            label: 'عرض على الخريطة',
            icon: Icons.map,
            action: 'show_map',
            data: propertiesFromAI,
          ));
        }

        if (contracts != null && contracts.isNotEmpty) {
          actions.add(ChatAction(
            label: 'عرض العقود (${contracts.length})',
            icon: Icons.description,
            action: 'show_contracts',
            data: contracts,
          ));
        }

        if (payments != null && payments.isNotEmpty) {
          actions.add(ChatAction(
            label: 'عرض الدفعات (${payments.length})',
            icon: Icons.payment,
            action: 'show_payments',
            data: payments,
          ));
        }

        if (maintenance != null && maintenance.isNotEmpty) {
          actions.add(ChatAction(
            label: 'عرض الصيانة (${maintenance.length})',
            icon: Icons.build,
            action: 'show_maintenance',
            data: maintenance,
          ));
        }

        if (complaints != null && complaints.isNotEmpty) {
          actions.add(ChatAction(
            label: 'عرض الشكاوى (${complaints.length})',
            icon: Icons.report,
            action: 'show_complaints',
            data: complaints,
          ));
        }
      }
    }

    setState(() {
      _isChatLoading = false;
      _chatMessages.add(ChatMessage(
        text: responseText,
        isUser: false,
        actions: actions,
      ));
      _chatMessages.add(ChatMessage(
        text: '',
        isUser: false,
        showQuickActions: true,
      ));
    });
    _scrollChatToBottom();
  }

  String _getGreetingResponse() {
    final greetings = [
      'مرحباً! أهلاً وسهلاً بك في نظام Smart System 🏠\n\nكيف يمكنني مساعدتك اليوم؟',
      'مرحباً! أنا مساعدك الذكي في SHAQATI 🧠\n\nماذا تريد أن تفعل اليوم؟',
      'أهلاً! سعيد بلقائك 😊\n\nكيف يمكنني مساعدتك في العثور على العقار المثالي؟',
      'مرحباً بك! أنا هنا لمساعدتك 🎯\n\nما الذي تبحث عنه؟',
    ];
    return greetings[DateTime.now().millisecond % greetings.length];
  }

  String _getCasualResponse(String question) {
    final normalized = _normalizeArabicText(question);

    if (normalized.contains('كيفك') || normalized.contains('how are you')) {
      return 'أنا بخير، شكراً لسؤالك! 😊\n\nأنا هنا لمساعدتك في:\n• البحث عن العقارات المناسبة\n• متابعة عقودك ودفعاتك\n• عرض الإحصائيات\n• التحكم بالخريطة\n\nماذا تريد أن تفعل؟';
    }

    if (normalized.contains('شو بتعمل') ||
        normalized.contains('what are you doing') ||
        normalized.contains('what do you do')) {
      return 'أنا أعمل على مساعدتك في:\n🏠 البحث عن العقارات المناسبة\n📊 تحليل إحصائياتك\n🗺️ عرض العقارات على الخريطة\n📄 متابعة عقودك ودفعاتك\n🔧 طلبات الصيانة\n\nماذا تريد أن نبدأ به؟';
    }

    if (normalized.contains('شو الوضع') ||
        normalized.contains('how is it going') ||
        normalized.contains('whats up')) {
      final propertyCount = _filteredRecommendations.length;
      return 'الوضع ممتاز! 👍\n\nلديك حالياً:\n• $propertyCount عقار متاح\n• ${_activeFiltersCount} فلتر نشط\n• ${_savedSearches.length} بحث محفوظ\n\nكيف يمكنني مساعدتك؟';
    }

    if (normalized.contains('شكرا') ||
        normalized.contains('thanks') ||
        normalized.contains('thank you')) {
      return 'العفو! 😊\n\nأنا دائماً هنا لمساعدتك. هل تريد أي شيء آخر؟';
    }

    if (normalized.contains('مع السلامة') ||
        normalized.contains('bye') ||
        normalized.contains('goodbye')) {
      return 'مع السلامة! 👋\n\nأتمنى أن أكون قد ساعدتك. أراك لاحقاً!';
    }

    if (normalized.contains('شو جديد') || normalized.contains('whats new')) {
      final newCount = _filteredRecommendations.length;
      return 'لدينا $newCount عقار جديد متاح! 🎉\n\nهل تريد:\n• عرض العقارات\n• تطبيق فلاتر جديدة\n• عرض على الخريطة';
    }

    // Default casual response
    return 'أنا بخير! شكراً لسؤالك 😊\n\nكيف يمكنني مساعدتك اليوم؟';
  }

  // Normalize Arabic text - handle ه/ة and other variations
  String _normalizeArabicText(String text) {
    return text
        .replaceAll('ة', 'ه') // Convert ة to ه
        .replaceAll('إ', 'ا') // Convert إ to ا
        .replaceAll('أ', 'ا') // Convert أ to ا
        .replaceAll('آ', 'ا') // Convert آ to ا
        .replaceAll('ى', 'ي') // Convert ى to ي
        .replaceAll('ئ', 'ي') // Convert ئ to ي
        .replaceAll('ؤ', 'و') // Convert ؤ to و
        .toLowerCase()
        .trim();
  }

  Map<String, dynamic> _extractFiltersFromQuestion(String question) {
    final filters = <String, dynamic>{};
    final lowerQuestion = question.toLowerCase();

    // Extract budget
    final budgetMatch =
        RegExp(r'(\d+)\s*(?:دولار|dollar|\$|usd)').firstMatch(lowerQuestion);
    if (budgetMatch != null) {
      filters['budget'] = int.tryParse(budgetMatch.group(1) ?? '');
    }

    // Extract city (common cities)
    final cities = [
      'ramallah',
      'nablus',
      'jerusalem',
      'bethlehem',
      'hebron',
      'gaza'
    ];
    for (final city in cities) {
      if (lowerQuestion.contains(city)) {
        filters['city'] = city;
        break;
      }
    }

    // Extract rooms
    final roomsMatch =
        RegExp(r'(\d+)\s*(?:غرفة|room|bedroom)').firstMatch(lowerQuestion);
    if (roomsMatch != null) {
      filters['rooms'] = int.tryParse(roomsMatch.group(1) ?? '');
    }

    // Extract type
    final types = ['apartment', 'villa', 'house', 'studio', 'townhouse'];
    for (final type in types) {
      if (lowerQuestion.contains(type)) {
        filters['type'] = type;
        break;
      }
    }

    // Extract operation
    if (lowerQuestion.contains('إيجار') || lowerQuestion.contains('rent')) {
      filters['operation'] = 'rent';
    } else if (lowerQuestion.contains('بيع') ||
        lowerQuestion.contains('sale') ||
        lowerQuestion.contains('buy')) {
      filters['operation'] = 'sale';
    }

    return filters;
  }

  void _handleChatAction(ChatAction action) {
    switch (action.action) {
      case 'show_properties':
        _scrollChatToBottom();
        Future.delayed(const Duration(milliseconds: 300), () {
          setState(() => _isChatbotOpen = false);
        });
        break;
      case 'show_map':
      case 'open_map':
      case 'control_map':
        if (action.data != null) {
          setState(() => _isChatbotOpen = false);
          Future.delayed(const Duration(milliseconds: 300), () {
            _showPropertiesOnMapWithControl(action.data as List<dynamic>);
          });
        } else if (_filteredRecommendations.isNotEmpty) {
          setState(() => _isChatbotOpen = false);
          Future.delayed(const Duration(milliseconds: 300), () {
            _showPropertiesOnMapWithControl(_filteredRecommendations);
          });
        }
        break;
      case 'zoom_in':
        _controlMap('zoom_in');
        break;
      case 'zoom_out':
        _controlMap('zoom_out');
        break;
      case 'center_map':
        _controlMap('center');
        break;
      case 'filter_map':
        _controlMap('filter');
        break;
      case 'open_filters':
        setState(() => _isChatbotOpen = false);
        Future.delayed(const Duration(milliseconds: 300), () {
          _showAdvancedFilters();
        });
        break;
      case 'show_statistics':
        _showAnalyticsDialog();
        break;
      case 'save_search':
        setState(() => _isChatbotOpen = false);
        Future.delayed(const Duration(milliseconds: 300), () {
          _showSaveSearchDialog();
        });
        break;
      case 'show_property_details':
        if (action.data != null) {
          setState(() => _isChatbotOpen = false);
          Future.delayed(const Duration(milliseconds: 300), () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PropertyDetailsScreen(property: action.data!),
              ),
            );
          });
        }
        break;
      case 'show_contracts':
        if (action.data != null) {
          _showContractsDialog(action.data as List<dynamic>);
        }
        break;
      case 'show_payments':
        if (action.data != null) {
          _showPaymentsDialog(action.data as List<dynamic>);
        }
        break;
      case 'show_maintenance':
        if (action.data != null) {
          _showMaintenanceDialog(action.data as List<dynamic>);
        }
        break;
      case 'show_complaints':
        if (action.data != null) {
          _showComplaintsDialog(action.data as List<dynamic>);
        }
        break;
    }
  }

  void _showComplaintsDialog(List<dynamic> complaints) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('شكاويك'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              return ListTile(
                leading: const Icon(Icons.report, color: Color(0xFF2E7D32)),
                title: Text(complaint['category'] ?? 'Unknown Category'),
                subtitle: Text(
                  '${complaint['description'] ?? ''}\nالحالة: ${complaint['status'] ?? ''}',
                ),
                trailing: Icon(
                  _getComplaintStatusIcon(complaint['status']),
                  color: _getComplaintStatusColor(complaint['status']),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  IconData _getComplaintStatusIcon(String? status) {
    switch (status) {
      case 'resolved':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.hourglass_empty;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.report;
    }
  }

  Color _getComplaintStatusColor(String? status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showPropertiesOnMap(List<dynamic> properties) {
    // Navigate to map screen with properties
    Navigator.pushNamed(context, '/map', arguments: {
      'properties': properties,
      'highlight': true,
    }).catchError((error) {
      // Fallback if route doesn't exist
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapScreen(properties: properties),
        ),
      );
    });
  }

  void _showPropertiesOnMapWithControl(List<dynamic> properties) {
    // Navigate to enhanced map screen with full control
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedMapScreen(
          properties: properties,
          onMapControl: (command, data) {
            _handleMapControl(command, data);
          },
        ),
      ),
    );
  }

  void _controlMap(String command) {
    // Control map from chatbot
    if (_isChatbotOpen) {
      setState(() => _isChatbotOpen = false);
    }
    Future.delayed(const Duration(milliseconds: 300), () {
      _showPropertiesOnMapWithControl(_filteredRecommendations);
      // Send control command after map opens
      Future.delayed(const Duration(milliseconds: 500), () {
        _handleMapControl(command, null);
      });
    });
  }

  void _showContractsDialog(List<dynamic> contracts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عقودك'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: contracts.length,
            itemBuilder: (context, index) {
              final contract = contracts[index];
              return ListTile(
                leading:
                    const Icon(Icons.description, color: Color(0xFF2E7D32)),
                title: Text(contract['property'] ?? 'Unknown Property'),
                subtitle: Text(
                  '${contract['city'] ?? ''} - ${contract['status'] ?? ''}\n'
                  'السعر: \$${contract['rentAmount'] ?? 0}',
                ),
                trailing: Icon(
                  _getContractStatusIcon(contract['status']),
                  color: _getContractStatusColor(contract['status']),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to contract details
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showPaymentsDialog(List<dynamic> payments) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دفعاتك'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return ListTile(
                leading: const Icon(Icons.payment, color: Color(0xFF2E7D32)),
                title: Text('\$${payment['amount'] ?? 0}'),
                subtitle: Text(
                  '${payment['method'] ?? ''} - ${payment['status'] ?? ''}',
                ),
                trailing: Icon(
                  _getPaymentStatusIcon(payment['status']),
                  color: _getPaymentStatusColor(payment['status']),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceDialog(List<dynamic> maintenance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلبات الصيانة'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: maintenance.length,
            itemBuilder: (context, index) {
              final maint = maintenance[index];
              return ListTile(
                leading: const Icon(Icons.build, color: Color(0xFF2E7D32)),
                title: Text(maint['property'] ?? 'Unknown Property'),
                subtitle: Text(
                  '${maint['description'] ?? ''}\nالحالة: ${maint['status'] ?? ''}',
                ),
                trailing: Icon(
                  _getMaintenanceStatusIcon(maint['status']),
                  color: _getMaintenanceStatusColor(maint['status']),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  IconData _getContractStatusIcon(String? status) {
    switch (status) {
      case 'active':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'expired':
        return Icons.cancel;
      default:
        return Icons.description;
    }
  }

  Color _getContractStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentStatusIcon(String? status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'failed':
        return Icons.error;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentStatusColor(String? status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getMaintenanceStatusIcon(String? status) {
    switch (status) {
      case 'resolved':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.build;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.build;
    }
  }

  Color _getMaintenanceStatusColor(String? status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _scrollChatToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ========================================================
  // Smart Context Builders (Deprecated - now handled in backend)
  // ========================================================

  bool _shouldHandleLocally(String question) {
    final normalized = _normalizeArabicText(question);
    final trimmed = normalized.trim();

    // Handle greetings and casual conversation
    if (_isGreeting(trimmed) || _isCasualQuestion(trimmed)) {
      return true;
    }

    return normalized.contains('أفضل عقار') ||
        normalized.contains('best property') ||
        normalized.contains('أرخص') ||
        normalized.contains('cheapest') ||
        normalized.contains('أغلى') ||
        normalized.contains('most expensive') ||
        normalized.contains('عقاراتي') ||
        normalized.contains('my properties') ||
        normalized.contains('عرض الخريطة') ||
        normalized.contains('show map') ||
        normalized.contains('open map') ||
        normalized.contains('فتح الخريطة');
  }

  bool _isGreeting(String text) {
    final greetings = [
      'مرحبا',
      'مرحبا بك',
      'مرحبا بيك',
      'مرحبا بك',
      'مرحبا',
      'hello',
      'hi',
      'hey',
      'hey there',
      'السلام عليكم',
      'سلام',
      'السلام',
      'صباح الخير',
      'مساء الخير',
      'good morning',
      'good evening',
      'good afternoon',
      'اهلا',
      'اهلا وسهلا',
      'اهلا بك',
      'welcome',
      'welcome back',
    ];
    return greetings
        .any((greeting) => text.contains(greeting) || text == greeting);
  }

  bool _isCasualQuestion(String text) {
    final casualQuestions = [
      'كيفك',
      'كيف حالك',
      'كيفك انت',
      'كيف الوضع',
      'كيف الحال',
      'how are you',
      'how are you doing',
      'how is it going',
      'what\'s up',
      'whats up',
      'شو اخبارك',
      'شو اخبار',
      'شو الوضع',
      'شو بتعمل',
      'شو عم تعمل',
      'what are you doing',
      'what do you do',
      'what can you do',
      'شو في',
      'شو جديد',
      'what\'s new',
      'whats new',
      'شكرا',
      'شكرا لك',
      'مشكور',
      'thanks',
      'thank you',
      'thx',
      'عفوا',
      'you\'re welcome',
      'welcome',
      'مع السلامة',
      'باي',
      'bye',
      'goodbye',
      'see you',
    ];
    return casualQuestions.any((q) => text.contains(q) || text == q);
  }

  void _handleLocalQuestion(String question) {
    final normalized = _normalizeArabicText(question);
    final trimmed = normalized.trim();
    final lowerQuestion = question.toLowerCase();
    String response = '';
    List<ChatAction>? actions;

    // Handle greetings first
    if (_isGreeting(trimmed)) {
      response = _getGreetingResponse();
      actions = [
        ChatAction(
          label: 'Show Recommendations',
          icon: Icons.home,
          action: 'show_properties',
        ),
        ChatAction(
          label: 'My Statistics',
          icon: Icons.analytics,
          action: 'show_statistics',
        ),
      ];
      setState(() {
        _isChatLoading = false;
        _chatMessages
            .add(ChatMessage(text: response, isUser: false, actions: actions));
        _chatMessages
            .add(ChatMessage(text: '', isUser: false, showQuickActions: true));
      });
      _scrollChatToBottom();
      return;
    }

    // Handle casual questions
    if (_isCasualQuestion(trimmed)) {
      response = _getCasualResponse(trimmed);
      actions = [
        ChatAction(
          label: 'Find Properties',
          icon: Icons.search,
          action: 'open_filters',
        ),
        ChatAction(
          label: 'View Map',
          icon: Icons.map,
          action: 'show_map',
          data: _filteredRecommendations,
        ),
      ];
      setState(() {
        _isChatLoading = false;
        _chatMessages
            .add(ChatMessage(text: response, isUser: false, actions: actions));
        _chatMessages
            .add(ChatMessage(text: '', isUser: false, showQuickActions: true));
      });
      _scrollChatToBottom();
      return;
    }

    // Handle map requests
    if (normalized.contains('عرض الخريطة') ||
        normalized.contains('show map') ||
        normalized.contains('open map') ||
        normalized.contains('فتح الخريطة') ||
        normalized.contains('خريطة')) {
      if (_filteredRecommendations.isNotEmpty) {
        _showPropertiesOnMap(_filteredRecommendations);
        response =
            'Opening map with ${_filteredRecommendations.length} properties...';
      } else {
        response = 'No properties available to show on map.';
      }
      setState(() {
        _isChatLoading = false;
        _chatMessages.add(ChatMessage(text: response, isUser: false));
      });
      return;
    }

    if (normalized.contains('أفضل عقار') ||
        normalized.contains('best property')) {
      if (_filteredRecommendations.isNotEmpty) {
        final best = _filteredRecommendations.first;
        final score = (best['recommendationScore'] as num?)?.toDouble() ?? 0.0;
        response = '''🏆 أفضل عقار موصى به لك:

📍 ${best['title'] ?? 'Property'}
💰 السعر: \$${best['price'] ?? 0}
🏙️ الموقع: ${best['city'] ?? 'Unknown'}
⭐ نقاط التوصية: ${score.toStringAsFixed(0)}%

${best['reasons'] != null && (best['reasons'] as List).isNotEmpty ? 'الأسباب: ${(best['reasons'] as List).join(', ')}' : ''}

هذا العقار الأفضل بناءً على تفضيلاتك وسلوكك!''';
        actions = [
          ChatAction(
            label: 'عرض التفاصيل',
            icon: Icons.info,
            action: 'show_property_details',
            data: best,
          ),
        ];
      } else {
        response =
            'حالياً لا توجد توصيات متاحة. جرّب تغيير الفلاتر أو انتظر قليلاً لتحديث التوصيات.';
      }
    } else if (normalized.contains('أرخص') || normalized.contains('cheapest')) {
      if (_filteredRecommendations.isNotEmpty) {
        final cheapest = _filteredRecommendations.reduce((a, b) {
          final priceA = (a['price'] as num?)?.toDouble() ?? double.infinity;
          final priceB = (b['price'] as num?)?.toDouble() ?? double.infinity;
          return priceA < priceB ? a : b;
        });
        response = '''💰 أرخص عقار متاح:

📍 ${cheapest['title'] ?? 'Property'}
💰 السعر: \$${cheapest['price'] ?? 0}
🏙️ الموقع: ${cheapest['city'] ?? 'Unknown'}
🛏️ غرف: ${cheapest['bedrooms'] ?? 0}
🛁 حمامات: ${cheapest['bathrooms'] ?? 0}''';
        actions = [
          ChatAction(
            label: 'عرض التفاصيل',
            icon: Icons.info,
            action: 'show_property_details',
            data: cheapest,
          ),
        ];
      } else {
        response = 'لا توجد عقارات متاحة حالياً.';
      }
    } else if (normalized.contains('إحصائيات') ||
        normalized.contains('statistics')) {
      response = _buildStatisticsResponse();
      actions = [
        ChatAction(
          label: 'عرض التفاصيل',
          icon: Icons.analytics,
          action: 'show_statistics',
        ),
      ];
    }

    setState(() {
      _chatMessages.add(ChatMessage(text: question, isUser: true));
      _chatMessages.add(ChatMessage(
        text: response,
        isUser: false,
        actions: actions,
      ));
      _chatMessages.add(ChatMessage(
        text: '',
        isUser: false,
        showQuickActions: true,
      ));
    });
    _scrollChatToBottom();
  }

  String _buildPropertiesContext() {
    if (_filteredRecommendations.isEmpty) {
      return 'No properties available currently.';
    }

    // Take top 5 properties for context
    final topProperties = _filteredRecommendations.take(5).map((p) {
      return {
        'title': p['title'] ?? 'Property',
        'price': p['price'] ?? 0,
        'city': p['city'] ?? 'Unknown',
        'type': p['type'] ?? 'Unknown',
        'bedrooms': p['bedrooms'] ?? 0,
        'bathrooms': p['bathrooms'] ?? 0,
        'area': p['area'] ?? 0,
        'score': (p['recommendationScore'] as num?)?.toDouble() ?? 0.0,
        'reasons': p['reasons'] ?? [],
      };
    }).toList();

    return 'Available properties:\n${topProperties.map((p) => '- ${p['title']} (${p['city']}): \$${p['price']}, ${p['bedrooms']} beds, ${p['bathrooms']} baths, Score: ${p['score']}%').join('\n')}';
  }

  String _buildStatisticsContext() {
    if (_statistics.isEmpty) {
      return 'No statistics available.';
    }

    return '''
- Total Properties: ${_statistics['totalProperties'] ?? 0}
- Average Score: ${((_statistics['averageScore'] ?? 0.0) as double).toStringAsFixed(1)}%
- Preferred Type: ${_statistics['mostViewedType'] ?? 'N/A'}
- Preferred City: ${_statistics['preferredCity'] ?? 'N/A'}
''';
  }

  String _buildFiltersContext() {
    final filters = <String>[];
    if (_filterCity != null) filters.add('City: $_filterCity');
    if (_filterType != null) filters.add('Type: $_filterType');
    if (_filterOperation != null) filters.add('Operation: $_filterOperation');
    if (_minPrice != null) filters.add('Min Price: \$$_minPrice');
    if (_maxPrice != null) filters.add('Max Price: \$$_maxPrice');
    if (_minBedrooms != null) filters.add('Min Bedrooms: $_minBedrooms');
    if (_minScore != null)
      filters.add('Min Score: ${_minScore!.toStringAsFixed(0)}%');

    return filters.isEmpty ? 'No filters active' : filters.join(', ');
  }

  String _buildStatisticsResponse() {
    if (_statistics.isEmpty) {
      return 'لا توجد إحصائيات متاحة حالياً.';
    }

    return '''📊 إحصائياتك الشخصية:

🏠 إجمالي العقارات: ${_statistics['totalProperties'] ?? 0}
⭐ متوسط النقاط: ${((_statistics['averageScore'] ?? 0.0) as double).toStringAsFixed(1)}%
🏘️ النوع المفضل: ${_statistics['mostViewedType'] ?? 'N/A'}
📍 المدينة المفضلة: ${_statistics['preferredCity'] ?? 'N/A'}
🔍 عمليات البحث المحفوظة: ${_savedSearches.length}''';
  }

  String _getSmartFallback(String question) {
    final normalized = _normalizeArabicText(question);
    final lowerQuestion = question.toLowerCase();

    // Property-related questions
    if (lowerQuestion.contains('عقار') || lowerQuestion.contains('property')) {
      if (_filteredRecommendations.isEmpty) {
        return 'حالياً لا يوجد عقارات تطابق بحثك. جرّب:\n• تغيير السعر\n• تغيير المدينة\n• إزالة بعض الفلاتر\n• أو انتظر قليلاً لتحديث التوصيات 😊';
      }
      return 'لدينا ${_filteredRecommendations.length} عقار متاح. استخدم الأزرار أدناه لعرض التفاصيل أو تطبيق فلاتر جديدة.';
    }

    // Statistics questions
    if (lowerQuestion.contains('إحصائيات') ||
        lowerQuestion.contains('statistics')) {
      return _buildStatisticsResponse();
    }

    // Filter questions
    if (lowerQuestion.contains('فلتر') || lowerQuestion.contains('filter')) {
      if (_activeFiltersCount == 0) {
        return 'لا توجد فلاتر نشطة حالياً. استخدم زر الفلاتر في الأعلى لتطبيق فلاتر جديدة.';
      }
      return 'لديك $_activeFiltersCount فلتر نشط. استخدم زر الفلاتر لتعديلها.';
    }

    // General fallback
    return '''أنا مساعدك في نظام Smart System لتطبيق SHAQATI 🏠

يمكنني مساعدتك في:
• البحث عن العقارات المناسبة
• عرض إحصائياتك الشخصية
• استخدام الفلاتر والبحث
• شرح ميزات النظام

جرّب أحد الأزرار السريعة أدناه أو اكتب سؤالك!''';
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }
}

// Chatbot Models
class ChatMessage {
  final String text;
  final bool isUser;
  final bool showQuickActions;
  final List<ChatAction>? actions;

  ChatMessage({
    required this.text,
    this.isUser = false,
    this.showQuickActions = false,
    this.actions,
  });
}

class ChatAction {
  final String label;
  final IconData icon;
  final String action;
  final dynamic data; // For passing property data, etc.

  ChatAction({
    required this.label,
    required this.icon,
    required this.action,
    this.data,
  });
}
