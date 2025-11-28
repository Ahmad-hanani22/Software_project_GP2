// lib/screens/admin_notifications_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

// --- Color Palette ---
const Color _primaryGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFF5F5F5);
const Color _textPrimary = Color(0xFF424242);
const Color _textSecondary = Color(0xFF757575);

class AdminNotificationsManagementScreen extends StatefulWidget {
  const AdminNotificationsManagementScreen({super.key});

  @override
  State<AdminNotificationsManagementScreen> createState() =>
      _AdminNotificationsManagementScreenState();
}

class _AdminNotificationsManagementScreenState
    extends State<AdminNotificationsManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllNotifications();
    if (mounted) {
      setState(() {
        if (ok) {
          _notifications = data as List<dynamic>;
        } else {
          _errorMessage = data.toString();
        }
        _isLoading = false;
      });
    }
  }

  void _showCreateNotificationDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String recipientGroup = 'all'; // Default value

    showDialog(
      context: context,
      builder: (ctx) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send New Notification'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: recipientGroup,
                      decoration: const InputDecoration(labelText: 'Send to'),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All Users')),
                        DropdownMenuItem(
                            value: 'tenants', child: Text('Tenants Only')),
                        DropdownMenuItem(
                            value: 'landlords', child: Text('Landlords Only')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => recipientGroup = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'Title (Optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(labelText: 'Message *'),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16),
                  label: Text(isSending ? 'Sending...' : 'Send'),
                  onPressed: isSending
                      ? null
                      : () async {
                          if (messageController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Message cannot be empty.'),
                                    backgroundColor: Colors.red));
                            return;
                          }

                          setDialogState(() => isSending = true);

                          final (ok, message) =
                              await ApiService.createNotification(
                            recipients: recipientGroup,
                            title: titleController.text,
                            message: messageController.text,
                          );

                          if (mounted) {
                            setDialogState(() => isSending = false);
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(message),
                              backgroundColor: ok ? _primaryGreen : Colors.red,
                            ));
                            if (ok) _fetchNotifications();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: const Text('Notifications Management'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
            tooltip: 'Refresh Log',
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateNotificationDialog,
        label: const Text('New Notification'),
        icon: const Icon(Icons.add_comment_outlined),
        backgroundColor: _primaryGreen,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading)
      return const Center(
          child: CircularProgressIndicator(color: _primaryGreen));
    if (_errorMessage != null)
      return Center(
          child:
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    if (_notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('No Notifications Sent',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary)),
            Text('The notification log is empty.',
                style: TextStyle(color: _textSecondary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Sent Notifications Log",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              return _NotificationCard(
                notification: _notifications[index],
                onRefresh: _fetchNotifications, // ✅ تم تمرير دالة التحديث
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback? onRefresh;

  const _NotificationCard({required this.notification, this.onRefresh});

  // ✅ دالة الموافقة على العقد (مدمجة هنا)
  Future<void> _approveContract(BuildContext context, String contractId) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Approving contract..."),
        duration: Duration(seconds: 1)));

    final (ok, msg) =
        await ApiService.updateContract(contractId, {'status': 'active'});

    if (context.mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Contract Approved & Activated!"),
            backgroundColor: _primaryGreen));

        if (onRefresh != null) onRefresh!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("❌ Error: $msg"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = notification['userId'] ?? {};
    final actor = notification['actorId'];
    final date = DateTime.parse(notification['createdAt']);
    final bool isRead = notification['isRead'] ?? false;
    final String type = notification['type'] ?? 'system';
    final String? entityId = notification['entityId']; // معرف العقد

    // ⚡ التحقق: هل هذا طلب عقد وهل يوجد معرف للعقد؟
    final bool isContractRequest =
        (type == 'contract_request' && entityId != null);

    IconData iconData = Icons.notifications;
    Color iconColor = _primaryGreen;

    if (isContractRequest) {
      iconData = Icons.description; // أيقونة مميزة للعقد
      iconColor = Colors.orange; // لون مميز للطلب
    } else if (type == 'payment') {
      iconData = Icons.payment;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isRead ? Colors.white : const Color(0xFFF1F8E9),
      elevation: isRead ? 2 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRead
            ? BorderSide(color: Colors.grey.shade200)
            : const BorderSide(color: _primaryGreen, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: iconColor.withOpacity(0.1),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              title: Text(notification['title'] ?? 'Notification',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(notification['message'] ?? 'No message',
                      style: TextStyle(color: _textPrimary, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(DateFormat('d MMM, h:mm a').format(date),
                      style: TextStyle(fontSize: 11, color: _textSecondary)),
                ],
              ),
            ),

            // ⚡ الزر السحري للموافقة (يظهر فقط لطلبات العقود)
            if (isContractRequest)
              Container(
                margin: const EdgeInsets.only(top: 8, left: 56),
                child: ElevatedButton.icon(
                  onPressed: () => _approveContract(context, entityId!),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text("Approve & Create Contract"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
