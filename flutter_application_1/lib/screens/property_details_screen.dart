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
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
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
            final contractPropertyId =
                contract['propertyId']?['_id']?.toString() ??
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

    try {
      // ✅ لا نحتاج landlordId - Backend يأخذه تلقائياً من property.ownerId (صاحب العقار/المنشئ)
      final (ok, msg, contract) = await ApiService.requestContract(
        propertyId: widget.property['_id'],
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

  // Calculate number of installments based on rent duration and payment frequency
  int? _calculateNumberOfInstallments() {
    if (_rentDurationMonths == null || _paymentFrequency == null) {
      return null;
    }

    final months = _rentDurationMonths!;
    final frequency = _paymentFrequency!.toLowerCase();

    switch (frequency) {
      case 'daily':
        // Approximate: 30.44 days per month
        return (months * 30.44).round();
      case 'weekly':
        // Approximate: 4.33 weeks per month
        return (months * 4.33).round();
      case 'monthly':
        return months;
      case 'yearly':
        // If yearly payment, number of installments = number of years
        return (months / 12).ceil();
      default:
        return months; // Default to monthly calculation
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
              // ✅ Hero Section - Grid of Images
              SliverAppBar(
                expandedHeight: 320, // ارتفاع مناسب للـ Grid
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
                  // ✅ زر Video
                  if (p['videoUrl'] != null &&
                      p['videoUrl'].toString().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.play_circle_filled, color: Colors.white),
                        onPressed: () => _showVideoPlayer(p['videoUrl']),
                        tooltip: 'Watch Video',
                      ),
                    ),
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
                  background: _buildImageGrid(images, p),
                ),
              ),

              // باقي المحتوى - تصميم جديد بالكامل
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section with Title and Location
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['title'] ?? 'No Title',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: kTextPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: kPrimaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.location_on,
                                    size: 18, color: kPrimaryColor),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${p['city'] ?? ''}, ${p['address'] ?? ''}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: kTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Price & Rental Info Card - في المقدمة
                    if (p['operation'] == 'rent') ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildRentInfoCard(),
                      ),
                    ],

                    // Basic Stats - Bedrooms, Bathrooms, Area
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _buildEnhancedStatItem(
                                Icons.bed_rounded,
                                "${p['bedrooms'] ?? 0}",
                                "Bedrooms",
                                kPrimaryColor,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: Colors.grey.shade300,
                            ),
                            Expanded(
                              child: _buildEnhancedStatItem(
                                Icons.bathtub_outlined,
                                "${p['bathrooms'] ?? 0}",
                                "Bathrooms",
                                kPrimaryColor,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: Colors.grey.shade300,
                            ),
                            Expanded(
                              child: _buildEnhancedStatItem(
                                Icons.square_foot_rounded,
                                "${p['area'] ?? 0}",
                                "Sq.m",
                                kPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Property Description
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                child: const Icon(
                                  Icons.description,
                                  color: kPrimaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "About this property",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: kTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: kSurfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              p['description'] ?? "No description available.",
                              style: const TextStyle(
                                fontSize: 15,
                                color: kTextSecondary,
                                height: 1.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amenities Section
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                child: const Icon(
                                  Icons.star_outline,
                                  color: kPrimaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Amenities & Features",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: kTextPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: (p['amenities'] as List? ?? [])
                                .map(
                                  (e) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: kWhite,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: kPrimaryColor.withOpacity(0.3)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: kPrimaryColor,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          e.toString(),
                                          style: const TextStyle(
                                            color: kTextPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),

                    // Additional Property Information Card
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildPropertyInfoCard(p),
                    ),

                    // Quick Facts Card
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildQuickFactsCard(p),
                    ),

                    // Property Features Grid
                    if ((p['amenities'] as List? ?? []).isNotEmpty ||
                        _hasElevator ||
                        _hasGarden ||
                        _hasBalcony ||
                        _hasPool ||
                        (_parkingSpaces != null && _parkingSpaces! > 0))
                      ...[
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildFeaturesGrid(p),
                        ),
                      ],

                    // Location Section
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.location_on,
                                      color: kPrimaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "Location",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: kTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  final propertyLat =
                                      (p['location']['coordinates'][1] as num)
                                          .toDouble();
                                  final propertyLng =
                                      (p['location']['coordinates'][0] as num)
                                          .toDouble();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenMapView(
                                        propertyLat: propertyLat,
                                        propertyLng: propertyLng,
                                        propertyTitle: p['title'] ?? 'Property',
                                        address:
                                            "${p['city'] ?? ''}, ${p['address'] ?? ''}",
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.open_in_full, size: 16),
                                label: const Text("Open Map"),
                                style: TextButton.styleFrom(
                                  foregroundColor: kPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                        height: 250,
                        decoration: BoxDecoration(
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              // ✅ Interactive Map مع GPS
                              _InteractiveMap(
                                propertyLat:
                                    (p['location']['coordinates'][1] as num)
                                        .toDouble(),
                                propertyLng:
                                    (p['location']['coordinates'][0] as num)
                                        .toDouble(),
                              ),
                              // زر فتح الخريطة الكاملة
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.fullscreen,
                                        color: kPrimaryColor),
                                    onPressed: () {
                                      final propertyLat = (p['location']
                                              ['coordinates'][1] as num)
                                          .toDouble();
                                      final propertyLng = (p['location']
                                              ['coordinates'][0] as num)
                                          .toDouble();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              FullScreenMapView(
                                            propertyLat: propertyLat,
                                            propertyLng: propertyLng,
                                            propertyTitle:
                                                p['title'] ?? 'Property',
                                            address:
                                                "${p['city'] ?? ''}, ${p['address'] ?? ''}",
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: 'Open Full Map',
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

                    // Reviews Section
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: kPrimaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.star,
                                      color: kAccentColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "Reviews",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: kTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
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
                          const SizedBox(height: 16),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),

          // 3. Fixed Bottom Action Bar - تصميم مصغر في سطر واحد
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Price Section - الجانب الأيسر
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['operation'] == 'rent' ? "Monthly Rent" : "Price",
                            style: TextStyle(
                              fontSize: 11,
                              color: kTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  currency.format(p['price']),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: kPrimaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (p['operation'] == 'rent')
                                Text(
                                  "/mo",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: kTextSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Chat button (only show if property is available)
                    if (isAvailable)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _openChatWithAdmin,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: kPrimaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: kPrimaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                color: kPrimaryColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Action Button - الجانب الأيمن
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: (isButtonEnabled && !_isSendingRequest)
                            ? _handleAction
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: kDisabledColor,
                        ),
                        icon: _isSendingRequest
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isButtonEnabled
                                    ? (p['operation'] == 'rent'
                                        ? Icons.handshake
                                        : Icons.shopping_cart)
                                    : Icons.block,
                                size: 18,
                              ),
                        label: Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 14,
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

  // ✅ بناء Carousel Slider للصور - تصميم جديد مع تمرير سلس
  Widget _buildImageGrid(List images, Map<String, dynamic> p) {
    if (images.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.image, size: 64, color: Colors.grey),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Carousel Slider للصور - بدون tap gesture
        CarouselSlider.builder(
          itemCount: images.length,
          itemBuilder: (context, index, realIndex) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(0),
              ),
              child: CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: kPrimaryColor,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.image, color: Colors.grey, size: 64),
                  ),
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: double.infinity,
            viewportFraction: 1.0,
            enableInfiniteScroll: images.length > 1,
            autoPlay: images.length > 1,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayAnimationDuration: const Duration(milliseconds: 1000),
            autoPlayCurve: Curves.easeInOutCubic,
            scrollPhysics: const BouncingScrollPhysics(),
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
        ),
        
        // Gradient Overlay في الأسفل
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
        
        // Pagination Indicators
        if (images.length > 1)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  width: _currentImageIndex == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentImageIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
        
        // Image Counter
        if (images.length > 1)
          Positioned(
            bottom: 130,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
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
        
        // FOR RENT/SALE Badge
        Positioned(
          bottom: 100,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: p['operation'] == 'rent' ? kAccentColor : kPrimaryColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  p['operation'] == 'rent' ? Icons.house : Icons.sell,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  p['operation'] == 'rent' ? "FOR RENT" : "FOR SALE",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // زر فتح الألبوم - في الأسفل
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openFullScreenGallery(_currentImageIndex),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.photo_library,
                        color: kPrimaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "View All Photos",
                          style: TextStyle(
                            color: kTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${images.length} ${images.length == 1 ? 'photo' : 'photos'} available",
                          style: TextStyle(
                            color: kTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: kPrimaryColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Helper method لبناء عنصر صورة واحد
  Widget _buildImageItem(
    String imageUrl,
    int index,
    Map<String, dynamic> p, {
    bool isFirst = false,
    bool showOverlay = false,
    int remainingCount = 0,
  }) {
    return GestureDetector(
      onTap: () => _openFullScreenGallery(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.image, color: Colors.grey),
            ),
          ),
          // Gradient overlay
          if (isFirst)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
          // Overlay للصور الإضافية
          if (showOverlay)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_library,
                        color: Colors.white, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      "+$remainingCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "more",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Badge للعملية (Rent/Sale) على الصورة الأولى فقط
          if (isFirst)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      p['operation'] == 'rent' ? kAccentColor : kPrimaryColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p['operation'] == 'rent' ? "FOR RENT" : "FOR SALE",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
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

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: kPrimaryColor, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: kTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedStatItem(
      IconData icon, String value, String label, Color iconColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: kTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyInfoCard(Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kPrimaryColor.withOpacity(0.08),
            kPrimaryColor.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimaryColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: kPrimaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Property Information",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (_yearBuilt != null)
                _buildInfoTile(
                  Icons.calendar_today,
                  "Year Built",
                  _yearBuilt!,
                ),
              if (_propertyAge != null)
                _buildInfoTile(
                  Icons.history,
                  "Property Age",
                  "$_propertyAge years",
                ),
              if (_floors != null)
                _buildInfoTile(
                  Icons.layers,
                  "Floors",
                  "$_floors",
                ),
              if (_propertyCondition != null)
                _buildInfoTile(
                  Icons.home_work,
                  "Condition",
                  _propertyCondition!,
                ),
              if (_furnishingStatus != null &&
                  _furnishingStatus != 'Not specified')
                _buildInfoTile(
                  Icons.chair,
                  "Furnishing",
                  _furnishingStatus!,
                ),
              if (_parkingSpaces != null && _parkingSpaces! > 0)
                _buildInfoTile(
                  Icons.local_parking,
                  "Parking",
                  "$_parkingSpaces spaces",
                ),
              if (_hasElevator)
                _buildInfoTile(
                  Icons.elevator,
                  "Elevator",
                  "Yes",
                ),
              if (_hasGarden)
                _buildInfoTile(
                  Icons.grass,
                  "Garden",
                  "Yes",
                ),
              if (_hasBalcony)
                _buildInfoTile(
                  Icons.balcony,
                  "Balcony",
                  "Yes",
                ),
              if (_hasPool)
                _buildInfoTile(
                  Icons.pool,
                  "Pool",
                  "Yes",
                ),
              if (_heatingType != null && _heatingType != 'Not specified')
                _buildInfoTile(
                  Icons.thermostat,
                  "Heating",
                  _heatingType!,
                ),
              if (_coolingType != null && _coolingType != 'Not specified')
                _buildInfoTile(
                  Icons.ac_unit,
                  "Cooling",
                  _coolingType!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kPrimaryColor, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: kTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Quick Facts Card - معلومات سريعة
  Widget _buildQuickFactsCard(Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kAccentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: kAccentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Quick Facts",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildQuickFactItem(
                  Icons.home,
                  "Property Type",
                  p['propertyType']?.toString().toUpperCase() ?? 'N/A',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickFactItem(
                  Icons.category,
                  "Operation",
                  p['operation']?.toString().toUpperCase() ?? 'N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p['status'] != null)
            Row(
              children: [
                Expanded(
                  child: _buildQuickFactItem(
                    Icons.info,
                    "Status",
                    p['status']?.toString().toUpperCase() ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickFactItem(
                    Icons.location_city,
                    "City",
                    p['city']?.toString() ?? 'N/A',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickFactItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimaryColor, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: kTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Features Grid - شبكة المميزات
  Widget _buildFeaturesGrid(Map<String, dynamic> p) {
    List<Map<String, dynamic>> features = [];

    // Add amenities
    if (p['amenities'] != null && (p['amenities'] as List).isNotEmpty) {
      for (var amenity in p['amenities']) {
        features.add({
          'icon': Icons.check_circle,
          'label': amenity.toString(),
          'color': kPrimaryColor,
        });
      }
    }

    // Add property features
    if (_hasElevator) {
      features.add({
        'icon': Icons.elevator,
        'label': 'Elevator',
        'color': kPrimaryColor,
      });
    }
    if (_hasGarden) {
      features.add({
        'icon': Icons.grass,
        'label': 'Garden',
        'color': kPrimaryColor,
      });
    }
    if (_hasBalcony) {
      features.add({
        'icon': Icons.balcony,
        'label': 'Balcony',
        'color': kPrimaryColor,
      });
    }
    if (_hasPool) {
      features.add({
        'icon': Icons.pool,
        'label': 'Pool',
        'color': kPrimaryColor,
      });
    }
    if (_parkingSpaces != null && _parkingSpaces! > 0) {
      features.add({
        'icon': Icons.local_parking,
        'label': 'Parking (${_parkingSpaces})',
        'color': kPrimaryColor,
      });
    }

    if (features.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.star,
                  color: kPrimaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Features & Amenities",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: features.map((feature) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (feature['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (feature['color'] as Color).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      feature['icon'] as IconData,
                      color: feature['color'] as Color,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      feature['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 50,
      color: Colors.grey.shade300,
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
          // Video Section
          if (p['videoUrl'] != null &&
              p['videoUrl'].toString().isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSectionHeader("Property Video"),
            const SizedBox(height: 12),
            _buildVideoPlayer(p['videoUrl']),
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
    final numberOfInstallments = _calculateNumberOfInstallments();
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0, name: 'USD');
    final totalPrice = widget.property['price'] as num?;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kPrimaryColor,
            kPrimaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Rental Information",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Total Price - Highlighted
          if (totalPrice != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Rental Price",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "For entire duration",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    currency.format(totalPrice),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Rental Details Grid
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Rent Duration
                if (_rentDurationMonths != null)
                  _buildRentDetailRow(
                    Icons.calendar_today,
                    "Rent Duration",
                    "$_rentDurationMonths months",
                    "How long you'll rent",
                  ),
                if (_rentDurationMonths != null && _paymentFrequency != null)
                  const Divider(height: 20),
                
                // Payment Frequency
                if (_paymentFrequency != null)
                  _buildRentDetailRow(
                    Icons.payment,
                    "Payment Frequency",
                    _paymentFrequency!,
                    "How often you pay",
                  ),
                if (numberOfInstallments != null && _paymentFrequency != null)
                  const Divider(height: 20),
                
                // Number of Installments
                if (numberOfInstallments != null && _paymentFrequency != null)
                  _buildRentDetailRow(
                    Icons.format_list_numbered,
                    "Number of Installments",
                    "$numberOfInstallments payments",
                    "Total number of payments",
                  ),
                if (paymentAmount != null && _paymentFrequency != null)
                  const Divider(height: 20),
                
                // Payment Amount per Installment
                if (paymentAmount != null && _paymentFrequency != null)
                  _buildRentDetailRow(
                    Icons.attach_money,
                    "Payment per ${_paymentFrequency!.toLowerCase()}",
                    currency.format(paymentAmount),
                    "Amount for each payment",
                    isHighlighted: true,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentDetailRow(
    IconData icon,
    String label,
    String value,
    String subtitle, {
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isHighlighted
                ? kPrimaryColor.withOpacity(0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isHighlighted ? kPrimaryColor : kTextSecondary,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: kTextSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlighted ? 18 : 16,
            fontWeight: FontWeight.bold,
            color: isHighlighted ? kPrimaryColor : kTextPrimary,
          ),
        ),
      ],
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

  Widget _buildRentInfoRowWithIcon(
    IconData icon,
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: isHighlighted ? kPrimaryColor : kTextSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: kTextSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 17 : 15,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? kPrimaryColor : kTextPrimary,
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

  Widget _buildVideoPlayer(String videoUrl) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Show thumbnail or placeholder
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      size: 64,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to play video',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Clickable overlay
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showVideoPlayer(videoUrl),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ دالة لعرض الفيديو في صفحة كاملة
  void _showVideoPlayer(String videoUrl) {
    // Handle YouTube URLs
    String embedUrl = videoUrl;
    if (videoUrl.contains('youtube.com/watch?v=')) {
      final videoId = videoUrl.split('v=')[1].split('&')[0];
      embedUrl = 'https://www.youtube.com/embed/$videoId?autoplay=1';
    } else if (videoUrl.contains('youtu.be/')) {
      final videoId = videoUrl.split('youtu.be/')[1].split('?')[0];
      embedUrl = 'https://www.youtube.com/embed/$videoId?autoplay=1';
    } else if (!videoUrl.contains('embed')) {
      embedUrl = videoUrl;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Property Video',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (embedUrl.contains('youtube.com/embed'))
                  SizedBox(
                    height: 300,
                    child: ModelViewer(
                      src: embedUrl,
                      alt: "Property Video",
                      backgroundColor: Colors.black,
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.video_library, 
                            size: 64, 
                            color: Colors.white70),
                          const SizedBox(height: 16),
                          const Text(
                            'Video Player',
                            style: TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            videoUrl,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Open video in external browser
                              _launchExternalUrl(videoUrl);
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open Video in Browser'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open video URL')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening video: $e')),
        );
      }
    }
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
  List<LatLng> _routePoints = []; // نقاط المسار على الطريق
  bool _isLoadingRoute = false;

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
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        forceAndroidLocationManager: true,
        timeLimit: const Duration(seconds: 20),
      ).timeout(
        const Duration(seconds: 30),
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
      
      // جلب المسار على الطريق
      if (_currentLocation != null) {
        await _fetchRoute();
      }

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

  // جلب المسار على الطريق العام باستخدام OSRM - يتبع الطرق الفعلية
  Future<void> _fetchRoute() async {
    if (_currentLocation == null) return;
    
    setState(() => _isLoadingRoute = true);
    
    try {
      // استخدام OSRM API للحصول على المسار على الطرق الفعلية
      final startLng = _currentLocation!.longitude;
      final startLat = _currentLocation!.latitude;
      final endLng = widget.propertyLng;
      final endLat = widget.propertyLat;
      
      // استخدام driving profile للحصول على مسار على الطرق
      // overview=full للحصول على جميع النقاط في المسار
      final url = 'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson&steps=true';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Route request timed out');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && 
            data['routes'] != null && 
            data['routes'].isNotEmpty &&
            data['routes'][0]['geometry'] != null) {
          
          final geometry = data['routes'][0]['geometry']['coordinates'];
          
          // تحويل الإحداثيات من [lng, lat] إلى LatLng [lat, lng]
          final routePoints = <LatLng>[];
          for (var coord in geometry) {
            if (coord is List && coord.length >= 2) {
              routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
            }
          }
          
          if (routePoints.isNotEmpty) {
            setState(() {
              _routePoints = routePoints;
              _isLoadingRoute = false;
            });
            return;
          }
        }
      }
      
      // إذا فشل OSRM، جرب GraphHopper كبديل
      await _fetchRouteFromGraphHopper();
      
    } catch (e) {
      // إذا فشل كل شيء، جرب GraphHopper
      await _fetchRouteFromGraphHopper();
    }
  }

  // جلب المسار من GraphHopper كبديل
  Future<void> _fetchRouteFromGraphHopper() async {
    if (_currentLocation == null) return;
    
    try {
      final startLng = _currentLocation!.longitude;
      final startLat = _currentLocation!.latitude;
      final endLng = widget.propertyLng;
      final endLat = widget.propertyLat;
      
      // GraphHopper API (مجاني بدون API key للاستخدام المحدود)
      final url = 'https://graphhopper.com/api/1/route?point=$startLat,$startLng&point=$endLat,$endLng&vehicle=car&type=json&instructions=false&points_encoded=false';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Route request timed out');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['paths'] != null && 
            data['paths'].isNotEmpty &&
            data['paths'][0]['points'] != null) {
          
          final points = data['paths'][0]['points']['coordinates'] as List;
          
          final routePoints = <LatLng>[];
          for (var coord in points) {
            if (coord is List && coord.length >= 2) {
              routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
            }
          }
          
          if (routePoints.isNotEmpty) {
            setState(() {
              _routePoints = routePoints;
              _isLoadingRoute = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      // إذا فشل كل شيء، لا نعرض مسار
      setState(() {
        _routePoints = [];
        _isLoadingRoute = false;
      });
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
              // ✅ المسار على الطريق العام (Route) - يتبع الطرق الفعلية
              if (_routePoints.isNotEmpty && _showCurrentLocation)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6,
                      color: kPrimaryColor,
                      borderStrokeWidth: 3,
                      borderColor: Colors.white,
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
    return SingleChildScrollView(
      child: Column(
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
          // Comment input field
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            decoration: InputDecoration(
              hintText: "Share your thoughts about this property...",
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),
          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
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
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isLoading ? "Submitting..." : "Submit Review",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
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
  double? _distance; // المسافة بالمتر
  List<LatLng> _routePoints = []; // نقاط المسار على الطريق
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  void _calculateDistance() {
    if (_currentLocation != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        widget.propertyLat,
        widget.propertyLng,
        _currentLocation!.latitude,
        _currentLocation!.longitude,
      );
      setState(() {
        _distance = distanceInMeters;
      });
    }
  }

  String _formatDistance(double? distance) {
    if (distance == null) return "Calculating...";
    if (distance < 1000) {
      return "${distance.toStringAsFixed(0)} m";
    } else {
      return "${(distance / 1000).toStringAsFixed(2)} km";
    }
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
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        forceAndroidLocationManager: true,
        timeLimit: const Duration(seconds: 20),
      ).timeout(
        const Duration(seconds: 30),
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
      
      // جلب المسار على الطريق
      if (_currentLocation != null) {
        await _fetchRoute();
      }

      // Center map to show both locations
      if (_currentLocation != null) {
        try {
          final bounds = LatLngBounds.fromPoints([
            LatLng(widget.propertyLat, widget.propertyLng),
            _currentLocation!,
          ]);
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
          );
        } catch (e) {
          // Fallback to property location
          _mapController.move(
              LatLng(widget.propertyLat, widget.propertyLng), 14);
        }
      }
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

  // جلب المسار على الطريق العام باستخدام OSRM - يتبع الطرق الفعلية
  Future<void> _fetchRoute() async {
    if (_currentLocation == null) return;
    
    setState(() => _isLoadingRoute = true);
    
    try {
      // استخدام OSRM API للحصول على المسار على الطرق الفعلية
      final startLng = _currentLocation!.longitude;
      final startLat = _currentLocation!.latitude;
      final endLng = widget.propertyLng;
      final endLat = widget.propertyLat;
      
      // استخدام driving profile للحصول على مسار على الطرق
      // overview=full للحصول على جميع النقاط في المسار
      final url = 'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson&steps=true';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Route request timed out');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && 
            data['routes'] != null && 
            data['routes'].isNotEmpty &&
            data['routes'][0]['geometry'] != null) {
          
          final geometry = data['routes'][0]['geometry']['coordinates'];
          
          // تحويل الإحداثيات من [lng, lat] إلى LatLng [lat, lng]
          final routePoints = <LatLng>[];
          for (var coord in geometry) {
            if (coord is List && coord.length >= 2) {
              routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
            }
          }
          
          if (routePoints.isNotEmpty) {
            setState(() {
              _routePoints = routePoints;
              _isLoadingRoute = false;
            });
            return;
          }
        }
      }
      
      // إذا فشل OSRM، جرب GraphHopper كبديل
      await _fetchRouteFromGraphHopper();
      
    } catch (e) {
      // إذا فشل كل شيء، جرب GraphHopper
      await _fetchRouteFromGraphHopper();
    }
  }

  // جلب المسار من GraphHopper كبديل
  Future<void> _fetchRouteFromGraphHopper() async {
    if (_currentLocation == null) return;
    
    try {
      final startLng = _currentLocation!.longitude;
      final startLat = _currentLocation!.latitude;
      final endLng = widget.propertyLng;
      final endLat = widget.propertyLat;
      
      // GraphHopper API (مجاني بدون API key للاستخدام المحدود)
      final url = 'https://graphhopper.com/api/1/route?point=$startLat,$startLng&point=$endLat,$endLng&vehicle=car&type=json&instructions=false&points_encoded=false';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Route request timed out');
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['paths'] != null && 
            data['paths'].isNotEmpty &&
            data['paths'][0]['points'] != null) {
          
          final points = data['paths'][0]['points']['coordinates'] as List;
          
          final routePoints = <LatLng>[];
          for (var coord in points) {
            if (coord is List && coord.length >= 2) {
              routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
            }
          }
          
          if (routePoints.isNotEmpty) {
            setState(() {
              _routePoints = routePoints;
              _isLoadingRoute = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      // إذا فشل كل شيء، لا نعرض مسار
      setState(() {
        _routePoints = [];
        _isLoadingRoute = false;
      });
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
            // ✅ خريطة الطرق (OpenStreetMap) بدلاً من الهوائية
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.shaqati.app',
              maxZoom: 19,
            ),
            // ✅ المسار على الطريق العام (Route)
            if (_routePoints.isNotEmpty && _showCurrentLocation)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5,
                    color: kPrimaryColor,
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Property marker
                Marker(
                  point: LatLng(widget.propertyLat, widget.propertyLng),
                  width: 60,
                  height: 60,
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
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Property",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                    width: 60,
                    height: 60,
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
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "You",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        // ✅ مؤشر تحميل المسار
        if (_isLoadingRoute)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kPrimaryColor,
                ),
              ),
            ),
          ),
        // ✅ بطاقة المسافة
        if (_distance != null)
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.straighten, color: kPrimaryColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _formatDistance(_distance),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
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
