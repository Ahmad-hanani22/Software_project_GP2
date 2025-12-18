import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

class PropertyHistoryScreen extends StatefulWidget {
  final String propertyId;
  final String propertyTitle;

  const PropertyHistoryScreen({
    super.key,
    required this.propertyId,
    required this.propertyTitle,
  });

  @override
  State<PropertyHistoryScreen> createState() => _PropertyHistoryScreenState();
}

class _PropertyHistoryScreenState extends State<PropertyHistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _histories = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getPropertyHistory(widget.propertyId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _histories = data as List<dynamic>;
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  String _getActionText(String action) {
    switch (action) {
      case 'created':
        return 'تم الإنشاء';
      case 'updated':
        return 'تم التحديث';
      case 'deleted':
        return 'تم الحذف';
      case 'status_changed':
        return 'تغيير الحالة';
      case 'price_changed':
        return 'تغيير السعر';
      case 'verified':
        return 'تم التحقق';
      case 'unit_added':
        return 'إضافة وحدة';
      case 'unit_removed':
        return 'حذف وحدة';
      case 'contract_added':
        return 'إضافة عقد';
      case 'contract_removed':
        return 'حذف عقد';
      default:
        return action;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle;
      case 'updated':
        return Icons.edit;
      case 'deleted':
        return Icons.delete;
      case 'status_changed':
        return Icons.swap_horiz;
      case 'price_changed':
        return Icons.attach_money;
      case 'verified':
        return Icons.verified;
      default:
        return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تاريخ العقار - ${widget.propertyTitle}'),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
      ),
      backgroundColor: _scaffoldBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _histories.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا يوجد تاريخ',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _histories.length,
                        itemBuilder: (ctx, idx) {
                          final history = _histories[idx];
                          final action = history['action'] ?? '';
                          final performedBy = history['performedBy'] is Map
                              ? history['performedBy']['name'] ?? 'Unknown'
                              : 'Unknown';
                          final createdAt = history['createdAt'] != null
                              ? DateTime.parse(history['createdAt'])
                              : null;
                          final description = history['description'] ?? '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _primaryBeige,
                                child: Icon(
                                  _getActionIcon(action),
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                _getActionText(action),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('بواسطة: $performedBy'),
                                  if (description.isNotEmpty) Text(description),
                                  if (createdAt != null)
                                    Text(
                                      DateFormat('yyyy-MM-dd HH:mm').format(createdAt),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

