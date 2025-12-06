import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/api_service.dart';

// ألوان التطبيق
const Color kPrimaryColor = Color(0xFF2E7D32);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PageController _pageController = PageController();

  // Controllers
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _isLoading = false;
  int _currentStep = 0; // 0: Email, 1: OTP & New Password

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // الخطوة 1: إرسال الكود
  Future<void> _sendCode() async {
    if (_emailCtrl.text.isEmpty || !_emailCtrl.text.contains('@')) {
      _showSnack("Please enter a valid email", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    final (ok, msg) = await ApiService.forgotPassword(_emailCtrl.text.trim());
    setState(() => _isLoading = false);

    if (ok) {
      _showSnack(msg, kPrimaryColor);
      // الانتقال للصفحة التالية
      _pageController.nextPage(
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      setState(() => _currentStep = 1);
    } else {
      _showSnack(msg, Colors.red);
    }
  }

  // الخطوة 2: تغيير كلمة المرور
  Future<void> _resetPassword() async {
    if (_otpCtrl.text.length < 6) {
      _showSnack("Please enter the 6-digit code", Colors.red);
      return;
    }
    if (_passCtrl.text.length < 6) {
      _showSnack("Password must be at least 6 characters", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    final (ok, msg) = await ApiService.resetPassword(
      email: _emailCtrl.text.trim(),
      otp: _otpCtrl.text.trim(),
      newPassword: _passCtrl.text.trim(),
    );
    setState(() => _isLoading = false);

    if (ok) {
      if (!mounted) return;
      // إظهار رسالة نجاح والعودة لتسجيل الدخول
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: kPrimaryColor, size: 50),
          title: const Text("Success!"),
          content: const Text("Your password has been reset successfully."),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // إغلاق الديالوج
                  Navigator.pop(context); // العودة لشاشة الدخول
                },
                child: const Text("Login Now"))
          ],
        ),
      );
    } else {
      _showSnack(msg, Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_currentStep == 1) {
              _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease);
              setState(() => _currentStep = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400), // تحسين للويب
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(
                  _currentStep == 0 ? Icons.lock_reset : Icons.mark_email_read,
                  size: 80,
                  color: kPrimaryColor,
                ),
                const SizedBox(height: 20),
                Text(
                  _currentStep == 0 ? "Forgot Password?" : "Reset Password",
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  _currentStep == 0
                      ? "Enter your email address to receive a verification code."
                      : "Enter the code sent to ${_emailCtrl.text}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics:
                        const NeverScrollableScrollPhysics(), // منع السحب اليدوي
                    children: [
                      // --- Step 1: Input Email ---
                      Column(
                        children: [
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: "Email Address",
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text("Send Code",
                                      style: TextStyle(fontSize: 16)),
                            ),
                          ),
                        ],
                      ),

                      // --- Step 2: Input OTP & New Password ---
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            TextField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 24,
                                  letterSpacing: 5,
                                  fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: "000000",
                                labelText: "Verification Code",
                                counterText: "",
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _passCtrl,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: "New Password",
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _resetPassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kPrimaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text("Reset Password",
                                        style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ],
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
}
