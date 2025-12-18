import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';
import 'package:intl/intl.dart';

const Color _primaryBeige = Color(0xFFD4B996);
const Color _accentGreen = Color(0xFF2E7D32);
const Color _scaffoldBackground = Color(0xFFFAF9F6);
const Color _textPrimary = Color(0xFF4E342E);

class InvoicesScreen extends StatefulWidget {
  final String? contractId;

  const InvoicesScreen({
    super.key,
    this.contractId,
  });

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    setState(() => _isLoading = true);
    final (ok, data) = await ApiService.getAllInvoices(
      contractId: widget.contractId,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (ok) {
        _invoices = data as List<dynamic>;
      } else {
        _errorMessage = data.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير'),
        backgroundColor: _primaryBeige,
        foregroundColor: _textPrimary,
      ),
      backgroundColor: _scaffoldBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _invoices.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد فواتير',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchInvoices,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _invoices.length,
                        itemBuilder: (ctx, idx) {
                          final invoice = _invoices[idx];
                          final invoiceNumber = invoice['invoiceNumber'] ?? 'N/A';
                          final total = invoice['total'] ?? 0;
                          final issuedAt = invoice['issuedAt'] != null
                              ? DateTime.parse(invoice['issuedAt'])
                              : null;

                          final payment = invoice['paymentId'];
                          String paymentInfo = 'دفع';
                          if (payment is Map) {
                            paymentInfo = 'دفع: \$${payment['amount'] ?? 0}';
                          }

                          final contract = invoice['contractId'];
                          String tenantName = 'مستأجر';
                          if (contract is Map) {
                            final tenant = contract['tenantId'];
                            if (tenant is Map) {
                              tenantName = tenant['name'] ?? 'N/A';
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: _accentGreen,
                                child: Icon(Icons.receipt, color: Colors.white),
                              ),
                              title: Text(
                                invoiceNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tenantName),
                                  if (issuedAt != null)
                                    Text(
                                      DateFormat('yyyy-MM-dd').format(issuedAt),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    paymentInfo,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    NumberFormat.currency(symbol: '\$')
                                        .format(total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _accentGreen,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (invoice['pdfUrl'] != null)
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf,
                                          color: Colors.red),
                                      onPressed: () {
                                        // TODO: فتح PDF
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('فتح PDF'),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                              onTap: () {
                                // TODO: عرض تفاصيل الفاتورة
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

