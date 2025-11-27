import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

// --- 🌿 Theme Matching Home ---
class AppTheme {
  static const Color primary = Color(0xFF2E7D32); // Same Green
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color accent = Color(0xFFFFA000);
  static const Color background = Color(0xFFF1F8E9);
  static const Color textMain = Color(0xFF1B5E20);
  static const Color textSub = Color(0xFF616161);
}

class PropertyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  bool _isLoadingReviews = true;
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoadingReviews = true);
    try {
      final (ok, data) =
          await ApiService.getReviewsByProperty(widget.property['_id']);
      if (mounted)
        setState(() {
          if (ok) _reviews = data as List<dynamic>;
          _isLoadingReviews = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _handleAction() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('token') == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please Login First"), backgroundColor: Colors.red));
      Navigator.pushNamed(context, '/login');
      return;
    }
    // Action logic
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Request sent to Owner!"),
        backgroundColor: AppTheme.primary));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final currency = NumberFormat.simpleCurrency(decimalDigits: 0);
    final img =
        (p['images'] != null && p['images'].isNotEmpty) ? p['images'][0] : '';
    // Determine Button Text
    final actionText = p['operation'] == 'rent' ? "Rent Now" : "Buy Now";

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomScrollView(
            slivers: [
              // 1. Image Header
              SliverAppBar(
                expandedHeight: 350,
                backgroundColor: AppTheme.primary,
                pinned: true,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: AppTheme.primary),
                      onPressed: () => Navigator.pop(context)),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(img,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) =>
                              Container(color: Colors.grey)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black12,
                                AppTheme.primaryDark.withOpacity(0.6)
                              ]),
                        ),
                      ),
                      Positioned(
                        bottom: 30,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text("${currency.format(p['price'])}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              // 2. Content
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.background,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  transform: Matrix4.translationValues(0, -20, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Chip(
                              label: Text(p['type'] ?? 'Property',
                                  style: const TextStyle(color: Colors.white)),
                              backgroundColor: AppTheme.primary),
                          Row(children: [
                            const Icon(Icons.star, color: AppTheme.accent),
                            Text(" 4.8 (${_reviews.length})",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))
                          ]),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(p['title'] ?? 'No Title',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain)),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.location_on,
                            size: 16, color: AppTheme.textSub),
                        Text("${p['city']}, ${p['address']}",
                            style: const TextStyle(color: AppTheme.textSub))
                      ]),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _FeatureBadge(Icons.bed, "${p['bedrooms']} Beds"),
                          _FeatureBadge(
                              Icons.bathtub, "${p['bathrooms']} Baths"),
                          _FeatureBadge(Icons.square_foot, "${p['area']} m²"),
                        ],
                      ),
                      const SizedBox(height: 25),
                      const Text("Description",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain)),
                      const SizedBox(height: 10),
                      Text(p['description'] ?? "No description.",
                          style: const TextStyle(
                              color: AppTheme.textSub, height: 1.5)),
                      const SizedBox(height: 25),
                      const Text("Amenities",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain)),
                      Wrap(
                        spacing: 8,
                        children: (p['amenities'] as List? ?? [])
                            .map((e) => Chip(
                                label: Text(e.toString()),
                                backgroundColor: Colors.white))
                            .toList(),
                      ),
                      const SizedBox(height: 25),
                      const Text("Reviews",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain)),
                      _buildReviewsList(),
                      const SizedBox(height: 20),
                      _AddReviewWidget(
                          propertyId: p['_id'], onSubmitted: _fetchReviews),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Price", style: TextStyle(color: Colors.grey)),
                    Text(currency.format(p['price']),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary)),
                  ],
                ),
                ElevatedButton(
                  onPressed: _handleAction,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15)),
                  child: Text(actionText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_isLoadingReviews)
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    if (_reviews.isEmpty) return const Text("No reviews yet.");
    return Column(
        children: _reviews
            .take(3)
            .map((r) => ListTile(
                title: Text(
                    r['reviewerId'] is Map ? r['reviewerId']['name'] : 'User'),
                subtitle: Text(r['comment'] ?? ""),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star, size: 14, color: AppTheme.accent),
                  Text(" ${r['rating']}")
                ])))
            .toList());
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureBadge(this.icon, this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(children: [
        Icon(icon, color: AppTheme.primary),
        const SizedBox(height: 5),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold))
      ]),
    );
  }
}

class _AddReviewWidget extends StatefulWidget {
  final String propertyId;
  final VoidCallback onSubmitted;
  const _AddReviewWidget({required this.propertyId, required this.onSubmitted});
  @override
  State<_AddReviewWidget> createState() => _AddReviewWidgetState();
}

class _AddReviewWidgetState extends State<_AddReviewWidget> {
  final _ctrl = TextEditingController();
  int _rating = 0;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        children: [
          const Text("Rate this property"),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (i) => IconButton(
                      icon: Icon(i < _rating ? Icons.star : Icons.star_border,
                          color: AppTheme.accent),
                      onPressed: () => setState(() => _rating = i + 1)))),
          TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                  hintText: "Comment", border: OutlineInputBorder())),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: () async {
                if (_rating > 0) {
                  await ApiService.addReview(
                      propertyId: widget.propertyId,
                      rating: _rating,
                      comment: _ctrl.text);
                  widget.onSubmitted();
                  setState(() {
                    _rating = 0;
                    _ctrl.clear();
                  });
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child:
                  const Text("Submit", style: TextStyle(color: Colors.white)))
        ],
      ),
    );
  }
}
