// screens/ai_assistant_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/ai_service.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<String> _sessionHistory = []; // ✅ Session Memory (آخر 5 أسئلة)
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    setState(() {
      _messages.add(ChatMessage(
        text: '''
مرحباً! أنا مساعدك الذكي 🧠

يمكنني مساعدتك في:
• تحليل بنية مشروع SHAQATI
• الإجابة على أسئلة حول الكود
• اقتراح تحسينات
• شرح الميزات والوظائف
• حل المشاكل التقنية

اكتب سؤالك أو اختر أحد الخيارات السريعة...
''',
        isUser: false,
      ));
      _isInitialized = true;
    });
    _scrollToBottom();
    _addQuickActions();
  }

  void _addQuickActions() {
    setState(() {
      _messages.add(ChatMessage(
        text: '',
        isUser: false,
        showQuickActions: true,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _sendMessage({String? quickQuestion}) async {
    final question = quickQuestion ?? _controller.text.trim();
    if (question.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: question, isUser: true));
      _isLoading = true;
      _controller.clear();

      // ✅ حفظ في Session Memory (آخر 5 أسئلة)
      _sessionHistory.add(question);
      if (_sessionHistory.length > 5) {
        _sessionHistory.removeAt(0);
      }
    });
    _scrollToBottom();

    // إزالة Quick Actions
    _messages.removeWhere((msg) => msg.showQuickActions == true);

    final (success, response, _) = await AIService.askAI(question: question);

    setState(() {
      _isLoading = false;
      _messages.add(ChatMessage(
        text: success ? response : '❌ خطأ: $response',
        isUser: false,
      ));
      _addQuickActions(); // ✅ أزرار ذكية تتغير حسب السياق
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
        title: const Row(
          children: [
            Icon(Icons.psychology_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('AI Assistant'),
          ],
        ),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('مساعدة'),
                  content: const Text(
                    'يمكنك طرح أي سؤال عن مشروع SHAQATI. '
                    'إذا سألت عن الكود أو المشروع، سأبحث في ملفات المشروع تلقائياً.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('حسناً'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isInitialized
                ? ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final message = _messages[index];

                      if (message.showQuickActions == true) {
                        return _buildQuickActions();
                      }

                      return _buildMessageBubble(message);
                    },
                  )
                : const Center(
                    child: CircularProgressIndicator(),
                  ),
          ),
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    // ✅ أزرار ذكية ديناميكية حسب السياق
    List<String> quickQuestions = [];

    // إذا لم تكن هناك أسئلة سابقة → أسئلة عامة
    if (_sessionHistory.isEmpty) {
      quickQuestions = [
        'حلل بنية مشروع SHAQATI',
        'اشرح نظام العقود',
        'كيف يعمل نظام الدفعات؟',
        'ما هي الأدوار في النظام؟',
      ];
    }
    // إذا كان المستخدم يتحدث عن العقارات
    else if (_sessionHistory.any(
        (q) => q.contains('عقار') || q.contains('شقة') || q.contains('منزل'))) {
      quickQuestions = [
        'اقترح عقارات ضمن ميزانيتي',
        'أرخص من اللي شفته',
        'قريب من الجامعة',
        'متاح فوراً',
      ];
    }
    // إذا كان المستخدم يتحدث عن العقود
    else if (_sessionHistory.any((q) =>
        q.contains('عقد') || q.contains('إيجار') || q.contains('عقدة'))) {
      quickQuestions = [
        'كيف أبدأ عقد جديد؟',
        'ما هي مدة العقد؟',
        'كيف أحسب الإيجار؟',
        'ما هي شروط العقد؟',
      ];
    }
    // إذا كان المستخدم يسأل عن الميزات
    else if (_sessionHistory.any((q) =>
        q.contains('ميزة') || q.contains('feature') || q.contains('وظيفة'))) {
      quickQuestions = [
        'ما هي ميزات النظام؟',
        'كيف أستخدم الصيانة؟',
        'كيف أقدم شكوى؟',
        'كيف أرسل رسالة؟',
      ];
    }
    // أسئلة عامة أخرى
    else {
      quickQuestions = [
        'أعطني ملخص المشروع',
        'ما هي التقنيات المستخدمة؟',
        'كيف أصلح مشكلة؟',
        'أخبرني أكثر',
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: quickQuestions.map((q) {
          return ActionChip(
            label: Text(q),
            onPressed: () => _sendMessage(quickQuestion: q),
            backgroundColor: const Color(0xFF00695C).withOpacity(0.1),
            labelStyle: const TextStyle(color: Color(0xFF00695C)),
            avatar: const Icon(
              Icons.bolt,
              size: 18,
              color: Color(0xFF00695C),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF00695C) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'اكتب سؤالك...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isLoading,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isLoading ? Colors.grey : const Color(0xFF00695C),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool showQuickActions;

  ChatMessage({
    required this.text,
    this.isUser = false,
    this.showQuickActions = false,
  });
}
