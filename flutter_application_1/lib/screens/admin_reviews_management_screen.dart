// lib/screens/admin_reviews_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

enum SortOption { newest, oldest, highestRating, lowestRating }

class AdminReviewsManagementScreen extends StatefulWidget {
  const AdminReviewsManagementScreen({super.key});

  @override
  State<AdminReviewsManagementScreen> createState() =>
      _AdminReviewsManagementScreenState();
}

class _AdminReviewsManagementScreenState
    extends State<AdminReviewsManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _allReviews = [];
  List<dynamic> _filteredReviews = [];
  final TextEditingController _searchController = TextEditingController();
  int? _selectedRatingFilter;
  SortOption _sortOption = SortOption.newest;

  // ألوان ثابتة للشاشة
  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _lightGreenAccent = Color(0xFFE8F5E9);
  static const Color _scaffoldBackground = Color(0xFFF5F5F5);
  static const Color _textPrimary = Color(0xFF424242);
  static const Color _textSecondary = Color(0xFF757575);

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

  // ======================= API & Logic =======================

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
        _applyFiltersAndSort();
      } else {
        _errorMessage = data.toString();
      }
      _isLoading = false;
    });
  }

  void _applyFiltersAndSort() {
    List<dynamic> tempReviews = List.from(_allReviews);

    // 🔎 فلترة حسب البحث
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      tempReviews = tempReviews.where((review) {
        final userName =
            review['reviewerId']?['name']?.toString().toLowerCase() ?? '';
        final propertyTitle =
            review['propertyId']?['title']?.toString().toLowerCase() ?? '';
        final comment = review['comment']?.toString().toLowerCase() ?? '';
        return userName.contains(query) ||
            propertyTitle.contains(query) ||
            comment.contains(query);
      }).toList();
    }

    // ⭐ فلترة حسب الرتينغ
    if (_selectedRatingFilter != null) {
      tempReviews = tempReviews.where((review) {
        return (review['rating'] as num? ?? 0) == _selectedRatingFilter;
      }).toList();
    }

    // 🔁 ترتيب
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
    final confirm = await _showConfirmationDialog(
      context,
      title: 'Delete Review',
      content: 'Are you sure you want to permanently delete this review?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (confirm != true) return;

    final (ok, message) = await ApiService.deleteReview(reviewId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? _primaryGreen : Colors.red,
      ),
    );
    if (ok) _fetchReviews();
  }

  Future<void> _toggleReviewVisibility(
      String reviewId, bool currentVisibility) async {
    final (ok, message) =
        await ApiService.updateReview(reviewId, {'isVisible': !currentVisibility});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ok ? _primaryGreen : Colors.red,
      ),
    );
    if (ok) _fetchReviews();
  }

  Future<void> _showReplyDialog(String reviewId, String currentReply) async {
    final replyController = TextEditingController(text: currentReply);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply to Review'),
        content: TextField(
          controller: replyController,
          decoration:
              const InputDecoration(hintText: 'Write your reply here...'),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(replyController.text),
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );

    if (result != null) {
      final (ok, message) =
          await ApiService.updateReview(reviewId, {'adminReply': result});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: ok ? _primaryGreen : Colors.red,
        ),
      );
      if (ok) _fetchReviews();
    }
  }

  // ======================= AppBar Actions =======================

  // BottomSheet لاختيار ترتيب الريفيوهات
  void _openSortSheet() {
    SortOption tempSort = _sortOption;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Widget buildRadioTile(String title, SortOption value) {
              return RadioListTile<SortOption>(
                title: Text(title),
                value: value,
                groupValue: tempSort,
                onChanged: (val) {
                  if (val == null) return;
                  setModalState(() => tempSort = val);
                },
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Sort Reviews',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  buildRadioTile('Newest First', SortOption.newest),
                  buildRadioTile('Oldest First', SortOption.oldest),
                  buildRadioTile('Highest Rating', SortOption.highestRating),
                  buildRadioTile('Lowest Rating', SortOption.lowestRating),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() => _sortOption = tempSort);
                        _applyFiltersAndSort();
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // BottomSheet لاختيار فلتر الرتينغ
  void _openRatingFilterSheet() {
    int? tempRating = _selectedRatingFilter;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Rating',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: tempRating == null,
                    onSelected: (_) {
                      setState(() {
                        tempRating = null;
                      });
                    },
                  ),
                  ...List.generate(
                    5,
                    (i) => ChoiceChip(
                      label: Text('${i + 1} ★'),
                      selected: tempRating == i + 1,
                      onSelected: (_) {
                        setState(() {
                          tempRating = i + 1;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() => _selectedRatingFilter = tempRating);
                    _applyFiltersAndSort();
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dialog إحصائيات سريعة عن الريفيوهات
  void _showQuickStats() {
    final total = _allReviews.length;
    final visibleCount =
        _allReviews.where((r) => r['isVisible'] ?? true).length;
    final hiddenCount = total - visibleCount;
    double averageRating = 0;
    if (total > 0) {
      final sum = _allReviews
          .map((r) => (r['rating'] as num? ?? 0).toDouble())
          .fold<double>(0, (p, c) => p + c);
      averageRating = sum / total;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reviews Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.rate_review, color: _primaryGreen),
              title: Text('Total Reviews: $total'),
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text('Average Rating: ${averageRating.toStringAsFixed(1)}'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.visibility, color: Colors.lightGreen),
              title: Text('Visible: $visibleCount'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.orange),
              title: Text('Hidden: $hiddenCount'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // إشعارات بسيطة (مثلاً عدد الريفيوهات المخفية)
  void _showNotifications() {
    final hiddenCount =
        _allReviews.where((r) => !(r['isVisible'] ?? true)).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reviews Alerts'),
        content: Text(
          hiddenCount == 0
              ? 'No hidden reviews. You are all caught up! 🎉'
              : 'You currently have $hiddenCount hidden review(s). You can unhide them if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ======================= UI =======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        elevation: 2,
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Reviews Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Change Sorting',
            onPressed: _openSortSheet,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Filter by Rating',
            onPressed: _openRatingFilterSheet,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Quick Statistics',
            onPressed: _showQuickStats,
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Review Alerts',
            onPressed: _showNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications),
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Reviews',
            onPressed: _fetchReviews,
          ),
          const SizedBox(width: 8),
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
      return const Center(
        child: CircularProgressIndicator(color: _primaryGreen),
      );
    }
    if (_errorMessage != null) {
      return _buildErrorWidget('Error: $_errorMessage');
    }
    if (_allReviews.isEmpty) {
      return _buildEmptyState('No reviews have been submitted yet.');
    }
    if (_filteredReviews.isEmpty) {
      return _buildEmptyState('No reviews match your current filters.');
    }
    return RefreshIndicator(
      onRefresh: _fetchReviews,
      color: _primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _filteredReviews.length,
        itemBuilder: (context, index) {
          final review = _filteredReviews[index];
          return _ReviewCard(
            review: review,
            onDelete: () => _deleteReview(review['_id']),
            onReply: () =>
                _showReplyDialog(review['_id'], review['adminReply'] ?? ''),
            onToggleVisibility: () => _toggleReviewVisibility(
              review['_id'],
              review['isVisible'] ?? true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.rate_review, size: 80, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'No Reviews',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(color: _textSecondary),
          ),
        ],
      ),
    );
  }
}

// ======================= Filter Bar =======================

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final int? ratingFilter;
  final SortOption sortOption;
  final ValueChanged<int?> onRatingChanged;
  final ValueChanged<SortOption?> onSortChanged;

  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _lightGreenAccent = Color(0xFFE8F5E9);

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
      decoration: BoxDecoration(
        color: _lightGreenAccent,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search by user, property, or comment...',
              prefixIcon: const Icon(Icons.search, color: _primaryGreen),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: ratingFilter,
                  decoration: InputDecoration(
                    labelText: 'Filter by Rating',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Ratings'),
                    ),
                    ...List.generate(
                      5,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1} Star${i > 0 ? 's' : ''}'),
                      ),
                    ),
                  ],
                  onChanged: onRatingChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<SortOption>(
                  value: sortOption,
                  decoration: InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: SortOption.newest,
                      child: Text('Newest First'),
                    ),
                    DropdownMenuItem(
                      value: SortOption.oldest,
                      child: Text('Oldest First'),
                    ),
                    DropdownMenuItem(
                      value: SortOption.highestRating,
                      child: Text('Highest Rating'),
                    ),
                    DropdownMenuItem(
                      value: SortOption.lowestRating,
                      child: Text('Lowest Rating'),
                    ),
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

// ======================= Review Card =======================

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onDelete;
  final VoidCallback onReply;
  final VoidCallback onToggleVisibility;

  const _ReviewCard({
    required this.review,
    required this.onDelete,
    required this.onReply,
    required this.onToggleVisibility,
  });

  static const Color _primaryGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final user = review['reviewerId'] as Map<String, dynamic>? ?? {};
    final property = review['propertyId'] as Map<String, dynamic>? ?? {};
    final rating = review['rating'] as num? ?? 0;
    final bool isVisible = review['isVisible'] ?? true;
    final String adminReply = review['adminReply'] ?? '';

    return Opacity(
      opacity: isVisible ? 1.0 : 0.6,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12.0),
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: _primaryGreen.withOpacity(0.1),
                        child: Text(
                          user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            color: _primaryGreen,
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
                              user['name'] ?? 'Anonymous User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              user['email'] ?? 'No email',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildRatingStars(rating),
                          ],
                        ),
                      ),
                      if (!isVisible)
                        Chip(
                          label: const Text('HIDDEN'),
                          backgroundColor: Colors.orange.shade100,
                          labelStyle: TextStyle(
                            color: Colors.orange.shade800,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    review['comment'] ?? 'No comment provided.',
                    style: const TextStyle(
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                  if (adminReply.isNotEmpty) _buildAdminReply(adminReply),
                  const SizedBox(height: 12),
                  _buildFooterInfo(property, review['createdAt']),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.reply, size: 18),
                    label: Text(adminReply.isEmpty ? 'Reply' : 'Edit Reply'),
                    onPressed: onReply,
                  ),
                  TextButton.icon(
                    icon: Icon(
                      isVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    label: Text(isVisible ? 'Hide' : 'Show'),
                    onPressed: onToggleVisibility,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Delete Review',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminReply(String reply) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: _primaryGreen, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Reply:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(reply),
        ],
      ),
    );
  }

  Widget _buildFooterInfo(Map<String, dynamic> property, String createdAt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.house_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    property['title'] ?? 'N/A',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat.yMMMd().add_jm().format(DateTime.parse(createdAt)),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
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
          size: 20,
        ),
      ),
    );
  }
}

// ======================= Confirmation Dialog =======================

Future<bool?> _showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = 'Confirm',
  Color confirmColor = const Color(0xFF2E7D32),
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: confirmColor,
        ),
      ),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}
