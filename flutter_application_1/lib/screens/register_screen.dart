// lib/screens/register_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _autoValidate = false;
  String? _errorMessage;
  bool _hovering = false;
  
  // ✅ 2️⃣ المتغير الجديد لحالة ظهور رسالة التفعيل
  bool _showVerificationMessage = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  // ✅ 1️⃣ الـ Widget الخاص برسالة النجاح
  Widget verificationSuccessBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // أخضر فاتح
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2E7D32),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.mark_email_read_outlined,
            color: Color(0xFF2E7D32),
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Account created successfully. Please check your email to verify your account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    setState(() {
      _autoValidate = true;
      _showVerificationMessage = false; // إخفاء رسالة النجاح السابقة إن وجدت
      _errorMessage = null; // إخفاء رسالة الخطأ السابقة
    });
    
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
    });

    final (ok, msg) = await ApiService.register(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text.trim(),
    );

    setState(() => _loading = false);

    // ✅ 3️⃣ تعديل المنطق عند النجاح
    if (ok) {
      if (!mounted) return;

      setState(() {
        _showVerificationMessage = true; // إظهار المستطيل الأخضر
        _errorMessage = null; // التأكد من اختفاء أي خطأ
      });
      
      // مسح الحقول (اختياري، لجمالية الواجهة)
      _name.clear();
      _email.clear();
      _password.clear();
      _confirmPassword.clear();
      _autoValidate = false;

      return; // ❗ عدم الانتقال لصفحة الدخول
    } else {
      setState(() {
        _errorMessage = msg.isNotEmpty ? msg : 'Registration failed';
        _showVerificationMessage = false;
      });
    }
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return regex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Stack(
        children: [
          // الخلفية
          if (!isMobile) ...[
            Positioned.fill(
              child: Image.asset(
                'assets/images/SHAQATI_LOGIN.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withOpacity(0.35)),
              ),
            ),
          ] else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF1F7F2), Color(0xFFDDEEE0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

          // الفورم
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Card(
                      color: Colors.white.withOpacity(0.93),
                      elevation: 25,
                      shadowColor: green.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: _autoValidate
                              ? AutovalidateMode.always
                              : AutovalidateMode.disabled,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_add_alt_1_rounded,
                                color: green,
                                size: 36,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: green,
                                ),
                              ),
                              const SizedBox(height: 25),

                              // ✅ 4️⃣ عرض مستطيل النجاح هنا
                              if (_showVerificationMessage) verificationSuccessBox(),

                              // 🔔 رسالة الخطأ (تظهر فقط إذا لم يكن هناك نجاح)
                              if (_errorMessage != null && !_showVerificationMessage)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFBC02D),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Color(0xFFF57C00),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFFF57C00),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // 👤 Full Name
                              TextFormField(
                                controller: _name,
                                decoration: _inputDecoration(
                                  'Full Name',
                                  icon: Icons.person_outline,
                                ),
                                validator: (v) =>
                                    v!.isEmpty ? 'Enter your name' : null,
                              ),
                              const SizedBox(height: 15),

                              // ✉️ Email
                              TextFormField(
                                controller: _email,
                                decoration: _inputDecoration(
                                  'Email',
                                  icon: Icons.email_outlined,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Enter your email';
                                  } else if (!_isValidEmail(v)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),

                              // 🔒 Password
                              TextFormField(
                                controller: _password,
                                obscureText: _obscurePassword,
                                decoration: _inputDecoration(
                                  'Password',
                                  icon: Icons.lock_outline,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) => v!.length < 6
                                    ? 'Password must be at least 6 chars'
                                    : null,
                              ),
                              const SizedBox(height: 15),

                              // ✅ Confirm Password
                              TextFormField(
                                controller: _confirmPassword,
                                obscureText: true,
                                decoration: _inputDecoration(
                                  'Confirm Password',
                                  icon: Icons.check_circle_outline,
                                ),
                                validator: (v) => v != _password.text
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                              const SizedBox(height: 25),

                              // 🌈 Register Button
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: _loading ? null : _register,
                                  child: _loading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        )
                                      : const Text(
                                          'Create Account',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 🖱️ رابط Login مع Hover + Cursor
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account?',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                  const SizedBox(width: 6),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) =>
                                        setState(() => _hovering = true),
                                    onExit: (_) =>
                                        setState(() => _hovering = false),
                                    child: GestureDetector(
                                      onTap: () => Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
                                        ),
                                      ),
                                      child: AnimatedDefaultTextStyle(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _hovering
                                              ? Colors.lightGreen[700]
                                              : green,
                                          decoration: _hovering
                                              ? TextDecoration.underline
                                              : TextDecoration.none,
                                        ),
                                        child: const Text('Login'),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    required IconData icon,
    Widget? suffix,
  }) {
    const green = Color(0xFF2E7D32);
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: green),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: green, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
      ),
    );
  }
}