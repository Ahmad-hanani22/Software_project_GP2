import 'package:flutter/material.dart';

class LandlordPropertyManagementScreen extends StatelessWidget {
  const LandlordPropertyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Properties'),
        backgroundColor: const Color(0xFF1976D2),
      ),
      body: const Center(
        child: Text('Here you will manage your properties.'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Add Property'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF1976D2),
      ),
    );
  }
}
