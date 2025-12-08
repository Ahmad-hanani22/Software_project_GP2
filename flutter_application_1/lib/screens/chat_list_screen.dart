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
  // لتخزين عدد الرسائل غير المقروءة لكل مستخدم (محاكاة)
  Map<String, bool> _hasUnreadMessages = {}; 
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    // تحديث القائمة كل 5 ثواني لجلب أي مستخدمين جدد أو تنبيهات (حل مؤقت بدون Socket Client)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchUsers(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsers({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    // ✅ استخدام الدالة الجديدة المسموحة للجميع
    final (ok, data) = await ApiService.getChatUsers();
    
    if (mounted) {
      setState(() {
        if (ok) {
          _allUsers = data as List<dynamic>;
          // هنا يمكنك إضافة منطق لجلب الرسائل غير المقروءة من API وتحديث _hasUnreadMessages
        } else if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $data")));
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _allUsers.isEmpty
              ? const Center(child: Text("No users found to chat with."))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: _allUsers.length,
                  itemBuilder: (context, index) {
                    final user = _allUsers[index];
                    final userId = user['_id'];
                    // محاكاة: إظهار نقطة حمراء لبعض المستخدمين عشوائياً أو بناء على منطق
                    bool hasNewMessage = _hasUnreadMessages[userId] ?? false;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: (user['profilePicture'] != null && user['profilePicture'] != "")
                                  ? NetworkImage(user['profilePicture'])
                                  : null,
                              child: (user['profilePicture'] == null || user['profilePicture'] == "")
                                  ? Text((user['name']?[0] ?? 'U').toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))
                                  : null,
                            ),
                            // 🔴 العلامة الحمراء (Red Badge)
                            if (hasNewMessage)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(user['name'] ?? 'Unknown',
                            style: TextStyle(fontWeight: hasNewMessage ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(user['role'] ?? 'User', style: const TextStyle(color: Colors.grey)),
                        trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2E7D32)),
                        onTap: () {
                          // عند الدخول، نخفي العلامة الحمراء
                          setState(() {
                            _hasUnreadMessages[userId] = false;
                          });
                          
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                receiverId: user['_id'],
                                receiverName: user['name'] ?? 'Chat',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}