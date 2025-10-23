// lib/screens/admin_reviews_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

// Enum for sorting options to make the code cleaner
enum SortOption { newest, oldest, highestRating, lowestRating }

class AdminReviewsManagementScreen extends StatefulWidget {
  const AdminReviewsManagementScreen({super.key});

  @override
  State<AdminReviewsManagementScreen> createState() =>
      _AdminReviewsManagementScreenState();
}

class _AdminReviewsManagementScreenState
    extends State<AdminReviewsManagementScreen> {
  // State variables
  bool _isLoading = true;
  String? _errorMessage;

  // Data lists
  List<dynamic> _allReviews = []; // Master list from API
  List<dynamic> _filteredReviews = []; // List displayed to the user

  // Controllers and filters
  final TextEditingController _searchController = TextEditingController();
  int? _selectedRatingFilter; // null means "All Ratings"
  SortOption _sortOption = SortOption.newest;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
    _searchController.addListener(_applyFiltersAndSort);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReviews() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final (ok, data) = await ApiService.getAllReviews();

    if (!mounted) return;
    setState(() {
      if (ok) {
        _allReviews = data as List<dynamic>;
        _applyFiltersAndSort(); // Apply default filters/sort on fresh data
      } else {
        _errorMessage = data.toString();
      }
      _isLoading = false;
    });
  }

  void _applyFiltersAndSort() {
    List<dynamic> tempReviews = List.from(_allReviews);

    // 1. Apply Search Filter
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempReviews = tempReviews.where((review) {
        final userName =
            review['userId']?['name']?.toString().toLowerCase() ?? '';
        final propertyTitle =
            review['propertyId']?['title']?.toString().toLowerCase() ?? '';
        final comment = review['comment']?.toString().toLowerCase() ?? '';
        return userName.contains(query) ||
            propertyTitle.contains(query) ||
            comment.contains(query);
      }).toList();
    }

    // 2. Apply Rating Filter
    if (_selectedRatingFilter != null) {
      tempReviews = tempReviews.where((review) {
        return (review['rating'] as num? ?? 0) == _selectedRatingFilter;
      }).toList();
    }

    // 3. Apply Sorting
    tempReviews.sort((a, b) {
      switch (_sortOption) {
        case SortOption.oldest:
          return DateTime.parse(a['createdAt'])
              .compareTo(DateTime.parse(b['createdAt']));
        case SortOption.highestRating:
          return (b['rating'] as num).compareTo(a['rating'] as num);
        case SortOption.lowestRating:
          return (a['rating'] as num).compareTo(b['rating'] as num);
        case SortOption.newest:
        default:
          return DateTime.parse(b['createdAt'])
              .compareTo(DateTime.parse(a['createdAt']));
      }
    });

    setState(() {
      _filteredReviews = tempReviews;
    });
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
            'Are you sure you want to permanently delete this review?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final (ok, message) = await ApiService.deleteReview(reviewId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));

    if (ok) _fetchReviews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Reviews Management'),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReviews,
            tooltip: 'Refresh Reviews',
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            searchController: _searchController,
            ratingFilter: _selectedRatingFilter,
            sortOption: _sortOption,
            onRatingChanged: (rating) {
              setState(() => _selectedRatingFilter = rating);
              _applyFiltersAndSort();
            },
            onSortChanged: (option) {
              if (option == null) return;
              setState(() => _sortOption = option);
              _applyFiltersAndSort();
            },
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
          child: Text('Error: $_errorMessage',
              style: const TextStyle(color: Colors.red)));
    }
    if (_allReviews.isEmpty) {
      return const Center(child: Text('No reviews have been submitted yet.'));
    }
    if (_filteredReviews.isEmpty) {
      return const Center(
          child: Text('No reviews match your current filters.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _filteredReviews.length,
      itemBuilder: (context, index) {
        return _ReviewCard(
          review: _filteredReviews[index],
          onDelete: () => _deleteReview(_filteredReviews[index]['_id']),
        );
      },
    );
  }
}

// Professional Filter Bar Widget
class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final int? ratingFilter;
  final SortOption sortOption;
  final ValueChanged<int?> onRatingChanged;
  final ValueChanged<SortOption?> onSortChanged;

  const _FilterBar({
    required this.searchController,
    required this.ratingFilter,
    required this.sortOption,
    required this.onRatingChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search by user, property, or comment...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: ratingFilter,
                  decoration: const InputDecoration(
                      labelText: 'Rating',
                      border: OutlineInputBorder(),
                      isDense: true),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Ratings')),
                    ...List.generate(
                        5,
                        (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1} Star${i > 0 ? 's' : ''}'))),
                  ],
                  onChanged: onRatingChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<SortOption>(
                  value: sortOption,
                  decoration: const InputDecoration(
                      labelText: 'Sort by',
                      border: OutlineInputBorder(),
                      isDense: true),
                  items: const [
                    DropdownMenuItem(
                        value: SortOption.newest, child: Text('Newest First')),
                    DropdownMenuItem(
                        value: SortOption.oldest, child: Text('Oldest First')),
                    DropdownMenuItem(
                        value: SortOption.highestRating,
                        child: Text('Highest Rating')),
                    DropdownMenuItem(
                        value: SortOption.lowestRating,
                        child: Text('Lowest Rating')),
                  ],
                  onChanged: onSortChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Professional Review Card Widget
class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onDelete;

  const _ReviewCard({required this.review, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final user = review['userId'] as Map<String, dynamic>? ?? {};
    final property = review['propertyId'] as Map<String, dynamic>? ?? {};
    final rating = review['rating'] as num? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['name'] ?? 'Anonymous User',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      _buildRatingStars(rating),
                    ],
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  onPressed: onDelete,
                  tooltip: 'Delete Review',
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              review['comment'] ?? 'No comment provided.',
              style: const TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.house_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'Property: ${property['title'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )),
                  Text(
                    DateFormat.yMMMd()
                        .format(DateTime.parse(review['createdAt'])),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingStars(num rating) {
    return Row(
      children: List.generate(
          5,
          (index) => Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 18,
              )),
    );
  }
}
