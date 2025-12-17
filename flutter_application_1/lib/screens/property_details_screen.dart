import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/screens/tenant_payment_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// --- 🎨 SHAQATI Premium Theme Colors ---
const Color kPrimaryColor = Color(0xFF2E7D32); // الأخضر الأساسي
const Color kDarkGreen = Color(0xFF1B5E20); // الأخضر الغامق
const Color kAccentColor = Color(0xFFFFA000); // ذهبي للتقييمات
const Color kTextPrimary = Color(0xFF1A1A1A); // أسود داكن للنصوص
const Color kTextSecondary = Color(0xFF757575); // رمادي للنصوص الفرعية
const Color kSurfaceColor = Color(0xFFF9F9F9); // خلفية فاتحة جداً
const Color kWhite = Colors.white;
const Color kDisabledColor = Color(0xFFBDBDBD); // لون رمادي للعناصر المعطلة

class PropertyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  bool _isLoadingReviews = true;
  List<dynamic> _reviews = [];
  bool _isSendingRequest = false;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
    _scrollController.addListener(() {
      setState(() {
        _showAppBarTitle = _scrollController.offset > 300;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  // ✅ دالة إرسال الطلب وفتح صفحة الدفع
  Future<void> _handleAction() async {
    final status =
        widget.property['status']?.toString().toLowerCase() ?? 'available';

    // يُسمح بالطلب فقط إذا كانت الحالة "available"
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

    // تحديد المبلغ وصاحب العقار
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
      // 1️⃣ إنشاء عقد مبدئي بحالة pending
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

      // 2️⃣ فتح شاشة الدفع لبطاقة الفيزا (مع وضع تجريبي)
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

  // ignore: unused_element
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: kPrimaryColor, size: 40),
            ),
            const SizedBox(height: 16),
            const Text("Request Sent!",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary)),
            const SizedBox(height: 8),
            const Text(
              "The owner has been notified. Wait for approval to finalize the contract.",
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child:
                    const Text("Done", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final imgUrl = (p['images'] != null && p['images'].isNotEmpty)
        ? p['images'][0]
        : 'https://via.placeholder.com/600x400';
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0, name: 'USD');

    // 🔒 منطق حالة العقار
    final String status = p['status']?.toString().toLowerCase() ?? 'available';

    final bool isAvailable = status == 'available';
    final bool isPendingApproval = status == 'pending_approval';

    // نص الزر ولونه وحالة التفعيل بناءً على حالة العقار
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
              SliverAppBar(
                expandedHeight: 350,
                pinned: true,
                backgroundColor: kWhite,
                elevation: 0,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
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
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: kPrimaryColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: kTextSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  (review['reviewerId']?['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                review['reviewerId']?['name'] ?? 'User',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < (review['rating'] ?? 0)
                        ? Icons.star
                        : Icons.star_border,
                    size: 14,
                    color: kAccentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review['comment'] ?? "",
            style: const TextStyle(color: kTextPrimary),
          ),
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
                          content: Text("Please Login first"),
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
                          content: Text("Review Submitted!"),
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
