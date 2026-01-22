import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String _formatCardNumber(String input) {
    final digits = input.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  bool _isExpiryValid(String value) {
    if (value.length != 5 || !value.contains('/')) return false;
    final parts = value.split('/');
    final mm = int.tryParse(parts[0]);
    final yy = int.tryParse(parts[1]);
    if (mm == null || yy == null) return false;
    if (mm < 1 || mm > 12) return false;
    final now = DateTime.now();
    final year = 2000 + yy;
    final exp = DateTime(year, mm + 1, 0);
    return exp.isAfter(DateTime(now.year, now.month, now.day));
  }

  bool _luhnValid(String number) {
    final digits = number.replaceAll(' ', '');
    if (digits.length < 12) return false;
    int sum = 0;
    bool alt = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.parse(digits[i]);
      if (alt) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alt = !alt;
    }
    return sum % 10 == 0;
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
          title: const Text('Payment successful 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount: \$${widget.amount.toStringAsFixed(2)}'),
              const SizedBox(height: 4),
              Text('Contract: ${widget.contractId}'),
              const SizedBox(height: 4),
              Text('Date: ${DateTime.now()}'),
              const SizedBox(height: 12),
              const Text(
                'A receipt will be generated and available in your payment history.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text('Back to payments'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment failed: ${msg.toString().replaceAll('❌', '').trim()}'),
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
              // Payment summary card
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: const Icon(Icons.home_work_rounded),
                  title: Text(property['title']?.toString() ?? 'Property'),
                  subtitle: Text("Contract: ${widget.contractId}"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "\$${widget.amount.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        "Amount due",
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Visual card preview
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox.shrink(),
                    const SizedBox(height: 16),
                    Text(
                      _cardNumberController.text.isEmpty
                          ? "**** **** **** ****"
                          : _formatCardNumber(_cardNumberController.text),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "CARDHOLDER",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                            Text(
                              _cardNameController.text.isEmpty
                                  ? "YOUR NAME"
                                  : _cardNameController.text.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "EXPIRY",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                            Text(
                              _expiryController.text.isEmpty
                                  ? "MM/YY"
                                  : _expiryController.text,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Text(
                'Card details',
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
                onChanged: (v) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: '1234 5678 9012 3456',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final text = _formatCardNumber(newValue.text);
                    return TextEditingValue(
                      text: text,
                      selection: TextSelection.collapsed(offset: text.length),
                    );
                  }),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter a card number';
                  }
                  if (!_luhnValid(v)) {
                    return 'Card number is not valid';
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
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Expiry (MM/YY)',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          var text = newValue.text;
                          if (text.length >= 3) {
                            text =
                                '${text.substring(0, 2)}/${text.substring(2)}';
                          }
                          return TextEditingValue(
                            text: text,
                            selection:
                                TextSelection.collapsed(offset: text.length),
                          );
                        }),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Required';
                        }
                        if (!_isExpiryValid(v)) {
                          return 'Expiry date is not valid';
                        }
                        return null;
                      },
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
                      'Test mode – no real card will be charged.\nUse this for demo and grading only.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_testMode) ...[
                Row(
                  children: const [
                    Chip(
                      avatar: Icon(Icons.credit_card, size: 16),
                      label: Text('FAKE VISA 4242 4242 4242 4242'),
                    ),
                  ],
                ),
              ],
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
