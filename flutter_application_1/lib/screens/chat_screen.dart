import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// تأكد من استيراد مكتبة http إذا كنت ستستخدم دالة markAsRead المخصصة،
// أو تأكد أن الدالة موجودة في ApiService كما شرحنا سابقاً.
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen(
      {super.key, required this.receiverId, required this.receiverName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  String? _myId;
  Timer? _timer;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMyIdAndFetch();

    // ✅ بمجرد فتح الشاشة، نرسل للسيرفر أننا قرأنا الرسائل
    _markMessagesAsRead();

    // تحديث المحادثة كل 3 ثواني
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _fetchMessages(scroll: false);
        // نعيد استدعاء القراءة للتأكد في حال وصلت رسالة وأنا داخل المحادثة
        _markMessagesAsRead();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ دالة جديدة لإخبار السيرفر بقراءة الرسائل
  Future<void> _markMessagesAsRead() async {
    // يمكنك وضع هذا الكود داخل ApiService لاستدعائه بسطر واحد
    // هنا نضعه مباشرة للتوضيح أو يمكنك استخدام ApiService.markMessagesAsRead(widget.receiverId)
    try {
      final token = await ApiService.getToken();
      final url = Uri.parse('${ApiService.baseUrl}/chats/read');
      await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'senderId': widget.receiverId}),
      );
    } catch (e) {
      print("Error marking read: $e");
    }
  }

  Future<void> _loadMyIdAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _myId = prefs.getString('userId'));

    _fetchMessages(scroll: true);
  }

  Future<void> _fetchMessages({bool scroll = false}) async {
    final (ok, data) = await ApiService.getConversation(widget.receiverId);
    if (mounted && ok) {
      // تحقق بسيط لتجنب إعادة البناء إذا لم تتغير البيانات (اختياري)
      if (_messages.length != data.length) {
        setState(() {
          _messages = data;
        });
        if (scroll) _scrollToBottom();
      } else {
        // حتى لو الطول نفسه، قد نحتاج للتحديث
        setState(() {
          _messages = data;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    setState(() => _isSending = true);

    // إضافة وهمية للرسالة لتظهر فوراً
    setState(() {
      _messages.add({
        'senderId': _myId,
        'message': text,
        'createdAt': DateTime.now().toIso8601String(),
        'temp': true, // علامة أنها مؤقتة
      });
    });
    _scrollToBottom();

    final (ok, _) = await ApiService.sendMessage(
      receiverId: widget.receiverId,
      message: text,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (ok) {
        _fetchMessages(); // تحديث حقيقي من السيرفر
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to send message")));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverName),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                // إذا كان المرسل هو أنا، تظهر الرسالة على اليمين
                final bool isMe =
                    (msg['senderId'].toString() == _myId.toString());

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF2E7D32) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomRight: isMe ? const Radius.circular(0) : null,
                        bottomLeft: !isMe ? const Radius.circular(0) : null,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          msg['message'] ?? "",
                          style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('h:mm a')
                              .format(DateTime.parse(msg['createdAt'])),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        // ✅ إضافة علامة صحين للقراءة (اختياري)
                        if (isMe && msg['isRead'] == true)
                          const Icon(Icons.done_all,
                              size: 14, color: Colors.white70)
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF2E7D32),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
