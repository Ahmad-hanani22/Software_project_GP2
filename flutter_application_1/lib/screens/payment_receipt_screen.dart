import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color _primaryGreen = Color(0xFF2E7D32);
const Color _textDark = Color(0xFF263238);
const Color _textLight = Color(0xFF78909C);

class PaymentReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> payment;

  const PaymentReceiptScreen({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final receipt = payment['receipt'] ?? {};
    final amount = payment['amount'] ?? 0;
    final date = payment['date'] != null ? DateTime.parse(payment['date']) : null;
    final receiptDate = receipt['receiptDate'] != null 
        ? DateTime.parse(receipt['receiptDate']) 
        : date;
    final receiptTime = receipt['receiptTime'] ?? '';
    final receiptNumber = receipt['receiptNumber'] ?? 'N/A';
    final paymentMethod = receipt['paymentMethod'] ?? payment['method'] ?? 'N/A';
    final referenceNumber = receipt['referenceNumber'] ?? 'N/A';
    final notes = receipt['notes'] ?? '';
    final contract = payment['contractId'] ?? {};
    final property = contract['propertyId'] ?? {};
    final tenant = contract['tenantId'] ?? {};
    final landlord = contract['landlordId'] ?? {};

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('سند قبض'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _primaryGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: _primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'سند قبض',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Receipt Number: $receiptNumber',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                
                // Payment Details
                _buildSectionTitle('تفاصيل الدفعة'),
                const SizedBox(height: 12),
                _buildInfoRow('المبلغ', '\$${amount.toStringAsFixed(2)}', Icons.attach_money),
                _buildInfoRow('طريقة الدفع', paymentMethod, Icons.payment),
                if (referenceNumber != 'N/A')
                  _buildInfoRow('رقم المرجع', referenceNumber, Icons.tag),
                
                const SizedBox(height: 24),
                const Divider(),
                
                // Date & Time
                _buildSectionTitle('التاريخ والوقت'),
                const SizedBox(height: 12),
                if (receiptDate != null)
                  _buildInfoRow('التاريخ', DateFormat('yyyy-MM-dd').format(receiptDate), Icons.calendar_today),
                if (receiptTime.isNotEmpty)
                  _buildInfoRow('الوقت', receiptTime, Icons.access_time),
                
                const SizedBox(height: 24),
                const Divider(),
                
                // Contract Details
                _buildSectionTitle('تفاصيل العقد'),
                const SizedBox(height: 12),
                if (property['title'] != null)
                  _buildInfoRow('العقار', property['title'], Icons.home),
                if (tenant['name'] != null)
                  _buildInfoRow('المستأجر', tenant['name'], Icons.person),
                if (landlord['name'] != null)
                  _buildInfoRow('المالك', landlord['name'], Icons.business_center),
                
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  _buildSectionTitle('ملاحظات'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notes,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Receipt Image if available
                if (payment['receiptUrl'] != null && payment['receiptUrl'].toString().isNotEmpty) ...[
                  const Divider(),
                  _buildSectionTitle('صورة الوصل'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        payment['receiptUrl'],
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, color: _primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'تم الدفع بنجاح',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: _textDark,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _textLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
