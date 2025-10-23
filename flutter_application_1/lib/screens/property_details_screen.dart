// lib/screens/property_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
// ✅ FIX: Corrected the import path from '.' to ':'
import 'package:intl/intl.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> property;

  const PropertyDetailsScreen({super.key, required this.property});

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  // State for reviews section
  bool _isLoadingReviews = true;
  List<dynamic> _reviews = [];
  String? _reviewsError;

  @override
  void initState() {
    super.initState();
    _fetchReviewsForProperty();
  }

  Future<void> _fetchReviewsForProperty() async {
    setState(() {
      _isLoadingReviews = true;
      _reviewsError = null;
    });

    try {
      final (ok, data) =
          await ApiService.getReviewsByProperty(widget.property['_id']);
      if (mounted) {
        setState(() {
          if (ok) {
            _reviews = data as List<dynamic>;
          } else {
            _reviewsError = data.toString();
          }
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reviewsError = 'Failed to load reviews.';
          _isLoadingReviews = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency(
        name: widget.property['currency'] ?? 'USD', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.property['title'] ?? 'Property Details'),
          backgroundColor: const Color(0xFF2E7D32)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImageGallery(images: widget.property['images'] as List? ?? []),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.property['title'] ?? 'Untitled Property',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      '${widget.property['city'] ?? ''}, ${widget.property['country'] ?? ''}',
                      style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Text(
                    '${currencyFormat.format(widget.property['price'] ?? 0)} ${widget.property['operation'] == 'rent' ? '/ month' : ''}',
                    style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w900,
                        fontSize: 24),
                  ),
                  const Divider(height: 32),
                  _buildStatsRow(widget.property),
                  const Divider(height: 32),
                  const Text('Description',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      widget.property['description']?.toString() ??
                          'No description available.',
                      style: const TextStyle(fontSize: 16, height: 1.5)),
                  const Divider(height: 32),
                  const Text('Amenities',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildAmenities(widget.property['amenities'] as List? ?? []),
                ],
              ),
            ),
            _buildReviewsSection(),
            _AddReviewSection(
              propertyId: widget.property['_id'],
              onReviewSubmitted: _fetchReviewsForProperty,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionButtons(context, widget.property),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reviews',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_isLoadingReviews)
            const Center(child: CircularProgressIndicator()),
          if (_reviewsError != null)
            Center(
                child: Text(_reviewsError!,
                    style: const TextStyle(color: Colors.red))),
          if (!_isLoadingReviews && _reviewsError == null && _reviews.isEmpty)
            const Center(
                child: Text('No reviews yet. Be the first to review!')),
          if (!_isLoadingReviews &&
              _reviewsError == null &&
              _reviews.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                return _ReviewCard(review: _reviews[index]);
              },
            ),
        ],
      ),
    );
  }

  // ✅ FIX: Added the implementation for the missing methods.
  Widget _buildStatsRow(Map<String, dynamic> p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _InfoBadge(
            icon: Icons.bed_outlined,
            label: 'Beds',
            value: p['bedrooms']?.toString() ?? 'N/A'),
        _InfoBadge(
            icon: Icons.bathtub_outlined,
            label: 'Baths',
            value: p['bathrooms']?.toString() ?? 'N/A'),
        _InfoBadge(
            icon: Icons.square_foot_outlined,
            label: 'Area (m²)',
            value: (p['area'] as num? ?? 0).toInt().toString()),
      ],
    );
  }

  Widget _buildAmenities(List<dynamic> amenities) {
    if (amenities.isEmpty) {
      return const Text('No amenities listed.');
    }
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: amenities
          .map((amenity) => Chip(label: Text(amenity.toString())))
          .toList(),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, Map<String, dynamic> property) {
    final isRent = property['operation'] == 'rent';
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Starting the ${isRent ? "rental" : "purchase"} process...')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: Text(isRent ? 'Rent Now' : 'Buy Now'),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening negotiation chat...')));
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 28),
            tooltip: 'Negotiate via Chat',
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              side: BorderSide(color: Colors.grey.shade300, width: 2),
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ FIX: Added the implementation for the build method.
class _ImageGallery extends StatelessWidget {
  final List<dynamic> images;
  const _ImageGallery({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey.shade300,
        child: const Center(
            child: Icon(Icons.house_outlined, size: 60, color: Colors.grey)),
      );
    }
    return SizedBox(
      height: 250,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          final imageUrl = images[index].toString();
          return Image.network(imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const Center(
                  child:
                      Icon(Icons.broken_image, size: 60, color: Colors.grey)));
        },
      ),
    );
  }
}

// ✅ FIX: Added the implementation for the build method.
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoBadge(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade700, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final user = review['userId'] as Map<String, dynamic>? ?? {};
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                    child: Text(
                        user['name']?.substring(0, 1).toUpperCase() ?? 'U')),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(user['name'] ?? 'Anonymous',
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                Row(
                  children: List.generate(
                      5,
                      (i) => Icon(
                          i < (review['rating'] ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 16)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(review['comment'] ?? ''),
          ],
        ),
      ),
    );
  }
}

class _AddReviewSection extends StatefulWidget {
  final String propertyId;
  final VoidCallback onReviewSubmitted;
  const _AddReviewSection(
      {required this.propertyId, required this.onReviewSubmitted});

  @override
  State<_AddReviewSection> createState() => _AddReviewSectionState();
}

class _AddReviewSectionState extends State<_AddReviewSection> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _token;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    _token = await ApiService.getToken();
    if (mounted) setState(() {});
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a rating.')));
      return;
    }
    setState(() => _isSubmitting = true);

    final (ok, message) = await ApiService.addReview(
      propertyId: widget.propertyId,
      rating: _rating,
      comment: _commentController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: ok ? Colors.green : Colors.red));
      setState(() {
        _isSubmitting = false;
        if (ok) {
          _rating = 0;
          _commentController.clear();
          widget.onReviewSubmitted();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Write a Review',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                  5,
                  (index) => IconButton(
                        icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 30),
                        onPressed: () => setState(() => _rating = index + 1),
                      )),
            ),
            const SizedBox(height: 10),
            TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Your comment (optional)'),
                maxLines: 3),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_isSubmitting ? 'Submitting...' : 'Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
