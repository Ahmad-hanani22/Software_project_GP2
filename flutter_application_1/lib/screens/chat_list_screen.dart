import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<dynamic> _allUsers = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    // تحديث هادئ كل 5 ثواني لجلب الرسائل الجديدة وتحديث العدادات
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchUsers(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      // الدالة في ApiService الآن تجلب users مع unreadCount
      final (ok, data) = await ApiService.getChatUsers();

      if (!mounted) return;

      setState(() {
        if (ok) {
          _allUsers = data;
        } else if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load users")),
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      print("Error in ChatListScreen: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _allUsers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 60, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("No users found to chat with."),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _allUsers.length,
                  itemBuilder: (context, index) {
                    final user = _allUsers[index];
                    final String userId = user['_id'];
                    final String name = user['name'] ?? 'Unknown';
                    final String role = user['role'] ?? 'User';
                    final String? pic = user['profilePicture'];

                    // ✅ جلب عدد الرسائل غير المقروءة (إن وجد)
                    final int unreadCount = user['unreadCount'] ?? 0;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: (pic != null && pic.isNotEmpty)
                                  ? NetworkImage(pic)
                                  : null,
                              child: (pic == null || pic.isEmpty)
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                          fontSize: 20))
                                  : null,
                            ),
                            // 🔴🔴 العداد الأحمر (يظهر فقط إذا كان أكبر من 0)
                            if (unreadCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                  child: Text(
                                    unreadCount > 9
                                        ? '+9'
                                        : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(name,
                            style: TextStyle(
                                // جعل الخط غامقاً إذا كانت هناك رسائل جديدة
                                fontWeight: unreadCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.w600)),
                        subtitle: Text(role,
                            style: const TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey),
                        onTap: () async {
                          // الانتقال للمحادثة وانتظار العودة
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                receiverId: userId,
                                receiverName: name,
                              ),
                            ),
                          );

                          // ✅ عند العودة، نقوم بتحديث القائمة فوراً لتختفي العلامة الحمراء
                          _fetchUsers(silent: true);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
