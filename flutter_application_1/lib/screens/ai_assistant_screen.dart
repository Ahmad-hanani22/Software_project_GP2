// screens/ai_assistant_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/services/ai_service.dart';
import 'package:flutter_application_1/screens/property_details_screen.dart';
import 'package:flutter_application_1/screens/contract_details_screen.dart';
import 'package:flutter_application_1/screens/expenses_management_screen.dart';
import 'package:flutter_application_1/screens/deposits_management_screen.dart';
import 'package:flutter_application_1/screens/invoices_screen.dart';
import 'package:intl/intl.dart';

class AIAssistantScreen extends StatefulWidget {
  final String? initialQuery;

  const AIAssistantScreen({super.key, this.initialQuery});

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
        text: widget.initialQuery != null
            ? '🤖 I\'m ready to help you!'
            : '''
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

    // If initial query is provided, send it automatically
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      // Wait a bit for UI to initialize
      Future.delayed(const Duration(milliseconds: 500), () {
        _sendMessage(quickQuestion: widget.initialQuery);
      });
    } else {
      _addQuickActions();
    }
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

    final (success, response, data) = await AIService.askAI(question: question);

    setState(() {
      _isLoading = false;

      // ✅ استخراج جميع أنواع البيانات من الاستجابة
      List<Map<String, dynamic>>? properties;
      String? dataType;
      Map<String, dynamic>? messageData;

      if (data != null) {
        dataType = data['dataType'] as String?;
        messageData = data;

        // استخراج العقارات
        if (data['properties'] != null) {
          final propsList = data['properties'] as List<dynamic>?;
          if (propsList != null && propsList.isNotEmpty) {
            properties =
                propsList.map((p) => p as Map<String, dynamic>).toList();
          }
        }
      }

      _messages.add(ChatMessage(
        text: success ? response : '❌ خطأ: $response',
        isUser: false,
        properties: properties,
        dataType: dataType,
        data: messageData,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.psychology_rounded, color: Colors.white, size: 24.0),
            SizedBox(width: 8.0),
            Flexible(
              child: Text(
                'AI Assistant',
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
              size: 18.0,
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
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  message.isUser ? const Color(0xFF00695C) : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
                fontSize: 15.0,
                height: 1.4,
              ),
            ),
          ),
          // ✅ عرض جميع أنواع البيانات كأزرار قابلة للنقر
          if (message.dataType != null && message.data != null)
            ..._buildDataItems(message.dataType!, message.data!),

          // ✅ عرض العقارات (للتوافق مع الكود القديم)
          if (message.properties != null && message.properties!.isNotEmpty)
            ...message.properties!.map((property) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: MediaQuery.of(context).size.width * 0.75,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      // ✅ الانتقال إلى صفحة تفاصيل العقار
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PropertyDetailsScreen(property: property),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          // صورة العقار (إن وجدت)
                          if (property['images'] != null &&
                              (property['images'] as List).isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                (property['images'] as List)[0],
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.home,
                                        color: Colors.grey),
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.home, color: Colors.grey),
                            ),
                          const SizedBox(width: 12),
                          // معلومات العقار
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  property['title'] ?? 'عقار',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${property['city'] ?? ''} • ${property['price'] ?? 0}\$',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                if (property['bedrooms'] != null ||
                                    property['bathrooms'] != null)
                                  Text(
                                    '${property['bedrooms'] ?? 0} غرف • ${property['bathrooms'] ?? 0} حمام',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Color(0xFF00695C),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
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
              textAlign: TextAlign.right,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.none,
              maxLines: null,
              minLines: 1,
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

  // ✅ بناء عناصر البيانات حسب النوع
  List<Widget> _buildDataItems(String dataType, Map<String, dynamic> data) {
    switch (dataType) {
      case 'properties':
        final properties = data['properties'] as List<dynamic>? ?? [];
        return properties
            .map((p) => _buildPropertyCard(p as Map<String, dynamic>))
            .toList();

      case 'contracts':
        final contracts = data['contracts'] as List<dynamic>? ?? [];
        return contracts
            .map((c) => _buildContractCard(c as Map<String, dynamic>))
            .toList();

      case 'payments':
        final payments = data['payments'] as List<dynamic>? ?? [];
        return payments
            .map((p) => _buildPaymentCard(p as Map<String, dynamic>))
            .toList();

      case 'maintenance':
        final requests = data['maintenanceRequests'] as List<dynamic>? ?? [];
        return requests
            .map((r) => _buildMaintenanceCard(r as Map<String, dynamic>))
            .toList();

      case 'complaints':
        final complaints = data['complaints'] as List<dynamic>? ?? [];
        return complaints
            .map((c) => _buildComplaintCard(c as Map<String, dynamic>))
            .toList();

      case 'notifications':
        final notifications = data['notifications'] as List<dynamic>? ?? [];
        return notifications
            .map((n) => _buildNotificationCard(n as Map<String, dynamic>))
            .toList();

      case 'expenses':
        final expenses = data['expenses'] as List<dynamic>? ?? [];
        return expenses
            .map((e) => _buildExpenseCard(e as Map<String, dynamic>))
            .toList();

      case 'deposits':
        final deposits = data['deposits'] as List<dynamic>? ?? [];
        return deposits
            .map((d) => _buildDepositCard(d as Map<String, dynamic>))
            .toList();

      case 'invoices':
        final invoices = data['invoices'] as List<dynamic>? ?? [];
        return invoices
            .map((i) => _buildInvoiceCard(i as Map<String, dynamic>))
            .toList();

      case 'financial':
        final List<Widget> items = [];
        if (data['expenses'] != null) {
          items.addAll((data['expenses'] as List<dynamic>)
              .map((e) => _buildExpenseCard(e as Map<String, dynamic>)));
        }
        if (data['deposits'] != null) {
          items.addAll((data['deposits'] as List<dynamic>)
              .map((d) => _buildDepositCard(d as Map<String, dynamic>)));
        }
        if (data['invoices'] != null) {
          items.addAll((data['invoices'] as List<dynamic>)
              .map((i) => _buildInvoiceCard(i as Map<String, dynamic>)));
        }
        return items;

      default:
        return [];
    }
  }

  // ✅ بطاقة العقار
  Widget _buildPropertyCard(Map<String, dynamic> property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: MediaQuery.of(context).size.width * 0.75,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PropertyDetailsScreen(property: property),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                _buildImageIcon(property['images'], Icons.home),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property['title'] ?? 'عقار',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${property['city'] ?? ''} • ${property['price'] ?? 0}\$',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (property['bedrooms'] != null ||
                          property['bathrooms'] != null)
                        Text(
                          '${property['bedrooms'] ?? 0} غرف • ${property['bathrooms'] ?? 0} حمام',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Color(0xFF00695C)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ بطاقة العقد
  Widget _buildContractCard(Map<String, dynamic> contract) {
    final contractId = contract['_id']?.toString() ?? '';
    final propertyTitle = contract['propertyId']?['title'] ??
        contract['propertyId']?['address'] ??
        'عقار';
    final status = contract['status'] ?? 'unknown';
    final rentAmount = contract['rentAmount'] ?? 0;

    return _buildGenericCard(
      icon: Icons.description,
      title: propertyTitle,
      subtitle: '${rentAmount}\$ • ${_getStatusText(status)}',
      onTap: () {
        if (contractId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ContractDetailsScreen(contractId: contractId),
            ),
          );
        }
      },
    );
  }

  // ✅ بطاقة الدفعة
  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final amount = payment['amount'] ?? 0;
    final status = payment['status'] ?? 'unknown';
    final date =
        payment['date'] != null ? _formatDate(payment['date']) : 'غير محدد';
    final propertyTitle =
        payment['contractId']?['propertyId']?['title'] ?? 'عقار';

    return _buildGenericCard(
      icon: Icons.payment,
      title: 'دفعة: ${amount}\$',
      subtitle: '$propertyTitle • $date • ${_getStatusText(status)}',
      onTap: () {
        // يمكن إضافة صفحة تفاصيل الدفعة هنا
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('دفعة: ${amount}\$ - ${_getStatusText(status)}')),
        );
      },
    );
  }

  // ✅ بطاقة طلب الصيانة
  Widget _buildMaintenanceCard(Map<String, dynamic> request) {
    final title = request['title'] ?? 'طلب صيانة';
    final status = request['status'] ?? 'unknown';
    final propertyTitle = request['propertyId']?['title'] ?? 'عقار';

    return _buildGenericCard(
      icon: Icons.build,
      title: title,
      subtitle: '$propertyTitle • ${_getStatusText(status)}',
      onTap: () {
        // يمكن إضافة صفحة تفاصيل طلب الصيانة هنا
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('طلب صيانة: $title')),
        );
      },
    );
  }

  // ✅ بطاقة الشكوى
  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    final category = complaint['category'] ?? 'شكوى';
    final status = complaint['status'] ?? 'unknown';

    return _buildGenericCard(
      icon: Icons.report_problem,
      title: category,
      subtitle: _getStatusText(status),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('شكوى: $category')),
        );
      },
    );
  }

  // ✅ بطاقة الإشعار
  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'إشعار';
    final message = notification['message'] ?? '';
    final isRead = notification['read'] ?? false;

    return _buildGenericCard(
      icon: Icons.notifications,
      title: title,
      subtitle: message,
      isRead: isRead,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(title)),
        );
      },
    );
  }

  // ✅ بطاقة المصروف
  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final amount = expense['amount'] ?? 0;
    final category = expense['category'] ?? 'مصروف';
    final date =
        expense['date'] != null ? _formatDate(expense['date']) : 'غير محدد';

    return _buildGenericCard(
      icon: Icons.money_off,
      title: '$category: ${amount}\$',
      subtitle: date,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpensesManagementScreen(),
          ),
        );
      },
    );
  }

  // ✅ بطاقة الوديعة
  Widget _buildDepositCard(Map<String, dynamic> deposit) {
    final amount = deposit['amount'] ?? 0;
    final date =
        deposit['date'] != null ? _formatDate(deposit['date']) : 'غير محدد';

    return _buildGenericCard(
      icon: Icons.account_balance_wallet,
      title: 'وديعة: ${amount}\$',
      subtitle: date,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DepositsManagementScreen(),
          ),
        );
      },
    );
  }

  // ✅ بطاقة الفاتورة
  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final amount = invoice['amount'] ?? 0;
    final date =
        invoice['date'] != null ? _formatDate(invoice['date']) : 'غير محدد';
    final status = invoice['status'] ?? 'unknown';

    return _buildGenericCard(
      icon: Icons.receipt,
      title: 'فاتورة: ${amount}\$',
      subtitle: '$date • ${_getStatusText(status)}',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InvoicesScreen(),
          ),
        );
      },
    );
  }

  // ✅ بطاقة عامة
  Widget _buildGenericCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isRead = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: MediaQuery.of(context).size.width * 0.75,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: isRead ? Colors.grey[100] : Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF00695C), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 16, color: Color(0xFF00695C)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ مساعد: بناء أيقونة الصورة
  Widget _buildImageIcon(dynamic images, IconData fallbackIcon) {
    if (images != null && images is List && images.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          images[0],
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(fallbackIcon, color: Colors.grey),
            );
          },
        ),
      );
    }
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(fallbackIcon, color: Colors.grey),
    );
  }

  // ✅ مساعد: تنسيق التاريخ
  String _formatDate(dynamic date) {
    try {
      if (date is String) {
        final parsed = DateTime.parse(date);
        return DateFormat('yyyy-MM-dd').format(parsed);
      }
      return 'غير محدد';
    } catch (e) {
      return 'غير محدد';
    }
  }

  // ✅ مساعد: نص الحالة
  String _getStatusText(String status) {
    const statusMap = {
      'active': 'فعال',
      'pending': 'قيد الانتظار',
      'expired': 'منتهي',
      'paid': 'مدفوع',
      'unpaid': 'غير مدفوع',
      'completed': 'مكتمل',
      'in_progress': 'قيد التنفيذ',
      'resolved': 'محلول',
      'open': 'مفتوح',
    };
    return statusMap[status.toLowerCase()] ?? status;
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
  final List<Map<String, dynamic>>? properties; // ✅ العقارات المرتبطة بالرسالة
  final String?
      dataType; // ✅ نوع البيانات (properties, contracts, payments, etc.)
  final Map<String, dynamic>? data; // ✅ جميع البيانات المرتبطة بالرسالة

  ChatMessage({
    required this.text,
    this.isUser = false,
    this.showQuickActions = false,
    this.properties,
    this.dataType,
    this.data,
  });
}
