import 'package:flutter/material.dart';

class LandlordMaintenanceScreen extends StatelessWidget {
  const LandlordMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Requests'),
        backgroundColor: const Color(0xFF1976D2), // Blue for Landlord
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.build_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Maintenance Requests',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('Review and update maintenance requests for your properties.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
