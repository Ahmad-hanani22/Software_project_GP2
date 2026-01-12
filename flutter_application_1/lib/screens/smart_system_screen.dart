import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/smart_system_service.dart';
import 'package:flutter_application_1/screens/property_details_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
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
          await SmartSystemService.getSmartRecommendations(limit: 20);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (success) {
            _recommendations = recommendations;
            if (extraData != null) {
              _behaviorAnalysis = extraData['behaviorAnalysis'];
            }
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
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
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
              onPressed: _isLoggedIn ? _loadRecommendations : () {
                Navigator.pushNamed(context, '/login');
              },
              icon: Icon(_isLoggedIn ? Icons.refresh : Icons.login),
              label: Text(_isLoggedIn ? 'Retry' : 'Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      color: const Color(0xFF2E7D32),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Premium Header Section
          SliverToBoxAdapter(
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
          ),

          // Recommendations List
          if (_recommendations.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final property = _recommendations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildPropertyCard(property),
                    );
                  },
                  childCount: _recommendations.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No recommendations available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start browsing properties to build your profile and get personalized recommendations',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.explore),
              label: const Text('Browse Properties'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
    final score = recommendationScore is num ? recommendationScore.toDouble() : 0.0;

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
                if (property['images'] != null && (property['images'] as List).isNotEmpty)
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    property['title'] ?? 'Property',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

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
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (property['operation'] == 'rent')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '/month',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

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

                  // Recommendation Reasons
                  if (reasons.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2E7D32).withOpacity(0.08),
                            const Color(0xFF1B5E20).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
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
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Why we recommend this',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: reasons.map((reason) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF2E7D32).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: const Color(0xFF2E7D32),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      reason.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
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
                      ),
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
}
