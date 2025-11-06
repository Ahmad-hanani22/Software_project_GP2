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
              return _NotificationCard(notification: _notifications[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final user = notification['userId'] ?? {};
    final actor = notification['actorId']; // Could be an admin
    final date = DateTime.parse(notification['createdAt']);
    final bool isRead = notification['isRead'] ?? false;

    IconData iconData;
    switch (notification['type']) {
      case 'payment':
        iconData = Icons.payment;
        break;
      case 'contract':
        iconData = Icons.description;
        break;
      case 'maintenance':
        iconData = Icons.build;
        break;
      default:
        iconData = Icons.system_update;
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isRead ? Colors.grey.shade200 : _primaryGreen.withOpacity(0.2),
          child: Icon(iconData,
              color: isRead ? _textSecondary : _primaryGreen, size: 20),
        ),
        title: Text(notification['message'] ?? 'No message',
            style: TextStyle(
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                color: _textPrimary)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To: ${user['name'] ?? 'N/A'}'),
            if (actor != null) Text('By: ${actor['name'] ?? 'System'}'),
            Text(DateFormat('d MMM, yyyy  h:mm a').format(date),
                style: const TextStyle(fontSize: 12, color: _textSecondary)),
          ],
        ),
        trailing: isRead
            ? null
            : const Icon(Icons.circle, color: Colors.blueAccent, size: 10),
      ),
    );
  }
}
