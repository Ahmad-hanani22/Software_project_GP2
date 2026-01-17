import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/smart_system_screen.dart';
import 'package:flutter_application_1/screens/ai_assistant_screen.dart';

/// 🧠 Premium Floating Smart Button
class FloatingSmartButton extends StatelessWidget {
  const FloatingSmartButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // زر AI Assistant الرئيسي
        FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AIAssistantScreen(),
              ),
            );
          },
          backgroundColor: const Color(0xFF00695C),
          foregroundColor: Colors.white,
          elevation: 6,
          icon: const Icon(
            Icons.psychology_rounded,
            size: 24,
          ),
          label: const Text(
            'AI Assistant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 12),
        // زر النظام الذكي القديم (اختياري)
        FloatingActionButton.small(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SmartSystemScreen(),
              ),
            );
          },
          backgroundColor: Colors.grey[600],
          child: const Icon(Icons.auto_awesome, color: Colors.white),
        ),
      ],
    );
  }
}
