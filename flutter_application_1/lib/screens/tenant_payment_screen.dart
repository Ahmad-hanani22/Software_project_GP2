import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

class TenantPaymentScreen extends StatefulWidget {
  final String contractId;
  final double amount;
  final Map<String, dynamic> property;

  const TenantPaymentScreen({
    super.key,
    required this.contractId,
    required this.amount,
    required this.property,
  });

  @override
  State<TenantPaymentScreen> createState() => _TenantPaymentScreenState();
}

class _TenantPaymentScreenState extends State<TenantPaymentScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  bool _isPaying = false;
  bool _testMode = true;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isPaying = true);
    final method = _testMode ? 'test_visa' : 'visa';

    final (ok, msg) = await ApiService.addPayment(
      contractId: widget.contractId,
      amount: widget.amount,
      method: method,
    );

    if (!mounted) return;
    setState(() => _isPaying = false);

    if (ok) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment Successful'),
          content: const Text(
            'Your payment has been successfully submitted.\nThe payment will appear in your payment history and the admin will be notified.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${msg.toString().replaceAll('❌', '').trim()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm Your Booking',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Property: ${property['title'] ?? ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Total Amount: \$${widget.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Card Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cardNameController,
                decoration: const InputDecoration(
                  labelText: 'Cardholder Name',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: '1234 5678 9012 3456',
                ),
                maxLength: 19,
                validator: (v) {
                  if (v == null || v.replaceAll(' ', '').length < 12) {
                    return 'Please enter a valid card number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      decoration: const InputDecoration(
                        labelText: 'Expiry (MM/YY)',
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                      ),
                      maxLength: 4,
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.length < 3) ? 'Invalid CVV' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: _testMode,
                    onChanged: (v) => setState(() => _testMode = v),
                  ),
                  const Expanded(
                    child: Text(
                      'Test Payment Mode (uses fake Visa, no real charge)',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isPaying ? null : _submitPayment,
                  child: _isPaying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Pay Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
