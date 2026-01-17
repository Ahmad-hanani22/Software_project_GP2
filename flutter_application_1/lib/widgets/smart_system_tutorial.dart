import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartSystemTutorial {
  static const String _tutorialCompletedKey = 'smart_system_tutorial_completed';

  static Future<bool> shouldShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_tutorialCompletedKey) ?? false);
  }

  static Future<void> markTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialCompletedKey, true);
  }

  static Future<void> resetTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialCompletedKey, false);
  }
}

class TutorialStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final Alignment alignment;
  final EdgeInsets padding;

  TutorialStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.alignment = Alignment.bottomCenter,
    this.padding = const EdgeInsets.all(16),
  });
}

class _TutorialStepOverlay extends StatelessWidget {
  final TutorialStep step;
  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TutorialStepOverlay({
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final RenderBox? renderBox = step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset? position = renderBox?.localToGlobal(Offset.zero);
    final Size? size = renderBox?.size;

    if (position == null || size == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onNext,
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Stack(
          children: [
            // Highlight area
            Positioned(
              left: position.dx - step.padding.left,
              top: position.dy - step.padding.top,
              child: Container(
                width: size.width + step.padding.horizontal,
                height: size.height + step.padding.vertical,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
            // Tooltip
            Positioned(
              left: 20,
              right: 20,
              bottom: 100,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        Text(
                          '$stepNumber / $totalSteps',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: onSkip,
                          child: const Text('Skip Tutorial'),
                        ),
                        ElevatedButton(
                          onPressed: onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(stepNumber == totalSteps ? 'Finish' : 'Next'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TutorialOverlayManager {
  static OverlayEntry? _currentOverlay;

  static void showTutorialStep(
    BuildContext context,
    TutorialStep step,
    int stepNumber,
    int totalSteps,
    VoidCallback onNext,
    VoidCallback onSkip,
  ) {
    if (_currentOverlay != null) {
      _currentOverlay!.remove();
    }

    _currentOverlay = OverlayEntry(
      builder: (context) => _TutorialStepOverlay(
        step: step,
        stepNumber: stepNumber,
        totalSteps: totalSteps,
        onNext: onNext,
        onSkip: onSkip,
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  static void hideTutorial() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}
