import 'package:flutter/material.dart';

// --- 1. صفحة اتصل بنا الاحترافية ---
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Contact Support"),
          backgroundColor: const Color(0xFF2E7D32)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("We'd love to hear from you!",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
                "Fill out the form below and we'll respond within 24 hours.",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            _buildTextField("Full Name", Icons.person),
            const SizedBox(height: 16),
            _buildTextField("Email Address", Icons.email),
            const SizedBox(height: 16),
            _buildTextField("Subject", Icons.title),
            const SizedBox(height: 16),
            _buildTextField("Message", Icons.message, maxLines: 5),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Message sent successfully!")));
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.send),
                label: const Text("Send Message"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 30),
            _buildContactInfoTile(Icons.phone, "+970 599 123 456"),
            _buildContactInfoTile(Icons.email, "support@shaqati.com"),
            _buildContactInfoTile(Icons.location_on, "Nablus, Palestine"),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildContactInfoTile(IconData icon, String text) {
    return ListTile(
      leading: CircleAvatar(
          backgroundColor: Colors.green[50],
          child: Icon(icon, color: const Color(0xFF2E7D32))),
      title: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

// --- 2. صفحة المساعدة والأسئلة الشائعة ---
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Help & FAQ"),
          backgroundColor: const Color(0xFF2E7D32)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Frequently Asked Questions",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildExpansionTile("How do I rent a property?",
              "Simply browse properties, click on one you like, and hit 'Rent Now'. The landlord will receive your request."),
          _buildExpansionTile("Is payment secure?",
              "Yes, we use encrypted payment gateways to ensure your safety."),
          _buildExpansionTile("Can I cancel a contract?",
              "Cancellation policies depend on the landlord. Please check the contract terms."),
          _buildExpansionTile("How to report an issue?",
              "Go to your Dashboard > Maintenance, and submit a request with photos."),
          _buildExpansionTile("Do you offer tourism services?",
              "Yes! Check out our 'Lifestyle & Services' section for trips and luxury additions."),
        ],
      ),
    );
  }

  Widget _buildExpansionTile(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(content, style: const TextStyle(color: Colors.black87)),
          )
        ],
      ),
    );
  }
}
