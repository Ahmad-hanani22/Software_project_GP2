import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/smart_system_screen.dart';

/// 🧠 Premium Floating Smart Button
class FloatingSmartButton extends StatelessWidget {
  const FloatingSmartButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SmartSystemScreen(),
          ),
        );
      },
      backgroundColor: Colors.red[600],
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(
        Icons.psychology_rounded,
        size: 24,
      ),
      label: const Text(
        'Smart',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
