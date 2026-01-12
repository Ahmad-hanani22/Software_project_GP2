import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/tenant_payment_screen.dart';
import 'package:flutter_application_1/screens/chat_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

// --- 🎨 SHAQATI Premium Theme Colors ---
const Color kPrimaryColor = Color(0xFF2E7D32); // Primary green
const Color kDarkGreen = Color(0xFF1B5E20); // Dark green
const Color kAccentColor = Color(0xFFFFA000); // Gold for ratings
const Color kTextPrimary = Color(0xFF1A1A1A); // Dark black for text
const Color kTextSecondary = Color(0xFF757575); // Gray for secondary text
const Color kSurfaceColor = Color(0xFFF9F9F9); // Very light background
const Color kWhite = Colors.white;
const Color kDisabledColor = Color(0xFFBDBDBD); // Gray for disabled elements

class PropertyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoadingReviews = true;
  List<dynamic> _reviews = [];
  bool _isSendingRequest = false;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;
  String? _adminId;
  String? _adminName;
  bool _hasActiveContract = false;
  bool _isCheckingContract = true;
  int _currentImageIndex = 0;
  late TabController _tabController;

  // Additional property information
  String?
      _propertyCondition; // Property condition (new, used, under construction)
  int? _rentDurationMonths; // Rent duration in months
  String?
      _paymentFrequency; // Payment frequency (daily, weekly, monthly, yearly)
  String? _furnishingStatus; // Furnishing status (furnished, unfurnished)
  int? _parkingSpaces; // Number of parking spaces
  int? _floors; // Number of floors
  String? _yearBuilt; // Year built
  String? _propertyAge; // Property age
  bool _hasElevator = false; // Has elevator
  bool _hasGarden = false; // Has garden
  bool _hasBalcony = false; // Has balcony
  bool _hasPool = false; // Has pool
  String? _heatingType; // Heating type
  String? _coolingType; // Cooling type
  String? _securityFeatures; // Security features
  String? _nearbyFacilities; // Nearby facilities

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchReviews();
    _loadAdminForChat();
    _checkActiveContract();
    _extractPropertyDetails();
    _scrollController.addListener(() {
      setState(() {
        _showAppBarTitle = _scrollController.offset > 300;
      });
    });
  }

  void _extractPropertyDetails() {
    final p = widget.property;

    // Extract additional information from description or data
    _propertyCondition = p['condition'] ?? 'Used';
    _rentDurationMonths =
        p['rentDurationMonths'] ?? (p['operation'] == 'rent' ? 12 : null);

    // Extract payment frequency - support multiple formats
    String? paymentFreq = p['paymentFrequency'] ??
        p['paymentCycle'] ??
        (p['operation'] == 'rent' ? 'monthly' : null);

    // Normalize payment frequency values
    if (paymentFreq != null) {
      paymentFreq = paymentFreq.toLowerCase();
      if (paymentFreq == 'daily' || paymentFreq == 'day') {
        _paymentFrequency = 'Daily';
      } else if (paymentFreq == 'weekly' || paymentFreq == 'week') {
        _paymentFrequency = 'Weekly';
      } else if (paymentFreq == 'monthly' || paymentFreq == 'month') {
        _paymentFrequency = 'Monthly';
      } else if (paymentFreq == 'yearly' ||
          paymentFreq == 'year' ||
          paymentFreq == 'annually') {
        _paymentFrequency = 'Yearly';
      } else {
        _paymentFrequency = capitalize(paymentFreq);
      }
    } else {
      _paymentFrequency = 'Monthly'; // Default for rent
    }

    _furnishingStatus = p['furnishingStatus'] ?? 'Not specified';
    _parkingSpaces = p['parkingSpaces'] ?? 0;
    _floors = p['floors'] ?? 1;
    _yearBuilt = p['yearBuilt']?.toString();
    _hasElevator = p['hasElevator'] ?? false;
    _hasGarden = p['hasGarden'] ?? false;
    _hasBalcony = p['hasBalcony'] ?? false;
    _hasPool = p['hasPool'] ?? false;
    _heatingType = p['heatingType'] ?? 'Not specified';
    _coolingType = p['coolingType'] ?? 'Not specified';
    _securityFeatures = p['securityFeatures'] ?? 'Not specified';
    _nearbyFacilities = p['nearbyFacilities'] ?? 'Not specified';

    // Calculate property age
    if (_yearBuilt != null) {
      final year = int.tryParse(_yearBuilt!);
      if (year != null) {
        final currentYear = DateTime.now().year;
        _propertyAge = (currentYear - year).toString();
      }
    }
  }

  // Helper method to capitalize first letter
  String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminForChat() async {
    final (ok, admins) = await ApiService.getAdminUsers();
    if (ok && admins.isNotEmpty) {
      setState(() {
        _adminId = admins[0]['_id']?.toString();
        _adminName = admins[0]['name']?.toString() ?? 'Admin';
      });
    }
  }

  Future<void> _openChatWithAdmin() async {
    if (_adminId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Admin not available. Please try again later."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please login to chat"),
        backgroundColor: Colors.red,
      ));
      if (mounted) {
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            receiverId: _adminId!,
            receiverName: _adminName ?? 'Admin',
          ),
        ),
      );
    }
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoadingReviews = true);
    try {
      final (ok, data) =
          await ApiService.getReviewsByProperty(widget.property['_id']);
      if (mounted) {
        setState(() {
          if (ok) _reviews = data as List<dynamic>;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _checkActiveContract() async {
    setState(() => _isCheckingContract = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final userRole = prefs.getString('role');
      
      // Only check for tenants
      if (userId != null && userRole == 'tenant') {
        final (ok, contracts) = await ApiService.getUserContracts(userId);
        if (mounted && ok && contracts is List) {
          final propertyId = widget.property['_id']?.toString();
          final hasActive = contracts.any((contract) {
            final contractPropertyId = contract['propertyId']?['_id']?.toString() ?? 
                                     contract['propertyId']?.toString();
            final status = contract['status']?.toString().toLowerCase();
            return contractPropertyId == propertyId && 
                   (status == 'active' || status == 'rented');
          });
          setState(() {
            _hasActiveContract = hasActive;
            _isCheckingContract = false;
          });
          return;
        }
      }
      if (mounted) {
        setState(() {
          _hasActiveContract = false;
          _isCheckingContract = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasActiveContract = false;
          _isCheckingContract = false;
        });
      }
    }
  }

  Future<void> _handleAction() async {
    final status =
        widget.property['status']?.toString().toLowerCase() ?? 'available';

    if (status != 'available') {
      String msg;
      if (status == 'pending_approval') {
        msg = "There is already a request waiting for approval.";
      } else if (status == 'active') {
        msg = "This property already has an active contract.";
      } else {
        msg = "This property is already ${status.toUpperCase()}";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.orange),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please login to continue"),
        backgroundColor: Colors.red,
      ));
      if (mounted) {
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    setState(() => _isSendingRequest = true);

    final double price = (widget.property['price'] is num)
        ? (widget.property['price'] as num).toDouble()
        : 0.0;
    String landlordId = 'admins';
    final owner = widget.property['ownerId'];
    if (owner is Map && owner['_id'] != null) {
      landlordId = owner['_id'].toString();
    } else if (owner is String && owner.isNotEmpty) {
      landlordId = owner;
    }

    try {
      final (ok, msg, contract) = await ApiService.requestContract(
        propertyId: widget.property['_id'],
        landlordId: landlordId,
        price: price,
      );

      if (!mounted) return;
      setState(() => _isSendingRequest = false);

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $msg"), backgroundColor: Colors.red),
        );
        return;
      }

      if (contract == null || contract['_id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Contract created but response data is missing."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final String contractId = contract['_id'].toString();
      final double amount = (contract['rentAmount'] is num)
          ? (contract['rentAmount'] as num).toDouble()
          : price;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TenantPaymentScreen(
            contractId: contractId,
            amount: amount,
            property: widget.property,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingRequest = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openFullScreenGallery(int initialIndex) {
    setState(() {
      _currentImageIndex = initialIndex;
    });

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _FullScreenGallery(
        images: widget.property['images'] ?? [],
        initialIndex: initialIndex,
        onClose: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  // Calculate payment amount based on frequency
  double? _calculatePaymentAmount() {
    if (widget.property['price'] == null || _paymentFrequency == null) {
      return null;
    }

    final basePrice = (widget.property['price'] as num).toDouble();

    switch (_paymentFrequency!.toLowerCase()) {
      case 'daily':
        return basePrice / 30; // Approximate monthly to daily
      case 'weekly':
        return basePrice / 4; // Approximate monthly to weekly
      case 'monthly':
        return basePrice;
      case 'yearly':
        return basePrice * 12;
      default:
        return basePrice;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final images = (p['images'] != null && p['images'].isNotEmpty)
        ? p['images'] as List
        : ['https://via.placeholder.com/600x400'];
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0, name: 'USD');

    final String status = p['status']?.toString().toLowerCase() ?? 'available';
    final bool isAvailable = status == 'available';
    final bool isPendingApproval = status == 'pending_approval';

    String buttonText;
    Color buttonColor;
    bool isButtonEnabled;

    if (isAvailable) {
      buttonText = p['operation'] == 'rent' ? "Rent Now" : "Buy Now";
      buttonColor = kPrimaryColor;
      isButtonEnabled = true;
    } else if (isPendingApproval) {
      buttonText = "Pending Approval";
      buttonColor = kDisabledColor;
      isButtonEnabled = false;
    } else if (status == 'active') {
      buttonText = "Contract Active";
      buttonColor = kDisabledColor;
      isButtonEnabled = false;
    } else if (status == 'rented') {
      buttonText = "Rented Out";
      buttonColor = kDisabledColor;
      isButtonEnabled = false;
    } else if (status == 'sold') {
      buttonText = "Sold Out";
      buttonColor = kDisabledColor;
      isButtonEnabled = false;
    } else {
      buttonText = "Not Available";
      buttonColor = kDisabledColor;
      isButtonEnabled = false;
    }

    return Scaffold(
      backgroundColor: kWhite,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Hero Section with Image Gallery
              SliverAppBar(
                expandedHeight: 450,
                pinned: true,
                backgroundColor: kWhite,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share, color: Colors.black),
                      onPressed: () {
                        // Share functionality
                      },
                    ),
                  ),
                ],
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showAppBarTitle ? 1.0 : 0.0,
                  child: Text(
                    p['title'] ?? 'Property Details',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(imgUrl, fit: BoxFit.cover),
                      Container(
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
                      Positioned(
                        bottom: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: p['operation'] == 'rent'
                                ? kAccentColor
                                : kPrimaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            p['operation'] == 'rent' ? "FOR RENT" : "FOR SALE",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      // شارة إضافية إذا كان غير متاح
                      if (!isAvailable)
                        Positioned(
                          top: 100,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // باقي المحتوى
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 18, color: kTextSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "${p['city']}, ${p['address']}",
                              style: const TextStyle(
                                fontSize: 15,
                                color: kTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: Colors.grey.shade200,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(Icons.bed_rounded,
                                "${p['bedrooms']}", "Bedrooms"),
                            _buildVerticalDivider(),
                            _buildStatItem(Icons.bathtub_outlined,
                                "${p['bathrooms']}", "Bathrooms"),
                            _buildVerticalDivider(),
                            _buildStatItem(Icons.square_foot_rounded,
                                "${p['area']}", "Sq.m"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader("About this home"),
                      const SizedBox(height: 8),
                      Text(
                        p['description'] ?? "No description available.",
                        style: const TextStyle(
                          fontSize: 15,
                          color: kTextSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader("Amenities"),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (p['amenities'] as List? ?? [])
                            .map(
                              (e) => Chip(
                                label: Text(e.toString()),
                                backgroundColor: kSurfaceColor,
                                labelStyle: const TextStyle(
                                  color: kTextPrimary,
                                  fontSize: 13,
                                ),
                                side: BorderSide.none,
                                avatar: const Icon(
                                  Icons.check_circle,
                                  color: kPrimaryColor,
                                  size: 18,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader("Location"),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: IgnorePointer(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(
                                  (p['location']['coordinates'][1] as num)
                                      .toDouble(),
                                  (p['location']['coordinates'][0] as num)
                                      .toDouble(),
                                ),
                                initialZoom: 14,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(
                                        (p['location']['coordinates'][1] as num)
                                            .toDouble(),
                                        (p['location']['coordinates'][0] as num)
                                            .toDouble(),
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: kPrimaryColor,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader("Reviews"),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: kAccentColor, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                "(${_reviews.length})",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingReviews)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_reviews.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: kSurfaceColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "No reviews yet. Be the first to share your experience!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kTextSecondary),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _reviews.length > 3 ? 3 : _reviews.length,
                          itemBuilder: (context, index) =>
                              _buildReviewItem(_reviews[index]),
                        ),
                      const SizedBox(height: 16),
                      // Only show review button if user has an active contract
                      if (!_isCheckingContract && _hasActiveContract)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showAddReviewModal(context, p['_id']),
                            icon: const Icon(Icons.rate_review_outlined),
                            label: const Text("Write a Review"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimaryColor,
                              side: const BorderSide(color: kPrimaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        )
                      else if (!_isCheckingContract && !_hasActiveContract)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kSurfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kDisabledColor),
                          ),
                          child: const Text(
                            "Rating is only available after renting this property.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: kTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Fixed Bottom Action Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
                border: const Border(
                  top: BorderSide(color: Color(0xFFEEEEEE)),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Total Price",
                          style: TextStyle(fontSize: 12, color: kTextSecondary),
                        ),
                        Text(
                          currency.format(p['price']),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Chat button (only show if property is available)
                    if (isAvailable)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          onPressed: _openChatWithAdmin,
                          icon: const Icon(Icons.chat, color: kPrimaryColor),
                          tooltip: 'Chat with Admin',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: kPrimaryColor, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: 160,
                      child: ElevatedButton(
                        onPressed: (isButtonEnabled && !_isSendingRequest)
                            ? _handleAction
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: kDisabledColor,
                        ),
                        child: _isSendingRequest
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                buttonText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: kTextPrimary,
                  background: _buildImageGallery(images),
                ),
              ),

              // Main Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Property Header Info
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p['title'] ?? 'No Title',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: kTextPrimary,
                                  ),
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 20, color: kPrimaryColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "${p['city'] ?? ''}, ${p['address'] ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: kTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Price and Key Info
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  kPrimaryColor.withOpacity(0.1),
                                  kPrimaryColor.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: kPrimaryColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Total Price",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: kTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currency.format(p['price']),
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: kPrimaryColor,
                                      ),
                                    ),
                                    if (p['operation'] == 'rent' &&
                                        _rentDurationMonths != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          "Duration: $_rentDurationMonths months",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: kTextSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    _buildInfoChip(
                                      Icons.bed_rounded,
                                      "${p['bedrooms'] ?? 0}",
                                      "Bedrooms",
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoChip(
                                      Icons.bathtub_outlined,
                                      "${p['bathrooms'] ?? 0}",
                                      "Bathrooms",
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tabs Section
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            indicatorColor: kPrimaryColor,
                            indicatorWeight: 3,
                            labelColor: kPrimaryColor,
                            unselectedLabelColor: kTextSecondary,
                            tabs: const [
                              Tab(text: "Overview"),
                              Tab(text: "Details"),
                              Tab(text: "Location"),
                              Tab(text: "Reviews"),
                            ],
                          ),
                          SizedBox(
                            height: 600,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildOverviewTab(p),
                                _buildDetailsTab(p),
                                _buildLocationTab(p),
                                _buildReviewsTab(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),

          // Fixed Bottom Action Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
                border: const Border(
                  top: BorderSide(color: Color(0xFFEEEEEE)),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (isAvailable)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: IconButton(
                          onPressed: _openChatWithAdmin,
                          icon: const Icon(Icons.chat_bubble_outline,
                              color: kPrimaryColor),
                          tooltip: 'Chat with Admin',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: kPrimaryColor, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (isButtonEnabled && !_isSendingRequest)
                              ? _handleAction
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: kDisabledColor,
                          ),
                          child: _isSendingRequest
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  buttonText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List images) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CarouselSlider.builder(
          itemCount: images.length,
          itemBuilder: (context, index, realIndex) {
            return GestureDetector(
              onTap: () => _openFullScreenGallery(index),
              child: CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.error),
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: 450,
            viewportFraction: 1.0,
            autoPlay: images.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
        ),
        // Gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Image counter
        if (images.length > 1)
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${_currentImageIndex + 1} / ${images.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // Operation badge
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.property['operation'] == 'rent'
                  ? kAccentColor
                  : kPrimaryColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              widget.property['operation'] == 'rent' ? "FOR RENT" : "FOR SALE",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (status.toLowerCase()) {
      case 'available':
        badgeColor = Colors.green;
        badgeText = 'Available';
        badgeIcon = Icons.check_circle;
        break;
      case 'pending_approval':
        badgeColor = Colors.orange;
        badgeText = 'Pending Approval';
        badgeIcon = Icons.pending;
        break;
      case 'active':
        badgeColor = Colors.blue;
        badgeText = 'Active';
        badgeIcon = Icons.verified;
        break;
      case 'rented':
        badgeColor = Colors.purple;
        badgeText = 'Rented';
        badgeIcon = Icons.home;
        break;
      case 'sold':
        badgeColor = Colors.red;
        badgeText = 'Sold';
        badgeIcon = Icons.sell;
        break;
      default:
        badgeColor = Colors.grey;
        badgeText = 'Unknown';
        badgeIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 16, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: kPrimaryColor, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: kTextPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, dynamic> p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("About this property"),
          const SizedBox(height: 12),
          Text(
            p['description'] ?? "No description available.",
            style: const TextStyle(
              fontSize: 15,
              color: kTextPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader("Basic Information"),
          const SizedBox(height: 12),
          _buildInfoGrid([
            _InfoItem(Icons.square_foot, "Area", "${p['area'] ?? 0} sq.m"),
            _InfoItem(Icons.bed_rounded, "Bedrooms", "${p['bedrooms'] ?? 0}"),
            _InfoItem(
                Icons.bathtub_outlined, "Bathrooms", "${p['bathrooms'] ?? 0}"),
            _InfoItem(Icons.local_parking, "Parking Spaces",
                "${_parkingSpaces ?? 0}"),
            _InfoItem(Icons.layers, "Floors", "${_floors ?? 1}"),
            _InfoItem(Icons.calendar_today, "Year Built",
                _yearBuilt ?? "Not specified"),
            _InfoItem(Icons.home, "Property Condition",
                _propertyCondition ?? "Not specified"),
            _InfoItem(Icons.chair, "Furnishing Status",
                _furnishingStatus ?? "Not specified"),
          ]),
          const SizedBox(height: 24),
          _buildSectionHeader("Amenities & Services"),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: (p['amenities'] as List? ?? [])
                .map(
                  (e) => Chip(
                    label: Text(e.toString()),
                    backgroundColor: kSurfaceColor,
                    labelStyle: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 13,
                    ),
                    side: BorderSide.none,
                    avatar: const Icon(
                      Icons.check_circle,
                      color: kPrimaryColor,
                      size: 18,
                    ),
                  ),
                )
                .toList(),
          ),
          if (p['operation'] == 'rent') ...[
            const SizedBox(height: 24),
            _buildSectionHeader("Rental Information"),
            const SizedBox(height: 12),
            _buildRentInfoCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsTab(Map<String, dynamic> p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Full Details"),
          const SizedBox(height: 20),
          _buildDetailCard(
            "Building Information",
            [
              _DetailRow("Year Built", _yearBuilt ?? "Not specified"),
              _DetailRow(
                  "Property Age",
                  _propertyAge != null
                      ? "$_propertyAge years"
                      : "Not specified"),
              _DetailRow("Number of Floors", "${_floors ?? 1}"),
              _DetailRow(
                  "Property Condition", _propertyCondition ?? "Not specified"),
            ],
            Icons.business,
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            "Facilities",
            [
              _DetailRow("Elevator", _hasElevator ? "Yes" : "No"),
              _DetailRow("Garden", _hasGarden ? "Yes" : "No"),
              _DetailRow("Balcony", _hasBalcony ? "Yes" : "No"),
              _DetailRow("Pool", _hasPool ? "Yes" : "No"),
              _DetailRow("Parking Spaces", "${_parkingSpaces ?? 0}"),
            ],
            Icons.apartment,
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            "Systems",
            [
              _DetailRow("Heating Type", _heatingType ?? "Not specified"),
              _DetailRow("Cooling Type", _coolingType ?? "Not specified"),
            ],
            Icons.ac_unit,
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            "Security & Nearby Facilities",
            [
              _DetailRow(
                  "Security Features", _securityFeatures ?? "Not specified"),
              _DetailRow(
                  "Nearby Facilities", _nearbyFacilities ?? "Not specified"),
            ],
            Icons.security,
          ),
          // 3D Viewer Section
          if (p['model3dUrl'] != null &&
              p['model3dUrl'].toString().isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader("3D View"),
            const SizedBox(height: 12),
            _build3DViewer(p['model3dUrl']),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationTab(Map<String, dynamic> p) {
    final propertyLat = (p['location']['coordinates'][1] as num).toDouble();
    final propertyLng = (p['location']['coordinates'][0] as num).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader("Location"),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenMapView(
                        propertyLat: propertyLat,
                        propertyLng: propertyLng,
                        propertyTitle: p['title'] ?? 'Property',
                        address: "${p['city'] ?? ''}, ${p['address'] ?? ''}",
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_full),
                label: const Text("Open Full Map"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _InteractiveMap(
                propertyLat: propertyLat,
                propertyLng: propertyLng,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoCard(
            Icons.location_city,
            "Full Address",
            "${p['city'] ?? ''}, ${p['address'] ?? ''}",
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            Icons.public,
            "Country",
            p['country'] ?? "Not specified",
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader("Reviews"),
              Row(
                children: [
                  const Icon(Icons.star, color: kAccentColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    "(${_reviews.length})",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingReviews)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_reviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: kSurfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "No reviews yet. Be the first to share your experience!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: kTextSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          else
            ..._reviews.map((review) => _buildReviewItem(review)).toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showAddReviewModal(context, widget.property['_id']),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text("Write a Review"),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryColor,
                side: const BorderSide(color: kPrimaryColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: kTextPrimary,
      ),
    );
  }

  Widget _buildInfoGrid(List<_InfoItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(item.icon, color: kPrimaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: kTextSecondary,
                      ),
                    ),
                    Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRentInfoCard() {
    final paymentAmount = _calculatePaymentAmount();
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0, name: 'USD');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kPrimaryColor.withOpacity(0.1),
            kPrimaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          if (_rentDurationMonths != null)
            _buildRentInfoRow("Rent Duration", "$_rentDurationMonths months"),
          if (_rentDurationMonths != null && _paymentFrequency != null)
            const Divider(),
          if (_paymentFrequency != null)
            _buildRentInfoRow("Payment Frequency", _paymentFrequency!),
          if (paymentAmount != null && _paymentFrequency != null) ...[
            const Divider(),
            _buildRentInfoRow(
              "${_paymentFrequency!} Payment",
              currency.format(paymentAmount),
            ),
          ],
          if (widget.property['price'] != null &&
              _paymentFrequency != null) ...[
            const Divider(),
            _buildRentInfoRow(
              "Total Price",
              currency.format(widget.property['price']),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRentInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: kTextSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(
      String title, List<_DetailRow> details, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: kPrimaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...details.map((detail) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      detail.label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: kTextSecondary,
                      ),
                    ),
                    Text(
                      detail.value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: kTextPrimary,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: kTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DViewer(String modelUrl) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ModelViewer(
          src: modelUrl,
          alt: "3D Model",
          ar: true,
          autoRotate: true,
          cameraControls: true,
          backgroundColor: Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: kPrimaryColor.withOpacity(0.1),
                child: Text(
                  (review['reviewerId']?['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['reviewerId']?['name'] ?? 'User',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < (review['rating'] ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: kAccentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('yyyy-MM-dd').format(
                  DateTime.parse(
                      review['createdAt'] ?? DateTime.now().toString()),
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
          if (review['comment'] != null &&
              review['comment'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review['comment'],
              style: const TextStyle(
                color: kTextPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddReviewModal(BuildContext context, String propertyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: _AddReviewForm(
          propertyId: propertyId,
          onSubmitted: () {
            Navigator.pop(context);
            _fetchReviews();
          },
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  _InfoItem(this.icon, this.label, this.value);
}

class _DetailRow {
  final String label;
  final String value;

  _DetailRow(this.label, this.value);
}

class _FullScreenGallery extends StatefulWidget {
  final List images;
  final int initialIndex;
  final VoidCallback onClose;

  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
    required this.onClose,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(widget.images[index]),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            itemCount: widget.images.length,
            loadingBuilder: (context, event) => Center(
              child: CircularProgressIndicator(
                value: event == null
                    ? 0
                    : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
              ),
            ),
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: widget.onClose,
                  ),
                  if (widget.images.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${_currentIndex + 1} / ${widget.images.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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
    );
  }
}

// Full Screen Map View with Advanced GPS Features
class FullScreenMapView extends StatefulWidget {
  final double propertyLat;
  final double propertyLng;
  final String propertyTitle;
  final String address;

  const FullScreenMapView({
    super.key,
    required this.propertyLat,
    required this.propertyLng,
    required this.propertyTitle,
    required this.address,
  });

  @override
  State<FullScreenMapView> createState() => _FullScreenMapViewState();
}

class _FullScreenMapViewState extends State<FullScreenMapView> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  bool _showCurrentLocation = false;
  double _currentZoom = 14.0;
  StreamSubscription<Position>? _positionStream;
  double? _distance; // Distance in meters
  Duration? _estimatedDuration; // Estimated travel time

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _calculateDistance() {
    if (_currentLocation != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        widget.propertyLat,
        widget.propertyLng,
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );

      // Calculate estimated travel time (assuming average driving speed of 50 km/h in city)
      final drivingSpeedKmh = 50.0; // km/h
      final distanceKm = distanceInMeters / 1000;

      final drivingMinutes = (distanceKm / drivingSpeedKmh * 60).round();

      setState(() {
        _distance = distanceInMeters;
        // Use driving time as default, but show both options
        _estimatedDuration = Duration(minutes: drivingMinutes);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() => _isLoadingLocation = true);
    try {
      // Check if location services are enabled with better error handling
      bool serviceEnabled;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (e) {
        // If the method doesn't exist or fails, try to get location anyway
        serviceEnabled = true;
      }

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text("Location services are disabled. Please enable them."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Location permissions are denied."),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Location permissions are permanently denied. Please enable location permissions in settings."),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get initial position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Location request timed out');
        },
      );

      if (!mounted) return;

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _showCurrentLocation = true;
        _isLoadingLocation = false;
      });

      _calculateDistance();

      // Start listening to position updates
      _positionStream?.cancel(); // Cancel previous stream if exists
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) {
          if (mounted) {
            setState(() {
              _currentLocation = LatLng(position.latitude, position.longitude);
            });
            _calculateDistance();
          }
        },
        onError: (error) {
          // Silently handle stream errors
          if (mounted && _showCurrentLocation) {
            debugPrint('Location stream error: $error');
          }
        },
      );

      // Center map on current location
      _mapController.move(_currentLocation!, 15);
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location request timed out. Please try again."),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _isLoadingLocation = false);
    } catch (e) {
      if (mounted) {
        // More user-friendly error message
        String errorMessage = "Unable to get your location. ";
        if (e.toString().contains('MissingPluginException')) {
          errorMessage += "Please restart the app or reinstall it.";
        } else {
          errorMessage += "Please check your location settings and try again.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() => _isLoadingLocation = false);
    }
  }

  void _centerOnProperty() {
    _mapController.move(LatLng(widget.propertyLat, widget.propertyLng), 15);
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    } else {
      _getCurrentLocation();
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0);
    });
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0);
    });
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  String _formatDistance(double? distance) {
    if (distance == null) return "Calculating...";
    if (distance < 1000) {
      return "${distance.toStringAsFixed(0)} m";
    } else {
      return "${(distance / 1000).toStringAsFixed(2)} km";
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "Calculating...";
    if (duration.inMinutes < 60) {
      return "${duration.inMinutes} min";
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      if (minutes == 0) {
        return "$hours ${hours == 1 ? 'hour' : 'hours'}";
      }
      return "$hours h $minutes min";
    }
  }

  String _formatEstimatedTime(Duration? duration) {
    if (duration == null) return "Calculating...";
    final now = DateTime.now();
    final arrivalTime = now.add(duration);
    return DateFormat('HH:mm').format(arrivalTime);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.propertyTitle,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Flexible(
              child: Text(
                widget.address,
                style: TextStyle(fontSize: isTablet ? 14 : 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_distance != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: 8,
              ),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.straighten,
                        size: isTablet ? 18 : 16,
                      ),
                      SizedBox(width: isTablet ? 6 : 4),
                      Text(
                        _formatDistance(_distance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isTablet ? 14 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(widget.propertyLat, widget.propertyLng),
              initialZoom: 14,
              onTap: (tapPosition, point) {
                // Allow map interaction
              },
              onMapReady: () {
                _mapController.mapEventStream.listen((event) {
                  if (event is MapEventMoveEnd) {
                    setState(() {
                      _currentZoom = _mapController.camera.zoom;
                    });
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  // Property marker
                  Marker(
                    point: LatLng(widget.propertyLat, widget.propertyLng),
                    width: 80,
                    height: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kPrimaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.home,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: kPrimaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              "Property",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Current location marker
                  if (_currentLocation != null && _showCurrentLocation)
                    Marker(
                      point: _currentLocation!,
                      width: 80,
                      height: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "You",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              // Polyline between property and current location
              if (_currentLocation != null && _showCurrentLocation)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(widget.propertyLat, widget.propertyLng),
                        _currentLocation!,
                      ],
                      strokeWidth: 3,
                      color: Colors.blue.withOpacity(0.6),
                    ),
                  ],
                ),
            ],
          ),
          // Control buttons - responsive positioning
          LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = constraints.maxHeight;
              final bottomOffset = screenHeight > 600 ? 100.0 : 80.0;
              return Positioned(
                bottom: bottomOffset,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      onPressed: _centerOnProperty,
                      backgroundColor: kPrimaryColor,
                      heroTag: "property_location",
                      mini: screenWidth < 600,
                      child: const Icon(Icons.home, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      onPressed: _isLoadingLocation
                          ? null
                          : (_currentLocation != null
                              ? _centerOnCurrentLocation
                              : _getCurrentLocation),
                      backgroundColor: Colors.blue,
                      heroTag: "current_location",
                      mini: screenWidth < 600,
                      child: _isLoadingLocation
                          ? SizedBox(
                              width: screenWidth < 600 ? 20 : 24,
                              height: screenWidth < 600 ? 20 : 24,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.my_location, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      onPressed: _zoomIn,
                      backgroundColor: Colors.white,
                      heroTag: "zoom_in",
                      mini: screenWidth < 600,
                      child: const Icon(Icons.add, color: Colors.black),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      onPressed: _zoomOut,
                      backgroundColor: Colors.white,
                      heroTag: "zoom_out",
                      mini: screenWidth < 600,
                      child: const Icon(Icons.remove, color: Colors.black),
                    ),
                  ],
                ),
              );
            },
          ),
          // Info card with distance, time, and duration - responsive
          if (_distance != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth > 600;
                return Positioned(
                  bottom: 16,
                  left: 16,
                  right: constraints.maxWidth > 600 ? null : 16,
                  width: isTablet ? 400 : null,
                  child: Container(
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Distance row
                        Row(
                          children: [
                            Icon(
                              Icons.straighten,
                              color: kPrimaryColor,
                              size: isTablet ? 32 : 28,
                            ),
                            SizedBox(width: isTablet ? 16 : 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Distance",
                                    style: TextStyle(
                                      fontSize: isTablet ? 14 : 12,
                                      color: kTextSecondary,
                                    ),
                                  ),
                                  Text(
                                    _formatDistance(_distance),
                                    style: TextStyle(
                                      fontSize: isTablet ? 20 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: kTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Duration column
                            if (_estimatedDuration != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Duration",
                                    style: TextStyle(
                                      fontSize: isTablet ? 14 : 12,
                                      color: kTextSecondary,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: kPrimaryColor,
                                        size: isTablet ? 18 : 16,
                                      ),
                                      SizedBox(width: isTablet ? 6 : 4),
                                      Text(
                                        _formatDuration(_estimatedDuration),
                                        style: TextStyle(
                                          fontSize: isTablet ? 20 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: kTextPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                        // Estimated arrival time
                        if (_estimatedDuration != null)
                          Padding(
                            padding: EdgeInsets.only(top: isTablet ? 16 : 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: Colors.blue,
                                  size: isTablet ? 22 : 20,
                                ),
                                SizedBox(width: isTablet ? 10 : 8),
                                Expanded(
                                  child: Text(
                                    "Estimated arrival: ${_formatEstimatedTime(_estimatedDuration)}",
                                    style: TextStyle(
                                      fontSize: isTablet ? 14 : 13,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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

class _AddReviewForm extends StatefulWidget {
  final String propertyId;
  final VoidCallback onSubmitted;
  const _AddReviewForm({required this.propertyId, required this.onSubmitted});

  @override
  State<_AddReviewForm> createState() => _AddReviewFormState();
}

class _AddReviewFormState extends State<_AddReviewForm> {
  final _ctrl = TextEditingController();
  int _rating = 0;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Write a Review",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          "How was your experience?",
          style: TextStyle(color: kTextSecondary),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < _rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: kAccentColor,
                size: 36,
              ),
              onPressed: () => setState(() => _rating = index + 1),
            );
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Share your thoughts about this property...",
            filled: true,
            fillColor: kSurfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
                    final prefs = await SharedPreferences.getInstance();
                    if (prefs.getString('token') == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please login first"),
                        ),
                      );
                      return;
                    }
                    if (_rating == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select a rating"),
                        ),
                      );
                      return;
                    }

                    setState(() => _isLoading = true);
                    final (ok, msg) = await ApiService.addReview(
                      propertyId: widget.propertyId,
                      rating: _rating,
                      comment: _ctrl.text,
                    );
                    setState(() => _isLoading = false);

                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Review submitted successfully!"),
                          backgroundColor: kPrimaryColor,
                        ),
                      );
                      widget.onSubmitted();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text("Submit Review"),
          ),
        ),
      ],
    );
  }
}

// Interactive Map Widget with GPS
class _InteractiveMap extends StatefulWidget {
  final double propertyLat;
  final double propertyLng;

  const _InteractiveMap({
    required this.propertyLat,
    required this.propertyLng,
  });

  @override
  State<_InteractiveMap> createState() => _InteractiveMapState();
}

class _InteractiveMapState extends State<_InteractiveMap> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  bool _isLoadingLocation = false;
  bool _showCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text("Location services are disabled. Please enable them."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Location permissions are denied."),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Location permissions are permanently denied. Please enable them in settings."),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _showCurrentLocation = true;
        _isLoadingLocation = false;
      });

      // Center map on current location
      _mapController.move(_currentLocation!, 15);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error getting location: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoadingLocation = false);
    }
  }

  void _centerOnProperty() {
    _mapController.move(LatLng(widget.propertyLat, widget.propertyLng), 15);
  }

  void _centerOnCurrentLocation() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(widget.propertyLat, widget.propertyLng),
            initialZoom: 14,
            onTap: (tapPosition, point) {
              // Allow map interaction
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(
              markers: [
                // Property marker
                Marker(
                  point: LatLng(widget.propertyLat, widget.propertyLng),
                  width: 50,
                  height: 50,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.home,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const Text(
                        "Property",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryColor,
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Current location marker
                if (_currentLocation != null && _showCurrentLocation)
                  Marker(
                    point: _currentLocation!,
                    width: 50,
                    height: 50,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const Text(
                          "You",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            shadows: [
                              Shadow(
                                color: Colors.white,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        // Control buttons
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton.small(
                onPressed: _centerOnProperty,
                backgroundColor: kPrimaryColor,
                heroTag: "property_location",
                child: const Icon(Icons.home, color: Colors.white),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                onPressed: _isLoadingLocation
                    ? null
                    : (_currentLocation != null
                        ? _centerOnCurrentLocation
                        : _getCurrentLocation),
                backgroundColor: Colors.blue,
                heroTag: "current_location",
                child: _isLoadingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
